//
//  Util.swift
//  TvPlayer
//
//  Created by admin on 2020/5/21.
//  Copyright © 2020 Yu Cao. All rights reserved.
//

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
