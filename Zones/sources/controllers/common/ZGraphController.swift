//
//  ZGraphController.swift
//  Seriously
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

var gGraphController: ZGraphController? { return gControllers.controllerForID(.idMap) as? ZGraphController }

class ZGraphController: ZGesturesController, ZScrollDelegate {
    
	override  var       controllerID : ZControllerID { return .idMap }
	var                   widgetType : ZWidgetType   { return .tMap }
	var                        isMap : Bool          { return true }
	var                     hereZone : Zone?         { return gHereMaybe }
	@IBOutlet var           dragView : ZDragView?
	@IBOutlet var          graphView : ZView?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?
	var          priorScrollLocation = CGPoint.zero
	let 	            clickManager = ZClickManager()
	let                   rootWidget = ZoneWidget   ()

	class ZClickManager : NSObject {

		var lastClicked:   Zone?
		var lastClickTime: Date?

		func isDoubleClick(on iZone: Zone? = nil) -> Bool {
			let    isFast = lastClickTime?.timeIntervalSinceNow ?? -10.0 > -1.8
			let  isRepeat = lastClicked == iZone
			lastClickTime = Date()
			lastClicked   = iZone

			columnarReport("repeat: \(isRepeat)", "fast: \(isFast)")

			return isRepeat ? isFast : false
		}
	}

    override func setup() {
		gestureView                      = dragView // do this before calling super setup, which uses gesture view
		view      .layer?.backgroundColor = kClearColor.cgColor
		dragView? .layer?.backgroundColor = kClearColor.cgColor
		graphView?.layer?.backgroundColor = kClearColor.cgColor

		super.setup()
		platformSetup()
        graphView?.addSubview(rootWidget)

		if  isMap {
			dragView?.updateTrackingAreas()
		}
    }

    #if os(OSX)
    
	func platformSetup() {}
    
    #elseif os(iOS)
    
    @IBOutlet weak var mobileKeyInput: ZMobileKeyInput?
    
    func platformSetup() {
        mobileKeyInput?.becomeFirstResponder()
    }

    #if false

	private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = rootWidget
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

	#endif

	// MARK:- operations
	// MARK:-

	func toggleGraphs() {
		toggleDatabaseID()
		gRecents.push()
		gHere.grab()
		gHere.revealChildren()
		gFavorites.updateAllFavorites()
	}

	func recenter(_ SPECIAL: Bool = false) {
		gScaling      = 1.0
		gScrollOffset = !SPECIAL ? CGPoint.zero : CGPoint(x: kHalfDetailsWidth, y: 0.0)
		
		layoutForCurrentScrollOffset()
	}

    func layoutForCurrentScrollOffset() {
		let offset = isMap ? gScrollOffset : CGPoint(x: -12.0, y: -6.0)

		if  let d = graphView {
			rootWidget.snp.setLabel("<w> \(rootWidget.widgetZone?.zoneName ?? "unknown")")
			rootWidget.snp.removeConstraints()
			rootWidget.snp.makeConstraints { make in
				make.centerY.equalTo(d).offset(offset.y)
				make.centerX.equalTo(d).offset(offset.x)

				if !isMap {
					make.top   .equalToSuperview()
					make.bottom.equalToSuperview().offset(-12.0)
				}
			}

            d.setNeedsDisplay()
        }
    }

    func layoutWidgets(for iZone: Any?, _ iKind: ZSignalKind) {
        if kIsPhone && (isMap == gShowFavorites) { return }

		let                        here = hereZone
        var specificWidget: ZoneWidget? = rootWidget
        var specificView:        ZView? = graphView
        var specificIndex:         Int?
        var                   recursing = true
        specificWidget?     .widgetZone = here
		gTextCapturing                  = false

        if  let          zone  = iZone as? Zone,
            let        widget  = zone.widget,
			widget.type       == zone.type {
            specificWidget     = widget
            specificIndex      = zone.siblingIndex
            specificView       = specificWidget?.superview
            recursing          = [.sData, .sRelayout].contains(iKind)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificIndex, recursing: recursing, iKind, visited: [])
    }

	// MARK:- events
	// MARK:-

    override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  !gDeferringRedraw,
			[.sRelayout, .sRelayout, .sDetails, .sFavorites].contains(iKind), // ignore for preferences, search, information, startup
			(!isMap ||             ![.sDetails, .sFavorites].contains(iKind)) {
			prepare(for: iKind)
			layoutForCurrentScrollOffset()
			layoutWidgets(for: iSignalObject, iKind)
			graphView?.setAllSubviewsNeedDisplay()
			dragView? .setNeedsDisplay()
        }
    }
	
	func prepare(for iKind: ZSignalKind) {
		if  iKind == .sRelayout {
			gWidgets.clearRegistry(for: widgetType)
		}

		if  kIsPhone {
			rootWidget.isHidden = gShowFavorites
		}
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture
	}

	override func restartGestureRecognition() {
		gestureView?.gestureHandler = self
		gDraggedZone				= nil
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if  gIsGraphOrEditIdeaMode,
			let gesture = iGesture as? ZKeyPanGestureRecognizer,
            let (_, dropNearest, location) = widgetNearest(gesture),
            let flags = gesture.modifiers {
            let state = gesture.state

            dropNearest.widgetZone?.needWrite() // WHY?

            if  isEditingText(at: location) {
                restartGestureRecognition()           // let text editor consume the gesture
            } else if flags.isCommand {               // shift background
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)          // logic for drawing the drop dot, and for dropping dragged idea
			} else if state == .changed,              // enlarge rubberband
				gRubberband.setRubberbandEnd(location) {
				gRubberband.updateGrabs(in: graphView)
				dragView?  .setNeedsDisplay()
            } else if state != .began {               // drag ended, failed or was cancelled
                gRubberband.rubberbandRect = nil      // erase rubberband

				restartGestureRecognition()
				graphView?.setAllSubviewsNeedDisplay()
				dragView? .setNeedsDisplay()
				gSignal([.sDatum])                    // so color well and indicators get updated
            } else if let dot = detectDot(iGesture) {
                if  !dot.isReveal {
                    dragStartEvent(dot, iGesture)     // start dragging a drag dot
                } else if let zone = dot.widgetZone {
                    cleanupAfterDrag()                // no dragging
					zone.revealDotClicked(COMMAND: flags.isCommand, OPTION: flags.isOption)
                }
            } else {                                  // begin drag
				gRubberband.rubberbandStartEvent(location, iGesture)
            }

			return true
        }

		return false
    }
	
	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if !gExitNoteMode(),
			gIsGraphOrEditIdeaMode,
			let    gesture = iGesture {
            let    COMMAND = gesture.isCommandDown
			let     OPTION = gesture.isOptionDown
			let      SHIFT = gesture.isShiftDown
            let editWidget = gCurrentlyEditingWidget
            var  regarding = ZSignalKind.sDatum
            var withinEdit = false

			editWidget?.widgetZone?.needWrite()

			if  editWidget != nil {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let backgroundLocation = gesture.location(in: graphView)
                let           textRect = editWidget!.convert(editWidget!.bounds, to: graphView)
                withinEdit             = textRect.contains(backgroundLocation)
            }

            if  !withinEdit {
				gSetGraphMode()

				if  let   widget = detectWidget(gesture) {
					if  let zone = widget.widgetZone {
						gTemporarilySetMouseZone(zone)

						if  let dot = detectDotIn(widget, gesture) {

							// ///////////////
							// click in dot //
							// ///////////////

							if  dot.isReveal {
								zone.revealDotClicked(COMMAND: COMMAND, OPTION: OPTION)
							} else {
								regarding = .sCrumbs // update selection level and TODO: breadcrumbs

								zone.dragDotClicked(COMMAND, SHIFT, clickManager.isDoubleClick(on: zone))
							}
						}
					}
				} else {

					// //////////////////////
					// click in background //
					// //////////////////////

					gTextEditor.stopCurrentEdit()

					if  clickManager.isDoubleClick() {
						recenter()
					} else if !kIsPhone {	// default reaction to click on background: select here
						gHereMaybe?.grab()  // safe version of here prevent crash early in launch
					}
                }

                gSignal([regarding])
            }

            restartGestureRecognition()
        }
	}
	
    // //////////////////////////////////////////
    // next four are only called by controller //
    // //////////////////////////////////////////

    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  var zone = dot.widgetZone { // should always be true
            if  iGesture?.isOptionDown ?? false {
                zone = zone.deepCopy // option means drag a copy
            }

            if  iGesture?.isShiftDown ?? false {
                zone.addToGrabs()
            } else if !zone.isGrabbed {
                zone.grab()
            }
            
            if  let location  = iGesture?.location(in: dot) {
                dot.dragStart = location
                gDraggedZone  = zone
            }
        }
    }

	func isDoneGesture(_ iGesture: ZGestureRecognizer?) -> Bool { return doneStates.contains(iGesture!.state) }

    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragDropMaybe(iGesture) {
            cleanupAfterDrag()
            
            if  isDoneGesture(iGesture) {
				gSignal([.sPreferences, .sCrumbs]) // so color well gets updated
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

    // //////////////////////////////////////////
    // next four are only called by controller //
    // //////////////////////////////////////////

    func dragDropMaybe(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let draggedZone       = gDraggedZone {
            if  draggedZone.userCanMove,
                let (isMap, dropNearest, location) = widgetNearest(iGesture, forMap: false) {
				let dropController = dropNearest.controller
                var       dropZone = dropNearest.widgetZone
                let  dropIsGrabbed = gSelecting.currentGrabs.contains(dropZone!)
                let      dropIndex = dropZone?.siblingIndex
                let           here = isMap ? gHere : gFavoritesHereMaybe
                let       dropHere = dropZone == here
				let       relation = dropController?.relationOf(location, to: dropNearest.textWidget) ?? .upon
                let  useDropParent = relation != .upon && !dropHere
                ;         dropZone = dropIsGrabbed ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let  lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var          index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gListsGrowDown || dropIsGrabbed) ? 0 :   lastDropIndex)
                ;            index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let      dragIndex = draggedZone.siblingIndex
                let      sameIndex = dragIndex == index || dragIndex == index - 1
                let   dropIsParent = dropZone?.children.contains(draggedZone) ?? false
                let     spawnCycle = dropZone?.spawnCycle ?? false
                let         isNoop = dropIsGrabbed || spawnCycle || (sameIndex && dropIsParent) || index < 0
                let          prior = gDragDropZone?.widget
                let        dropNow = isDoneGesture(iGesture)
                gDragDropIndices   = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
                gDragDropZone      = isNoop || dropNow ? nil : dropZone
                gDragRelation      = isNoop || dropNow ? nil : relation
                gDragPoint         = isNoop || dropNow ? nil : location

                if !isNoop && !dropNow && !dropHere && index > 0 {
                    gDragDropIndices?.add(index - 1)
                }

                prior?                          .displayForDrag() // erase    child lines
                dropNearest                     .displayForDrag() // relayout child lines
				gGraphController?    .dragView?.setNeedsDisplay() // relayout drag line and dot, in each drag view
				gFavoritesController?.dragView?.setNeedsDisplay()

                if !isNoop, dropNow,
					let         drop = dropZone {
                    let   toBookmark = drop.isBookmark
                    var dropAt: Int? = index

                    if toBookmark {
                        dropAt       = gListsGrowDown ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        dropAt!     -= 1
                    }

                    if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
                        let CONTROL = gesture.modifiers?.isControl {

						gGraphEditor.moveGrabbedZones(into: drop, at: dropAt, CONTROL) {
							gRedrawGraph()
                            gSelecting.updateBrowsingLevel()
                            gSelecting.updateCousinList()
                            self.restartGestureRecognition()
                        }
                    }
                }

                return dropNow
            }
        }

        return true
    }

    // MARK:- internals
    // MARK:-

	func widgetNearest(_ iGesture: ZGestureRecognizer?, forMap: Bool = true) -> (Bool, ZoneWidget, CGPoint)? {
		if  let     gView = iGesture?.view,
			let    gPoint = iGesture?.location(in: gView),
			let  location = graphView?.convert(gPoint, from: gView),
			let    widget = rootWidget.widgetNearestTo(location, in: graphView, hereZone) {
			let alternate = isMap ? gFavoritesController : gGraphController

			if  !kIsPhone,
				let alternateGraphView = alternate?.graphView,
				let alternateLocation  = graphView?.convert(location, to: alternateGraphView),
				let alternateWidget    = alternate?.rootWidget.widgetNearestTo(alternateLocation, in: alternateGraphView, alternate?.hereZone) {
				let           dragDotW =          widget.dragDot
                let           dragDotA = alternateWidget.dragDot
                let            vectorW = dragDotW.convert(dragDotW.bounds.center, to: view) - location
                let            vectorA = dragDotA.convert(dragDotA.bounds.center, to: view) - location
                let          distanceW = vectorW.hypontenuse
                let          distanceA = vectorA.hypontenuse

				// ////////////////////////////////////////////////////// //
				// determine which drag dot's center is closest to cursor //
				// ////////////////////////////////////////////////////// //

                if  distanceW > distanceA {
					return (false, alternateWidget, forMap ? location : alternateLocation)
                }
            }

            return (true, widget, location)
        }

        return nil
    }
    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: graphView)

            return rect.contains(location)
        }

        return false
    }

    func cleanupAfterDrag() {
		gRubberband.rubberbandStart = CGPoint.zero

        // cursor exited view, remove drag cruft

        let          dot = gDragDropZone?.widget?.revealDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        rootWidget.setNeedsDisplay()
		graphView?.setNeedsDisplay()
		dragView? .setNeedsDisplay() // erase drag: line and dot
		dot?      .setNeedsDisplay()
    }

    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  let   view = iView {
            let margin = CGFloat(5.0)
            let  point = dragView!.convert(iPoint, to: view)
            let   rect = view.bounds
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
		if  isMap,
			let    widget = gFavoritesController?.detectWidget(iGesture) {
			return widget
		}

		var          hit : ZoneWidget?
		var     smallest = CGSize.big
        if  let        d = graphView,
            let location = iGesture?.location(in: d), d.bounds.contains(location) {
			let     dict = gWidgets.getWidgetsDict(for: widgetType)
            let  widgets = dict.values.reversed()
			for  widget in widgets {
                let rect = widget.convert(widget.outerHitRect, to: d)
				let size = rect.size

                if  rect.contains(location),
					smallest.isLargerThan(size) {
					smallest = size
					hit      = widget
                }
            }
        }

        return hit
    }

    func detectDotIn(_ widget: ZoneWidget, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit: ZoneDot?

        if  let                d = graphView,
            let         location = iGesture?.location(in: d) {
            let test: DotClosure = { iDot in
                let         rect = iDot.convert(iDot.bounds, to: d)

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

