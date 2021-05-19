//
//  ZMapController.swift
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

var gMapController:  ZMapController? { return gControllers.controllerForID(.idBigMap) as? ZMapController }
var gCurrentMapView: ZMapView?       { return gMapController?.mapView }

class ZMapController: ZGesturesController, ZScrollDelegate {
    
	override  var       controllerID : ZControllerID { return .idBigMap }
	var                   widgetType : ZWidgetType   { return .tBigMap }
	var                   isExemplar : Bool          { return false }
	var                     isBigMap : Bool          { return true }
	var                     hereZone : Zone?         { return gHereMaybe }
	override  var       allowedKinds : [ZSignalKind] { return [.sRelayout, .sData, .sDatum, .sAppearance] }
	@IBOutlet var            mapView : ZMapView?
	@IBOutlet var  mapContextualMenu : ZContextualMenu?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?
	var          priorScrollLocation = CGPoint.zero
	let 	            clickManager = ZClickManager()
	let                   rootWidget = ZoneWidget   ()

	class ZClickManager : NSObject {

		var lastClicked:   Zone?
		var lastClickTime: Date?

		func isDoubleClick(on iZone: Zone? = nil) -> Bool {
			let  interval = lastClickTime?.timeIntervalSinceNow ?? -10.0
			let    isFast = interval > -1.8
			let  isRepeat = lastClicked == iZone
			let  isDouble = isRepeat ? isFast : false
			lastClickTime = Date()
			lastClicked   = iZone

			if  isDouble {
				columnarReport("repeat: \(isRepeat)", "fast: \(isFast)")
			}

			return isDouble
		}
	}

    override func setup() {
		gestureView                      = mapView // do this before calling super setup, which uses gesture view
		view    .layer?.backgroundColor = kClearColor.cgColor
		mapView?.layer?.backgroundColor = kClearColor.cgColor

		super.setup()
		platformSetup()
        mapView?.addSubview(rootWidget)

		if  isBigMap {
			mapView?.updateTrackingAreas()
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

	func toggleMaps() {
		gToggleDatabaseID()
		gHere.grab()
		gHere.expand()
		gFavorites.updateCurrentFavorite()
	}

	func recenter(_ SPECIAL: Bool = false) {
		gScaling      = 1.0
		gScrollOffset = !SPECIAL ? CGPoint.zero : CGPoint(x: kHalfDetailsWidth, y: 0.0)
		
		layoutForCurrentScrollOffset()
	}

    func layoutForCurrentScrollOffset() {
		let offset = isExemplar ? .zero : isBigMap ? gScrollOffset : CGPoint(x: -12.0, y: -6.0)

		if  let d = mapView {
			rootWidget.snp.setLabel("<w> \(rootWidget.widgetZone?.zoneName ?? "unknown")")
			rootWidget.snp.removeConstraints()
			rootWidget.snp.makeConstraints { make in
				make.centerY.equalTo(d).offset(offset.y)
				make.centerX.equalTo(d).offset(offset.x)

				if !isBigMap {
					make.top   .equalToSuperview()
					make.bottom.equalToSuperview().offset(-12.0)
				}
			}

            d.setNeedsDisplay()
        }
    }

	var doNotLayout: Bool {
		return (kIsPhone && (isBigMap == gShowSmallMapForIOS)) || gIsEditIdeaMode
	}

    func layoutWidgets(for iZone: Any?, _ iKind: ZSignalKind) {
        if  doNotLayout { return }

		var specificIndex:   Int?
        var specificView:  ZView? = mapView
		var specificWidget        = rootWidget
        var             recursing = true
		let                  here = hereZone
        specificWidget.widgetZone = here
		gTextCapturing            = false
        if  let              zone = iZone as? Zone,
            let            widget = zone.widget,
			widget.type          == zone.widgetType {
            specificWidget        = widget
            specificIndex         = zone.siblingIndex
            specificView          = specificWidget.superview
            recursing             = [.sData, .sRelayout].contains(iKind)
        }

		let total = specificWidget.layoutInView(specificView, for: widgetType, atIndex: specificIndex, recursing: recursing, iKind, visited: [])

		printDebug(.dWidget, "layout \(widgetType.description): \(total)")
    }

	// MARK:- events
	// MARK:-

    override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  !gDeferringRedraw, iKind != .sData { // ignore the signal from the end of process next batch
			prepare(for: iKind)
			layoutForCurrentScrollOffset()
			layoutWidgets(for: iSignalObject, iKind)
			mapView?.setAllSubviewsNeedDisplay()
        }
    }
	
	func prepare(for iKind: ZSignalKind) {
		if  iKind == .sRelayout {
			gWidgets.clearRegistry(for: widgetType)
		}

		if  kIsPhone {
			rootWidget.isHidden = gShowSmallMapForIOS
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

		if  gIsDraggableMode,
			let         gesture  = iGesture as? ZKeyPanGestureRecognizer,
			let (_, _, location) = widgetHit(by: gesture),
			let           flags  = gesture.modifiers {
            let           state  = gesture.state

			if  isEditingText(at: location) {
				restartGestureRecognition()                       // let text editor consume the gesture
			} else {
				if  gCurrentlyEditingWidget != nil {
					gTextEditor.stopCurrentEdit()
				}

				if flags.isCommand && !flags.isOption {           // shift background
					scrollEvent(move: state == .changed,  to: location)
				} else if gIsDragging {
					dragMaybeStopEvent(iGesture)                  // logic for drawing the drop dot, and for dropping dragged idea
				} else if state == .changed,                      // enlarge rubberband
						  gRubberband.setRubberbandExtent(to: location) {
					gRubberband.updateGrabs(in: mapView)
					gDragView? .setNeedsDisplay()
				} else if ![.began, .cancelled].contains(state) { // drag ended, failed or was cancelled
					gRubberband.rubberbandRect = nil              // erase rubberband

					restartGestureRecognition()
					gSignal([.sDatum])                            // so color well and indicators get updated
				} else if let  dot = detectDot(iGesture),
						  let zone = dot.widgetZone {
					if  dot.isReveal {
						cleanupAfterDrag()                        // no dragging
						zone.revealDotClicked(flags)
					} else if clickManager.isDoubleClick(on: zone) {
						gHere = zone
					} else {
						dragStartEvent(dot, iGesture)             // start dragging a drag dot
					}
				} else {                                          // begin drag
					gRubberband.rubberbandStartEvent(location, iGesture)
				}

				gDragView?.setNeedsDisplay()
			}

			return true
        }

		return false
    }
	
	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if (gIsMapOrEditIdeaMode || gIsEssayMode),
		    let    gesture = iGesture as? ZKeyClickGestureRecognizer,
		    let      flags = gesture.modifiers {
            let    COMMAND = flags.isCommand
			let      SHIFT = flags.isShift
            let editWidget = gCurrentlyEditingWidget
            var   multiple = [ZSignalKind.sData]
            var  notInEdit = true

			editWidget?.widgetZone?.needWrite()

			if  editWidget != nil {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let backgroundLocation = gesture.location(in: mapView)
                let           textRect = editWidget!.convert(editWidget!.bounds, to: mapView)
                notInEdit              = !textRect.contains(backgroundLocation)
            }

            if  notInEdit {

				if !gIsEssayMode {
					gSetBigMapMode()
				}

				gTextEditor.stopCurrentEdit()

				if  let   widget = detectWidget(gesture) {
					if  let zone = widget.widgetZone {
						gTemporarilySetMouseZone(zone)

						if  let dot = detectDotIn(widget, gesture) {

							// ///////////////
							// click in dot //
							// ///////////////

							if  dot.isReveal {
								zone.revealDotClicked(flags)
							} else {
								multiple = [.sCrumbs] // update selection level and breadcrumbs

								zone.dragDotClicked(COMMAND, SHIFT, clickManager.isDoubleClick(on: zone))
							}
						}
					}
				} else if gIsMapMode {

					// //////////////////////
					// click in background //
					// //////////////////////

					if  clickManager.isDoubleClick() {
						recenter()
					} else if !kIsPhone {	// default reaction to click on background: select here
						gHereMaybe?.grab()  // safe version of here prevent crash early in launch
					}
                } else if gIsEssayMode {
					gControllers.swapMapAndEssay(force: .wMapMode)
				}


                gSignal(multiple)
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
				zone = zone.deepCopy(dbID: .mineID) // option means drag a copy
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

    func dragDropMaybe(_ iGesture: ZGestureRecognizer?) -> Bool { // true means done with drags
        if  let draggedZone        = gDraggedZone {
            if  draggedZone.userCanMove,
				let (inBigMap, dropWidget, location) = widgetHit(by: iGesture, locatedInBigMap: isBigMap),
				draggedZone       != dropWidget.widgetZone {
				let dropController = dropWidget.controller
                var       dropZone = dropWidget.widgetZone
				let  dropIsGrabbed = gSelecting.currentMapGrabs.contains(dropZone!)
				let      dropIndex = dropZone?.siblingIndex
                let           here = inBigMap ? gHere : gSmallMapHere
                let       dropHere = dropZone == here
				let       relation = dropController?.relationOf(location, to: dropWidget) ?? .upon
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

                prior?                       .displayForDrag()  // erase    child lines
				dropWidget                   .displayForDrag()  // relayout child lines
				gMapController?     .mapView?.setNeedsDisplay() // relayout drag line and dot, in each drag view
				gSmallMapController?.mapView?.setNeedsDisplay()

                if !isNoop, dropNow,
					let         drop = dropZone {
                    let   toBookmark = drop.isBookmark
                    var dropAt: Int? = index

                    if  toBookmark {
                        dropAt       = gListsGrowDown ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        dropAt!     -= 1
                    }

					if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
						let   flags = gesture.modifiers {

						drop.addGrabbedZones(at: dropAt, undoManager: undoManager, flags) {
							gRedrawMaps()
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

	func widgetHit(by gesture: ZGestureRecognizer?, locatedInBigMap: Bool = true) -> (Bool, ZoneWidget, CGPoint)? {
		if  let     gView = gesture?.view,
			let    gPoint = gesture?.location(in: gView),
			let  location = mapView?.convert(gPoint, from: gView),
			let    widget = rootWidget.widgetNearestTo(location, in: mapView, hereZone) {
			let alternate = isBigMap ? gSmallMapController : gMapController

			if  !kIsPhone,
				let alternatemapView   = alternate?.mapView,
				let alternateLocation  = mapView?.convert(location, to: alternatemapView),
				let alternateWidget    = alternate?.rootWidget.widgetNearestTo(alternateLocation, in: alternatemapView, alternate?.hereZone) {
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
					return (false, alternateWidget, locatedInBigMap ? location : alternateLocation)
                }
            }

            return (true, widget, location)
        }

        return nil
    }
    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: mapView)

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
		mapView?  .setNeedsDisplay()
		dot?      .setNeedsDisplay()
		gDragView?.setNeedsDisplay() // erase drag: line and dot
    }

    func relationOf(_ point: CGPoint, to iWidget: ZoneWidget?) -> ZRelation {
        var     relation = ZRelation.upon
        if  let   widget = iWidget,
			let     rect = gDragView?.convert(widget.bounds, from:  widget).insetBy(dx: 0.0, dy: 5.0) {
			let     minY = rect.minY
			let     maxY = rect.maxY
			let        y = point.y
            if         y < minY {
                relation = .below
            } else if  y > maxY {
                relation = .above
			}
		}

        return relation
    }

    // MARK:- detect
    // MARK:-

    func detectWidget(_ iGesture: ZGestureRecognizer?) -> ZoneWidget? {
		if  isBigMap,
			let    widget = gSmallMapController?.detectWidget(iGesture) {
			return widget
		}

		var          hit : ZoneWidget?
		if  let        d = mapView,
            let location = iGesture?.location(in: d), d.bounds.contains(location) {
			var smallest = CGSize.big
			let  widgets = gWidgets.getZoneWidgetRegistry(for: widgetType).values.reversed()
			for  widget in widgets {
                let rect = widget.convert(widget.outerHitRect, to: d)
				let size = rect.size

                if  rect.contains(location),
					smallest.isLargerThan(size) { // prefer widget with shortest text size; why?
					smallest = size
					hit      = widget
                }
            }
        }

        return hit
    }

    func detectDotIn(_ widget: ZoneWidget, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit: ZoneDot?

        if  let                d = mapView,
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

