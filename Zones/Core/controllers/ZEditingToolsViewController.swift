//
//  ZEditingToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZEditingToolsViewController: ZGenericViewController {


    @IBOutlet weak var           deleteZoneButton: ZButton!
    @IBOutlet weak var              newZoneButton: ZButton!
    @IBOutlet weak var               moveUpButton: ZButton!
    @IBOutlet weak var             moveDownButton: ZButton!
    @IBOutlet weak var         moveToParentButton: ZButton!
    @IBOutlet weak var moveIntoSiblingAboveButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        zonesManager.takeAction(ZEditAction(rawValue: UInt(button.tag))!)
    }


    override func updateFor(_ object: NSObject?) {
        let         zone = zonesManager.currentlyMovableZone
        let hasSelection = zone != nil
        let   parentZone = zone?.parentZone
        let     siblings = parentZone?.children
        let    hasParent = parentZone != nil
        let  hasSiblings = hasParent && (siblings?.count)! > 1
        let     atBottom = (siblings?.last  == zone)
        let        atTop = (siblings?.first == zone)

        deleteZoneButton          .isHidden = !hasSelection || !zonesManager.canDelete
        moveDownButton            .isHidden = !hasSelection || !hasSiblings || atBottom
        moveUpButton              .isHidden = !hasSelection || !hasSiblings || atTop
        moveIntoSiblingAboveButton.isHidden = !hasSelection || !hasSiblings || atTop
        moveToParentButton        .isHidden = !hasSelection || !hasParent   || parentZone?.parentZone == nil
    }
}
