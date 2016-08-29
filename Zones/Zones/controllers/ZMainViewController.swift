//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Cocoa


class ZMainViewController: ZViewController {

    @IBOutlet weak var label: NSTextField!

    var root: Zone = zonesManager.root()


    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        label.stringValue = root.zoneName!
    }
    
}

