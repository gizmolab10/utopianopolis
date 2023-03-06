//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZStartupProgressBar: NSProgressIndicator {

	func updateProgress() { doubleValue = minValue + ((maxValue - minValue) * gStartup.fractionOfLoadTime)  }

//	override func draw(_ iDirtyRect: CGRect) {
//		printDebug(.dTime, doubleValue.stringTo(precision: 2) + "      \(gCurrentOp)")
//		super.draw(frame)
//	}

}
