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
        gTextCapturing                  = false
        hereWidget.widgetZone           = gHere
        view    .zlayer.backgroundColor = gBackgroundColor.cgColor

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
        if  let       location = iGesture?.location (in: view) {
            let    dropNearest = hereWidget.widgetNearestTo(location, in: view)
            var       dropZone = dropNearest?.widgetZone
            let      dropIndex = dropZone?.siblingIndex
            let       dropHere = dropZone == gHere
            let         relate = relationOf(location, to: dropNearest?.textWidget)
            let           done = [ZGestureRecognizerState.ended, ZGestureRecognizerState.cancelled].contains(iGesture!.state)
            let            dot = iGesture?.view as! ZoneDot
            let    draggedZone = dot.widgetZone!
            let           same = draggedZone == dropZone
            let      dragIndex = draggedZone.siblingIndex!
            let  useDropParent = relate != .upon && !dropHere
            ;         dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
            let     childCount = dropZone != nil ? dropZone!.count - 1 : 0
            let   dropIsParent = draggedZone.isChild(of: dropZone)
            let           bump = (dropIsParent && dropIndex != nil && dragIndex <= dropIndex!) ? 1 : 0
            var          index = useDropParent && dropIndex != nil ? (dropIndex! + relate.rawValue) : ((asTask || same) ? 0 : childCount)
            ;            index = !dropHere ? index : relate == .above ? 0 : childCount
            let      sameIndex = dragIndex == index || dragIndex == index - 1
            let         isNoop = same || (sameIndex && dropIsParent)
            let              s = gSelectionManager
            let          prior = s.dragDropZone?.widget
            s .dragDropIndices = isNoop ? nil : NSMutableIndexSet(index: index)
            s    .dragDropZone = isNoop ? nil : done ? nil : dropZone
            s    .dragRelation = isNoop ? nil : relate
            s       .dragPoint = isNoop ? nil : location

            if !isNoop && index > 0 && relate != .upon {
                s.dragDropIndices?.add(index - 1)
            }

            prior?              .displayForDrag() // erase  child lines
            dropZone?  .widget? .displayForDrag() // redraw child lines
            draggedZone.widget?.setNeedsDisplay() // redraw parent's child lines
            gEditorView?       .setNeedsDisplay() // redraw dragline and dot

            if done {
                let     editor = gEditingManager
                let      prior = draggedZone.widget
                s.dragDropZone = nil
                s .draggedZone = nil
                s   .dragPoint = nil

                prior?.dragDot.innerDot?.setNeedsDisplay()

                if let t = dropZone, !isNoop {
                    if t.isBookmark {
                        editor.moveZone(draggedZone, t)
                        editor.syncAndRedraw()
                    } else if !same, index >= bump {
                        editor.moveZone(draggedZone, into: t, at: index - bump, orphan: true) {
                            editor.syncAndRedraw()
                        }
                    }
                }
            }
        }
    }
}
