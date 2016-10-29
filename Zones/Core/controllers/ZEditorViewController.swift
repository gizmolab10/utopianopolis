//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditorViewController: ZGenericViewController {

    
    var widget: ZoneWidget!


    override func update() {
        if widget != nil {
            widget.removeFromSuperview()
        }

        widget            = ZoneWidget()
        widget.widgetZone = zonesManager.rootZone!

        widget.layoutInView(view, atIndex: -1)
    }


    func unselect() {
        zonesManager.currentlyEditingZone = nil

        update()
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.captureText()
    }


    #if os(OSX)

    override func mouseDown(with event: ZEvent) {
        super.mouseDown(with:event)

        unselect()
    }

    #elseif os(iOS)

    func mouseDown(with event: ZEvent) {
        unselect()
    }
    
    #endif
}
