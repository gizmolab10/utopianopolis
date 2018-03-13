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


    var cloudStatusText: String {
        let      operationCount = gBatchManager.queue.operationCount
        let    countsSuffixText = operationCount == 1 ? "" : "s"
        let operationsCountText = operationCount == 0 ? "" : "\(operationCount) cloud operation\(countsSuffixText) in progress"

        return gNoInternet ? "no internet" : !gHasCloudAccount ? "missing or invalid Apple ID" : operationsCountText
    }


    var totalCountsText: String {
        let (count, notSavableCount) = gCloudManager.undeletedCounts
        let                    total = gRemoteStoresManager.rootProgenyCount

        return "of \(total), retrieved: \(count) + \(notSavableCount)"
    }


    var graphNameText: String {
        if let dbID = currentZone.databaseID {
            return dbID.rawValue + " database"
        }

        return ""
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) && gReadyState {
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
