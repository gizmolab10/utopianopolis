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
    
    @IBInspectable var startLocation: Double =   0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { updatePoints() }}
    @IBInspectable var invertMode:      Bool =  false { didSet { updateColors() }}
    
    private let mask = CAGradientLayer()
    
    private func updatePoints() {
        if  horizontalMode {
            mask.startPoint = diagonalMode ? CGPoint(x: 1, y: 0) : CGPoint(x: 0, y: 0.5)
            mask.endPoint   = diagonalMode ? CGPoint(x: 0, y: 1) : CGPoint(x: 1, y: 0.5)
        } else {
            mask.startPoint = diagonalMode ? CGPoint(x: 0, y: 0) : CGPoint(x: 0.5, y: 0)
            mask.endPoint   = diagonalMode ? CGPoint(x: 1, y: 1) : CGPoint(x: 0.5, y: 1)
        }
    }
    
    private func updateLocations() {
        mask.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }
    
    private func updateSize() {
        mask.frame = bounds
    }
    
    private func updateColors() {
        let a = ZColor.white.withAlphaComponent(0.8).cgColor
        let b = ZColor.clear.cgColor
        mask.colors = invertMode ? [a, b] : [b, a]
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
        updateSize()
        updateColors()
        updatePoints()
        updateLocations()
    }
}
