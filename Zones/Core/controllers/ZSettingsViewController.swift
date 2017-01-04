//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif



class ZSettingsViewController: ZGenericViewController {


    @IBOutlet var  totalCountLabel: ZTextField?
    @IBOutlet var       depthLabel: ZTextField?
    @IBOutlet var fractionInMemory: NSProgressIndicator?


    override func identifier() -> ZControllerID { return .settings }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        //travelManager .manifest.total = 343
        let                     count = cloudManager.zones.count
        let                     total = travelManager.manifest.total
        totalCountLabel?        .text = "zones: \(count) of \(total)"
        depthLabel?             .text = "focus depth: \((travelManager.hereZone?.level)!)"
        fractionInMemory?   .minValue = 0
        fractionInMemory?   .maxValue = Double(total)
        fractionInMemory?.doubleValue = Double(count)
    }

    
    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        cloudManager.royalFlush {}
    }


    @IBAction func editModeChoiceAction(_ control: ZSegmentedControl) {
        editMode = ZEditMode(rawValue: control.selectedSegment)!
    }
}
