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
        if  iView     != nil {
            let margin = CGFloat(5.0)
            let weight = CGFloat(gVerticalWeight)
            let  point = view.convert(iPoint, to: iView)
            let   rect = iView!.bounds
            let      y = weight * point.y

            if y > ((weight * rect.maxY) - margin) {
                return .below
            }

            if y < ((weight * rect.minY) + margin) {
                return .above
            }
        }

        return .upon
    }


    func handleDragEvent(_ iGesture: ZGestureRecognizer?) {
        if  let       location = iGesture?.location (in: view) {
            let           done = [ZGestureRecognizerState.ended, ZGestureRecognizerState.cancelled].contains(iGesture!.state)
            let            dot = iGesture?.view as! ZoneDot
            let    draggedZone = dot.widgetZone!
            let    dropNearest = hereWidget.widgetNearestTo(location, in: view)
            var       dropZone = dropNearest?.widgetZone
            let      dropIndex = dropZone?.siblingIndex
            let       dropHere = dropZone == gHere
            let           same = dropZone == draggedZone
            let       relation = relationOf(location, to: dropNearest?.textWidget)
            let  useDropParent = relation != .upon && !dropHere
            ;         dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
            let  lastDropIndex = dropZone == nil ? 0 : dropZone!.count
            var          index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((asTask || same) ? 0 : lastDropIndex)
            ;            index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
            let      dragIndex = draggedZone.siblingIndex!
            let      sameIndex = dragIndex == index || dragIndex == index - 1
            let   dropIsParent = draggedZone.isChild(of: dropZone)
            let         isNoop = same || (sameIndex && dropIsParent) || index < 0
            let              s = gSelectionManager
            let          prior = s.dragDropZone?.widget
            s .dragDropIndices = isNoop ? nil : NSMutableIndexSet(index: index)
            s    .dragDropZone = isNoop ? nil : done ? nil : dropZone
            s    .dragRelation = isNoop ? nil : relation
            s       .dragPoint = isNoop ? nil : location

            if !isNoop && !dropHere && index > 0 {
                s.dragDropIndices?.add(index - 1)
            }

            report("index \(index)")
            prior?             .displayForDrag() // erase  child lines
            dropZone?  .widget?.displayForDrag() // redraw child lines
            gEditorView?      .setNeedsDisplay() // redraw dragline and dot

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
                    } else if !same {
                        editor.moveZone(draggedZone, into: t, at: index, orphan: true) {
                            editor.syncAndRedraw()
                        }
                    }
                }
            }
        }
    }
}
