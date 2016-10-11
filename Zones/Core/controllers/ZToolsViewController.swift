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


class ZToolsViewController: ZViewController {


    @IBOutlet weak var toolsChoiceControl: ZSegmentedControl!


    @IBAction func choiceAction(_ control: ZSegmentedControl) {
        state.toolState = ZToolState(rawValue: control.selectedSegmentIndex)!
    }



    #if os(OSX)
    override func viewWillAppear() {
        super.viewWillAppear()
        update()
    }
    #elseif os(iOS)
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }
    #endif


    func update() {
        toolsChoiceControl.selectedSegmentIndex = state.toolState.rawValue
    }
}
