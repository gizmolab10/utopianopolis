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


    @IBOutlet weak var      newZoneButton: ZButton!
    @IBOutlet weak var   deleteZoneButton: ZButton!
    @IBOutlet weak var   moveZoneUpButton: ZButton!
    @IBOutlet weak var moveZoneDownButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        modelManager.editAction(ZEditAction(rawValue: UInt(button.tag))!)
    }


    override func update() {
        let         zone = modelManager.currentlyEditingZone
        let       isRoot = zone == modelManager.rootZone
        let hasSelection = zone != nil
        let       parent = zone?.parent
        let     children = parent?.children
        let  hasSiblings = parent != nil && (children?.count)! > 1
        let        atTop = (children?.first == zone)
        let     atBottom = (children?.last  == zone)

        deleteZoneButton  .isHidden = !hasSelection || isRoot
        moveZoneUpButton  .isHidden = !hasSelection || !hasSiblings || atTop
        moveZoneDownButton.isHidden = !hasSelection || !hasSiblings || atBottom
    }
}
