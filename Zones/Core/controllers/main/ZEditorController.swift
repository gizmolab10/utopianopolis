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


    // MARK:- initialization
    // MARK:-
    

    var           isDragging = false
    var draggedDot: ZoneDot? = nil
    var   rubberbandPreGrabs = [Zone] ()
    var      rubberbandStart = CGPoint.zero
    var           hereWidget = ZoneWidget()
    let            doneState: [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]
    var         clickGesture:  ZGestureRecognizer?
    var    rubberbandGesture:  ZGestureRecognizer?
    @IBOutlet var    spinner:  ZProgressIndicator?
    @IBOutlet var   dragView:  ZDragDrawView?
    @IBOutlet var scrollView:  ZScrollView?


    override func identifier() -> ZControllerID { return .editor }


    override func setup() {
        restartGestures()
        super.setup()
    }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind) {
            if gWorkMode != .editMode {
                dragView?.snp.removeConstraints()
                hereWidget.removeFromSuperview()
            } else if !gEditingManager.isEditing {
                var                   recursing = true
                var specificWidget: ZoneWidget? = hereWidget
                var        specificView: ZView? = dragView
                var         specificindex: Int? = nil
                gTextCapturing                  = false
                hereWidget          .widgetZone = gHere

                if  let       zone = object as? Zone, zone != gHere {
                    specificWidget = zone.widget
                    specificindex  = zone.siblingIndex
                    specificView   = specificWidget?.superview
                    recursing      = [.data, .redraw].contains(kind)
                }

                note("<  <  -  >  >  \(specificWidget?.widgetZone.zoneName ?? "---")")

                specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind, visited: [])

                dragView?.applyToAllSubviews { iView in
                    iView.setNeedsDisplay()
                }
            }
        }
    }


    func restartGestures() {
        dragView?.clearGestures()

        rubberbandGesture = dragView?.createDragGestureRecognizer (self, action: #selector(ZEditorController.rubberbandEvent))
        clickGesture      = dragView?.createPointGestureRecognizer(self, action: #selector(ZEditorController.clickEvent), clicksRequired: 1)
        isDragging        = false
    }


    func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
        return gestureRecognizer == rubberbandGesture && otherGestureRecognizer == clickGesture
    }

    
    func clickEvent(_ iGesture: ZGestureRecognizer?) {

        /////////////////////////////////////////////
        // called by controller and gesture system //
        /////////////////////////////////////////////

        gShowsSearching    = false

        if  let    gesture = iGesture {
            let   location = gesture.location(in: dragView)
            var   onWidget = false

            if  let widget = gEditingManager.editedTextWidget {
                let   rect = widget.convert(widget.bounds, to: dragView)
                onWidget   = rect.contains(location)
            }

            if !onWidget {
                if  let     dot = dotsHitTest(location) {
                    if let zone = dot.widgetZone {
                        if dot.isToggle {
                            gEditingManager.toggleDotActionOnZone(zone)
                        } else if zone.isGrabbed {
                            zone.ungrab()
                        } else if gesture.isShiftDown {
                            zone.addToGrab()
                        } else {
                            zone.grab()
                        }

                        signalFor(nil, regarding: .preferences)
                    }
                } else {
                    gSelectionManager.deselect()
                    signalFor(nil, regarding: .search)
                }
            }
        }

        restartGestures()
    }


    func rubberbandEvent(_ iGesture: ZGestureRecognizer?) {

        ///////////////////////////////////
        // only called by gesture system //
        ///////////////////////////////////

        if  let  gesture = iGesture {
            let location = gesture.location(in: dragView)
            let    state = gesture.state

            if isTextEditing(at: location) {
                restartGestures()       // let text editor consume the gesture
            } else if isDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .changed {
                rubberbandUpdate(CGRect(start: rubberbandStart, end: location))
            } else if state != .began { // ended
                rubberbandUpdate(nil)
            } else if let dot = dotsHitTest(location) {
                if dot.isToggle {
                    clickEvent(iGesture)
                } else {
                    dragStartEvent(dot, iGesture)
                }
            } else {                    // began
                rubberbandStartEvent(location, iGesture)
            }
        }
    }


    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////


    func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
        rubberbandStart = location
        isDragging      = false

        //////////////////////
        // detect SHIFT key //
        //////////////////////

        if let gesture = iGesture, gesture.isShiftDown {
            rubberbandPreGrabs.append(contentsOf: gSelectionManager.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }

        note("-- R --")
        gSelectionManager.deselect(retaining: rubberbandPreGrabs)
    }


    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  let   zone = dot.widgetZone { // should always be true
            isDragging = true

            if let gesture = iGesture, (gesture.isShiftDown || zone.isGrabbed) {
                zone.addToGrab()
            } else {
                zone.grab()
            }

            note("d --- d")

            if  zone == gHere {
                restartGestures()
            } else if let            location = iGesture?.location(in: dot) {
                dot.dragStart                 = location
                gSelectionManager.draggedZone = zone
            }
        }
    }


    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragEvent(iGesture) {
            cleanupAfterDrag()

            if doneState.contains(iGesture!.state) {
                restartGestures()
            }
        }
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) -> Bool {
        let                 s = gSelectionManager

        if  let      location = iGesture?.location(in: dragView),
            let   dropNearest = hereWidget.widgetNearestTo(location) {

            let   draggedZone = s.rootMostMoveable
            var      dropZone = dropNearest.widgetZone
            let     dropIndex = dropZone?.siblingIndex
            let      dropHere = dropZone == gHere
            let          same = s.currentGrabs.contains(dropZone!)
            let      relation = relationOf(location, to: dropNearest.textWidget)
            let useDropParent = relation != .upon && !dropHere
            ;        dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
            let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
            var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gInsertionsFollow || same) ? 0 : lastDropIndex)
            ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
            let     dragIndex = draggedZone.siblingIndex
            let     sameIndex = dragIndex == index || dragIndex == index - 1
            let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
            let    cycleSpawn = dropZone?.wasSpawnedByAGrab() ?? false
            let        isNoop = same || cycleSpawn || (sameIndex && dropIsParent) || index < 0
            let         prior = s.dragDropZone?.widget
            let       dropNow = doneState.contains(iGesture!.state)
            s.dragDropIndices = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
            s   .dragDropZone = isNoop || dropNow ? nil : dropZone
            s   .dragRelation = isNoop || dropNow ? nil : relation
            s      .dragPoint = isNoop || dropNow ? nil : location

            if !isNoop && !dropNow && !dropHere && index > 0 {
                s.dragDropIndices?.add(index - 1)
            }

            prior?           .displayForDrag() // erase  child lines
            dropZone?.widget?.displayForDrag() // redraw child lines
            dragView?       .setNeedsDisplay() // redraw drag (line and dot)

            columnarReport(relation, dropZone?.unwrappedName)

            if dropNow {
                restartGestures()

                let         editor = gEditingManager
                isDragging         = false
                if  let       drop = dropZone, !isNoop {
                    let toBookmark = drop.isBookmark
                    var   at: Int? = index

                    if toBookmark {
                        at         = gInsertionsFollow ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        at!       -= 1
                    }

                    editor.moveGrabbedZones(into: drop, at: at) {
                        self.redrawAndSync(nil)
                    }
                }
            }

            return false
        }
        
        return true
    }


    // MARK:- internals
    // MARK:-


    func rubberbandUpdate(_ rect: CGRect?) {
        if  rect == nil {
            dragView?.rubberbandRect = CGRect.zero

            restartGestures()
        } else {
            dragView?.rubberbandRect = rect

            gSelectionManager.deselectGrabs(retaining: rubberbandPreGrabs)

            for widget in gWidgetsManager.widgets.values {
                if  let    hitRect = widget.hitRect {
                    let widgetRect = widget.convert(hitRect, to: dragView)

                    if  widgetRect.intersects(rect!) {
                        widget.widgetZone.addToGrab()
                    }
                }
            }

            hereWidget.setNeedsDisplay()
        }

        signalFor(nil, regarding: .preferences)
        dragView?.setNeedsDisplay()
    }


    func dotsHitTest(_ location: CGPoint) -> ZoneDot? {
        var        hit: ZoneDot? = nil

        gHere.traverseProgeny { iZone -> ZTraverseStatus in
            if  let       widget = iZone.widget {
                var         rect = widget.outerHitRect
                rect             = widget.convert(rect, to: dragView)

                if rect.contains(location) {
                    let hits: DotToBooleanClosure = { (iDot: ZoneDot) -> Bool in
                        rect     = iDot.bounds
                        rect     = iDot.convert(rect, to: self.dragView)
                        let bang = rect.contains(location)

                        if bang {
                            hit = iDot
                        }

                        return bang
                    }

                    if hits(widget.dragDot) || hits(widget.toggleDot) {
                        return .eStop
                    }
                }
            }

            return .eContinue
        }

        return hit
    }


    func isTextEditing(at location: CGPoint) -> Bool {
        let e = gEditingManager

        if  e.isEditing, let textWidget = e.editedTextWidget {
            let rect = textWidget.convert(textWidget.bounds, to: dragView)

            return rect.contains(location)
        }

        return false
    }


    func cleanupAfterDrag() {

        // cursor exited view, remove drag cruft

        let             s = gSelectionManager
        let           dot = s.dragDropZone?.widget?.toggleDot.innerDot // drag view does not "un"draw this
        rubberbandStart   = CGPoint.zero
        s.dragDropIndices = nil
        s   .dragDropZone = nil
        s   .dragRelation = nil
        s      .dragPoint = nil

        dragView?.setNeedsDisplay()
        dot?     .setNeedsDisplay()
    }


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  iView     != nil {
            let margin = CGFloat(5.0)
            let  point = dragView!.convert(iPoint, to: iView)
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
    

    override func displayActivity(_ show: Bool) {
        spinner?.isHidden = !show

        if show {
            spinner?.startAnimating()
        } else {
            spinner?.stopAnimating()
        }
    }
}
