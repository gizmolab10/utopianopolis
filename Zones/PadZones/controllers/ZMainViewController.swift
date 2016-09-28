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

    var root: Zone!

    
    open override func viewWillAppear(_ animated: Bool) -> Void {
        super.viewWillAppear(animated)
        label.text = root.zoneName
    }

}

