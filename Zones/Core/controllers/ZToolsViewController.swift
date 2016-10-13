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


class ZToolsViewController: ZBaseViewController {


    @IBOutlet weak var toolsChoiceControl: ZSegmentedControl!


    @IBAction func choiceAction(_ control: ZSegmentedControl) {
        state.toolState = ZToolState(rawValue: control.selectedSegmentIndex)!
    }


    override func update() {
        toolsChoiceControl.selectedSegmentIndex = state.toolState.rawValue
    }
}
