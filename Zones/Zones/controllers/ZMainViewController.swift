//
//  ZMainViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import ZonesFramework
import Cocoa


class ZMainViewController: ZViewController, ZOutlineViewDataSource {


    @IBOutlet weak var treeController: NSTreeController?
    @IBOutlet weak var outlineView: NSOutlineView?


    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if let t = treeController {
            return t.arrangedObjects.count
        }

        return 0
    }


}

