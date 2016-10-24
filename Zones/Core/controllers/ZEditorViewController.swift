//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import SnapKit


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditorViewController: ZViewController {

    
    @IBOutlet weak var widget: ZoneWidget!
    var childrenWidgets: [ZoneWidget] = []


    override open func viewDidLoad() {
        super.viewDidLoad()

        modelManager.registerUpdateClosure { (kind, object) -> (Void) in
            if kind == UpdateKind.data {
                self.update()
            }
        }
    }


    func update() {
        let          zone = modelManager.selectedZone!
        var         count = zone.children.count
        widget.widgetZone = zone
        let  rect: CGRect = widget.updateInView(view)

        while childrenWidgets.count != count {
            childrenWidgets.append(ZoneWidget())
        }

        while count > 0 {
            count                      -= 1
            let childWidget: ZoneWidget = childrenWidgets[count]
            childWidget.widgetZone      = zone.children  [count]

            //   childWidget.updateInView(view, atOffset: offset)
        }
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.captureText()
    }
}
