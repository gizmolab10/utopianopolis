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
    

    let        graphRootWidget = ZoneWidget ()
    let              doneState: [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]
    var           clickGesture:  ZGestureRecognizer?
    var          moveUpGesture:  ZGestureRecognizer?
    var        movementGesture:  ZGestureRecognizer?
    var        moveDownGesture:  ZGestureRecognizer?
    var        moveLeftGesture:  ZGestureRecognizer?
    var       moveRightGesture:  ZGestureRecognizer?
    var    alternateController:  ZGraphController? { return gEditorController }
    var                   here:  Zone              { return gFavoritesManager.rootZone! }
    override  var controllerID:  ZControllerID     { return .graph }
    @IBOutlet var   editorView:  ZoneDragView?


    // MARK:- gestures
    // MARK:-


    override func awakeFromNib() {
        super.awakeFromNib()

        if !gDebugTextInput {
            editorView?.addSubview(graphRootWidget)
        }
    }


    override func setup() {
        restartGestureRecognition()
        super.setup()

        if controllerID == .graph {
            view.zlayer.backgroundColor = ZColor.clear.cgColor  // so rubberband will not be clipped by favorites view
        }
    }


    func restartGestureRecognition() {
        editorView?.gestureHandler = self
    }


    func layoutForCurrentScrollOffset() {
        if  let e = editorView, !gDebugTextInput {
            graphRootWidget.snp.removeConstraints()
            graphRootWidget.snp.makeConstraints { make in
                make  .top.equalTo(e).offset(20.0 - Double(gGenericOffset.height / 3.0))
                make .left.equalTo(e).offset(15.0 - Double(gGenericOffset.width       ))
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
                var specificWidget: ZoneWidget? = graphRootWidget
                var   specificView:      ZView? = editorView
                var  specificindex:        Int? = nil
                gTextCapturing                  = false
                graphRootWidget     .widgetZone = here

                if let zone = object as? Zone {
                    if zone == here {
                        specificWidget = zone.widget
                        specificindex  = zone.siblingIndex
                        specificView   = specificWidget?.superview
                        recursing      = [.data, .redraw].contains(kind)
                    }
                }

                if gDebugTextInput { recursing = false }

                note("<  <  -  >  >  \(specificWidget?.widgetZone.zoneName ?? "---")")

                layoutForCurrentScrollOffset()
                specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind, visited: [])

                editorView?.applyToAllSubviews { iView in
                    iView.setNeedsDisplay()
                }
            }
        }
    }


    func movementGestureEvent(_ iGesture: ZGestureRecognizer?) {

        ///////////////////////////////////
        // only called by gesture system //
        ///////////////////////////////////

        if  let  gesture = iGesture as? ZKeyPanGestureRecognizer {
            let location = gesture.location(in: editorView)
            let    state = gesture.state

            if isEditingText(at: location) {
                restartGestureRecognition()     // let text editor consume the gesture
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .began, let (dot, controller) = dotHitTest(iGesture) {
                if dot.isToggle {
                    clickEvent(iGesture)  // no movement
                } else {
                    controller.dragStartEvent(dot, iGesture)

                }
            }
        }
    }

    
    func clickEvent(_ iGesture: ZGestureRecognizer?) {

        /////////////////////////////////////////////
        // called by controller and gesture system //
        /////////////////////////////////////////////

        if  let    gesture = iGesture {
            let   location = gesture.location(in: editorView)
            var     inText = false

            if  let widget = gEditingManager.editedTextWidget {
                let   rect = widget.convert(widget.bounds, to: editorView)
                inText     = rect.contains(location)
            }

            if !inText {
                if let (dot, _) = dotHitTest(iGesture) {
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

                        signalFor(nil, regarding: .data)
                    }
                } else {
                    gSelectionManager.deselect()
                    signalFor(nil, regarding: .search)
                }
            }
        }

        restartGestureRecognition()
    }


    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////


    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  let    zone = dot.widgetZone { // should always be true
            if let gesture = iGesture, (gesture.isShiftDown || zone.isGrabbed) {
                zone.addToGrab()
            } else {
                zone.grab()
            }

            note("d --- d")

            if let location = iGesture?.location(in: dot) {
                dot.dragStart = location
                gDraggedZone  = zone
            }
        }
    }


    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragEvent(iGesture) {
            cleanupAfterDrag()

            if doneState.contains(iGesture!.state) {
                restartGestureRecognition()
            }
        }
    }


    func widgetNearest(_ iGesture: ZGestureRecognizer?, recursed : Bool = false) -> (ZGraphController, ZoneWidget, CGPoint)? {
        if  let    location = iGesture?.location(in: editorView),
            let dropNearest = graphRootWidget.widgetNearestTo(location, in: editorView, here) {

            if  !recursed, let alternate = alternateController,
                let (controller, otherDrop, otherLocation) = alternate.widgetNearest(iGesture, recursed: true) {

                /////////////////////////////////////////////////
                // target zone found in both controllers' view //
                //  deterimine which zone is closer to cursor  //
                /////////////////////////////////////////////////

                let      dotA = dropNearest.dragDot
                let      dotB = otherDrop  .dragDot
                let distanceA = dotA.convert(dotA.bounds.center, to: view) - location
                let distanceB = dotB.convert(dotB.bounds.center, to: view) - location

                if distanceA.scalarDistance > distanceB.scalarDistance {
                    return (controller, otherDrop, otherLocation)
                }
            }

            return (self, dropNearest, location)
        }

        return nil
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let (controller, dropNearest, location) = widgetNearest(iGesture), let draggedZone = gDraggedZone {
            var      dropZone = dropNearest.widgetZone
            let          same = gSelectionManager.currentGrabs.contains(dropZone!)
            let     dropIndex = dropZone?.siblingIndex
            let      dropHere = dropZone == controller.here
            let      relation = controller.relationOf(location, to: dropNearest.textWidget)
            let useDropParent = relation != .upon && !dropHere
            ;        dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
            let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
            var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gInsertionsFollow || same) ? 0 : lastDropIndex)
            ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
            let     dragIndex = draggedZone.siblingIndex
            let     sameIndex = dragIndex == index || dragIndex == index - 1
            let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
            let    spawnCycle = bookmarkCycle(dropZone) || dropZone?.wasSpawnedByAGrab() ?? false
            let        isNoop = same || spawnCycle || (sameIndex && dropIsParent) || index < 0
            let         prior = gDragDropZone?.widget
            let       dropNow = doneState.contains(iGesture!.state)
            gDragDropIndices  = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
            gDragDropZone     = isNoop || dropNow ? nil : dropZone
            gDragRelation     = isNoop || dropNow ? nil : relation
            gDragPoint        = isNoop || dropNow ? nil : location

            if !isNoop && !dropNow && !dropHere && index > 0 {
                gDragDropIndices?.add(index - 1)
            }

            prior?           .displayForDrag() // erase  child lines
            dropZone?.widget?.displayForDrag() // redraw child lines
            gFavoritesView? .setNeedsDisplay() // redraw drag (line and dot)
            gEditorView?    .setNeedsDisplay() // redraw drag (line and dot)

            columnarReport(relation, dropZone?.unwrappedName)

            if dropNow {
                let           editor = gEditingManager

                if  let         drop = dropZone, !isNoop {
                    let   toBookmark = drop.isBookmark
                    var     at: Int? = index

                    if toBookmark {
                        at           = gInsertionsFollow ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        at!         -= 1
                    }

                    editor.moveGrabbedZones(into: drop, at: at) {
                        controller.restartGestureRecognition()
                        self.redrawAndSync(nil)
                    }
                }
            }

            return dropNow
        }
        
        return true
    }


    // MARK:- internals
    // MARK:-


    func bookmarkCycle(_ dropZone: Zone?) -> Bool {
        if let target = dropZone?.bookmarkTarget, let dragged = gDraggedZone, (target == dragged || target.wasSpawnedBy(dragged) || target.children.contains(dragged)) {
            return true
        }

        return false
    }


    func dotHit(_ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit: ZoneDot? = nil

        if  let e = editorView, let location = iGesture?.location(in: e), e.bounds.contains(location) {
            here.traverseProgeny { iZone -> ZTraverseStatus in
                if  let       widget = iZone.widget {
                    var         rect = widget.convert(widget.outerHitRect, to: e)

                    if rect.contains(location) {
                        let hits: DotToBooleanClosure = { iDot -> Bool in
                            rect     = iDot.convert(iDot.bounds, to: e)
                            let stop = rect.contains(location)

                            if  stop {
                                hit = iDot
                            }

                            return stop
                        }

                        if hits(widget.dragDot) || hits(widget.toggleDot) {
                            return .eStop
                        }
                    }
                }
                
                return .eContinue
            }
        }

        return hit
    }
    

    func dotHitTest(_ iGesture: ZGestureRecognizer?) -> (ZoneDot, ZGraphController)? {
        if  let hit  = dotHit(iGesture) {
            return (hit, self)
        }

        if  let c = alternateController, let hit  = c.dotHit(iGesture) {
            return (hit, c)
        }

        return nil
    }


    func isEditingText(at location: CGPoint) -> Bool {
        let e = gEditingManager

        if  e.isEditing, let textWidget = e.editedTextWidget {
            let rect = textWidget.convert(textWidget.bounds, to: editorView)

            return rect.contains(location)
        }

        return false
    }


    func cleanupAfterDrag() {

        // cursor exited view, remove drag cruft

        let          dot = gDragDropZone?.widget?.toggleDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        gFavoritesView?.setNeedsDisplay()
        gEditorView?   .setNeedsDisplay()
        dot?           .setNeedsDisplay()
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
