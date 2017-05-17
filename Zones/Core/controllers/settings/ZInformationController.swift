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


    @IBOutlet var fractionInMemory: ZProgressIndicator?
    @IBOutlet var  totalCountLabel: ZTextField?
    @IBOutlet var   graphNameLabel: ZTextField?
    @IBOutlet var     versionLabel: ZTextField?
    @IBOutlet var       levelLabel: ZTextField?


    override func identifier() -> ZControllerID { return .information }


    override func awakeFromNib() {
        view.zlayer.backgroundColor = CGColor.clear
        fractionInMemory? .minValue = 0
    }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let                     count = gRemoteStoresManager.recordsManagerFor(storageMode).undeletedCount
        let                     total = gRemoteStoresManager.rootProgenyCount // TODO wrong manager
        totalCountLabel?        .text = "of \(total), retrieved: \(count)"
        graphNameLabel?         .text = "graph: \(gStorageMode.rawValue)"
        levelLabel?             .text = "level: \(gHere.level)"
        fractionInMemory?.doubleValue = Double(count)
        fractionInMemory?   .maxValue = Double(total)

        if let                version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            versionLabel?       .text = "Focus version \(version)"
        }
    }
}
