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
