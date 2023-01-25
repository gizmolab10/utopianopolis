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
let kFontDelta = CGFloat(10)
let kDotFactor = CGFloat(1.5)
var gTextOffset: CGFloat?
#elseif os(iOS)
import UIKit
let kFontDelta = CGFloat(17)
let kDotFactor = CGFloat(1.25)
var gTextOffset: CGFloat? { return gTextEditor.currentOffset }
#endif

var gSmallFontSize : CGFloat { return   gBigFontSize * kSmallMapReduction }
var   gBigFontSize : CGFloat { return  gBaseFontSize + kFontDelta }          // 15 ... 28
var     gSmallFont :   ZFont { return  gFavoritesMapController.font }
var     gMicroFont :   ZFont { return .systemFont(ofSize: gSmallFontSize * kSmallMapReduction * kSmallMapReduction) }
var       gBigFont :   ZFont { return .systemFont(ofSize: gBigFontSize) }

protocol ZGeometry {

	var  coreFontSize : CGFloat { get }
	var coreThickness : CGFloat { get }
	var horizontalGap : CGFloat { get }

}

func gUpdateBaseFontSize(up: Bool) {
	let     delta = CGFloat(up ? 1 : -1)
	var      size = gBaseFontSize + delta
	size          = size.confineBetween(low: .zero, high: 15.0)
	gBaseFontSize = size

	gSignal([.spRelayout, .spPreferences])
}

extension ZGenericController {

	@objc var horizontalGap : CGFloat { return gHorizontalGap }
	@objc var coreThickness : CGFloat { return gLineThickness }
	@objc var  coreFontSize : CGFloat { return gBaseFontSize }
	var            fontSize : CGFloat { return  coreFontSize + kFontDelta }      // 15 ... 28
	var           dotHeight : CGFloat { return (fontSize  / kDotFactor) + 2.0 }
	var       dotHalfHeight : CGFloat { return  dotHeight / 2.0 }
	var    circleIdeaRadius : CGFloat { return  dotHeight * 2.2 }
	var            dotWidth : CGFloat { return  dotHeight * kDragDotReduction }
	var        dotHalfWidth : CGFloat { return  dotWidth  / 2.0 }
	var      dotThirdhWidth : CGFloat { return  dotWidth  / 3.0 }
	var      dotEighthWidth : CGFloat { return  dotWidth  / 8.0 }
	var       sideDotRadius : CGFloat { return  dotWidth  * 0.25 }
	var                font :   ZFont { return .systemFont(ofSize: fontSize) }
	func  dotSize(forReveal : Bool) -> CGSize { return CGSize(width: forReveal ? dotHeight : dotWidth, height: dotHeight) }

}

extension ZFavoritesMapController {

	override var coreThickness: CGFloat { return super.coreThickness * kSmallMapReduction }
	override var  coreFontSize: CGFloat { return super .coreFontSize * kSmallMapReduction }

}

extension ZHelpDotsExemplarController {

	override var horizontalGap: CGFloat { return kDefaultHorizontalGap * 1.3 }
	override var coreThickness: CGFloat { return kDefaultLineThickness }
	override var  coreFontSize: CGFloat { return kDefaultBaseFontSize * 0.7 }

}

extension ZHelpController {

	override var coreThickness: CGFloat { return kDefaultLineThickness }
	override var  coreFontSize: CGFloat { return kDefaultBaseFontSize * 1.4 }

}
