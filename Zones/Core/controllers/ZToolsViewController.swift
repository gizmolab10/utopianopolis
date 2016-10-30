//
//  ZToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZToolsViewController: ZGenericViewController {


    @IBOutlet weak var        toolsChoiceControl: ZSegmentedControl!
    @IBOutlet weak var editingToolsContainerView: ZView!
    @IBOutlet weak var     settingsContainerView: ZView!
    @IBOutlet weak var            containersView: ZView!
    var                       frontContainerView: ZView?


    @IBAction func choiceAction(_ control: ZSegmentedControl) {
        let mode = ZToolMode(rawValue: control.selectedSegmentIndex)!
        stateManager.toolState = mode

        switch mode {
        case .edit: frontContainerView = editingToolsContainerView; break
        case .travel:                                               break
        case .settings: frontContainerView = settingsContainerView; break
        }

        update()
    }


    override func update() {
        let mode = stateManager.toolState
        toolsChoiceControl.selectedSegmentIndex = mode.rawValue

        if frontContainerView != nil {
            for subView in containersView.subviews {
                subView.isHidden = subView != frontContainerView
            }
        }
    }
}
