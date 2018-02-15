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


    @IBOutlet var    fractionInMemory: ZProgressIndicator?
    @IBOutlet var operationCountLabel: ZTextField?
    @IBOutlet var     totalCountLabel: ZTextField?
    @IBOutlet var      graphNameLabel: ZTextField?
    @IBOutlet var        versionLabel: ZTextField?
    @IBOutlet var          levelLabel: ZTextField?


    override func setup() {
        controllerID               = .information
        fractionInMemory?.minValue = 0
    }


    var versionText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return "BUILD ERROR --- NO VERSION"
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) && gReadyState {
            let  (count, notSavableCount) = gCloudManager.undeletedCounts
            let                     total = gRemoteStoresManager.rootProgenyCount // TODO wrong manager
            let            operationCount = gBatchOperationsManager.queue.operationCount
            let                      zone = gSelectionManager.rootMostMoveable
            let                      dbID = zone.databaseID
            totalCountLabel?        .text = "of \(total), retrieved: \(count) + \(notSavableCount)"
            graphNameLabel?         .text = dbID == nil ? "" : "graph: \(dbID!.rawValue)"
            operationCountLabel?    .text = operationCount == 0 ? "" : "\(operationCount) cloud operation\(operationCount == 1 ? "" : "s") in progress"
            versionLabel?           .text = versionText
            fractionInMemory?.doubleValue = Double(count)
            fractionInMemory?   .maxValue = Double(total)

            if iKind != .startup {
                levelLabel?         .text = "level: \(zone.level)"
            }
        }
    }


    @IBAction func debugButtonAction(_ sender: Any?) {
        gDebugDetails = !gDebugDetails

        gDetailsController?.displayViewFor(ids: [.Tools, .Debug])
    }
}
