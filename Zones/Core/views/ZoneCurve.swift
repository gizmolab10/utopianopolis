//
//  ZoneCurve.swift
//  Zones
//
//  Created by Jonathan Sand on 10/31/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneCurve: ZView {


    func setup() {
        zlayer.setNeedsDisplay()
        zlayer.backgroundColor = stateManager.lineColor.cgColor
    }


    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
    }
}
