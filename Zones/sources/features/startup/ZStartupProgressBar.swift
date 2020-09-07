//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZStartupProgressBar: NSProgressIndicator {

	var fraction: Double {
		let   total = Double(gTotalTime)
		var partial = Double(gGetAccumulatedProgressTime(untilNotIncluding: gCurrentOp)) / total

		if  gCurrentOp.useTimer {
			let opTime = Double(gGetIndividualProgressTime(for: gCurrentOp))
			let  delta = gStartup.count / opTime
			partial   += delta
		}

		return partial
	}

	func update() {
		if  gCurrentOp    != .oCompletion {
			let multiplier = maxValue - minValue
			let      value = multiplier * fraction
			doubleValue    = value + minValue

			printDebug(.dTime, "\(value)      \(gCurrentOp)")
		}
	}

}
