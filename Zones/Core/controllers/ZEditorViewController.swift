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
        var specificView:        ZView? = view
        var specificindex:          Int = -1

        if object != nil && object != zonesManager.rootZone! {
            let       zone = object as! Zone
            specificWidget = zonesManager.widgetForZone(zone)
            specificView   = specificWidget?.superview
            specificindex  = zone.siblingIndex()

            if let name = zone.zoneName {
                print(name)
            }
        } else {
            if widget != nil {
                widget.removeFromSuperview()
            }

            widget            = ZoneWidget()
            widget.widgetZone = zonesManager.rootZone!
            specificWidget    = widget

            print("root")
            zonesManager.clearWidgets()
        }

        specificWidget?.layoutInView(specificView, atIndex: specificindex)
        specificWidget?.updateConstraints()
        specificWidget?.layoutFinish()
        specificWidget?.display()

        stateManager.textCapturing = false
    }


    override func setup() {
        view.setupGestures(target: self, action: #selector(ZEditorViewController.gestureEvent))
        super.setup()
    }

    
    func gestureEvent(_ sender: ZGestureRecognizer) {
        zonesManager.deselect()
    }
}
