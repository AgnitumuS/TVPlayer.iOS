//
//  Device.swift
//  TvPlayer
//
//  Created by admin on 2020/2/29.
//  Copyright © 2020 Yu Cao. All rights reserved.
//

import Combine
import UIKit

final public class Device: ObservableObject {

    @Published public var isLandscape: Bool = false
    
    public init() {}
}
