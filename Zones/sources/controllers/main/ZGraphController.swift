//
//  ZGraphController.swift
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


class ZGraphController: ZGenericController, ZGestureRecognizerDelegate {


    // MARK:- initialization
    // MARK:-
    

    var   draggedDot: ZoneDot? = nil
    var             isDragging = false
    var             hereWidget = ZoneWidget ()
    let              doneState: [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]
    var           clickGesture:  ZGestureRecognizer?
    var           swipeGesture:  ZGestureRecognizer?
    var        movementGesture:  ZGestureRecognizer?
    var                   here:  Zone          { return gFavoritesManager.rootZone! }
    override  var controllerID:  ZControllerID { return .basic }
    @IBOutlet var   editorView:  ZoneDragView?


    // MARK:- gestures
    // MARK:-


    override func awakeFromNib() {
        super.awakeFromNib()

        editorView?.addSubview(hereWidget)
    }


    override func setup() {
        restartDragHandling()
        super.setup()
    }


    func restartDragHandling() {
        editorView?.restartClickAndOtherGestureRecognizers(handledBy: self)
    }


    func layoutForCurrentScrollOffset() {
        if let e = editorView {
            hereWidget.snp.removeConstraints()
            hereWidget.snp.makeConstraints { make in
                make.centerY.equalTo(e)
                make.centerX.equalTo(e)
            }
        }
    }


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found, .startup].contains(kind) {

            if gWorkMode != .editMode {
                editorView?.snp.removeConstraints()
            } else if !gEditingManager.isEditing {
                var                   recursing = true
                var specificWidget: ZoneWidget? = hereWidget
                var   specificView:      ZView? = editorView
                var  specificindex:        Int? = nil
                gTextCapturing                  = false
                hereWidget          .widgetZone = here

                if      controllerID  != .basic {
                    if  let       zone = object as? Zone, zone != here {
                        specificWidget = zone.widget
                        specificindex  = zone.siblingIndex
                        specificView   = specificWidget?.superview
                        recursing      = [.data, .redraw].contains(kind)
                    } else {
                        gWidgetsManager.widgets.removeAll()
                    }
                }

                note("<  <  -  >  >  \(specificWidget?.widgetZone.zoneName ?? "---")")

                layoutForCurrentScrollOffset()
                specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind, visited: [])

                editorView?.applyToAllSubviews { iView in
                    iView.setNeedsDisplay()
                }
            }
        }
    }
    

    func swipeEvent(_ iGesture: ZGestureRecognizer?) {
        report("hah!")
    }


    func movementGestureEvent(_ iGesture: ZGestureRecognizer?) {

        ///////////////////////////////////
        // only called by gesture system //
        ///////////////////////////////////

        if  let  gesture = iGesture as? ZKeyPanGestureRecognizer {
            let location = gesture.location(in: editorView)
            let    state = gesture.state

            if isTextEditing(at: location) {
                restartDragHandling()     // let text editor consume the gesture
            } else if isDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .began, let dot = dotsHitTest(location) {
                if dot.isToggle {
                    clickEvent(iGesture)  // no movement
                } else {
                    dragStartEvent(dot, iGesture)
                }
            }
        }
    }

    
    func clickEvent(_ iGesture: ZGestureRecognizer?) {

        /////////////////////////////////////////////
        // called by controller and gesture system //
        /////////////////////////////////////////////

        gShowsSearching    = false

        if  let    gesture = iGesture {
            let   location = gesture.location(in: editorView)
            var     inText = false

            if  let widget = gEditingManager.editedTextWidget {
                let   rect = widget.convert(widget.bounds, to: editorView)
                inText     = rect.contains(location)
            }

            if !inText {
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

        restartDragHandling()
    }


    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////


    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  let   zone = dot.widgetZone { // should always be true
            isDragging = true

            if let gesture = iGesture, (gesture.isShiftDown || zone.isGrabbed) {
                zone.addToGrab()
            } else {
                zone.grab()
            }

            note("d --- d")

            if  zone == here {
                restartDragHandling()
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
                restartDragHandling()
            }
        }
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) -> Bool {
        let                 s = gSelectionManager

        if  let      location = iGesture?.location(in: editorView),
            let   dropNearest = hereWidget.widgetNearestTo(location) {

            let   draggedZone = s.rootMostMoveable
            var      dropZone = dropNearest.widgetZone
            let     dropIndex = dropZone?.siblingIndex
            let      dropHere = dropZone == here
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

            prior?           .displayForDrag()  // erase  child lines
            dropZone?.widget?.displayForDrag()  // redraw child lines
            editorView?      .setNeedsDisplay() // redraw drag (line and dot)

            columnarReport(relation, dropZone?.unwrappedName)

            if dropNow {
                restartDragHandling()

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


    func dotsHitTest(_ location: CGPoint) -> ZoneDot? {
        var        hit: ZoneDot? = nil

        here.traverseProgeny { iZone -> ZTraverseStatus in
            if  let       widget = iZone.widget {
                var         rect = widget.outerHitRect
                rect             = widget.convert(rect, to: editorView)

                if rect.contains(location) {
                    let hits: DotToBooleanClosure = { (iDot: ZoneDot) -> Bool in
                        rect     = iDot.bounds
                        rect     = iDot.convert(rect, to: self.editorView)
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
            let rect = textWidget.convert(textWidget.bounds, to: editorView)

            return rect.contains(location)
        }

        return false
    }


    func cleanupAfterDrag() {

        // cursor exited view, remove drag cruft

        let             s = gSelectionManager
        let           dot = s.dragDropZone?.widget?.toggleDot.innerDot // drag view does not "un"draw this
        s.dragDropIndices = nil
        s   .dragDropZone = nil
        s   .dragRelation = nil
        s      .dragPoint = nil

        editorView?.setNeedsDisplay()
        dot?     .setNeedsDisplay()
    }


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  iView     != nil {
            let margin = CGFloat(5.0)
            let  point = editorView!.convert(iPoint, to: iView)
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
}
