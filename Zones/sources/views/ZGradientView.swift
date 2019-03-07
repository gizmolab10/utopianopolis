//
//  ZGradientView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 3/2/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

@IBDesignable
class ZGradientView: ZView {
    
    @IBInspectable var horizontalMode:  Bool =  false { didSet { setup() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { setup() }}
    @IBInspectable var invertMode:      Bool =  false { didSet { update() }}
    
    private var mask = CAGradientLayer()
    
    func setup() {
        mask = CAGradientLayer()
        zlayer.mask = mask

        update()

        if  horizontalMode {
            mask.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            mask.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            mask.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            mask.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }
    }

    private func update() {
        let white = ZColor.white.cgColor
        let clear = ZColor.clear.cgColor
        mask.colors = invertMode ? [white, clear] : [clear, white]
        mask.frame = bounds
    }
    
}
