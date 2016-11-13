//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZSettingsViewController: ZGenericViewController {


    @IBOutlet weak var flushButton: ZButton!


    override func identifier() -> ZControllerID { return .settings }


    @IBAction func genericButtonAction(_ button: ZButton) {
        cloudManager.flushOnCompletion {}
    }
}
