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


    override func awakeFromNib() {
        view.zlayer.backgroundColor = CGColor.clear
        fractionInMemory? .minValue = 0

        // view.addSubview(ZTextField(frame: CGRect(x: 0, y: 0, width: 100, height: 22)))
    }

    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let                     count = gRemoteStoresManager.recordsManagerFor(storageMode).undeletedCount
        let                     total = gRemoteStoresManager.rootProgenyCount // TODO wrong manager
        totalCountLabel?        .text = "of \(total), retrieved: \(count)"
        graphNameLabel?         .text = "graph: \(gStorageMode.rawValue)"
        fractionInMemory?.doubleValue = Double(count)
        fractionInMemory?   .maxValue = Double(total)

        if kind != .startup {
            levelLabel?         .text = "level: \(gSelectionManager.rootMostMoveable.level)"
        }

        if let                version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            versionLabel?       .text = "Focus version \(version)"
        }
    }
}
