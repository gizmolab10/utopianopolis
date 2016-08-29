//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import UIKit


public class ZMainViewController: ZViewController {

    @IBOutlet weak var label: NSTextField!

    var root: Zone = zonesManager.root()


    @IBOutlet weak var label: UILabel!;


    public override func viewWillAppear(animated: Bool) -> Void {
        super.viewWillAppear(animated)
        label.text = root.zoneName
    }

}

