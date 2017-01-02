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


class ZEditorViewController: ZGenericViewController, ZGestureRecognizerDelegate {

    
    var hereWidget:                 ZoneWidget = ZoneWidget()
    @IBOutlet var spinner: ZProgressIndicator?


    override func identifier() -> ZControllerID { return .editor }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if [.search, .found].contains(kind) {
            return
        } else if workMode != .editMode {
            view.snp.removeConstraints()
            hereWidget.removeFromSuperview()

            return
        }

        let                        zone = object as? Zone
        var specificWidget: ZoneWidget? = hereWidget
        var specificView:        ZView? = view
        var specificindex:          Int = -1
        var recursing:             Bool = [.data, .redraw].contains(kind)
        hereWidget.widgetZone           = travelManager.hereZone!

        if zone == nil || zone == travelManager.hereZone! {
            recursing = true

            toConsole("all")
        } else {
            specificWidget = widgetsManager.widgetForZone(zone!)
            specificView   = specificWidget?.superview
            specificindex  = zone!.siblingIndex()

            toConsole(zone?.zoneName)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, redrawLines: kind == .redraw)
        specificWidget?.updateConstraints()
        specificWidget?.layoutFinish()
        specificWidget?.display()
        setup()

        textCapturing = false
    }


    override func displayActivity() {
        let isReady = operationsManager.isReady

        spinner?.isHidden = isReady

        if isReady {
            spinner?.stopAnimating()
        } else {
            spinner?.startAnimating()
        }
    }


    override func setup() {
        view.clearGestures()
        view.createGestureRecognizer(self, action: #selector(ZEditorViewController.oneClick), clicksRequired: 1)
        super.setup()
    }

    
    func oneClick(_ sender: ZGestureRecognizer?) {
        selectionManager.deselect()
    }
}
