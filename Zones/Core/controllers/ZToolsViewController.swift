//
//  ZToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZToolsViewController: ZGenericViewController {


    override func identifier() -> ZControllerID { return .tools }


    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        cloudManager.royalFlush {}
    }


    @IBAction func normalizeButtonAction(_ button: ZButton) {
        editingManager.normalize()
    }


    @IBAction func editModeChoiceAction(_ control: ZSegmentedControl) {
        editMode = ZEditMode(rawValue: control.selectedSegment)!
    }


    @IBAction func ignoreFilesChoiceAction(_ control: ZSegmentedControl) {
        fileMode = ZFileMode(rawValue: control.selectedSegment)!
    }
}
