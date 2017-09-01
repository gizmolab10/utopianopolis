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
    var           swipeGesture:  ZGestureRecognizer?
    var        movementGesture:  ZGestureRecognizer?
    var                   here:  Zone              { return gFavoritesManager.rootZone! }
    var    alternateController:  ZGraphController? { return gEditorController }
    override  var controllerID:  ZControllerID     { return .favorites }
    @IBOutlet var   editorView:  ZoneDragView?


    // MARK:- gestures
    // MARK:-


    override func awakeFromNib() {
        super.awakeFromNib()

        editorView?.addSubview(graphRootWidget)
    }


    override func setup() {
        restartDragHandling()
        super.setup()

        if controllerID == .favorites {
            view.zlayer.backgroundColor = ZColor.clear.cgColor  // so rubberband will not be clipped by favorites view
        }
    }


    func restartDragHandling() {
        editorView?.restartClickAndOtherGestureRecognizers(handledBy: self)
    }


    func layoutForCurrentScrollOffset() {
        if let e = editorView {
            graphRootWidget.snp.removeConstraints()
            graphRootWidget.snp.makeConstraints { make in
                make.centerY.equalTo(e)
                make.centerX.equalTo(e).offset(-60.0)
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
                graphRootWidget          .widgetZone = here

                if controllerID  == .favorites {
                    let here = gRemoteStoresManager.manifest(for: storageMode).hereZone

                    gFavoritesManager.updateIndexFor(here) { object in
                        gFavoritesManager.update()
                    }
                } else if let zone = object as? Zone, zone != here {
                    specificWidget = zone.widget
                    specificindex  = zone.siblingIndex
                    specificView   = specificWidget?.superview
                    recursing      = [.data, .redraw].contains(kind)
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

        gShowsSearching    = false

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
        if  let    zone = dot.widgetZone { // should always be true
            if let gesture = iGesture, (gesture.isShiftDown || zone.isGrabbed) {
                zone.addToGrab()
            } else {
                zone.grab()
            }

            note("d --- d")

            if  zone == here {
                restartDragHandling()
            } else if let location = iGesture?.location(in: dot) {
                dot.dragStart      = location
                gDraggedZone       = zone
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


    func widgetNearest(_ iGesture: ZGestureRecognizer?, recursed : Bool = false) -> (ZGraphController, ZoneWidget, CGPoint)? {
        if  let    location = iGesture?.location(in: editorView),
            let dropNearest = graphRootWidget.widgetNearestTo(location, in: editorView, here) {

            return (self, dropNearest, location)
        }

        return recursed ? nil : alternateController?.widgetNearest(iGesture, recursed: true)
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
            let    cycleSpawn = dropZone?.wasSpawnedByAGrab() ?? false
            let        isNoop = same || cycleSpawn || (sameIndex && dropIsParent) || index < 0
            let         prior = gDragDropZone?.widget
            let       dropNow = doneState.contains(iGesture!.state)
            gDragDropIndices  = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
            gDragDropZone     = isNoop || dropNow ? nil : dropZone
            gDragRelation     = isNoop || dropNow ? nil : relation
            gDragPoint        = isNoop || dropNow ? nil : location

            if !isNoop && !dropNow && !dropHere && index > 0 {
                gDragDropIndices?.add(index - 1)
            }

            prior?                 .displayForDrag() // erase  child lines
            dropZone?.widget?      .displayForDrag() // redraw child lines
            controller.editorView?.setNeedsDisplay() // redraw drag (line and dot)

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
                        controller.restartDragHandling()
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


    func dotHit(_ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit: ZoneDot? = nil

        if  editorView != nil, let location = iGesture?.location(in: editorView), editorView!.bounds.contains(location) {
            here.traverseProgeny { iZone -> ZTraverseStatus in
                if  let       widget = iZone.widget {
                    var         rect = widget.outerHitRect
                    rect             = widget.convert(rect, to: editorView)

                    if rect.contains(location) {
                        let hits: DotToBooleanClosure = { (iDot: ZoneDot) -> Bool in
                            rect     = iDot.bounds
                            rect     = iDot.convert(rect, to: self.editorView)
                            let onIt = rect.contains(location)

                            if  onIt {
                                hit = iDot
                            }

                            return onIt
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

        let          dot = gDragDropZone?.widget?.toggleDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        editorView?.setNeedsDisplay()
        dot?       .setNeedsDisplay()
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
