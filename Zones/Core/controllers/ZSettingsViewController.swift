//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZSettingsViewController: ZGenericViewController {


    @IBOutlet var totalCountLabel: ZTextField?


    override func identifier() -> ZControllerID { return .settings }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        totalCountLabel?.text = "zones: \(cloudManager.zones.count)"
    }

    
    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        cloudManager.royalFlush {}
    }


    @IBAction func editModeChoiceAction(_ control: ZSegmentedControl) {
        editMode = ZEditMode(rawValue: control.selectedSegment)!
    }
}
