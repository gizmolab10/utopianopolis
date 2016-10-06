//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import UIKit


open class ZMainViewController: ZViewController {

    @IBOutlet weak var label: UILabel!

    
    override open func viewDidLoad() {
        super.viewDidLoad()
        modelManager.registerClosure { (kind) -> (Void) in
            if kind == UpdateKind.data {
                if let name: String = modelManager.currentZone.zoneName {
                    self.label.text = name
                }
            }
        }
    }

}

