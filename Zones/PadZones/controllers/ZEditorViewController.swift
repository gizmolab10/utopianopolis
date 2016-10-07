//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import UIKit


class ZEditorViewController: ZViewController, ZoneWidgetDelegate {

    
    @IBOutlet weak var label: ZoneWidget!

    
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.label.delegate = self

        modelManager.registerUpdateClosure { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.currentZone.zoneName {
                    self.label.text = name
                }
            }
        }
    }


    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        modelManager.currentZone.zoneName = textField.text;

        return true
    }
}

