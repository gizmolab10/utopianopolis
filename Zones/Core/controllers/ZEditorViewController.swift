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


    var        hereWidget = ZoneWidget()
    @IBOutlet var spinner:  ZProgressIndicator?


    override func identifier() -> ZControllerID { return .editor }


    override func setup() {
        view.clearGestures()
        view.createPointGestureRecognizer(self, action: #selector(ZEditorViewController.oneClick), clicksRequired: 1)
        super.setup()
    }


    // MARK:- events
    // MARK:-


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
        specificWidget?.display()

        view.zlayer.backgroundColor = gBackgroundColor.cgColor
        gTextCapturing              = false
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

    
    func oneClick(_ sender: ZGestureRecognizer?) {
        gShowsSearching = false

        gSelectionManager.deselect()
        signalFor(nil, regarding: .search)
    }


    // MARK:- dragon droppings
    // MARK:-


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        if     iView != nil {
            let point = view.convert(iPoint, to: iView)
            let frame = iView!.bounds
            let delta = point.x - frame.minX

            if     delta      > -10.0 {
                if frame.midY +   8.0 < point.y { return .below }
                if frame.midY -   8.0 > point.y { return .above }
            }

            // report("\(delta)")
        }

        return .upon
    }


    func handleDragEvent(_ iGesture: ZGestureRecognizer?) {
        if  iGesture    != nil, let location = iGesture?.location (in: view) {
            let         nearest = hereWidget.widgetNearestTo(   location, in: view)
            let          relate = relationOf(location, to: nearest?.textWidget)
            let            done = [NSGestureRecognizerState.ended, NSGestureRecognizerState.cancelled].contains(iGesture!.state)
            let             dot = iGesture?.target as! ZoneDot
            let           match = nearest?.widgetZone
            let           mover = dot.widgetZone
            let            same = mover == match
            let        useMatch = relate == .upon || match == gTravelManager.hereZone
            let          target = same ? nil : useMatch ? match : match?.parentZone
            let               s = gSelectionManager
            let      sameParent = target == s.zoneBeingDragged?.parentZone
            let      matchIndex = match?.siblingIndex
            let            bump = (sameParent && matchIndex != nil && s.zoneBeingDragged!.siblingIndex! <= matchIndex!) ? 1 : 0
            let           index = ((useMatch  || matchIndex == nil) ? ((asTask || same) ? 0 : target?.count) : (matchIndex! + relate.rawValue))!
            let           prior = gWidgetsManager.widgetForZone(s.targetDropZone)
            s.targetLineIndices = NSMutableIndexSet(index: index)
            s.targetDropZone    = done ? nil : target

            if relate != .upon && index > 0 { // target != nil && index < target!.count {
                // let delta = relate == .above ? 1 : -1

                s.targetLineIndices?.add(index - 1) // + delta)
            }

            prior?  .displayForDrag()
            nearest?.displayForDrag()

            if index == 4 {
                report("!!!")
            }

            if done {
                let                             prior = gWidgetsManager.widgetForZone(s.zoneBeingDragged)
                s.zoneBeingDragged                    = nil
                prior?.dragDot.innerDot?.needsDisplay = true

                if !same && mover != nil && target != nil && index >= 0 {
                    gEditingManager.moveZone(mover!, into: target!, at: index - bump, orphan: true) {
                        self.signalFor(nil, regarding: .redraw)
                    }
                }
            }
        }
    }
}
