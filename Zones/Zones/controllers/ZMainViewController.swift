//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Cocoa


class ZMainViewController: ZViewController, NSTextFieldDelegate {


    @IBOutlet weak var label: NSTextField!


    override open func viewDidLoad() {
        super.viewDidLoad()

        self.label.delegate = self

        modelManager.registerClosure { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.currentZone.zoneName {
                    self.label.stringValue = name
                }
            }
        }
    }
    

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        modelManager.currentZone.zoneName = label.stringValue;

        return true
    }

}

