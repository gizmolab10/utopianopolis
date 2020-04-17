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

class ZStatusController: ZGenericController {

	@IBOutlet var creationDateLabel: ZTextField?
	@IBOutlet var  cloudStatusLabel: ZTextField?
    @IBOutlet var   totalCountLabel: ZTextField?
    @IBOutlet var    graphNameLabel: ZTextField?
    @IBOutlet var      versionLabel: ZTextField?
    @IBOutlet var        levelLabel: ZTextField?
    var                 currentZone: Zone?         { return gSelecting.rootMostMoveable }
    override  var      controllerID: ZControllerID { return .idStatus }

    var versionText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return "BUILD ERROR --- NO VERSION"
    }

    var totalCountsText: String {
        let  count = (gCloud?.rootZone?.progenyCount ?? 0) + 1 // add one for root
        let suffix = count == 1 ? "" : "s"

        return "\(count) idea\(suffix)"
    }

    var graphNameText: String {
        if  let dbID = currentZone?.databaseID {
            return "in \(dbID.userReadableString) database"
        }

        return ""
    }

    var statusText: String {
        let    opStatus = gBatches.statusText
		let timerStatus =  gTimers.statusText

		return opStatus != "" ? opStatus : timerStatus != "" ? timerStatus : gCanAccessMyCloudDatabase ? "all data synchronized" : "all data saved locally"
    }

	var zoneRecordNameText: String {
		return currentZone?.recordName ?? ""
	}

	var creationDateText: String {
		var   date: Date? // currentZone?.record?.modificationDate
		var prefix = "last edited"

		if  date == nil {
			date = currentZone?.record?.creationDate
			prefix = "created"
		}

		if  let d = date {
			return "\(prefix) on \(d.easyToReadDate) at \(d.easyToReadTime)"
		}
		
		return ""
	}    

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if ![.sSearch, .sFound, .sCrumbs, .sSwap, .sRing].contains(iKind) {
			creationDateLabel?.text = zoneRecordNameText // creationDateText
            cloudStatusLabel? .text = statusText
            totalCountLabel?  .text = totalCountsText
            graphNameLabel?   .text = graphNameText
            versionLabel?     .text = versionText

            if iKind != .sStartup, let zone = currentZone {
                levelLabel?   .text = "is at level \(zone.level + 1)"
            }
        }
    }

}
