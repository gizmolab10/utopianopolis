//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZStartupProgressBar: NSProgressIndicator {

	func updateProgress() {
		if  gAssureProgressTimesAreLoaded() {

			let  totalTime = gTotalTime
			let multiplier = maxValue - minValue
			let      value = multiplier * gStartup.elapsedStartupTime / totalTime
			doubleValue    = value + minValue

			printDebug(.dTime, "\(doubleValue.stringTo(precision: 2))      \(gCurrentOp)")
		}
	}

}
