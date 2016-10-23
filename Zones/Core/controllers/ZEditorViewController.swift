//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

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


    func offsetAtIndex(_ index: CGFloat, inRect: CGRect, height: CGFloat) -> CGPoint {
        var offset: CGPoint = inRect.origin
        offset.y -= inRect.size.height
        offset.y += height + index * (height + stateManager.genericOffset.height)

        return offset
    }


    func rectForCount(_ count: CGFloat, fromRect: CGRect) -> CGRect {
        var rect: CGRect = fromRect
        rect.size.height = (rect.size.height * count) + (stateManager.genericOffset.height * (count - 1.0))
        rect.origin.x   += rect.size.width            +  stateManager.genericOffset.width
        rect.origin.y   += rect.size.height / 2.0

        return rect
    }


    func update() {
        let          zone = modelManager.selectedZone!
        var         count = zone.children.count
        widget.widgetZone = zone
        let  rect: CGRect = widget.updateInView(view)
        let wRect: CGRect = rectForCount(CGFloat(count), fromRect: rect)

        while childrenWidgets.count != count {
            childrenWidgets.append(ZoneWidget())
        }

        while count > 0 {
            count                      -= 1
            let childWidget: ZoneWidget = childrenWidgets[count]
            childWidget.widgetZone      = zone.children  [count]
            let offset:         CGPoint = offsetAtIndex(CGFloat(count), inRect: wRect, height: rect.size.height)

            childWidget.updateInView(view, atOffset: offset)
        }
    }


    @IBAction func tapped(_ sender: AnyObject) {
        widget.captureText()
    }
}
