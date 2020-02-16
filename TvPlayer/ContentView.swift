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

var player: AVPlayer!
let playerLayer = AVPlayerLayer()
var stationListUrl: String = "http://13.78.120.63/tv/tv_station_list_ext.json"

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
    print("Playing: \(url)")
    player = AVPlayer(url: URL(string: url)!)
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

struct ContentView: View {
    var body: some View {
          PlayerContainerView()
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

struct PlayerContainerView : View {
    @ObservedObject var stationLoader = StationLoader(urlString: stationListUrl)
    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(name: "TV Player", urls: [""]), source: 0, sourceInfo: "")
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "tv")
                Text(currentPlayingInfo.station.name)
                    .bold()
                    .font(.system(size: 20))
                Spacer()
                Button (action: {
                    self.currentPlayingInfo.setCurrentSource(source: switchSource(station: self.currentPlayingInfo.station, source: self.currentPlayingInfo.source))
                }) {
                    Text(self.currentPlayingInfo.sourceInfo)
                        .bold()
                        .font(.system(size: 20))
                        .padding(.trailing, 15.0)
                        
                }
            }
            
            PlayerView()
                .aspectRatio(1.778, contentMode: .fit)
            
            List(stationLoader.stations) { station in
                StationRow(station: station, currentPlayingInfo: self.currentPlayingInfo)
            }
        }
    }
}

struct StationRow : View {
    var station: Station

    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(name: "TV Player", urls: [""]), source: 0, sourceInfo: "")
    
    var body: some View {
        HStack {
            Button(action: {
                self.currentPlayingInfo.setCurrentStation(station: self.station, source: 0)
                playStation(url: self.station.urls[0])
                }
            ) {
                Text(station.name)
                .padding(.leading, 15.0)
            }
        }
    }
}

struct Station: Decodable, Identifiable {
    var id = UUID()
    var name : String
    var urls: [String]
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
