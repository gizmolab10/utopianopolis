//
//  ZEditorController.swift
//  Thoughtful
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


var gEditorController: ZEditorController? { return gControllers.controllerForID(.editor) as? ZEditorController }


class ZEditorController: ZGenericController, ZGestureRecognizerDelegate, ZScrollDelegate {
    
    
    // MARK:- initialization
    // MARK:-
    
    
    let       editorRootWidget = ZoneWidget ()
    let    favoritesRootWidget = ZoneWidget ()
    var     rubberbandPreGrabs = [Zone] ()
    var    priorScrollLocation = CGPoint.zero
    var        rubberbandStart = CGPoint.zero
    let              doneState: [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]
    var           clickGesture:  ZGestureRecognizer?
    var          moveUpGesture:  ZGestureRecognizer?
    var        movementGesture:  ZGestureRecognizer?
    var        moveDownGesture:  ZGestureRecognizer?
    var        moveLeftGesture:  ZGestureRecognizer?
    var       moveRightGesture:  ZGestureRecognizer?
    @IBOutlet var   editorView:  ZoneDragView?
    @IBOutlet var      spinner:  ZProgressIndicator?
    @IBOutlet var  spinnerView:  ZView?


    override func setup() {
        controllerID = .editor

        restartGestureRecognition()
        editorView?.addSubview(editorRootWidget)

        if  !kIsPhone {
            editorView?.addSubview(favoritesRootWidget)
        }
    }


    // MARK:- gestures
    // MARK:-


    func clear() {
        editorRootWidget   .widgetZone = nil
        favoritesRootWidget.widgetZone = nil
    }

    
    func restartGestureRecognition() {
        editorView?.gestureHandler = self
    }
    
    
    #if os(iOS) && false
    private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = editorRootWidget
        let heightScale = size.height / w.bounds.height
        let  widthScale = size.width  / w.bounds.width
        let    minScale = min(widthScale, heightScale)
        gScaling        = Double(minScale)
    }


    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateMinZoomScaleForSize(view.bounds.size)
    }
    #endif

    
    func layoutForCurrentScrollOffset() {
        if  let e = editorView {
            if kIsDesktop {
                editorRootWidget.snp.removeConstraints()
                editorRootWidget.snp.makeConstraints { make in
                    make.centerY.equalTo(e).offset(gScrollOffset.y)
                    make.centerX.equalTo(e).offset(gScrollOffset.x)
                }
            }

            if  !kIsPhone {
                if favoritesRootWidget.superview == nil {
                    editorView?.addSubview(favoritesRootWidget)
                }

                favoritesRootWidget.snp.removeConstraints()
                favoritesRootWidget.snp.makeConstraints { make in
                    make  .top.equalTo(e).offset(45.0 - Double(gGenericOffset.height / 3.0))
                    make .left.equalTo(e).offset(15.0 - Double(gGenericOffset.width       ))
                }

                e.setNeedsDisplay()
            }
        }
    }
    
    
    // MARK:- events
    // MARK:-


    func layoutRootWidget(for iZone: Any?, _ iKind: ZSignalKind, inMainGraph: Bool) {
        if !inMainGraph && kIsPhone { return }

        let                        here = inMainGraph ? gHere : gFavoritesRoot
        var specificWidget: ZoneWidget? = inMainGraph ? editorRootWidget : favoritesRootWidget
        var specificView:        ZView? = editorView
        var specificIndex:         Int?
        var                   recursing = true
        gTextCapturing                  = false
        specificWidget?     .widgetZone = here

        if  let        zone  = iZone as? Zone,
            let      widget  = zone.widget,
            widget.isInMain == inMainGraph {
            specificWidget   = widget
            specificIndex    = zone.siblingIndex
            specificView     = specificWidget?.superview
            recursing        = [.eData, .eRelayout].contains(iKind)
        }

        if iKind == .eRelayout {
            specificWidget?.layoutInView(specificView, atIndex: specificIndex, recursing: recursing, iKind, isMain: inMainGraph, visited: [])
        } else {
            specificWidget?.setNeedsDisplay()
        }
    }

    
    override func handleSignal(_ iSignalObject: Any?, iKind: ZSignalKind) {
        if [.eDatum, .eData, .eRelayout].contains(iKind) { // ignore for preferences, search, information, startup
            if gWorkMode != .graphMode {
                editorView?.snp.removeConstraints()
            } else if !gIsEditingText {
                if iKind == .eRelayout {
                    gWidgets.clearRegistry()
                }

                layoutForCurrentScrollOffset()
                layoutRootWidget(for: iSignalObject, iKind, inMainGraph: true)
                layoutRootWidget(for: iSignalObject, iKind, inMainGraph: false)
                editorView?.setAllSubviewsNeedDisplay()
            }
        }
    }

    
    @objc func dragGestureEvent(_ iGesture: ZGestureRecognizer?) {
        if  gWorkMode        != .graphMode {
            gSearching.exitSearchMode()
        }
        
        if let gesture = iGesture as? ZKeyPanGestureRecognizer,
            let (_, dropNearest, location) = widgetNearest(gesture),
            let         flags = gesture.modifiers {
            let         state = gesture.state

            dropNearest.widgetZone?.deferWrite()

            if isEditingText(at: location) {
                restartGestureRecognition()     // let text editor consume the gesture
            } else if flags.isCommand {
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .changed {       // changed
                rubberbandUpdate(CGRect(start: rubberbandStart, end: location))
            } else if state != .began {         // ended, cancelled or failed
                rubberbandUpdate(nil)
                gControllers.signalFor(nil, regarding: .ePreferences) // so color well gets updated
            } else if let dot = detectDot(iGesture) {
                if  !dot.isReveal {
                    dragStartEvent(dot, iGesture)
                } else if let zone = dot.widgetZone {
                    cleanupAfterDrag()
                    gGraphEditor.clickActionOnRevealDot(for: zone, isCommand: flags.isCommand)   // no dragging
                }
            } else {                            // began
                rubberbandStartEvent(location, iGesture)
            }
        }
    }
    
    
    @objc func clickEvent(_ iGesture: ZGestureRecognizer?) {
        if  gWorkMode != .graphMode {
            gSearching.exitSearchMode()
        }
        
        if let gesture = iGesture as? ZKeyClickGestureRecognizer {
            let           COMMAND = gesture.modifiers?.contains(.command) ?? false
            let        textWidget = gEditedTextWidget
            var            inText = false

            textWidget?.widgetZone?.deferWrite()

            if  textWidget != nil {
                let clickLocation = gesture.location(in: editorView)
                let      textRect = textWidget!.convert(textWidget!.bounds, to: editorView)
                inText            = textRect.contains(clickLocation)
            }

            if !inText {
                if  let   widget = detectWidget(gesture) {
                    if  let zone = widget.widgetZone,
                        let  dot = detectDotIn(widget, gesture) {
                        let isShift = gesture.isShiftDown
                        if  dot.isReveal {
                            gGraphEditor.clickActionOnRevealDot(for: zone, isCommand: COMMAND)
                        } else {
                            zone.dragDotClicked(isCommand: COMMAND, isShift: isShift)
                        }

                        gControllers.signalFor(nil, regarding: .eDetails)
                    } else {
                        gTextEditor.stopCurrentEdit()
                        widget.widgetZone?.grab()
                        gControllers.signalFor(nil, regarding: .eSearch)
                    }
                } else { // click on background
                    gTextEditor.stopCurrentEdit()
                    gHere.grab()
                    gControllers.signalFor(nil, regarding: .eDatum)
                }
            }

            restartGestureRecognition()
        }
    }
    
    
    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////
    
    
    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  var zone = dot.widgetZone { // should always be true
            if  iGesture?.isOptionDown ?? false {
                zone = zone.deepCopy // option means drag a copy
            }

            if  iGesture?.isShiftDown ?? false {
                zone.addToGrab()
            } else if !zone.isGrabbed {
                zone.grab()
            }
            
            if  let location  = iGesture?.location(in: dot) {
                dot.dragStart = location
                gDraggedZone  = zone
            }
        }
    }
    
    
    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragEvent(iGesture) {
            cleanupAfterDrag()
            
            if doneState.contains(iGesture!.state) {
                gControllers.signalFor(nil, regarding: .ePreferences) // so color well gets updated
                restartGestureRecognition()
            }
        }
    }

    
    func scrollEvent(move: Bool, to location: CGPoint) {
        if move {
            gScrollOffset   = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)
            
            layoutForCurrentScrollOffset()
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
            rubberbandPreGrabs.append(contentsOf: gSelecting.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }
        
        gTextEditor.stopCurrentEdit()
        gSelecting.deselectGrabs(retaining: rubberbandPreGrabs)
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let draggedZone       = gDraggedZone {
            if  draggedZone.userCanMove,
                let (isMain, dropNearest, location) = widgetNearest(iGesture) {
                var      dropZone = dropNearest.widgetZone
                let dropIsGrabbed = gSelecting.currentGrabs.contains(dropZone!)
                let     dropIndex = dropZone?.siblingIndex
                let          here = isMain ? gHere : gFavoritesRoot
                let      dropHere = dropZone == here
                let      relation = relationOf(location, to: dropNearest.textWidget)
                let useDropParent = relation != .upon && !dropHere
                ;        dropZone = dropIsGrabbed ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gInsertionsFollow || dropIsGrabbed) ? 0 : lastDropIndex)
                ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let     dragIndex = draggedZone.siblingIndex
                let     sameIndex = dragIndex == index || dragIndex == index - 1
                let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
                let    spawnCycle = dropZone?.spawnCycle ?? false
                let        isNoop = dropIsGrabbed || spawnCycle || (sameIndex && dropIsParent) || index < 0
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
                dropZone?.widget?.displayForDrag() // relayout child lines
                editorView?     .setNeedsDisplay() // relayout drag: line and dot

                // columnarReport(String(describing: gDragRelation), gDragDropZone?.unwrappedName)

                if dropNow, let drop = dropZone, !isNoop {
                    let   toBookmark = drop.isBookmark
                    var dropAt: Int? = index

                    if toBookmark {
                        dropAt       = gInsertionsFollow ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        dropAt!     -= 1
                    }

                    if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
                        let COMMAND = gesture.modifiers?.isCommand {
                        gGraphEditor.moveGrabbedZones(into: drop, at: dropAt, COMMAND) {
                            gSelecting.updateBrowsingLevel()
                            gSelecting.updateCousinList()
                            self.restartGestureRecognition()
                            self.redrawAndSync()
                        }
                    }
                }

                return dropNow
            }
        }

        return true
    }


    // MARK:- spinner
    // MARK:-


    override func displayActivity(_ show: Bool) {
        spinnerView?.isHidden = !show

        if show {
            spinner?.startAnimating()
        } else {
            spinner?.stopAnimating()
        }
    }

    
    // MARK:- internals
    // MARK:-


    func widgetNearest(_ iGesture: ZGestureRecognizer?, isMain: Bool = true) -> (Bool, ZoneWidget, CGPoint)? {
        let      rootWidget = isMain ? editorRootWidget : favoritesRootWidget
        if  let    location = iGesture?.location(in: editorView),
            let dropNearest = rootWidget.widgetNearestTo(location, in: editorView, gHere) {
            if  isMain, !kIsPhone,

                //////////////////////////////////
                // recurse only for isMain true //
                //////////////////////////////////

                let (_, otherDrop, otherLocation) = widgetNearest(iGesture, isMain: false) {

                ///////////////////////////////////////////////
                //     target zone found in both graphs      //
                // deterimine which zone is closer to cursor //
                ///////////////////////////////////////////////

                let      dotN = dropNearest.dragDot
                let      dotO = otherDrop  .dragDot
                let distanceN = dotN.convert(dotN.bounds.center, to: view) - location
                let distanceO = dotO.convert(dotO.bounds.center, to: view) - location
                let   scalarN = distanceN.scalarDistance
                let   scalarO = distanceO.scalarDistance

                if scalarN > scalarO {
                    return (false, otherDrop, otherLocation)
                }
            }

            return (true, dropNearest, location)
        }

        return nil
    }

    
    func rubberbandUpdate(_ rect: CGRect?) {
        if  rect == nil || rubberbandStart == CGPoint.zero {
            editorView?.rubberbandRect = CGRect.zero
            
            gSelecting.assureMinimalGrabs()
            gSelecting.updateCousinList()
            restartGestureRecognition()
        } else {
            editorView?.rubberbandRect = rect
            let                widgets = gWidgets.visibleWidgets

            gSelecting.deselectGrabs(retaining: rubberbandPreGrabs)
            gHere.ungrab()

            for widget in widgets {
                if  let    hitRect = widget.hitRect {
                    let widgetRect = widget.convert(hitRect, to: editorView)

                    if  let zone = widget.widgetZone, !zone.isRootOfFavorites,
                        
                        widgetRect.intersects(rect!) {
                        widget.widgetZone?.addToGrab()
                    }
                }
            }
        }
        
        editorView?.setAllSubviewsNeedDisplay()
    }

    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditingText, let textWidget = gEditedTextWidget {
            let rect = textWidget.convert(textWidget.bounds, to: editorView)

            return rect.contains(location)
        }

        return false
    }


    func cleanupAfterDrag() {
        rubberbandStart  = CGPoint.zero

        // cursor exited view, remove drag cruft

        let          dot = gDragDropZone?.widget?.revealDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        favoritesRootWidget.setNeedsDisplay()
        editorRootWidget   .setNeedsDisplay()
        editorView?        .setNeedsDisplay() // erase drag: line and dot
        dot?               .setNeedsDisplay()
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


    // MARK:- detect
    // MARK:-


    func detectWidget(_ iGesture: ZGestureRecognizer?) -> ZoneWidget? {
        var hit: ZoneWidget?
        if  let               e = editorView,
            let        location = iGesture?.location(in: e),
            e.bounds.contains(location) {
            let         widgets = gWidgets.widgets.values
            for         widget in widgets {
                let        rect = widget.convert(widget.outerHitRect, to: e)

                if  rect.contains(location) {
                    hit     = widget

                    break
                }
            }
        }

        return hit
    }


    func detectDotIn(_ widget: ZoneWidget, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit:        ZoneDot?

        if  let                e = editorView,
            let         location = iGesture?.location(in: e) {
            let test: DotClosure = { iDot in
                let         rect = iDot.convert(iDot.bounds, to: e)

                if  rect.contains(location) {
                    hit = iDot
                }
            }

            test(widget.dragDot)
            test(widget.revealDot)
        }

        return hit
    }


    func detectDot(_ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        if  let widget = detectWidget(iGesture) {
            return detectDotIn(widget, iGesture)
        }

        return nil
    }

}

