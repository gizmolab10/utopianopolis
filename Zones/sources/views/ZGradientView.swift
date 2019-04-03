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
    
    private var gradientMask = CAGradientLayer()
    
    func setup() {
        gradientMask = CAGradientLayer()
        zlayer.mask  = gradientMask

        update()

        if  horizontalMode {
            gradientMask.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            gradientMask.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            gradientMask.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            gradientMask.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }
    }

    private func update() {
        let white = kWhiteColor.cgColor
        let clear = kClearColor.cgColor
        gradientMask.colors = invertMode ? [white, clear] : [clear, white]
        gradientMask.frame = bounds
    }
    
}
