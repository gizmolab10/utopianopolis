//
//  ZStartupProgressBar.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/4/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZStartupProgressBar: NSProgressIndicator {

	var fractionOfRecords: Double {
		let partial = Double(gRemoteStorage.totalRecordsCount)
		let   total = Double(gFiles.approximatedRecords)

		return partial / total
	}

	var fractionOfOperations: Double {
		let   first = Double(ZOperationID.oReadFile.rawValue)
		let  second = Double(ZOperationID.oDone    .rawValue) - first
		let current = Double(gCurrentOp.rawValue)

		return (current - first) / second
	}

	var fraction: Double {
		let   first = Double(gStartup.count) / 50.0
		let  second = fractionOfOperations
		let partial = fractionOfRecords

		if  first < 1.0 {
			return       first
		} else if gCurrentOp == .oReadFile {
			return 1.0 + partial
		} else {
			return 2.0 + second
		}
	}

	func update() {
		if  gCurrentOp    != .oCompletion {
			let multiplier = maxValue - minValue
			let      value = multiplier * fraction / 3.0
			doubleValue    = value + minValue
		}
	}

}
