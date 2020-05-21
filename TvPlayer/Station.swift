//
//  NetworkingManager.swift
//  TvPlayer
//
//  Created by CaoYu on 2020/2/14.
//  Copyright © 2020 Yu Cao. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Alamofire
import SwiftyJSON
import RemoteImage

struct Station: Decodable, Identifiable {
    var id = UUID()
    var index: Int
    var name: String
    var logo: String
    var urls: [String]
}

struct StationRow : View {
            
    @Binding var playerData : PlayerData
    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(index: -1, name: "TV Player", logo: "", urls: [""]), sourceIndex: 0, sourceInfo: "")
    @State private var logoPic: UIImage?
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedStationIndex: Int
    
    var station: Station
    
    var body: some View {

        HStack {
            if self.colorScheme == .dark && self.station.name.contains("CCTV") {
                RemoteImage(type: .url(URL(string: severPrefix + "logo/" + self.station.logo)!), errorView: { error in
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
                .frame(width: 80, height: 48)
                .padding(6)
            } else {
                RemoteImage(type: .url(URL(string: severPrefix + "logo/" + self.station.logo)!), errorView: { error in
                    Text(error.localizedDescription)
                }, imageView: { image in
                    image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                }, loadingView: {
                    Text("")
                })
                .frame(width: 80, height: 48)
                .padding(6)
            }
            
            Text(station.name)
            .font(.system(size: 24))
            .padding(.leading, 15.0)
            
            Spacer()
        }
        .contentShape(Rectangle())
        //.frame(width: UIScreen.main.bounds.width)
        .onTapGesture {
            self.currentPlayingInfo.setCurrentStation(station: self.station, sourceIndex: 0)
            playStation(playerData: self.playerData, station: self.station, sourceIndex: 0)
            self.selectedStationIndex = self.station.index
        }
    }
}

struct StationRowLandscape : View {
            
    @Binding var playerData : PlayerData
    @ObservedObject var currentPlayingInfo = CurrentPlayingInfo(station: Station(index: -1, name: "TV Player", logo: "", urls: [""]), sourceIndex: 0, sourceInfo: "")
    @State private var logoPic: UIImage?
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedStationIndex: Int
    
    var station: Station
    
    var body: some View {

        HStack {
            if self.colorScheme == .dark && self.station.name.contains("CCTV") {
                RemoteImage(type: .url(URL(string: severPrefix + "logo/" + self.station.logo)!), errorView: { error in
                    Text(error.localizedDescription)
                }, imageView: { image in
                    image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                }, loadingView: {
                    Text("")
                })
                .background(Color(red: 0.35, green: 0.35, blue: 0.35))
                .cornerRadius(4)
                .frame(width: 40, height: 24)
                .padding(2)
            } else {
                RemoteImage(type: .url(URL(string: severPrefix + "logo/" + self.station.logo)!), errorView: { error in
                    Text(error.localizedDescription)
                }, imageView: { image in
                    image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                }, loadingView: {
                    Text("")
                })
                .frame(width: 40, height: 24)
                .padding(2)
            }
            
            Text(station.name)
            .font(.system(size: 14))
            .padding(.leading, 2.0)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            self.currentPlayingInfo.setCurrentStation(station: self.station, sourceIndex: 0)
            playStation(playerData: self.playerData, station: self.station, sourceIndex: 0)
            self.selectedStationIndex = self.station.index
        }
    }
}

class StationLoader: ObservableObject {
    @Published var stations = [Station]()
    
    init(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        var tempStationList: [Station] = []
        var tmpIndex: Int = 0
        
        AF.request(url).responseJSON { (response) in
            switch response.result {
            case .success(let json):
                //print(json)
                let jsonObj = JSON.init(json)
                for station in jsonObj["stations"].arrayValue {
                    var urls: [String] = []
                    for url in station["url"].arrayValue {
                        urls.append(url.stringValue)
                    }
                    tempStationList.append(
                        Station(
                            index: tmpIndex,
                            name: station["name"].stringValue,
                            logo: station["logo"].stringValue,
                            urls: urls
                            )
                    )
                    tmpIndex = tmpIndex + 1
                }
                self.stations = tempStationList
                break
            case .failure(let error):
                print("error:\(error)")
                break
            }
        }
    }
}
