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


    func setupAsCurved(_ curved: Bool) {
        if curved == false {
            zlayer.backgroundColor = stateManager.lineColor.cgColor
        } else {
            zlayer.delegate        = self
        }
    }


    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
}
