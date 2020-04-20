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

var isBuffering: Bool = false

var downloadSpeed: String = ""

var timer: DispatchSourceTimer?

var upWWAN: UInt64 = 0
var upWiFi: UInt64 = 0
var downWWAN: UInt64 = 0
var downWiFi: UInt64 = 0
var upSpeed: Double = 0.0
var downSpeed: Double = 0.0

var lastTraficMonitorTime: TimeInterval = Date().timeIntervalSince1970

var player: AVPlayer!
var asset: AVAsset!
var playerItem: AVPlayerItem!
let playerLayer = AVPlayerLayer()
let requiredAssetKeys = [
    "playable",
    "hasProtectedContent"
]

var stationListUrl: String = "https://gitee.com/cy8018/Resources/raw/master/tv/tv_station_list_ext.json"
var severPrefix: String = "https://gitee.com/cy8018/Resources/raw/master/tv/"

class BufferInfo: ObservableObject {
    @Published var downloadSpeed: String = ""
    //@Published var percentage: String = ""
    
    init(downloadSpeed: String) {
        self.downloadSpeed = downloadSpeed
    }
    
    func setDownloadSpeed(downloadSpeed: String) {
        self.downloadSpeed = downloadSpeed
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

func playStation(url: String) {
    
    os_log("Playing: %@", log: OSLog.default, type: .debug, url)
    
    // Create the asset to play
    asset = AVAsset(url: URL(string: url)!)
    //player = AVPlayer(url: URL(string: url)!)
    
    // Create a new AVPlayerItem with the asset and an
    // array of asset keys to be automatically loaded
    playerItem = AVPlayerItem(asset: asset,
                              automaticallyLoadedAssetKeys: requiredAssetKeys)
    
    // Associate the player item with the player
    player = AVPlayer(playerItem: playerItem)
    
    playerLayer.player = player
    player?.play()
}

func playStation(station: Station, source: Int) {
    playStation(url: station.urls[source])
}

func switchSource (station: Station, source: Int) -> Int {
    var index = source + 1;
    if (index >= station.urls.count) {
        index = 0
    }
    playStation(station: station, source: index)
    return index
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

class ViewData: NSObject {
    
    func setObserver() {
        playerItem.addObserver(self, forKeyPath: "status", options: [], context: nil)
        playerItem.addObserver(self, forKeyPath: "timeControlStatus", options: [], context: nil)
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
            if newStatus != oldStatus {
                DispatchQueue.main.async {[weak self] in
                    if newStatus == .playing {
                        //self?.showPauseButton()
                    }
                    else if newStatus == .paused {
                        //self?.showPlayButton()
                    }
                    else {
                        //self?.showLoadingButton()
                    }
                }
            }
        }

   }
}



struct PlayerView: UIViewRepresentable {
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PlayerView>) {
    }
    func makeUIView(context: Context) -> UIView {
        return PlayerUIView()
    }
}

class PlayerUIView: UIView {
    
    init() {
        super.init(frame: .zero)
        playerLayer.player = player
        layer.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resize
    }
}

class ContentData: ObservableObject {
    //@Published var playing: Bool = false
    @Published var isBuffering: Bool = false
}

struct PlayerContainerView : View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var contentData = ContentData()
    @EnvironmentObject var device : Device
    @ObservedObject var stationLoader = StationLoader(urlString: stationListUrl)
    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(name: "TV Player", logo: "", urls: [""]), source: 0, sourceInfo: "")
    
    @ObservedObject var bufferInfo = BufferInfo(downloadSpeed: downloadSpeed)
    
    init() {
        startNetworkMonitor()
    }
    
    func startNetworkMonitor() {

        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer?.schedule(deadline: DispatchTime.now(), repeating: .milliseconds(1000))
        
        timer?.setEventHandler(
            handler: {
                DispatchQueue.main.sync {
                    let timeNow: TimeInterval = Date().timeIntervalSince1970
                    
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
                    
                    os_log("Download Speed: %@", log: OSLog.default, type: .debug, downloadSpeed)
                }
            }
        )
        timer?.resume()
    }
    
    var body: some View {
        VStack {
            if self.device.isLandscape {
                PlayerView()
                    .aspectRatio(1.778, contentMode: .fit)
            }
            else {
                HStack {
//                    Image(systemName: "repeat")
//                        .opacity(0)
//                    Text(self.currentPlayingInfo.sourceInfo)
//                        .bold()
//                        .font(.system(size: 22))
//                        .opacity(0)
                    Text(downloadSpeed)
                        .font(.system(size: 16))
                        .padding(.leading, 10.0)
                        .frame(width: 80)
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "tv")
                    Text(currentPlayingInfo.station.name)
                        .bold()
                        .font(.system(size: 24))
                        .lineLimit(1)
                    Spacer()
                    Button (action: {
                        self.currentPlayingInfo.setCurrentSource(source: switchSource(station: self.currentPlayingInfo.station, source: self.currentPlayingInfo.source))
                    })
                    {
                        Image(systemName: "repeat")
                            .foregroundColor(Color.gray)
                            .opacity(self.currentPlayingInfo.sourceInfo.count > 0 ? 1 : 0)
                        Text(self.currentPlayingInfo.sourceInfo)
                            //.bold()
                            .font(.system(size: 20))
                            .foregroundColor(Color.gray)
                            .padding(.trailing, 10.0)
                            .frame(width: 65)
                            .lineLimit(1)
                    }
                }.padding(.top, 5.0)
                ZStack() {
                    PlayerView()
                        .aspectRatio(1.778, contentMode: .fit)
                    //Text(downloadSpeed)
                        //.font(.system(size: 24))
                }
                
                List(stationLoader.stations) { station in
                    StationRow(station: station, currentPlayingInfo: self.currentPlayingInfo)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct StationRow : View {
    var station: Station

    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(name: "TV Player", logo: "", urls: [""]), source: 0, sourceInfo: "")
    
    @State private var logoPic: UIImage?
    

    
    var body: some View {
        HStack {
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
                playStation(url: self.station.urls[0])
                }
            ) {
                Text(station.name)
                .font(.system(size: 24))
                .padding(.leading, 15.0)
            }
        }
    }
}

struct Station: Decodable, Identifiable {
    var id = UUID()
    var name: String
    var logo: String
    var urls: [String]
}

struct ContentView: View {
    
    
    var body: some View {
        PlayerContainerView()
        .prefersHomeIndicatorAutoHidden(true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
