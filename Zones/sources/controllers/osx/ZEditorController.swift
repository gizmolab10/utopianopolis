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


class ZEditorController: ZGenericController, ZGestureRecognizerDelegate, ZScrollDelegate {
    
    
    // MARK:- initialization
    // MARK:-
    
    
    var                 isMain = true        // set via keyPath in storyboard
    var     rubberbandPreGrabs = [Zone] ()
    var    priorScrollLocation = CGPoint.zero
    var        rubberbandStart = CGPoint.zero
    let        graphRootWidget = ZoneWidget ()
    let              doneState: [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]
    var           clickGesture:  ZGestureRecognizer?
    var          moveUpGesture:  ZGestureRecognizer?
    var        movementGesture:  ZGestureRecognizer?
    var        moveDownGesture:  ZGestureRecognizer?
    var        moveLeftGesture:  ZGestureRecognizer?
    var       moveRightGesture:  ZGestureRecognizer?
    var    alternateController:  ZEditorController? { return isMain ? gFavoritesController : gEditorController }
    var                   here:  Zone               { return isMain ? gHere : gFavoritesManager.rootZone! }
    override  var controllerID:  ZControllerID      { return isMain ? .editor : .favorites }
    @IBOutlet var   editorView:  ZoneDragView?
    @IBOutlet var      spinner:  ZProgressIndicator?
    
    
    // MARK:- gestures
    // MARK:-
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        editorView?.addSubview(graphRootWidget)
    }
    
    
    override func setup() {
        restartGestureRecognition()
        super.setup()
        
        if !isMain {
            view.zlayer.backgroundColor = ZColor.clear.cgColor  // so rubberband will not be clipped by favorites view
        }
    }
    
    
    func restartGestureRecognition() {
        editorView?.gestureHandler = self
    }
    
    
    #if os(iOS)
    private func updateMinZoomScaleForSize(_ size: CGSize) {
    let           d = graphRootWidget
    let heightScale = size.height / d.bounds.height
    let  widthScale = size.width  / d.bounds.width
    let    minScale = min(widthScale, heightScale)
    gScaling        = Double(minScale)
    }
    
    
    override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    if isMain {
    updateMinZoomScaleForSize(view.bounds.size)
    }
    }
    #endif
    
    
    func layoutForCurrentScrollOffset() {
        if let e = editorView {
            graphRootWidget.snp.removeConstraints()
            
            graphRootWidget.snp.makeConstraints { make in
                if isMain {
                    make.centerY.equalTo(e).offset(gScrollOffset.y)
                    make.centerX.equalTo(e).offset(gScrollOffset.x)
                } else {
                    make  .top.equalTo(e).offset(20.0 - Double(gGenericOffset.height / 3.0))
                    make .left.equalTo(e).offset(15.0 - Double(gGenericOffset.width       ))
                }
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
        
        if  let  gesture = iGesture as? ZKeyPanGestureRecognizer,
            let    flags = gesture.modifiers {
            let location = gesture.location(in: editorView)
            let    state = gesture.state
            var    fussy = self
            
            if isMain,
                let altView = alternateController?.graphRootWidget,
                altView.bounds.contains(gesture.location(in: altView)) {
                fussy = alternateController!
            }
            
            if isEditingText(at: location) {
                restartGestureRecognition()     // let text editor consume the gesture
            } else if flags.isOption {
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .changed { // changed
                rubberbandUpdate(CGRect(start: rubberbandStart, end: location))
            } else if state != .began {   // ended
                rubberbandUpdate(nil)
            } else if let (dot, controller) = fussy.dotHitTest(iGesture) {
                if !dot.isToggle {
                    controller.dragStartEvent(dot, iGesture)
                } else if let zone = dot.widgetZone {
                    cleanupAfterDrag()
                    gEditingManager.toggleDotActionOnZone(zone)   // no movement
                }
            } else {                      // began
                rubberbandStartEvent(location, iGesture)
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
    
    
    func widgetNearest(_ iGesture: ZGestureRecognizer?, recursed : Bool = false) -> (ZEditorController, ZoneWidget, CGPoint)? {
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
    
    
    func scrollEvent(move: Bool, to location: CGPoint) {
        if move {
            gScrollOffset   = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)
            
            layoutForCurrentScrollOffset()
            editorView?.setNeedsDisplay()
        }
        
        priorScrollLocation = location
    }
    
    
    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////
    
    
    func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
        rubberbandStart = location
        gDraggedZone    = nil
        
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
    
    
    // MARK:- internals
    // MARK:-
    
    
    func rubberbandUpdate(_ rect: CGRect?) {
        if  rect == nil || rubberbandStart == CGPoint.zero {
            editorView?.rubberbandRect = CGRect.zero
            
            restartGestureRecognition()
        } else {
            editorView?.rubberbandRect = rect
            let                   mode = gCloudManager.storageMode
            
            gSelectionManager.deselectGrabs(retaining: rubberbandPreGrabs)
            
            if let             widgets = gWidgetsManager.widgets[mode]?.values {
                
                for widget in widgets {
                    if  let    hitRect = widget.hitRect {
                        let widgetRect = widget.convert(hitRect, to: editorView)
                        
                        if  widgetRect.intersects(rect!) {
                            widget.widgetZone.addToGrab()
                        }
                    }
                }
                
                graphRootWidget.setNeedsDisplay()
            }
        }
        
        signalFor(nil, regarding: .preferences)
        editorView?.setNeedsDisplay()
    }
    
    
    // MARK:- spinner
    // MARK:-
    
    
    override func displayActivity(_ show: Bool) {
        spinner?.isHidden = !show
        
        if show {
            spinner?.startAnimating()
        } else {
            spinner?.stopAnimating()
        }
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
    
    
    func dotHitTest(_ iGesture: ZGestureRecognizer?) -> (ZoneDot, ZEditorController)? {
        let    alt = alternateController
        let altHit = alt?.dotHit(iGesture)
        let    hit = dotHit(iGesture)

        if isMain {
            if  alt != nil && altHit != nil {
                return (altHit!, alt!)
            }

            if  hit != nil {
                return (hit!, self)
            }
        } else {
            if  hit != nil {
                return (hit!, self)
            }

            if  alt != nil && altHit != nil {
                return (altHit!, alt!)
            }
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
        if isMain {
            rubberbandStart = CGPoint.zero
        }
        
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

