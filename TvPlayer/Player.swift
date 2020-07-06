//
//  Player.swift
//  TvPlayer
//
//  Created by admin on 2020/5/21.
//  Copyright © 2020 Yu Cao. All rights reserved.
//

import SwiftUI
import AVKit
import AVFoundation
import RemoteImage
import os.log

let requiredAssetKeys = [
    "playable",
    "hasProtectedContent"
]

var SHOW_CONTROL_TIME: Double = 8

var dataUsageInfo: DataUsageInfo = DataUsageInfo()

var lastTraficMonitorTime: TimeInterval = Date().timeIntervalSince1970
var downloadSpeed: String = ""

var showLogo: Bool = true

enum PlaybackStatus {
    case idle
    case playing
    case loading
    case paused
    case error
}

enum Direction {
    case forward
    case backward
}

func playStation(playerData: PlayerData, station: Station, sourceIndex: Int) {
    
    let url = station.urls[sourceIndex]
    os_log("Playing: %@", log: OSLog.default, type: .debug, url)
    
    // Create the asset to play
    let asset = AVAsset(url: URL(string: url)!)
    let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: requiredAssetKeys)
    playerData.player.replaceCurrentItem(with: playerItem)
    playerData.player.play()
    showLogo = false
}

func switchSource (playerData: PlayerData, station: Station, sourceIndex: Int, direction: Direction) -> Int {
    var index = sourceIndex + 1;
    if direction == Direction.forward {
        index = sourceIndex + 1;
        if (index >= station.urls.count) {
            index = 0
        }
    }
    else {
        index = sourceIndex - 1;
        if (index < 0) {
            index = station.urls.count - 1
        }
    }
    playStation(playerData: playerData, station: station, sourceIndex: index)
    return index
}

func switchStation (playerData: PlayerData, station: Station, stationList: [Station], direction: Direction) -> Station {
    var index = station.index;
    if direction == Direction.forward {
        index = index + 1;
        if (index >= stationList.count) {
            index = 0
        }
    }
    else {
        index = index - 1;
        if (index < 0) {
            index = stationList.count - 1
        }
    }
    
    let newStation: Station = stationList[index]
    playStation(playerData: playerData, station: newStation, sourceIndex: 0)
    return newStation
}

class Host : UIHostingController<ContentView>{
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .lightContent
    }
}

class PlayerData: NSObject {
    var player: AVPlayer!
    var playerItem: AVPlayerItem!
    var playbackStatus: PlaybackStatus!

    func setObserver() {
        //playerItem.addObserver(self, forKeyPath: "status", options: [], context: nil)
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "timeControlStatus",
            let change = change,
            let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
            let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                DispatchQueue.main.async {
                    //[weak self] in
                    if newStatus == .playing {
                        self.playbackStatus = .playing
                    }
                    else if newStatus == .paused {
                        if oldStatus == .playing {
                            self.playbackStatus = .paused
                        }
                        else {
                            self.playbackStatus = .error
                        }
                    }
                    else {
                        self.playbackStatus = .loading
                    }
                }
            }
        }
    }
}

struct VideoPlayer : UIViewControllerRepresentable {
    
    @Binding var playerData : PlayerData
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<VideoPlayer>) -> AVPlayerViewController {
        
        let controller = AVPlayerViewController()
        controller.player = playerData.player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resize
        return controller
    }
    
    func updateUIViewController(
        _ uiViewController: AVPlayerViewController,
        context: UIViewControllerRepresentableContext<VideoPlayer>
    ) { }
}

class ControlInfo: ObservableObject {
    @Published var lastControlActiveTime: TimeInterval = Date().timeIntervalSince1970
    @Published var showControls: Bool
    
    init(lastControlActiveTime: TimeInterval, showControls: Bool) {
        self.lastControlActiveTime = lastControlActiveTime
        self.showControls = showControls
    }
    
    func setShowControls(showControls: Bool) {
        self.showControls = showControls
    }
    
    func setLastControlActiveTime(lastControlActiveTime: TimeInterval) {
        self.lastControlActiveTime = lastControlActiveTime
    }
}

class BufferInfo: ObservableObject {
    @Published var downloadSpeed: String = ""
    @Published var percentage: String = ""
    
    init(downloadSpeed: String, percentage: String) {
        self.downloadSpeed = downloadSpeed
        self.percentage = downloadSpeed
    }
    
    func setDownloadSpeed(downloadSpeed: String) {
        self.downloadSpeed = downloadSpeed
    }
    
    func setPercentage(percentage: String) {
        self.percentage = percentage
    }
}

class CurrentPlayingInfo: ObservableObject {
    @Published var station: Station
    @Published var sourceIndex: Int
    @Published var sourceInfo: String
    
    init(station: Station, sourceIndex: Int, sourceInfo: String) {
        self.station = station
        self.sourceIndex = sourceIndex
        self.sourceInfo = sourceInfo
    }
    
    func setCurrentStation(station: Station, sourceIndex: Int) {
        self.station = station
        self.sourceIndex = sourceIndex
        self.sourceInfo = "\(self.sourceIndex + 1)/\(self.station.urls.count)"
        
        if (self.sourceInfo == "1/1") {
            self.sourceInfo = ""
        }
    }
    
    func setCurrentSource(sourceIndex: Int) {
        self.sourceIndex = sourceIndex
        self.sourceInfo = "\(self.sourceIndex + 1)/\(self.station.urls.count)"
        
        if (self.sourceInfo == "1/1") {
            self.sourceInfo = ""
        }
    }
}

struct Controls : View {
    
    @EnvironmentObject var device : Device
    @Binding var playerData : PlayerData
    @ObservedObject var currentPlayingInfo: CurrentPlayingInfo
    @ObservedObject var bufferInfo: BufferInfo
    @ObservedObject var controlInfo: ControlInfo
    @Binding var value : Float
    @Binding var stationList: [Station]
    //@Environment(\.colorScheme) var colorScheme
    @FetchRequest(entity: StationModel.entity(), sortDescriptors: []) var stationModels: FetchedResults<StationModel>
    @Environment(\.managedObjectContext) var moc
    
    var body : some View {
        VStack {
            if self.device.isLandscape {
                VStack {
                    HStack {
                        if currentPlayingInfo.station.index < 0 {
                            
                        } else if currentPlayingInfo.station.name.contains("CCTV") {
                            RemoteImage(type: .url(URL(string: severPrefix + "logo/" + currentPlayingInfo.station.logo)!), errorView: { error in
                                Text(error.localizedDescription)
                            }, imageView: { image in
                                image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            }, loadingView: {
                                Text("")
                            })
                            .background(Color(red: 0.35, green: 0.35, blue: 0.35))
                            .cornerRadius(10)
                            .frame(width: 80, height: 36)
                            .padding(.top, 2.0)
                            .padding(.bottom, 2.0)
                            .padding(.leading, 8.0)
                            .padding(.trailing, 1.0)
                        } else {
                            RemoteImage(type: .url(URL(string: severPrefix + "logo/" + currentPlayingInfo.station.logo)!), errorView: { error in
                                Text(error.localizedDescription)
                            }, imageView: { image in
                                image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            }, loadingView: {
                                Text("")
                            })
                            .frame(width: 80, height: 36)
                            .padding(.top, 2.0)
                            .padding(.bottom, 2.0)
                            .padding(.leading, 8.0)
                            .padding(.trailing, 1.0)
                        }
                        Text(currentPlayingInfo.station.name)
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                        .padding(.top, 5.0)
                        .padding(.bottom, 5.0)
                        .padding(.leading, 1.0)
                        .padding(.trailing, 15.0)
                    }
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(12)
                    .padding(.all, 16.0)
                    
                    Spacer()
                    
                    HStack {
                        HStack {
                            Button(action: {
                                self.currentPlayingInfo.station = switchStation(playerData: self.playerData, station: self.currentPlayingInfo.station, stationList: self.stationList, direction: .backward)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: 0)
                                self.currentPlayingInfo.setCurrentStation(station: self.currentPlayingInfo.station, sourceIndex: 0)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "backward.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            }
                            .padding(.trailing, 10.0)
                            .padding(.top, 5.0)
                            .padding(.bottom, 5.0)
                            Button(action: {
                                if self.playerData.playbackStatus == PlaybackStatus.playing {
                                    
                                    self.playerData.player.pause()
                                }
                                else{
                                    
                                    self.playerData.player.play()
                                }
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: self.playerData.playbackStatus == PlaybackStatus.playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 28)
                            }
                            .padding(.leading, 10.0)
                            .padding(.trailing, 10.0)
                            .padding(.top, 5.0)
                            .padding(.bottom, 5.0)
                            Button(action: {
                                self.currentPlayingInfo.station = switchStation(playerData: self.playerData, station: self.currentPlayingInfo.station, stationList: self.stationList, direction: .forward)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: 0)
                                self.currentPlayingInfo.setCurrentStation(station: self.currentPlayingInfo.station, sourceIndex: 0)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "forward.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            }
                            .padding(.leading, 10.0)
                            .padding(.trailing, 10.0)
                            .padding(.top, 5.0)
                            .padding(.bottom, 5.0)
                        }
                        .padding(.top, 5.0)
                        .padding(.bottom, 5.0)
                        .padding(.leading, 15.0)
                        .padding(.trailing, 10.0)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                        Spacer()
                        HStack {
                            Button(action: {
                                let sourceIndex = switchSource(playerData: self.playerData, station: self.currentPlayingInfo.station, sourceIndex: self.currentPlayingInfo.sourceIndex, direction: .backward)
                                
                                saveSourceIndex(context: self.moc, stationModels: self.stationModels, stationName: self.currentPlayingInfo.station.name, index: sourceIndex)
                                
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: sourceIndex)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "arrow.left.square.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                            Text(self.currentPlayingInfo.sourceInfo)
                            .font(.system(size: 28))
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                            Button(action: {
                                let sourceIndex = switchSource(playerData: self.playerData, station: self.currentPlayingInfo.station, sourceIndex: self.currentPlayingInfo.sourceIndex, direction: .forward)
                                saveSourceIndex(context: self.moc, stationModels: self.stationModels, stationName: self.currentPlayingInfo.station.name, index: sourceIndex)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: sourceIndex)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "arrow.right.square.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 5.0)
                        .padding(.bottom, 5.0)
                        .padding(.leading, 15.0)
                        .padding(.trailing, 15.0)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                    }
                }
                .padding(.leading, 80.0)
                .padding(.trailing, 80.0)
                .padding(.bottom, 25.0)
                .background(Color.black.opacity(0.0000001))
                .onTapGesture {
                    self.controlInfo.setShowControls(showControls: false)
                }
            }
            else {
                VStack {
                    Spacer()
                    HStack {
                        HStack {
                            Button(action: {
                                self.currentPlayingInfo.station = switchStation(playerData: self.playerData, station: self.currentPlayingInfo.station, stationList: self.stationList, direction: .backward)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: 0)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                
                                Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                            }
                            .padding(.trailing, 10.0)
                            .padding(.top, 5.0)
                            .padding(.bottom, 5.0)
                            Button(action: {
                                if self.playerData.playbackStatus == PlaybackStatus.playing {
                                    
                                    self.playerData.player.pause()
                                }
                                else{
                                    
                                    self.playerData.player.play()
                                }
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: self.playerData.playbackStatus == PlaybackStatus.playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 25))
                                .foregroundColor(.white)
                                .frame(width: 24)
                            }
                            .padding(.leading, 10.0)
                            .padding(.trailing, 10.0)
                            .padding(.top, 5.0)
                            .padding(.bottom, 5.0)
                            Button(action: {
                                self.currentPlayingInfo.station = switchStation(playerData: self.playerData, station: self.currentPlayingInfo.station, stationList: self.stationList, direction: .forward)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: 0)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "forward.fill")
                                .font(.system(size: 25))
                                .foregroundColor(.white)
                            }
                            .padding(.leading, 10.0)
                            .padding(.top, 5.0)
                            .padding(.bottom, 5.0)
                        }
                        .padding(.top, 5.0)
                        .padding(.bottom, 5.0)
                        .padding(.leading, 12.0)
                        .padding(.trailing, 12.0)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                        Spacer()
                        HStack {
                            Button(action: {
                                let sourceIndex = switchSource(playerData: self.playerData, station: self.currentPlayingInfo.station, sourceIndex: self.currentPlayingInfo.sourceIndex, direction: .backward)
                                saveSourceIndex(context: self.moc, stationModels: self.stationModels, stationName: self.currentPlayingInfo.station.name, index: sourceIndex)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: sourceIndex)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "arrow.left.square.fill")
                                    .font(.system(size: 25))
                                    .foregroundColor(.white)
                            }
                            Text(self.currentPlayingInfo.sourceInfo)
                            .font(.system(size: 24))
                            .foregroundColor(Color.white)
                            .lineLimit(1)
                            Button(action: {
                                let sourceIndex = switchSource(playerData: self.playerData, station: self.currentPlayingInfo.station, sourceIndex: self.currentPlayingInfo.sourceIndex, direction: .forward)
                                saveSourceIndex(context: self.moc, stationModels: self.stationModels, stationName: self.currentPlayingInfo.station.name, index: sourceIndex)
                                self.currentPlayingInfo.setCurrentSource(sourceIndex: sourceIndex)
                                self.controlInfo.setLastControlActiveTime(lastControlActiveTime: Date().timeIntervalSince1970)
                            }) {
                                Image(systemName: "arrow.right.square.fill")
                                .font(.system(size: 25))
                                .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 5.0)
                        .padding(.bottom, 5.0)
                        .padding(.leading, 12.0)
                        .padding(.trailing, 12.0)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(12)
                    }
                }
                .padding(.leading, 15.0)
                .padding(.trailing, 15.0)
                .padding(.bottom, 20.0)
                .background(Color.black.opacity(0.0000001))
                .onTapGesture {
                    self.controlInfo.setShowControls(showControls: false)
                }
            }
        }
    }
}

struct LoadingView : View {
    
    @Binding var speedString : String
    
    var body : some View{
        VStack {
            Text(" Loading ...")
            .font(.system(size: 18))
            .padding(.leading, 20.0)
            .padding(.trailing, 22.0)
            .padding(.top, 10.0)
            .padding(.bottom, 6.0)
            .foregroundColor(Color.white)
            .lineLimit(1)
            
            Text(speedString)
            .font(.system(size: 18))
            .padding(.leading, 20.0)
            .padding(.trailing, 22.0)
            .padding(.top, 6.0)
            .padding(.bottom, 10.0)
            .foregroundColor(Color.white)
            .lineLimit(1)
        }
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }
}

struct ErrorView : View {
    
    var body : some View{
        
        VStack {
            Image(systemName: "exclamationmark.square")
            .foregroundColor(.white)
            .font(.system(size: 40))
            .imageScale(.large)
            .padding(.all, 10.0)
            Text("Load failed, please try switch source.")
            .font(.system(size: 18))
            .padding(.all, 10.0)
            .foregroundColor(Color.white)
        }
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }
}
