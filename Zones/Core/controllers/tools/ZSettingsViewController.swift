//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZSettingsViewController: ZGenericViewController {


    override func identifier() -> ZControllerID { return .settings }


    @IBAction func genericButtonAction(_ button: ZButton) {
        cloudManager.flushOnCompletion {}
    }


    @IBAction func normalizeButtonAction(_ button: ZButton) {
        editingManager.normalize()
    }

}
