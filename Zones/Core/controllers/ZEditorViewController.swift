//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZEditorViewController: ZGenericViewController {

    
    var widget: ZoneWidget!


    override func updateFor(_ object: NSObject?) {
        var specificWidget: ZoneWidget?
        var specificView: ZView?

        if object != nil && object != zonesManager.rootZone! {
            specificWidget = zonesManager.widgetForZone(object as! Zone)
            specificView   = specificWidget?.superview
        } else {
            if widget != nil {
                widget.removeFromSuperview()
            }

            widget            = ZoneWidget()
            widget.widgetZone = zonesManager.rootZone!
            specificWidget    = widget
            specificView      = view

            zonesManager.clearWidgets()
        }

        specificWidget?.layoutInView(specificView!, atIndex: -1)
        specificWidget?.updateConstraints()
        specificWidget?.layoutFinish()

        ZoneWidget.capturing = false
    }


    func deselect() {
        let                         object = zonesManager.currentlyMovableZone
        zonesManager.currentlyEditingZone  = nil
        zonesManager.currentlyGrabbedZones = []

        updateFor(object)
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.captureText()
    }


    override func userEvent() {
        deselect()
    }
}
