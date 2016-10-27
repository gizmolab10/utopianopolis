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


class ZEditorViewController: ZViewController {

    
    let widget: ZoneWidget! = ZoneWidget()


    override open func viewDidLoad() {
        super.viewDidLoad()

        modelManager.registerUpdateClosure { (kind, object) -> (Void) in
            if kind != .error {
                self.update()
            }
        }
    }


    func update() {
        widget.widgetZone = modelManager.rootZone!

        widget.updateInView(view, atIndex: -1)
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.captureText()
    }
}
