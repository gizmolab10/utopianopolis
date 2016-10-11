//
//  ZState.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


enum ZToolState: Int {
    case edit
    case travel
    case layout
}


let state: ZState = ZState()


class ZState: NSObject {
    var toolState: ZToolState = .travel
}
