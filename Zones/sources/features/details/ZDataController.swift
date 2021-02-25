//
//  ZInformationController.swift
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

class ZDataController: ZGenericController {

	@IBOutlet var creationDateLabel: ZTextField?
	@IBOutlet var  cloudStatusLabel: ZTextField?
    @IBOutlet var   totalCountLabel: ZTextField?
	@IBOutlet var   recordNameLabel: ZTextField?
	@IBOutlet var     synopsisLabel: ZTextField?
    @IBOutlet var      mapNameLabel: ZTextField?
    var                 currentZone: Zone?         { return gSelecting.rootMostMoveable }
    override  var      controllerID: ZControllerID { return .idData }

    var versionText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return "BUILD ERROR --- NO VERSION"
    }

    var totalCountsText: String {
		let   root = gRecords?.rootZone
		let  depth =  root?.maxDepth ?? 0
		let  count = (root?.progenyCount ?? 0) + 1 // add one for root
		let suffix =    count != 1 ? "s" : ""
		let result = "\(count) idea\(suffix), \(depth) depth"

		return result
	}

    var mapNameText: String {
        if  let dbID = currentZone?.databaseID {
            return "in \(dbID.userReadableString) database"
        }

        return ""
    }

    var statusText: String {
		let    cdStatus = gCoreDataStack.statusText
        let    opStatus =       gBatches.statusText
		let timerStatus =        gTimers.statusText

		return cdStatus != "" ? cdStatus :
			opStatus    != "" ? opStatus :
			timerStatus != "" ? timerStatus :
			gCloudStatusIsActive ? "all data synchronized" : "all data saved locally"
    }

	var zoneRecordNameText: String {
		var text = ""

		if  let zone = currentZone,
			let name = zone.ckRecordName {
			let type = zone.type.identifier.uppercased()
			text     = name

			if  gDebugInfo, type.count > 0 {
				text     = "\(type) \(text)"
			}

		}

		return text
	}

	var creationDateText: String {
		var   date: Date? // currentZone?.record?.modificationDate
		var prefix = "last edited"

		if  date == nil {
			date = currentZone?.ckRecord?.creationDate
			prefix = "created"
		}

		if  let d = date {
			return "\(prefix) on \(d.easyToReadDate) at \(d.easyToReadTime)"
		}
		
		return ""
	}    

	var synopsisText: String {
		guard let zone = currentZone,
			  gIsReadyToShowUI else {
			return ""
		}

		zone.updateAllProgenyCounts()

		var  text = "level \(zone.level + 1)"
		let zones = gSelecting.currentGrabs

		if  zones.count > 1 {
			text.append("   (\(zones.count) selected)")
		} else {
			let p = zone.progenyCount
			let c = zone.count
			let n = zone.zonesWithNotes.count

			if  c > 0 {
				text.append("   (\(c) in list")

				if  p > c {
					text.append(", \(p) total")
				}

				text.append(")")
			}

			if  n > 0 {
				text.append(" and \(n) notes")
			}
		}

		return text
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		creationDateLabel?.text = creationDateText
		cloudStatusLabel? .text = statusText
		recordNameLabel?  .text = zoneRecordNameText
		totalCountLabel?  .text = totalCountsText
		mapNameLabel?     .text = mapNameText

		if  iKind != .sStartupProgress {
			synopsisLabel?.text = synopsisText
		}
	}

}
