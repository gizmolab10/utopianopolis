//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZStartupProgressBar: NSProgressIndicator {

	func update() {
		if  gCurrentOp    != .oCompletion {
			let multiplier = maxValue - minValue
			let      value = multiplier * gStartup.count / gTotalTime
			doubleValue    = value + minValue

			printDebug(.dTime, "\(value)      \(gCurrentOp)")
		}
	}

}
