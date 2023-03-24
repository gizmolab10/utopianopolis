//
//  ZDataDetailsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZDataDetailsController: ZGenericController {

	@IBOutlet var modificationDateLabel: ZTextField?
	@IBOutlet var      cloudStatusLabel: ZTextField?
    @IBOutlet var       totalCountLabel: ZTextField?
	@IBOutlet var       recordNameLabel: ZTextField?
	@IBOutlet var         synopsisLabel: ZTextField?
    override  var          controllerID: ZControllerID { return .idDataDetails }
	var                     currentZone: Zone?         { return gSelecting.rootMostMoveable }

	override func handleSignal(kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vData) {
			modificationDateLabel?.text  = modificationDateText
			cloudStatusLabel?     .text  = statusText
			recordNameLabel?      .text  = zoneRecordNameText
			totalCountLabel?      .text  = totalCountsText
			synopsisLabel?        .text  = synopsisText
		}
	}

	var modificationDateText: String {
		var     text = kEmpty
		if  let zone = currentZone,
			let date = zone.modificationDate {
			text     = date.easyToReadDateTime
		}

		return text
	}

    var versionText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return "BUILD ERROR --- NO VERSION"
    }

    var totalCountsText: String {
		let   root = gRecords.rootZone
		let  depth = gCloud?.maxLevel ?? 0
		let  count = (root?.progenyCount ?? 0) + 1 // add one for root
		let suffix =    count != 1 ? "s" : kEmpty
		let result = "\(count) idea\(suffix), \(depth) deep"

		return result
	}

    var statusText: String {
		let    cdStatus = gCoreDataStack.statusText
        let    opStatus =       gBatches.statusText
		let timerStatus =        gTimers.statusText
		let        text = cdStatus ?? opStatus ?? timerStatus ?? "all data synchronized\(gCloudStatusIsActive ? kEmpty : " locally")"

		return text
    }

	var zoneRecordNameText: String {
		var     text = kEmpty

		if  let zone = currentZone,
			let name = zone.recordName {
			text     = name
		}

		return text
	}

	var synopsisText: String {
		guard let current = currentZone,
			  gIsReadyToShowUI else {
			return kEmpty
		}

		current.updateAllProgenyCounts()

		var  text = "level \(current.level + 1)"
		let grabs = gSelecting.currentMapGrabs

		if  grabs.count > 1 {
			text.append("   (\(grabs.count) selected)")
		} else {
			let p = current.progenyCount
			let c = current.count
			let n = current.zonesWithNotes.count

			if  c > 0 {
				text.append("   (\(c) in list")

				if  p > c {
					text.append(", \(p) total")
				}

				text.append(")")
			}

			if  n > 0 {
				text.append(" and \(n) note")

				if  n > 1 {
					text.append("s")
				}
			}
		}

		return text
	}

}
