//
//  ZEditorController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditorController: ZGenericController, ZGestureRecognizerDelegate {


    var         hereWidget = ZoneWidget()
    var    rubberbandStart = CGPoint.zero
    var rubberbandPreGrabs = [Zone] ()
    var   hitDot: ZoneDot? = nil
    var           dragView:  ZDragDrawView { return view as! ZDragDrawView }
    var       clickGesture:  ZGestureRecognizer?
    var  rubberbandGesture:  ZGestureRecognizer?
    @IBOutlet var  spinner:  ZProgressIndicator?


    override func identifier() -> ZControllerID { return .editor }


    override func setup() {
        view.clearGestures()

        rubberbandGesture = view.createDragGestureRecognizer (self, action: #selector(ZEditorController.rubberbandEvent))
        clickGesture      = view.createPointGestureRecognizer(self, action: #selector(ZEditorController.clickEvent), clicksRequired: 1)
        hitDot            = nil

        super.setup()
    }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind) {
            if gWorkMode != .editMode {
                view.snp.removeConstraints()
                hereWidget.removeFromSuperview()
            } else if !gEditingManager.isEditing {
                var                   recursing = true
                var specificWidget: ZoneWidget? = hereWidget
                var        specificView: ZView? = view
                var         specificindex: Int? = nil
                gTextCapturing                  = false
                hereWidget          .widgetZone = gHere

                if  let       zone = object as? Zone, zone != gHere {
                    specificWidget = zone.widget
                    specificindex  = zone.siblingIndex
                    specificView   = specificWidget?.superview
                    recursing      = [.data, .redraw].contains(kind)

                    if zone.isSelected {
                        zone.grab()
                    }
                }

                note("<  <  -  >  >  \(specificWidget?.widgetZone.zoneName ?? "---")")

                specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind, visited: [])
                view.applyToAllSubviews { iView in
                    iView.setNeedsDisplay()
                }
            }
        }
    }


    override func displayActivity(_ show: Bool) {
        spinner?.isHidden = !show

        if show {
            spinner?.startAnimating()
        } else {
            spinner?.stopAnimating()
        }
    }


    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return gestureRecognizer == rubberbandGesture && otherGestureRecognizer == clickGesture
    }

    
    func clickEvent(_ iGesture: ZGestureRecognizer?) {
        gShowsSearching      = false

        if  let      gesture = iGesture as? ZKeyClickGestureRecognizer {
            let     location = gesture.location (in: view)
            var onTextWidget = false

            if  let   widget = gEditingManager.editedTextWidget {
                let     rect = widget.convert(widget.bounds, to: view)
                onTextWidget = rect.contains(location)
            }

            if !onTextWidget {
                if let dot = dotHitTest(location) {
                    dot.clickEvent(iGesture)
                } else {
                    gSelectionManager.deselect()
                    signalFor(nil, regarding: .search)
                }
            }
        }

        setup()
    }


    // MARK:- rubberbanding
    // MARK:-


    typealias DotToBooleanClosure = (ZoneDot) -> (Bool)


    func dotHitTest(_ location: CGPoint) -> ZoneDot? {
        var hit: ZoneDot? = nil

        gHere.traverseApply { (iZone) -> (ZTraverseStatus) in
            if  let widget = iZone.widget {
                var   rect = widget.hitOuterRect
                rect       = widget.convert(rect, to: view)

                if rect.contains(location) {
                    let found: DotToBooleanClosure = { (iDot: ZoneDot) -> Bool in
                        rect   = iDot.bounds
                        rect   = iDot.convert(rect, to: self.view)
                        let found = rect.contains(location)

                        if found {
                            hit = iDot
                        }

                        return found
                    }

                    if found(widget.dragDot)   { return .eStop } else
                    if found(widget.toggleDot) { return .eStop }
                }
            }

            return .eContinue
        }

        return hit
    }


    func isTextEditing(at location: NSPoint) -> Bool {
        let e = gEditingManager

        if  e.isEditing, let textWidget = e.editedTextWidget {
            let rect = textWidget.convert(textWidget.bounds, to: view)

            return rect.contains(location)
        }

        return false
    }


    func rubberbandEvent(_ iGesture: ZGestureRecognizer?) {
        if  let  gesture = iGesture as? ZKeyPanGestureRecognizer {
            let location = gesture.location (in: view)
            let    state = gesture.state

            if isTextEditing(at: location) {
                gesture.cancel() // let text editor consume the gesture
            } else if hitDot != nil {
                hitDot!.dragEvent(iGesture)
            } else if state == .changed {
                updateRubberband(rect: CGRect(start: rubberbandStart, end: location))
            } else if state != .began {
                updateRubberband(rect: NSZeroRect)
            } else if let dot = dotHitTest(location) {
                hitDot  = dot

                dot.dragEvent(iGesture)
            } else { // began
                rubberbandStart = location
                hitDot          = nil

                //////////////////////
                // detect SHIFT key //
                //////////////////////

                if let modifiers = gesture.modifiers, modifiers.contains(.shift) {
                    rubberbandPreGrabs.append(contentsOf: gSelectionManager.currentGrabs)
                } else {
                    rubberbandPreGrabs.removeAll()
                }

                report("-- R --")
                gSelectionManager.deselect(retaining: rubberbandPreGrabs)
            }
        }
    }


    func updateRubberband(rect: CGRect) {
        dragView.rubberbandRect = rect

        if  rect.isEmpty {
            redrawAndSync()
            setup()
        } else {
            gSelectionManager.deselectGrabs(retaining: rubberbandPreGrabs)

            for widget in gWidgetsManager.widgets.values {
                if  let    hitRect = widget.hitRect {
                    let widgetRect = widget.convert(hitRect, to: view)

                    if  widgetRect.intersects(rect) {
                        gSelectionManager.addToGrab(widget.widgetZone)
                    }
                }
            }

            hereWidget.setNeedsDisplay()
        }

        view.setNeedsDisplay()
    }


    // MARK:- drag and drop
    // MARK:-


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  iView     != nil {
            let margin = CGFloat(5.0)
            let  point = view.convert(iPoint, to: iView)
            let   rect = iView!.bounds
            let      y = point.y

            if y < rect.minY + margin {
                relation = .above
            } else if y > rect.maxY - margin {
                relation = .below
            }
        }

        return relation
    }


    let doneState: [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]


    func dragEvent(for dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        let                      s = gSelectionManager
        let                   done = doneState.contains(iGesture!.state)

        if  let           location = iGesture?.location (in: view) {
            let        draggedZone = dot.widgetZone!
            if  let    dropNearest = hereWidget.widgetNearestTo(location) {
                var       dropZone = dropNearest.widgetZone
                let      dropIndex = dropZone?.siblingIndex
                let       dropHere = dropZone == gHere
                let           same = dropZone == draggedZone
                let       relation = relationOf(location, to: dropNearest.textWidget)
                let  useDropParent = relation != .upon && !dropHere
                ;         dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let  lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var          index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!naturally || same) ? 0 : lastDropIndex)
                ;            index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let      dragIndex = draggedZone.siblingIndex!
                let      sameIndex = dragIndex == index || dragIndex == index - 1
                let   dropIsParent = draggedZone.isChild(of: dropZone)
                let         isNoop = same || (sameIndex && dropIsParent) || index < 0
                let          prior = s.dragDropZone?.widget
                s .dragDropIndices = isNoop || done ? nil : NSMutableIndexSet(index: index)
                s    .dragDropZone = isNoop || done ? nil : dropZone
                s    .dragRelation = isNoop || done ? nil : relation
                s       .dragPoint = isNoop || done ? nil : location

                if !isNoop && !done && !dropHere && index > 0 {
                    s.dragDropIndices?.add(index - 1)
                }

                prior?           .displayForDrag() // erase  child lines
                dropZone?.widget?.displayForDrag() // redraw child lines
                view            .setNeedsDisplay() // redraw dragline and dot

                // performance("\(relation) \(dropZone?.zoneName ?? "no name")")

                if done {
                    let editor = gEditingManager
                    hitDot     = nil

                    draggedZone.widget?.dragDot.innerDot?.setNeedsDisplay()

                    if !isNoop && dropZone != nil {
                        if dropZone!.isBookmark {
                            editor.moveZone(draggedZone, dropZone!)
                            redrawAndSync()
                            setup()
                        } else {
                            if dropIsParent && dragIndex <= index {
                                index -= 1
                            }

                            editor.moveZone(draggedZone, into: dropZone!, at: index, orphan: true) {
                                self.redrawAndSync()
                            }
                        }
                    }
                }

                return
            }
        }

        // cursor exited view, remove drag cruft

        let            dot = s.dragDropZone?.widget?.toggleDot.innerDot // drag view does not "un"draw this
        rubberbandStart    = CGPoint.zero
        s .dragDropIndices = nil
        s    .dragDropZone = nil
        s    .dragRelation = nil
        s       .dragPoint = nil

        if done {
            setup()
        }

        dragView.setNeedsDisplay()
        dot?    .setNeedsDisplay()
    }
}
