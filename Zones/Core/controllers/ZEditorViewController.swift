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


    override func update() {
        if widget != nil {
            widget.removeFromSuperview()
        }

        widget            = ZoneWidget()
        widget.widgetZone = zonesManager.rootZone!

        zonesManager.clearWidgets()
        widget.layoutInView(view, atIndex: -1)
        widget.updateConstraints()
        widget.layoutFinish()

        ZoneWidget.capturing = false
    }


    func deselect() {
        zonesManager.currentlyEditingZone = nil
        zonesManager.currentlyGrabbedZones = []

        update()
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.captureText()
    }


    override func userEvent() {
        deselect()
    }
}
