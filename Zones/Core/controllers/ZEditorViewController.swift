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


class ZEditorViewController: ZBaseViewController {

    
    var widget: ZoneWidget!


    override func update() {
        if widget != nil {
            widget.removeFromSuperview()
        }

        widget            = ZoneWidget()
        widget.widgetZone = modelManager.rootZone!

        widget.layoutView(view, atIndex: -1)
    }


    func unselect() {
        modelManager.currentlyEditingZone = nil

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
