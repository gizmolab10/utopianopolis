//
//  ZToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZToolsViewController: ZGenericViewController {


    override func identifier() -> ZControllerID { return .settings }


    @IBAction func genericButtonAction(_ button: ZButton) {
        cloudManager.flushOnCompletion {}
    }


    @IBAction func normalizeButtonAction(_ button: ZButton) {
        editingManager.normalize()
    }


    @IBAction func editModeChoiceAction(_ control: ZSegmentedControl) {
        stateManager.editMode = ZEditMode(rawValue: control.selectedSegment)!
    }
}
