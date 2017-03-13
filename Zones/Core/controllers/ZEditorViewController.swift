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
        hereWidget.widgetZone           = gHere

        if zone != nil {
            specificWidget = zone!.widget
            specificindex  = zone!.siblingIndex
            specificView   = specificWidget?.superview

            if zone!.isSelected {
                zone!.grab()
            }

            toConsole(zone?.zoneName)
        } else if zone == gHere {
            recursing = true

            toConsole("all")
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
        if  iView    != nil {
            let point = view.convert(iPoint, to: iView)
            let frame = iView!.bounds
            let delta = point.x - frame.minX

            if     delta      > -10.0 {
                if frame.midY +   8.0 < point.y { return .below }
                if frame.midY -   8.0 > point.y { return .above }
            }
        }

        return .upon
    }


    func handleDragEvent(_ iGesture: ZGestureRecognizer?) {
        if  let        location = iGesture?.location (in: view) {
            let         nearest = hereWidget.widgetNearestTo(location, in: view)
            let          relate = relationOf(location, to: nearest?.textWidget)
            let            done = [ZGestureRecognizerState.ended, ZGestureRecognizerState.cancelled].contains(iGesture!.state)
            let             dot = iGesture?.view as! ZoneDot
            let           match = nearest?.widgetZone
            let          isHere = match == gHere
            let           mover = dot.widgetZone
            let            same = mover == match
            let        useMatch = relate == .upon || match == gHere
            let          target = same ? nil : useMatch ? match : match?.parentZone
            let      sameParent = target == mover?.parentZone
            let      matchIndex = match?.siblingIndex
            let            bump = (sameParent && matchIndex != nil && mover!.siblingIndex! <= matchIndex!) ? 1 : 0
            let           index = (isHere ? (relate != .below ? 0 : target?.count) : (useMatch  || matchIndex == nil) ? ((asTask || same) ? 0 : target?.count) : (matchIndex! + relate.rawValue))!
            let               s = gSelectionManager
            let           prior = s.targetDropZone?.widget
            s.targetLineIndices = NSMutableIndexSet(index: index)
            s   .targetDropZone = done ? nil : target
            s  .targetDragPoint = location

            if relate != .upon && index > 0 {
                s.targetLineIndices?.add(index - 1)
            }

            prior?      .displayForDrag()
            nearest?    .displayForDrag()
            gEditorView?.setNeedsDisplay()

            if done {
                let              e = gEditingManager
                let          prior = mover?.widget
                s.zoneBeingDragged = nil

                prior?.dragDot.innerDot?.setNeedsDisplay()

                if let t = target, let m = mover {
                    if t.isBookmark {
                        e.moveZone(m, t)

                        self.signalFor(nil, regarding: .redraw)
                    } else if !same, index >= bump {
                        e.moveZone(m, into: t, at: index - bump, orphan: true) {
                            e.syncAndRedraw()
                        }
                    }
                }
            }
        }
    }
}
