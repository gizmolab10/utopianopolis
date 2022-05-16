//
//  ZGeometry.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/25/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
let kFontDelta = CGFloat(11)
let kDotFactor = CGFloat(2.5)
var gTextOffset: CGFloat?
#elseif os(iOS)
import UIKit
let kFontDelta = CGFloat(17)
let kDotFactor = CGFloat(1.25)
var gTextOffset: CGFloat? { return gTextEditor.currentOffset }
#endif

var        gBigFontSize : CGFloat { return gBaseFontSize + kFontDelta } // 13 ... 28
var      gSmallFontSize : CGFloat { return gBigFontSize  * kSmallMapReduction }
var   gCircleIdeaRadius : CGFloat { return gDotHeight * 2.2 }
var           gDotWidth : CGFloat { return gDotHeight * kDragDotReduction }
var       gDotHalfWidth : CGFloat { return gDotWidth / 2.0 }
var          gDotHeight : CGFloat { return (gBaseFontSize / kDotFactor) + kFontDelta + 2.0 }

func gDotSize(forReveal: Bool)                  -> CGSize  { return CGSize(width: forReveal ? gDotHeight : gDotWidth, height: gDotHeight) }
func gDotSize(forReveal: Bool, forBigMap: Bool) -> CGSize  { return gDotSize(forReveal: forReveal).multiplyBy(forBigMap ? 1.0 : kSmallMapReduction) }
