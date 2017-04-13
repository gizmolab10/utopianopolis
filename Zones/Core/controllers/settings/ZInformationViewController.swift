//
//  ZInformationViewController.swift
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


class ZInformationViewController: ZGenericViewController {


    @IBOutlet var fractionInMemory: ZProgressIndicator?
    @IBOutlet var  totalCountLabel: ZTextField?
    @IBOutlet var   graphNameLabel: ZTextField?
    @IBOutlet var     versionLabel: ZTextField?
    @IBOutlet var       levelLabel: ZTextField?


    override func identifier() -> ZControllerID { return .information }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        let                     count = gCloudManager.undeletedCount
        let                     total = gRoot.progenyCount + 1
        totalCountLabel?        .text = "of \(total), retrieved: \(count)"
        graphNameLabel?         .text = "graph: \(gStorageMode.rawValue)"
        levelLabel?             .text = "level: \(gHere.level)"
        view  .zlayer.backgroundColor = gBackgroundColor.cgColor
        fractionInMemory?   .maxValue = Double(total)
        fractionInMemory?.doubleValue = Double(count)

        if let                version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            versionLabel?       .text = "Focus version \(version)"
        }
    }


    override func awakeFromNib() {
        fractionInMemory?.minValue = 0
    }

}
