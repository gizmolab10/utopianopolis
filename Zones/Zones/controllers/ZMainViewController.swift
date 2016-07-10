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


    @IBOutlet weak var outlineView: ZOutlineView?


    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int { return ideasController.arrangedObjects.count }


}

