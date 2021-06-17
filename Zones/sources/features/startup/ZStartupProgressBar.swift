//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZStartupProgressBar: NSProgressIndicator {

	func updateProgress() {
		if  gCurrentOp    != .oCompletion,
			gAssureProgressTimesAreLoaded() {

			let  totalTime = gTotalTime
			let multiplier = maxValue - minValue
			let      value = multiplier * gStartup.elapsedStartupTime / totalTime
			doubleValue    = value + minValue

			printDebug(.dTime, "\(doubleValue.stringToTwoDecimals)      \(gCurrentOp)")
		}
	}

}
