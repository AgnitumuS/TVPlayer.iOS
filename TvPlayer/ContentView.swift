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
var stationListUrl: String = "http://13.78.120.63/tv/tv_station_list.json"

func playStation(url: String) {
    player = AVPlayer(url: URL(string: url)!)
    playerLayer.player = player
    player?.play()
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
    
    var body: some View {
        VStack {
            Text("TV Player")
                .bold()
            PlayerView()
                .frame(height: 211)
            
            List(stationLoader.stations) { station in
                StationRow(station: station)
            }
        }
    }
}

struct StationRow : View {
    var station: Station

    var body: some View {
            Button(action: {
                playStation(url: self.station.url)
                }
            ) {
                Text(station.name)
                    .multilineTextAlignment(.center)
                    .padding(.leading, 20.0)
        }
    }
}

struct Station: Decodable, Identifiable {
    var id = UUID()
    var name, url : String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
