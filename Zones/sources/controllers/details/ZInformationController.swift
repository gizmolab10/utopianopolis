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
    var                currentZone: Zone { return gSelectionManager.rootMostMoveable }


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
        let (count, notSavableCount) = gCloudManager.undeletedCounts
        let                    total = gRemoteStoresManager.rootProgenyCount

        return "of roughly \(total), have: \(count) + \(notSavableCount)"
    }


    var graphNameText: String {
        if let dbID = currentZone.databaseID {
            return dbID.rawValue + " database"
        }

        return ""
    }


    var cloudStatusText: String {
        let  count = gBatchManager.queue.operationCount
        let plural = count == 1 ? "" : "s"
        let   text = count == 0 ? "" : "\(count) cloud operation\(plural) in progress"

        return !gHasInternet ? "no internet" : gCloudAccountStatus != .active ? "missing or invalid Apple ID" : text
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) && gIsReadyToShowUI {
            cloudStatusLabel?.text = cloudStatusText
            totalCountLabel? .text = totalCountsText
            graphNameLabel?  .text = graphNameText
            versionLabel?    .text = versionText

            if iKind != .startup {
                levelLabel?  .text = "level: \(currentZone.level)"
            }
        }
    }


    @IBAction func debugButtonAction(_ sender: Any?) {
        gDebugDetails = !gDebugDetails

        gDetailsController?.displayViewFor(ids: [.Tools, .Debug])
    }
}
