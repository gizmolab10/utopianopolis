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
        } else if gWorkMode != .editMode {
            view.snp.removeConstraints()
            hereWidget.removeFromSuperview()

            return
        }

        let                        zone = object as? Zone
        var specificWidget: ZoneWidget? = hereWidget
        var specificView:        ZView? = view
        var specificindex:         Int? = nil
        var recursing:             Bool = [.data, .redraw].contains(kind)
        hereWidget.widgetZone           = gTravelManager.hereZone

        if zone == nil || zone == gTravelManager.hereZone {
            recursing = true

            toConsole("all")
        } else {
            specificWidget = gWidgetsManager.widgetForZone(zone!)
            specificView   = specificWidget?.superview
            specificindex  = zone!.siblingIndex

            if zone!.isSelected {
                zone!.grab()
            }

            toConsole(zone?.zoneName)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind)
        specificWidget?.updateConstraints()
        specificWidget?.layoutFinish()
        specificWidget?.display()

        view.zlayer.backgroundColor = gBackgroundColor.cgColor
        gTextCapturing               = false
    }


    func handleDragEvent(_ iGesture: ZGestureRecognizer?) {
        if  iGesture != nil, let location = iGesture?.location(in: view) {
            let  dot = iGesture!.target as! ZoneDot
            let name = dot.widgetZone!.zoneName!

            report("\(name) \(iGesture!.state.rawValue) at \(location.debugDescription)")
        }
    }


    override func displayActivity() {
        let isReady = gOperationsManager.isReady

        spinner?.isHidden = isReady

        if isReady {
            spinner?.stopAnimating()
        } else {
            spinner?.startAnimating()
        }
    }


    override func setup() {
        view.clearGestures()
        view.createPointGestureRecognizer(self, action: #selector(ZEditorViewController.oneClick), clicksRequired: 1)
        super.setup()
    }

    
    func oneClick(_ sender: ZGestureRecognizer?) {
        gShowsSearching = false

        gSelectionManager.deselect()
        signalFor(nil, regarding: .search)
    }
}
