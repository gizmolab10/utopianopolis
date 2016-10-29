//
//  ZToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZToolsViewController: ZGenericViewController {


    @IBOutlet weak var toolsChoiceControl: ZSegmentedControl!


    @IBAction func choiceAction(_ control: ZSegmentedControl) {
        stateManager.toolState = ZToolMode(rawValue: control.selectedSegmentIndex)!
    }


    override func update() {
        toolsChoiceControl.selectedSegmentIndex = stateManager.toolState.rawValue
    }
}
