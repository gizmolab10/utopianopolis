//
//  ZInformationController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZInformationController: ZGenericController {


    @IBOutlet var cloudStatusLabel: ZTextField?
    @IBOutlet var  totalCountLabel: ZTextField?
    @IBOutlet var   graphNameLabel: ZTextField?
    @IBOutlet var     versionLabel: ZTextField?
    @IBOutlet var       levelLabel: ZTextField?
    var                currentZone: Zone    { return gSelectionManager.rootMostMoveable }
    override var   backgroundColor: CGColor { return gDarkishBackgroundColor }


    override func setup() {
        controllerID = .information
    }


    var versionText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return "BUILD ERROR --- NO VERSION"
    }


    var totalCountsText: String {
        let count = gCloudManager?.rootZone?.progenyCount ?? 0

        return "\(count + 1) ideas"
    }


    var graphNameText: String {
        if let dbID = currentZone.databaseID {
            return "in \(dbID.text) database"
        }

        return ""
    }


    var cloudStatusText: String {
        if !gCloudAccountIsActive { return "local storage only" }
        
        let ops = // String.pluralized(gBatchManager.totalCount - 1,       unit: "batch", plural: "es", followedBy: ", ") +
                  String.pluralized(gBatchManager.queue.operationCount, unit: "iCloud request")
        return ops != "" ? ops : "synced with iCloud"
    }
    

    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) {
            cloudStatusLabel?.text = cloudStatusText
            totalCountLabel? .text = totalCountsText
            graphNameLabel?  .text = graphNameText
            versionLabel?    .text = versionText

            if iKind != .startup {
                levelLabel?  .text = "your selection is at level \(currentZone.level + 1)"
            }
        }
    }


    @IBAction func debugButtonAction(_ sender: Any?) {
        gShowDebugDetails = !gShowDebugDetails

        gDetailsController?.displayViewsFor(ids: [.Tools, .Debug])
    }
}
