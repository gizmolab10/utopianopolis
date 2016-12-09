//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZEditorViewController: ZGenericViewController {

    
    var hereWidget:                 ZoneWidget = ZoneWidget()
    @IBOutlet var spinner: ZProgressIndicator?


    override func identifier() -> ZControllerID { return .editor }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        let                        zone = object as? Zone
        var specificWidget: ZoneWidget? = hereWidget
        var specificView:        ZView? = view
        var specificindex:          Int = -1
        var recursing:             Bool = kind == .data
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

        specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing)
        specificWidget?.updateConstraints()
        specificWidget?.layoutFinish()
        specificWidget?.display()

        textCapturing = false
    }


    override func displayActivity() {
        let isActive = !operationsManager.isReady

        spinner?.isHidden = !isActive

        if isActive {
            spinner?.startAnimating()
        } else {
            spinner?.stopAnimating()
        }
    }


    override func setup() {
        view.setupGestures(self, action: #selector(ZEditorViewController.gestureEvent))
        super.setup()
    }

    
    func gestureEvent(_ sender: ZGestureRecognizer?) {
        selectionManager.deselect()
    }
}
