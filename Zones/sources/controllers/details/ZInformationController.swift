//
//  ZInformationController.swift
//  Thoughtful
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


class ZInformationController: ZGenericController {


	@IBOutlet var creationDateLabel: ZTextField?
	@IBOutlet var  cloudStatusLabel: ZTextField?
    @IBOutlet var   totalCountLabel: ZTextField?
    @IBOutlet var    graphNameLabel: ZTextField?
    @IBOutlet var      versionLabel: ZTextField?
    @IBOutlet var        levelLabel: ZTextField?
    var                 currentZone: Zone          { return gSelecting.rootMostMoveable }
    override  var   backgroundColor: CGColor       { return gDarkishBackgroundColor }
    override  var      controllerID: ZControllerID { return .idInformation }


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
        if let dbID = currentZone.databaseID {
            return "in \(dbID.userReadableString) database"
        }

        return ""
    }


    var cloudStatusText: String {
        if !gCanAccessMyCloudDatabase { return "local only" }
        
        let ops = // String.pluralized(gBatchManager.totalCount - 1,       unit: "batch", plural: "es", followedBy: ", ") +
                  String.pluralized(gBatches.queue.operationCount, unit: "iCloud request")
        return ops != "" ? ops : "synced with iCloud"
    }
	
	
	var creationDateText: String {
		var   date: Date? // currentZone.record?.modificationDate
		var prefix = "last edited"

		if  date == nil {
			date = currentZone.record?.creationDate
			prefix = "created"
		}

		if  let d = date {
			return "\(prefix) on \(d.easyToReadDate) at \(d.easyToReadTime)"
		}
		
		return ""
	}
    

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        if ![.eSearch, .eFound].contains(iKind) {
			creationDateLabel?.text = creationDateText
            cloudStatusLabel? .text = cloudStatusText
            totalCountLabel?  .text = totalCountsText
            graphNameLabel?   .text = graphNameText
            versionLabel?     .text = versionText

            if iKind != .eStartup {
                levelLabel?  .text = "is at level \(currentZone.level + 1)"
            }
        }
    }


    @IBAction func debugButtonAction(_ sender: Any?) {
        gShowDebugDetails = !gShowDebugDetails

        gDetailsController?.displayViewsFor(ids: [.Tools, .Debug])
    }
}
