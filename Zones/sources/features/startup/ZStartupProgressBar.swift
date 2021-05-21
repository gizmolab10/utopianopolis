//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZStartupProgressBar: NSProgressIndicator {

	var totalStartupTime : Double {
		gAssureProgressTimesAreLoaded()

		return gProgressTimes.values.reduce(0, +)
	}

	func update() {
		if  gCurrentOp    != .oCompletion {
			let multiplier = maxValue - minValue
			let      value = multiplier * gStartup.elapsedStartupTime / totalStartupTime
			doubleValue    = value + minValue

			printDebug(.dTime, "\(doubleValue.stringToTwoDecimals)      \(gCurrentOp)")
		}
	}

}
