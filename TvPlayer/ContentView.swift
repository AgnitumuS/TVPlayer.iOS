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


let requiredAssetKeys = [
    "playable",
    "hasProtectedContent"
]

var upWWAN: UInt64 = 0
var upWiFi: UInt64 = 0
var downWWAN: UInt64 = 0
var downWiFi: UInt64 = 0
var upSpeed: Double = 0.0
var downSpeed: Double = 0.0
var lastTraficMonitorTime: TimeInterval = Date().timeIntervalSince1970
var downloadSpeed: String = ""

var showLogo: Bool = true

enum PlayStatus {
    case idle
    case playing
    case loading
    case paused
    case error
}

var gPlayStatus: PlayStatus = .idle

struct ContentView: View {
    
    @State var timer: DispatchSourceTimer? = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    
    @State var playerData = PlayerData()
    @State var isplaying = false
    @State var showcontrols = false
    @State var value : Float = 0
    
    @ObservedObject var bufferInfo = BufferInfo(downloadSpeed: "", percentage: "")
    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(name: "TV Player", logo: "", urls: [""]), source: 0, sourceInfo: "")
    @ObservedObject var stationLoader = StationLoader(urlString: stationListUrl)
    @EnvironmentObject var device : Device
    
    init() {
        startNetworkMonitor()
        playerData.player = AVPlayer()
        playerData.setObserver()
    }
    
    func getNetSpeedText(speed: UInt64) -> String {
        var text: String = ""
        if (speed >= 0 && speed < 1024) {
            text = String(speed) + " B/s"
        } else if (speed >= 1024 && speed < (1024 * 1024)) {
            text = String(speed / 1024) + " KB/s"
        } else if (speed >= (1024 * 1024) && speed < (1024 * 1024 * 1024)) {
            text = String(speed / (1024 * 1024)) + " MB/s"
        }
        return text
    }
    
    func startNetworkMonitor() {

        self.timer?.schedule(deadline: DispatchTime.now(), repeating: .milliseconds(1000))
        
        self.timer?.setEventHandler( handler: {
            DispatchQueue.main.sync {
                
                let timeNow: TimeInterval = Date().timeIntervalSince1970

                let dataUsage = DataUsage.getDataUsage()
                let downChanged = dataUsage.wirelessWanDataReceived + dataUsage.wifiReceived - downWWAN - downWiFi
                var timeChanged = timeNow * 1000 - lastTraficMonitorTime * 1000
                if timeChanged < 1 {
                    timeChanged = 1
                }
                let downSpeedRaw = downChanged * 1000 / UInt64(timeChanged)

                downloadSpeed = self.getNetSpeedText(speed: downSpeedRaw)
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
    
    func switchSource (station: Station, source: Int) -> Int {
        var index = source + 1;
        if (index >= station.urls.count) {
            index = 0
        }
        playStation(station: station, source: index)
        return index
    }
    
    func playStation(url: String) {
        
        os_log("Playing: %@", log: OSLog.default, type: .debug, url)
        
        // Create the asset to play
        let asset = AVAsset(url: URL(string: url)!)
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: requiredAssetKeys)
        playerData.player.replaceCurrentItem(with: playerItem)
        playerData.player.play()
        showLogo = false
    }

    func playStation(station: Station, source: Int) {
        playStation(url: station.urls[source])
    }
    
    struct StationRow : View {
        
        @Binding var playerData : PlayerData

        @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(name: "TV Player", logo: "", urls: [""]), source: 0, sourceInfo: "")
        
        @State private var logoPic: UIImage?
        
        var station: Station

        //let playerLayer = AVPlayerLayer()

        func playStation(url: String) {
            
            os_log("Playing: %@", log: OSLog.default, type: .debug, url)
            
            // Create the asset to play
            let asset = AVAsset(url: URL(string: url)!)
            let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: requiredAssetKeys)
            playerData.player.replaceCurrentItem(with: playerItem)
            playerData.player.play()
            showLogo = false
        }

        func playStation(station: Station, source: Int) {
            playStation(url: station.urls[source])
        }

        
        var body: some View {
            HStack {
                if self.station.name != ""
                {
                    RemoteImage(type: .url(URL(string: severPrefix + "logo/" + self.station.logo)!), errorView: { error in
                        Text(error.localizedDescription)
                    }, imageView: { image in
                        image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    }, loadingView: {
                        Text("")
                    })
                    .frame(width: 80, height: 36)
                    .padding(8)
                    
                    Button(action: {
                        self.currentPlayingInfo.setCurrentStation(station: self.station, source: 0)
                        self.playStation(url: self.station.urls[0])
                        }
                    ) {
                        Text(station.name)
                        .font(.system(size: 24))
                        .padding(.leading, 15.0)
                    }
                }
            }
        }
    }
    
    var body: some View {
        
        VStack{
            if !self.device.isLandscape {
                HStack {
                    Image("tv_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36)
                        .offset(y: -4)
                    Text(currentPlayingInfo.station.name)
                        .bold()
                        .font(.system(size: 26))
                        .lineLimit(1)
                    Spacer()
                    Button (action: {
                        self.currentPlayingInfo.setCurrentSource(source: self.switchSource(station: self.currentPlayingInfo.station, source: self.currentPlayingInfo.source))
                    })
                    {
                        Text(self.currentPlayingInfo.sourceInfo)
                            //.bold()
                            .font(.system(size: 21))
                            .foregroundColor(Color.gray)
                            .frame(/*maxWidth: 70, */alignment: .trailing)
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
            
            if self.device.isLandscape {
                ZStack{
                    VideoPlayer(playerData: $playerData)
                        .aspectRatio(1.778, contentMode: .fit)
                    
                    if self.showcontrols{
                        Controls(playerData: self.$playerData, isplaying: self.$isplaying, pannel: self.$showcontrols,value: self.$value)
                    }
                    if gPlayStatus == PlayStatus.loading {
                        LoadingView(speedString: self.$bufferInfo.downloadSpeed)
                    }
                    else if gPlayStatus == PlayStatus.error {
                        ErrorView()
                    }
                }
                .onTapGesture {
                    self.showcontrols = true
                }
            } else {
                
                ZStack{
                    VideoPlayer(playerData: $playerData)
                        .aspectRatio(1.778, contentMode: .fit)
                    
                    if showLogo {
                        Image("tv_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 100)
                    }
                    
                    if self.showcontrols {
                        Controls(playerData: self.$playerData, isplaying: self.$isplaying, pannel: self.$showcontrols,value: self.$value)
                    }
                    if gPlayStatus == PlayStatus.loading {
                        LoadingView(speedString: self.$bufferInfo.downloadSpeed)
                    }
                    else if gPlayStatus == PlayStatus.error {
                        ErrorView()
                    }
                }
                .frame(height: UIScreen.main.bounds.width / 1.778)
                .onTapGesture {
                    self.showcontrols = true
                }
                
                GeometryReader{_ in
                    NavigationView{
                        List(self.stationLoader.stations) { station in
                            StationRow(playerData: self.$playerData, currentPlayingInfo: self.currentPlayingInfo, station: station)
                        }
                        .navigationBarTitle("")
                        .navigationBarHidden(true)
                    }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.bottom)
//        .background(Color.gray.edgesIgnoringSafeArea(.all))
//        .onAppear {
//            self.player.play()
//            self.isplaying = true
//        }
        .prefersHomeIndicatorAutoHidden(true)
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct LoadingView : View {
    
    @Binding var speedString : String
    
    var body : some View{
        
        VStack {
            Text(" Loading...")
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

struct Controls : View {
    
    @Binding var playerData : PlayerData
    @Binding var isplaying : Bool
    @Binding var pannel : Bool
    @Binding var value : Float
    
    var body : some View {
        VStack{
            Spacer()
            HStack{
                Button(action: {
                    self.playerData.player.seek(to: CMTime(seconds: self.getSeconds() - 10, preferredTimescale: 1))
                }) {
                    
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(20)
                }
                Spacer()
                Button(action: {
                    if self.isplaying{
                        
                        self.playerData.player.pause()
                        self.isplaying = false
                    }
                    else{
                        
                        self.playerData.player.play()
                        self.isplaying = true
                    }
                }) {
                    Image(systemName: self.isplaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(20)
                }
                Spacer()
                Button(action: {
                    self.playerData.player.seek(to: CMTime(seconds: self.getSeconds() + 10, preferredTimescale: 1))
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(20)
                }
            }
            
            Spacer()
            
            //CustomProgressBar(value: self.$value, player: self.$player, isplaying: self.$isplaying)
            
        }
        //.padding()
        .background(Color.black.opacity(0.4))
        .onTapGesture {
            self.pannel = false
        }
        .onAppear {
            
            self.playerData.player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { (_) in
                
                self.value = self.getSliderValue()
                
                if self.value == 1.0{
                    
                    self.isplaying = false
                }
            }
        }
        
        
    }
    
    func getSliderValue()->Float{
        
        return Float(self.playerData.player.currentTime().seconds / (self.playerData.player.currentItem?.duration.seconds)!)
    }
    
    func getSeconds()->Double{
        
        return Double(Double(self.value) * (self.playerData.player.currentItem?.duration.seconds)!)
    }
}

class Host : UIHostingController<ContentView>{
    
    override var preferredStatusBarStyle: UIStatusBarStyle{
        
        return .lightContent
    }
}

class PlayerData: NSObject {
    var player: AVPlayer!
    var playerItem: AVPlayerItem!

    func setObserver() {
        //playerItem.addObserver(self, forKeyPath: "status", options: [], context: nil)
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                DispatchQueue.main.async {
                    //[weak self] in
                    if newStatus == .playing {
                        gPlayStatus = .playing
                    }
                    else if newStatus == .paused {
                        
                        if oldStatus == .playing {
                            gPlayStatus = .paused
                        }
                        else {
                            gPlayStatus = .error
                        }
                    }
                    else {
                        gPlayStatus = .loading
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
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: UIViewControllerRepresentableContext<VideoPlayer>) {
        
        
    }
}

struct Station: Decodable, Identifiable {
    var id = UUID()
    var name: String
    var logo: String
    var urls: [String]
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
    @Published var source: Int
    @Published var sourceInfo: String
    
    init(station: Station, source: Int, sourceInfo: String) {
        self.station = station
        self.source = source
        self.sourceInfo = sourceInfo
    }
    
    func setCurrentStation(station: Station, source: Int) {
        self.station = station
        self.source = source
        self.sourceInfo = "\(self.source + 1)/\(self.station.urls.count)"
        
        if (self.sourceInfo == "1/1") {
            self.sourceInfo = ""
        }
    }
    
    func setCurrentSource(source: Int) {
        self.source = source
        self.sourceInfo = "\(self.source + 1)/\(self.station.urls.count)"
        
        if (self.sourceInfo == "1/1") {
            self.sourceInfo = ""
        }
    }
}
