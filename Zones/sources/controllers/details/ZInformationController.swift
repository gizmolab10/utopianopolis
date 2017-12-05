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


    override  var     controllerID: ZControllerID { return .information }
    @IBOutlet var fractionInMemory: ZProgressIndicator?
    @IBOutlet var  totalCountLabel: ZTextField?
    @IBOutlet var   graphNameLabel: ZTextField?
    @IBOutlet var     versionLabel: ZTextField?
    @IBOutlet var       levelLabel: ZTextField?


    var versionText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return "BUILD ERROR --- NO VERSION"
    }


    override func awakeFromNib() {
        view.zlayer.backgroundColor = CGColor.clear
        fractionInMemory? .minValue = 0
    }

    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if ![.search, .found].contains(kind) {
            let                     count = gRemoteStoresManager.recordsManagerFor(gStorageMode)?.undeletedCount ?? 0
            let                     total = gRemoteStoresManager.rootProgenyCount // TODO wrong manager
            totalCountLabel?        .text = "of \(total), retrieved: \(count)"
            graphNameLabel?         .text = "graph: \(gStorageMode.rawValue)"
            fractionInMemory?.doubleValue = Double(count)
            fractionInMemory?   .maxValue = Double(total)
            versionLabel?           .text = versionText

            if kind != .startup {
                levelLabel?         .text = "level: \(gSelectionManager.rootMostMoveable.level)"
            }
        }
    }
}
