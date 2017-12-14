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
    override  var controllerID:  ZControllerID { return .editor }
    @IBOutlet var   editorView:  ZoneDragView?
    @IBOutlet var      spinner:  ZProgressIndicator?
    @IBOutlet var  spinnerView:  ZView?

    
    // MARK:- gestures
    // MARK:-
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        editorView?.addSubview(editorRootWidget)

        if gHasPrivateDatabase && !isPhone {
            editorView?.addSubview(favoritesRootWidget)
        }
    }
    

    func clear() {
        editorRootWidget   .widgetZone = nil
        favoritesRootWidget.widgetZone = nil
    }


    override func setup() {
        restartGestureRecognition()
        super.setup()
    }
    
    
    func restartGestureRecognition() {
        editorView?.gestureHandler = self
    }
    
    
    #if os(iOS)
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
        if let e = editorView {
            if isOSX {
                editorRootWidget.snp.removeConstraints()
                editorRootWidget.snp.makeConstraints { make in
                    make.centerY.equalTo(e).offset(gScrollOffset.y)
                    make.centerX.equalTo(e).offset(gScrollOffset.x)
                }
            }

            if gHasPrivateDatabase && !isPhone {
                if favoritesRootWidget.superview == nil {
                    editorView?.addSubview(favoritesRootWidget)
                }

                favoritesRootWidget.snp.removeConstraints()
                favoritesRootWidget.snp.makeConstraints { make in
                    make  .top.equalTo(e).offset(20.0 - Double(gGenericOffset.height / 3.0))
                    make .left.equalTo(e).offset(15.0 - Double(gGenericOffset.width       ))
                }

                e.setNeedsDisplay()
            }
        }
    }
    
    
    // MARK:- events
    // MARK:-


    func update(_ object: Any?, _ kind: ZSignalKind, isMain: Bool) {
        if !isMain && (!gHasPrivateDatabase || isPhone) { return }

        let                        here = isMain ? gHere : gFavoritesManager.rootZone
        var specificWidget: ZoneWidget? = isMain ? editorRootWidget : favoritesRootWidget
        var   specificView:      ZView? = editorView
        var  specificindex:        Int? = nil
        var                   recursing = true
        gTextCapturing                  = false
        specificWidget?     .widgetZone = here

        if  let       zone = object as? Zone,
            zone          == here {
            specificWidget = zone.widget
            specificindex  = zone.siblingIndex
            specificView   = specificWidget?.superview
            recursing      = [.data, .redraw].contains(kind)
        }

        note("<  <  -  >  >  \(specificWidget?.widgetZone?.zoneName ?? "---")")

        specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing, kind: kind, visited: [])
    }

    
    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        if [.datum, .data, .redraw].contains(kind) { // ignore for preferences, search, information, startup
            if gWorkMode != .editMode {
                editorView?.snp.removeConstraints()
            } else if !gEditingManager.isEditing {
                layoutForCurrentScrollOffset()
                update(object, kind, isMain: true)
                update(object, kind, isMain: false)
                editorView?.setAllSubviewsNeedDisplay()
            }
        }
    }
    
    
    func movementGestureEvent(_ iGesture: ZGestureRecognizer?) {
        
        ///////////////////////////////////
        // only called by gesture system //
        ///////////////////////////////////

        if gManifest.alreadyExists {
            if  gWorkMode        != .editMode {
                #if os(OSX)
                    gSearchManager.exitSearchMode()
                #endif
            } else if let gesture = iGesture as? ZKeyPanGestureRecognizer,
                let         flags = gesture.modifiers {
                let      location = gesture.location(in: editorView)
                let         state = gesture.state

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
                    signalFor(nil, regarding: .preferences) // so color well gets updated
                } else if let dot = detectDot(iGesture) {
                    if  !dot.isToggle {
                        dragStartEvent(dot, iGesture)
                    } else if let zone = dot.widgetZone {
                        cleanupAfterDrag()
                        gEditingManager.toggleDotActionOnZone(zone)   // no movement
                    }
                } else {                            // began
                    rubberbandStartEvent(location, iGesture)
                }
            }
        }
    }
    
    
    func clickEvent(_ iGesture: ZGestureRecognizer?) {
        
        /////////////////////////////////////////////
        // called by controller and gesture system //
        /////////////////////////////////////////////
        
        if  let             gesture = iGesture as? ZKeyClickGestureRecognizer, gManifest.alreadyExists { // avoid crash for click event before manifest is fetched
            let          textWidget = gEditingManager.editedTextWidget

            if gesture.modifiers?.contains(.command) ?? false, let zone = textWidget?.widgetZone, let link = zone.hyperLink, link != gNullLink {
                link.openAsURL()
            } else {
                var          inText = false

                if  textWidget != nil {
                    let    location = gesture.location(in: editorView)
                    let        rect = textWidget!.convert(textWidget!.bounds, to: editorView)
                    inText          = rect.contains(location)
                }

                if !inText {
                    if  let  widget = detectWidget(gesture) {
                        if let zone = widget.widgetZone,
                            let dot = detectDotIn(widget, gesture) {
                            if  dot.isToggle {
                                gEditingManager.toggleDotActionOnZone(zone)
                            } else if zone.isGrabbed {
                                zone.ungrab()
                            } else if gesture.isShiftDown {
                                zone.addToGrab()
                            } else {
                                zone.grab()
                            }

                            signalFor(nil, regarding: .information)
                        } else {
                            textWidget?.isEditingText = false

                            gSelectionManager.deselect()
                            widget.widgetZone?.grab()
                            signalFor(nil, regarding: .search)
                        }
                    } else { // click on background
                        gSelectionManager.deselect()
                        signalFor(nil, regarding: .datum)
                    }
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
                zone = zone.deepCopy()
            }

            if  iGesture?.isShiftDown ?? false {
                zone.addToGrab()
            } else if !zone.isGrabbed {
                zone.grab()
            }
            
            note("d --- d")
            
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
                signalFor(nil, regarding: .preferences) // so color well gets updated
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
            rubberbandPreGrabs.append(contentsOf: gSelectionManager.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }
        
        note("-- R --")
        gSelectionManager.deselect(retaining: rubberbandPreGrabs)
    }


    func dragEvent(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let draggedZone       = gDraggedZone {
            if  draggedZone.isMovableByUser,
                let (isMain, dropNearest, location) = widgetNearest(iGesture) {
                var      dropZone = dropNearest.widgetZone
                let          same = gSelectionManager.currentGrabs.contains(dropZone!)
                let     dropIndex = dropZone?.siblingIndex
                let          here = isMain ? gHere : gFavoritesManager.rootZone
                let      dropHere = dropZone == here
                let      relation = relationOf(location, to: dropNearest.textWidget)
                let useDropParent = relation != .upon && !dropHere
                ;        dropZone = same ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gInsertionsFollow || same) ? 0 : lastDropIndex)
                ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let     dragIndex = draggedZone.siblingIndex
                let     sameIndex = dragIndex == index || dragIndex == index - 1
                let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
                let    spawnCycle = bookmarkCycle(dropZone) || dropZone?.spawnedByAGrab() ?? false
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
                gEditorView?    .setNeedsDisplay() // redraw drag (line and dot)

                columnarReport(relation, dropZone?.unwrappedName)

                if dropNow, let drop = dropZone, !isNoop {
                    let   toBookmark = drop.isBookmark
                    var     at: Int? = index

                    if toBookmark {
                        at           = gInsertionsFollow ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        at!         -= 1
                    }

                    gEditingManager.moveGrabbedZones(into: drop, at: at) {
                        self.restartGestureRecognition()
                        self.redrawAndSync(nil)
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

            if  isMain,
                !isPhone,
                gHasPrivateDatabase,
                let (_, otherDrop, otherLocation) = widgetNearest(iGesture, isMain: false) {

                /////////////////////////////////////////////////
                // target zone found in both controllers' view //
                //  deterimine which zone is closer to cursor  //
                /////////////////////////////////////////////////

                let      dotA = dropNearest.dragDot
                let      dotB = otherDrop  .dragDot
                let distanceA = dotA.convert(dotA.bounds.center, to: view) - location
                let distanceB = dotB.convert(dotB.bounds.center, to: view) - location
                let   scalarA = distanceA.scalarDistance
                let   scalarB = distanceB.scalarDistance

                if scalarA > scalarB {
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
            
            restartGestureRecognition()
        } else {
            editorView?.rubberbandRect = rect
            let                widgets = gWidgetsManager.visibleWidgets

            gSelectionManager.deselectGrabs(retaining: rubberbandPreGrabs)

            for widget in widgets {
                if  let    hitRect = widget.hitRect {
                    let widgetRect = widget.convert(hitRect, to: editorView)

                    if  let zone = widget.widgetZone, !zone.isRootOfFavorites,
                        
                        widgetRect.intersects(rect!) {
                        widget.widgetZone?.addToGrab()
                    }
                }
            }

            editorView?.setAllSubviewsNeedDisplay()
        }
        
        // signalFor(nil, regarding: .preferences)
        editorView?.setAllSubviewsNeedDisplay()
    }

    
    func bookmarkCycle(_ dropZone: Zone?) -> Bool {
        if let target = dropZone?.bookmarkTarget, let dragged = gDraggedZone, (target == dragged || target.spawnedBy(dragged) || target.children.contains(dragged)) {
            return true
        }
        
        return false
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
        rubberbandStart  = CGPoint.zero

        // cursor exited view, remove drag cruft

        let          dot = gDragDropZone?.widget?.toggleDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        favoritesRootWidget.setNeedsDisplay()
        editorRootWidget   .setNeedsDisplay()
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
        if  let    altHit = detectWidgetFor(.favoritesMode, iGesture) {
            return altHit
        }

        if  let    hit    = detectWidgetFor(  gStorageMode, iGesture) {
            return hit
        }

        return nil
    }


    func detectWidgetFor(_ iMode: ZStorageMode?, _ iGesture: ZGestureRecognizer?) -> ZoneWidget? {
        var hit:   ZoneWidget? = nil
        if  let           mode = iMode,
            let              e = editorView,
            let       location = iGesture?.location(in: e),
            e.bounds.contains(location),
            let         iStart = ancestor(for: mode),
            let    widgetsDict = gWidgetsManager.widgets[mode] {
            let        widgets = widgetsDict.values
            for         widget in widgets {
                let       rect = widget.convert(widget.outerHitRect, to: e)

                if  rect.contains(location) {
                    if widget.widgetZone?.spawnedBy(iStart) ?? false {
                        hit    = widget
                    }
                }
            }
        }

        return hit
    }

    
    func ancestor(for iMode: ZStorageMode?) -> Zone? {
        if let mode = iMode {
            switch mode {
            case .favoritesMode: return gFavoritesManager.rootZone
            default:
                let    manifest = gRemoteStoresManager.manifest(for: mode)
                return manifest.hereZone
            }
        }

        return nil
    }


    func detectDotIn(_ widget: ZoneWidget, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var  hit:   ZoneDot? = nil

        if  let                e = editorView,
            let         location = iGesture?.location(in: e) {
            let test: DotClosure = { iDot in
                let         rect = iDot.convert(iDot.bounds, to: e)

                if  rect.contains(location) {
                    hit = iDot
                }
            }

            test(widget.dragDot)
            test(widget.toggleDot)
        }

        return hit
    }


    func detectDotFor(_ iMode: ZStorageMode?, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        if  let widget = detectWidgetFor(iMode, iGesture) {
            return detectDotIn(widget, iGesture)
        }

        return nil
    }


    func detectDot(_ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        let altHit = detectDotFor(.favoritesMode, iGesture)
        let    hit = detectDotFor(  gStorageMode, iGesture)

        if  altHit != nil {
            return altHit
        }

        if  hit != nil {
            return hit
        }

        return nil
    }

}

