//
//  ZoneLine.swift
//  Zones
//
//  Created by Jonathan Sand on 10/30/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneLine: ZView {


    func setup() {
        zlayer.backgroundColor = stateManager.lineColor.cgColor

    }
}
