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
        if  let            location = iGesture?.location (in: view) {
            let             nearest = hereWidget.widgetNearestTo(location, in: view)
            let              relate = relationOf(location, to: nearest?.textWidget)
            let                done = [ZGestureRecognizerState.ended, ZGestureRecognizerState.cancelled].contains(iGesture!.state)
            let                 dot = iGesture?.view as! ZoneDot
            let               mover = dot.widgetZone
            var        dragDropZone = nearest?.widgetZone
            let       dragDropIndex = dragDropZone?.siblingIndex
            let        notUseParent = relate == .upon || dragDropZone == gHere
            let              isHere = dragDropZone == gHere
            let                same = mover == dragDropZone
            dragDropZone            = same ? nil : notUseParent ? dragDropZone : dragDropZone?.parentZone
            let          sameParent = dragDropZone == mover?.parentZone
            let                bump = (sameParent && dragDropIndex != nil && mover!.siblingIndex! <= dragDropIndex!) ? 1 : 0
            let               index = (isHere ? (relate != .below ? 0 : dragDropZone?.count) : (notUseParent  || dragDropIndex == nil) ? ((asTask || same) ? 0 : dragDropZone?.count) : (dragDropIndex! + relate.rawValue))!
            let           sameIndex = mover?.siblingIndex == index || mover?.siblingIndex == index - 1
            let              isNoop = sameIndex && (mover?.isChild(of: dragDropZone) ?? false)
            let                   s = gSelectionManager
            let               prior = s.dragDropZone?.widget
            s      .dragDropIndices = isNoop ? nil : NSMutableIndexSet(index: index)
            s         .dragDropZone = isNoop ? nil : done ? nil : dragDropZone
            s            .dragPoint = isNoop ? nil : location

            if !isNoop && index > 0 && relate != .upon {
                s.dragDropIndices?.add(index - 1)
            }

            prior?      .displayForDrag()  // erase  children lines
            nearest?    .displayForDrag()  // redraw children lines
            gEditorView?.setNeedsDisplay() // redraw dragline and dot

            if done {
                let               e = gEditingManager
                let           prior = mover?.widget
                s .zoneBeingDragged = nil
                s     .dragDropZone = nil
                s        .dragPoint = nil

                prior?.dragDot.innerDot?.setNeedsDisplay()

                if let t = dragDropZone, let m = mover {
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
