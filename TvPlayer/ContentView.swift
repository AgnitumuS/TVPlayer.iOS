//
//  ContentView.swift
//  TvPlayer
//
//  Created by CaoYu on 2020/2/4.
//  Copyright © 2020 Yu Cao. All rights reserved.
//

import SwiftUI
import AVKit
import AVFoundation
import Alamofire
import SwiftyJSON
import os.log
import RemoteImage

//var stationListUrl: String = "https://raw.githubusercontent.com/cy8018/Resources/master/tv/tv_station_list_ext.json"
//var severPrefix: String = "https://raw.githubusercontent.com/cy8018/Resources/master/tv/"
var stationListUrl: String = "https://gitee.com/cy8018/Resources/raw/master/tv/tv_station_list_ext.json"
var severPrefix: String = "https://gitee.com/cy8018/Resources/raw/master/tv/"


struct ContentView: View {
        
    @State var playerData = PlayerData()
    @State var value : Float = 0
    @State var timer: DispatchSourceTimer? = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    
    @ObservedObject var bufferInfo = BufferInfo(downloadSpeed: "", percentage: "")
    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(index: -1, name: "TV Player", logo: "", urls: [""]), sourceIndex: 0, sourceInfo: "")
    @ObservedObject var stationLoader = StationLoader(urlString: stationListUrl)
    @ObservedObject var controlInfo = ControlInfo(lastControlActiveTime: Date().timeIntervalSince1970, showControls: false)
    @EnvironmentObject var device : Device
    @Environment(\.colorScheme) var colorScheme
    
    init() {
        startNetworkMonitor()
        playerData.player = AVPlayer()
        playerData.setObserver()
        //UITableView.appearance().separatorStyle = .none
    }
    
    func startNetworkMonitor() {

        self.timer?.schedule(deadline: DispatchTime.now(), repeating: .milliseconds(1000))
        self.timer?.setEventHandler( handler: {
            DispatchQueue.main.sync {
                
                let timeNow: TimeInterval = Date().timeIntervalSince1970
                if timeNow - self.controlInfo.lastControlActiveTime > SHOW_CONTROL_TIME {
                    if self.controlInfo.showControls {
                        self.controlInfo.setShowControls(showControls: false)
                    }
                }
                
                let dataUsage = DataUsage.getDataUsage()
                let downChanged = dataUsage.wirelessWanDataReceived + dataUsage.wifiReceived - downWWAN - downWiFi
                var timeChanged = timeNow * 1000 - lastTraficMonitorTime * 1000
                if timeChanged < 1 {
                    timeChanged = 1
                }
                let downSpeedRaw = downChanged * 1000 / UInt64(timeChanged)

                downloadSpeed = getNetSpeedText(speed: downSpeedRaw)
                upWWAN = dataUsage.wirelessWanDataSent
                upWiFi = dataUsage.wifiSent
                downWWAN = dataUsage.wirelessWanDataReceived
                downWiFi = dataUsage.wifiReceived

                lastTraficMonitorTime = timeNow
                self.bufferInfo.downloadSpeed = downloadSpeed
                self.bufferInfo.setDownloadSpeed(downloadSpeed: downloadSpeed)

                os_log("Download Speed: %@", log: OSLog.default, type: .debug, downloadSpeed)
            }
        })
        
        self.timer?.resume()
    }
        
    var body: some View {
        
        VStack{
            if !self.device.isLandscape {
                HStack {
                    if currentPlayingInfo.station.urls[0].count > 0 {
                        if self.colorScheme == .dark && currentPlayingInfo.station.name.contains("CCTV") {
                            RemoteImage(type: .url(URL(string: severPrefix + "logo/" + currentPlayingInfo.station.logo)!), errorView: { error in
                                Text(error.localizedDescription)
                            }, imageView: { image in
                                image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            }, loadingView: {
                                Text("")
                            })
                            .frame(width: 40, height: 18)
                            .padding(1)
                            .background(Color(red: 0.35, green: 0.35, blue: 0.35))
                            .cornerRadius(6)
                        }
                        else {
                            RemoteImage(type: .url(URL(string: severPrefix + "logo/" + currentPlayingInfo.station.logo)!), errorView: { error in
                                Text(error.localizedDescription)
                            }, imageView: { image in
                                image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            }, loadingView: {
                                Text("")
                            })
                            .frame(width: 40, height: 30)
                            .padding(1)
                        }
                    }
                    else {
                        Text("  ")
                        .bold()
                        .font(.system(size: 26))
                    }
                    
                    Text(currentPlayingInfo.station.name)
                        .bold()
                        .font(.system(size: 26))
                        .lineLimit(1)
                    Spacer()
                    Button (action: {
                        self.currentPlayingInfo.setCurrentSource(
                            sourceIndex: switchSource(
                                playerData: self.playerData,
                                station: self.currentPlayingInfo.station,
                                sourceIndex: self.currentPlayingInfo.sourceIndex,
                                direction: .forward
                            )
                        )
                    })
                    {
                        Text(self.currentPlayingInfo.sourceInfo)
                        //.bold()
                        .font(.system(size: 21))
                        .foregroundColor(Color.gray)
                        .frame(alignment: .trailing)
                        .lineLimit(1)

                        Image(systemName: "arrow.right.arrow.left.square.fill")
                        .foregroundColor(Color.gray)
                        .opacity(self.currentPlayingInfo.sourceInfo.count > 0 ? 1 : 0)
                        .font(.system(size: 23))
                    }
                    .padding(.leading, 7.0)
                    .padding(.trailing, 7.0)
                    .padding(.top, 3.0)
                    .padding(.bottom, 3.0)
                    .overlay(
                    RoundedRectangle(cornerRadius: 6)
                    .stroke(lineWidth: 2)
                    .foregroundColor(Color.gray)
                    .opacity(self.currentPlayingInfo.sourceInfo.count > 0 ? 1 : 0)
                    )
                }
                .padding(.top, 5.0)
                .padding(.bottom, 0.0)
                .padding(.leading, 10.0)
                .padding(.trailing, 12.0)
            }
            ZStack {
                VideoPlayer(playerData: $playerData)
                .aspectRatio(1.778, contentMode: .fit)
                
                if showLogo {
                    Image("tv_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: self.device.isLandscape ? 280 : 150, height: self.device.isLandscape ? 180 : 100)
                }
                
                if self.playerData.playbackStatus == PlaybackStatus.loading {
                    if self.device.isLandscape {
                        LoadingView(speedString: self.$bufferInfo.downloadSpeed)
                    }
                    else {
                        LoadingView(speedString: self.$bufferInfo.downloadSpeed)
                        .offset(y: -15)
                    }
                }
                else if self.playerData.playbackStatus == PlaybackStatus.error {
                    ErrorView()
                }
                if self.controlInfo.showControls {
                    Controls(
                        playerData: self.$playerData,
                        currentPlayingInfo: self.currentPlayingInfo,
                        bufferInfo: self.bufferInfo,
                        controlInfo: self.controlInfo,
                        value: self.$value,
                        stationList: self.$stationLoader.stations
                    )
                }
                
                HStack {
                    Spacer()
                    GeometryReader{_ in
                        NavigationView {
                            List {
                                ForEach(self.stationLoader.stations) { station in

                                    StationRowLandscape(
                                        playerData: self.$playerData,
                                        currentPlayingInfo:
                                        self.currentPlayingInfo,
                                        selectedStationIndex: self.$currentPlayingInfo.station.index,
                                        station: station
                                    )
                                    .listRowBackground(self.currentPlayingInfo.station.index == station.index ? Color(red: 0.35, green: 0.35, blue: 0.35) : Color.clear)
                                }
                            }
                            .navigationBarTitle("")
                            .navigationBarHidden(true)
                        }
                        .opacity(0.65)
                    }
                    .cornerRadius(10)
                    .frame(maxWidth: self.controlInfo.showControls && self.device.isLandscape ? 200 : 0, maxHeight: self.controlInfo.showControls && self.device.isLandscape ? 230 : 0)
                    .onTapGesture {
                        self.controlInfo.setShowControls(showControls: true)
                        self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                    }
                }
                .padding(.trailing, 35)
                .frame(maxWidth: self.controlInfo.showControls && self.device.isLandscape ? .infinity : 0, maxHeight: self.controlInfo.showControls && self.device.isLandscape ? .infinity : 0)
            }
            .frame(height: self.device.isLandscape ? UIScreen.main.bounds.height : UIScreen.main.bounds.width / 1.778)
            .onTapGesture {
                self.controlInfo.setShowControls(showControls: true)
                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
            }
            
            GeometryReader{_ in
                NavigationView {
                    if self.colorScheme == .dark {
                        List {
                            ForEach(self.stationLoader.stations) { station in

                                StationRow(
                                    playerData: self.$playerData,
                                    currentPlayingInfo:
                                    self.currentPlayingInfo,
                                    selectedStationIndex: self.$currentPlayingInfo.station.index,
                                    station: station
                                )
                                .listRowBackground(self.currentPlayingInfo.station.index == station.index ? Color(red: 0.35, green: 0.35, blue: 0.35) : Color.clear)
                            }
                        }
                        .navigationBarTitle("")
                        .navigationBarHidden(true)
                    }
                    
                    else {
                        List {
                            ForEach(self.stationLoader.stations) { station in

                                StationRow(
                                    playerData: self.$playerData,
                                    currentPlayingInfo:
                                    self.currentPlayingInfo,
                                    selectedStationIndex: self.$currentPlayingInfo.station.index,
                                    station: station
                                )
                                .listRowBackground(self.currentPlayingInfo.station.index == station.index ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color.clear)
                            }
                        }
                        .navigationBarTitle("")
                        .navigationBarHidden(true)
                    }
                }
                .frame(maxHeight: self.device.isLandscape ? 0 : .infinity)
            }
            Text("")
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: self.device.isLandscape ? 0 : 25, maxHeight: self.device.isLandscape ? 0 : 30)
        }
        .background(self.device.isLandscape ? Color.black : Color.clear)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(self.device.isLandscape ? .all : .bottom)
        .prefersHomeIndicatorAutoHidden(true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
