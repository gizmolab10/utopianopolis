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
	var                     hereZone : Zone?         { return gHereMaybe ?? gCloud?.rootZone }
	@IBOutlet var            mapView : ZMapView?
	@IBOutlet var  mapContextualMenu : ZContextualMenu?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?
	var          priorScrollLocation = CGPoint.zero
	let                mapPseudoView = ZPseudoView()
	let                   rootWidget = ZoneWidget()

    override func setup() {
		gestureView                     = mapView // do this before calling super setup, which uses gesture view
		view    .layer?.backgroundColor = kClearColor.cgColor
		mapView?.layer?.backgroundColor = kClearColor.cgColor

		if  let           frame = mapView?.frame {
			mapPseudoView.frame = frame
		}

		super.setup()
		platformSetup()
		mapPseudoView.addSubpseudoview(rootWidget)
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
		gScrollOffset = !SPECIAL ? .zero : CGPoint(x: kHalfDetailsWidth, y: 0.0)
		
		layoutForCurrentScrollOffset()
	}

	func layoutForCurrentScrollOffset() {
		rootWidget.updateAllFrames(false)
		rootWidget.updateAllFrames(true)

		var       offset = isExemplar ? .zero : isBigMap ? gScrollOffset.offsetBy(0.0, 20.0) : CGPoint(x: -12.0, y: -6.0)
		offset.y         = -offset.y
		let         size = rootWidget.drawnSize
		let        vSize = isBigMap ? view.frame.size : size
		let       origin = CGPoint((vSize - size).multiplyBy(0.5) + CGSize(offset))
		rootWidget.frame = CGRect(origin: origin, size: size)
	}

	var doNotLayout: Bool {
		return (kIsPhone && (isBigMap == gShowSmallMapForIOS)) || gIsEditIdeaMode
	}

    func layoutWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		if  doNotLayout || kind == .sResize { return }

		var specificIndex:   Int?
		let specificView          = mapPseudoView
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
            recursing             = [.sData, .sRelayout].contains(kind)
        }

		let total = specificWidget.layoutAllPseudoViews(inPseudoView: specificView, for: widgetType, atIndex: specificIndex, recursing: recursing, kind, visited: [])

		layoutForCurrentScrollOffset()

		printDebug(.dWidget, "layout \(widgetType.description): \(total)")
    }

	// MARK:- events
	// MARK:-

    override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  !gDeferringRedraw {
			prepare(for: kind)

			if  kind == .sResize {
				layoutForCurrentScrollOffset()
			} else {
				layoutWidgets(for: iSignalObject, kind)
				mapView?.setAllSubviewsNeedDisplay()
			}
		}
	}
	
	func prepare(for kind: ZSignalKind) {
		if  [.sRelayout].contains(kind) {
			gWidgets.clearRegistry(for: widgetType)
		}

//		if  kIsPhone {
//			rootWidget.isHidden = gShowSmallMapForIOS
//		}
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture
	}

	override func restartGestureRecognition() {
		gestureView?.gestureHandler = self

		gDraggedZones.removeAll()
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

			printDebug(.dClick, "drag")

			if  isEditingText(at: location) {
				restartGestureRecognition()                       // let text editor consume the gesture
			} else {
				if  gCurrentlyEditingWidget != nil {
					gTextEditor.stopCurrentEdit()
				}

				if  flags.isCommand && !flags.isOption {          // shift background
					scrollEvent(move: state == .changed,  to: location)
				} else if gIsDragging {
					dropMaybeGesture(iGesture)                    // logic for drawing the drop dot, and for dropping dragged idea
				} else if state == .changed,                      // enlarge rubberband
						  gRubberband.setRubberbandExtent(to: location) {
					gRubberband.updateGrabs()
					gDragView?.setNeedsDisplay()
					mapView?.setNeedsDisplay()
				} else if ![.began, .cancelled].contains(state) { // drag ended or failed
					gRubberband.rubberbandRect = nil              // erase rubberband

					cleanupAfterDrag()
					restartGestureRecognition()
					gSignal([.spPreferences, .sDatum])                            // so color well and indicators get updated
				} else if let  dot = detectDot(iGesture),
						  let zone = dot.widgetZone {
					if  dot.isReveal {
						cleanupAfterDrag()                        // no dragging
						zone.revealDotClicked(flags)
					} else {
						dragStartEvent(dot, iGesture)             // start dragging a drag dot
					}
				} else {                                          // begin drag
					gRubberband.rubberbandStartEvent(location, iGesture)
					gMainWindow?.makeFirstResponder(mapView)
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
		    let    gesture  = iGesture as? ZKeyClickGestureRecognizer,
		    let      flags  = gesture.modifiers {
            let    COMMAND  = flags.isCommand
			let      SHIFT  = flags.isShift
            let editWidget  = gCurrentlyEditingWidget
            var   multiple  = [ZSignalKind.sData]
            var  notInEdit  = true

			printDebug(.dClick, "only")

			if  editWidget != nil {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let location = gesture.location(in: mapView)
                let textRect = editWidget!.convert(editWidget!.bounds, to: mapView)
                notInEdit    = !textRect.contains(location)
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

							if  gIsEssayMode {
								gMainWindow?.makeFirstResponder(mapView)
							}

							// ///////////////
							// click in dot //
							// ///////////////

							if  dot.isReveal {
								zone.revealDotClicked(flags)
							} else { // else it is a drag dot
								multiple = [.spCrumbs] // update selection level and breadcrumbs

								zone.dragDotClicked(COMMAND, SHIFT)
							}
						}
					}
				} else if gIsMapMode {

					// //////////////////////
					// click in background //
					// //////////////////////

					if !kIsPhone {	// default reaction to click on background: select here
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
        if  var      zone = dot.widgetZone,              // should always be true
			let   gesture = iGesture {

            if  gesture.isOptionDown {
				zone = zone.deepCopy(dbID: .mineID) // option means drag a copy
            }

            if  gesture.isShiftDown {
                zone.addToGrabs()
            } else if !zone.isGrabbed {
                zone.grab()
            }

			gDraggedZones = gSelecting.currentMapGrabs

			if  gIsEssayMode {
				gMainWindow?.makeFirstResponder(mapView)
			}
        }
    }

    func scrollEvent(move: Bool, to location: CGPoint) {
        if move {
            gScrollOffset = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)
            
            layoutForCurrentScrollOffset()
        }
        
        priorScrollLocation = location
    }

	// MARK:- drop
	// MARK:-

	func dropOnto(_ zone: Zone, at dropAt: Int? = nil, _ iGesture: ZGestureRecognizer?) {
		if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
			let   flags = gesture.modifiers {
			zone.addZones(gDraggedZones, at: dropAt, undoManager: undoManager, flags) {
				gSelecting.updateBrowsingLevel()
				gSelecting.updateCousinList()
				self.restartGestureRecognition()
				gRelayoutMaps()
			}
		}
	}

	func dropMaybeGesture(_ iGesture: ZGestureRecognizer?) {
		cleanupAfterDrag()

		if  gDraggedZones.isEmpty ||
			dropMaybeOntoCrumbButton(iGesture) ||
			dropMaybeOntoWidget(iGesture) {
		}

		if  iGesture?.isDone ?? false {
			restartGestureRecognition()
			gSignal([.sDatum, .spPreferences, .spCrumbs]) // so color well gets updated
		}
	}

	func dropMaybeOntoCrumbButton(_ iGesture: ZGestureRecognizer?) -> Bool { // true means done with drags
		if  let crumb = gBreadcrumbsView?.detectCrumb(iGesture),
			!gDraggedZones.containsARoot,
			!gDraggedZones.contains(crumb.zone),
			!gDraggedZones.anyParentMatches(crumb.zone) {

			if  iGesture?.isDone ?? false {
				dropOnto(crumb.zone, iGesture)
			} else {
				gDropCrumb = crumb

				crumb.highlight(true)
			}

			return true
		}

		return false
	}

    func dropMaybeOntoWidget(_ iGesture: ZGestureRecognizer?) -> Bool { // true means done with drags
        if  !gDraggedZones.containsARoot {
			let         totalGrabs = gDraggedZones + gSelecting.currentMapGrabs
            if  gDraggedZones.userCanMoveAll,
				let (inBigMap, zone, location) = widgetHit(by: iGesture, locatedInBigMap: isBigMap),
				var       dropZone = zone, !totalGrabs.contains(dropZone),
				var     dropWidget = dropZone.widget {
				let dropController = dropWidget.controller
				let      dropIndex = dropZone.siblingIndex
                let           here = inBigMap ? gHere : gSmallMapHere
                let    notDropHere = dropZone != here
				let       relation = dropController?.relationOf(location, to: dropWidget) ?? .upon
				let      useParent = relation != .upon && notDropHere

				if  useParent,
					let dropParent = dropZone.parentZone,
					let    pWidget = dropParent.widget {
					dropZone       = dropParent
					dropWidget     = pWidget

					if  relation == .below {
						noop()
					}
				}

				let  lastDropIndex = dropZone.count
				var          index = (useParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : (!gListsGrowDown ? 0 : lastDropIndex)
				;            index = notDropHere ? index : relation != .below ? 0 : lastDropIndex
				let      dragIndex = gDraggedZones[0].siblingIndex
				let      sameIndex = dragIndex == index || dragIndex == index - 1
				let   dropIsParent = dropZone.children.intersects(gDraggedZones)
				let     spawnCycle = dropZone.spawnCycle
				let    isForbidden = gIsEssayMode && dropZone.isInBigMap
				let         isNoop = spawnCycle || (sameIndex && dropIsParent) || index < 0 || isForbidden
				let         isDone = iGesture?.isDone ?? false
				let      forgetAll = isNoop || isDone
                gDropIndices       = forgetAll ? nil : NSMutableIndexSet(index: index)
				gDropWidget        = forgetAll ? nil : dropWidget
                gDragRelation      = forgetAll ? nil : relation
                gDragPoint         = forgetAll ? nil : location

                if !forgetAll && notDropHere && index > 0 {
                    gDropIndices?.add(index - 1)
                }

				gMapController?     .mapView?.setNeedsDisplay() // relayout drag line and dot, in each drag view
				gSmallMapController?.mapView?.setNeedsDisplay()

                if !isNoop, isDone {
                    let   toBookmark = dropZone.isBookmark
                    var dropAt: Int? = index

                    if  toBookmark {
                        dropAt       = gListsGrowDown ? nil : 0
                    } else if dropIsParent,
							  dragIndex  != nil,
							  dragIndex! <= index {
                        dropAt!     -= 1
                    }

					dropOnto(dropZone, at: dropAt, iGesture)

					return true
                }
            }
        }

        return false
    }

    // MARK:- internals
    // MARK:-

	func widgetHit(by gesture: ZGestureRecognizer?, locatedInBigMap: Bool = true) -> (Bool, Zone?, CGPoint)? {
		if  let             viewG = gesture?.view,
			let         locationG = gesture?.location(in: viewG),
			let         locationM = mapView?.convert(locationG, from: viewG),
			let           widgetM = rootWidget.widgetNearestTo(locationM, in: mapPseudoView, hereZone) {
			let         alternate = isBigMap ? gSmallMapController : gMapController
			if  let      mapViewA = alternate?.mapPseudoView, !kIsPhone {
				let     locationA = mapPseudoView.convert(locationM, toContaining: mapViewA)
				if  let   widgetA = alternate?.rootWidget.widgetNearestTo(locationA, in: mapViewA, alternate?.hereZone) {
					let  dragDotM = widgetM.dragDot
					let  dragDotA = widgetA.dragDot
					let   vectorM = dragDotM.convert(dragDotM.bounds.center, toContaining: mapPseudoView) - locationM
					let   vectorA = dragDotA.convert(dragDotA.bounds.center, toContaining: mapPseudoView) - locationM
					let   lengthM = vectorM.length
					let   lengthA = vectorA.length

					// ////////////////////////////////////////////////////// //
					// determine which drag dot's center is closest to cursor //
					// ////////////////////////////////////////////////////// //

					if  lengthA < lengthM {
						return (false, widgetA.widgetZone, locatedInBigMap ? locationM : locationA)
					}
				}
			}

            return (true, widgetM.widgetZone, locationM)
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
		
		// cursor exited view, remove drag cruft

		gDropCrumb?.highlight(false)

		gRubberband.rubberbandStart = .zero

		gDragRelation = nil
		gDropIndices  = nil
		gDropWidget   = nil
		gDropCrumb    = nil
		gDragPoint    = nil

		gDragView?.setNeedsDisplay() // erase drag: line and dot
		mapView?  .setNeedsDisplay()
    }

    func relationOf(_ point: CGPoint, to iWidget: ZoneWidget?) -> ZRelation {
        var     relation = ZRelation.upon
		if  let     text = iWidget?.textWidget,
			let     rect = gDragView?.convert(text.bounds, from: text).insetBy(dx: 0.0, dy: 5.0) {
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
                let rect = widget.convert(widget.outerHitRect, toContaining: mapPseudoView)
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
				let         rect = iDot.convert(iDot.bounds, toContaining: self.mapPseudoView)

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

