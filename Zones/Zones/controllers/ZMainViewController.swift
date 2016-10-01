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


    override open func viewDidLoad() {
        super.viewDidLoad()
        modelManager.register { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.root.zoneName {
                    self.label.stringValue = name
                }
            }
        }
    }
    
}

