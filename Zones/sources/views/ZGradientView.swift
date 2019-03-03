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
    
    @IBInspectable var startLocation: Double =   0.05 { didSet { update() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { update() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { update() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { update() }}
    @IBInspectable var invertMode:      Bool =  false { didSet { update() }}
    
    private let mask = CAGradientLayer()
    
    private func update() {
        if  horizontalMode {
            mask.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            mask.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            mask.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            mask.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }

        let a = ZColor.white.withAlphaComponent(0.6).cgColor
        let b = ZColor.clear.cgColor
        mask.colors = invertMode ? [a, b] : [b, a]
        mask.locations = [startLocation as NSNumber, endLocation as NSNumber]
        mask.frame = bounds
    }
    
    private func setupMask() {
        zlayer.mask = mask
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMask()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupMask()
    }
    
    override func layout() {
        super.layout()
        update()
    }
}
