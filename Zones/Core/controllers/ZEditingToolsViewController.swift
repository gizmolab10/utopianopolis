//
//  ZEditingToolsViewController.swift
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


class ZEditingToolsViewController: ZBaseViewController {


    @IBOutlet weak var            newZoneButton: ZButton!
    @IBOutlet weak var         deleteZoneButton: ZButton!
    @IBOutlet weak var         moveZoneUpButton: ZButton!
    @IBOutlet weak var       moveZoneDownButton: ZButton!
    @IBOutlet weak var childrenVisibilityButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        modelManager.editAction(ZActionKind(rawValue: UInt(button.tag))!)
    }


    override func update() {
        let hasSelection = modelManager.selectedZone != nil

        deleteZoneButton         .isHidden = !hasSelection
        moveZoneUpButton         .isHidden = !hasSelection
        moveZoneDownButton       .isHidden = !hasSelection
        childrenVisibilityButton .isHidden = !hasSelection || modelManager.selectedZone?.children.count == 0

        if hasSelection {
            let               showChildren = modelManager.selectedZone?.showChildren
            childrenVisibilityButton.title = showChildren! ? "Collapse" : "Expand"
        }
    }
}
