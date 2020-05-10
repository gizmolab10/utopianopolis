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

var gGraphController:     ZGraphController? { return gControllers.controllerForID(.idMap)     as? ZGraphController }
var gFavoritesController: ZGraphController? { return gControllers.controllerForID(.idFavorites) as? ZGraphController }

class ZGraphController: ZGesturesController, ZScrollDelegate {
    
	override  var       controllerID : ZControllerID { return isFavorites ? .idFavorites : .idMap }
	var                  isFavorites : Bool { return false }
	@IBOutlet var            spinner : ZProgressIndicator?
	@IBOutlet var           dragView : ZDragView?
	@IBOutlet var        spinnerView : ZView?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?
	var          priorScrollLocation = CGPoint.zero
	var           rubberbandStart    = CGPoint.zero
	var           rubberbandPreGrabs = ZoneArray    ()
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

	var rubberbandRect: CGRect? { // wrapper with new value logic
		get {
			return dragView?.drawingRubberbandRect
		}
		
		set {
			if  let d = dragView {
				d.drawingRubberbandRect = newValue

				if  newValue == nil || newValue == .zero {
					gSelecting.assureMinimalGrabs()
					gSelecting.updateCurrentBrowserLevel()
					gSelecting.updateCousinList()
				} else {
					gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
					gHere.ungrab()

					for widget in gWidgets.visibleWidgets {
						if  let    hitRect = widget.hitRect {
							let widgetRect = widget.convert(hitRect, to: d)

							if  let   zone = widget.widgetZone, !zone.isRootOfFavorites,
								widgetRect.intersects(newValue!) {
								widget.widgetZone?.addToGrab()
							}
						}
					}
				}
				
				d.setAllSubviewsNeedDisplay()
			}
		}
	}

    override func setup() {
		gestureView = dragView // do this before calling super setup

		super.setup()
		platformSetup()
        dragView?.addSubview(rootWidget)
    }

    #if os(OSX)
    
    func platformSetup() {
        guard let lighten = CIFilter(name: "CIColorControls") else { return }

		lighten.setDefaults()
        lighten.setValue(1, forKey: "inputBrightness")

		spinner?.contentFilters = [lighten]
    }
    
    #elseif os(iOS)
    
    @IBOutlet weak var mobileKeyInput: ZMobileKeyInput?
    
    func platformSetup() {
        mobileKeyInput?.becomeFirstResponder()
    }
    
    #endif

	// MARK:- operations
	// MARK:-

    func clear() {
//        mapRootWidget      .widgetZone = nil
    }

    #if os(iOS) && false
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

	func toggleGraphs() {
		toggleDatabaseID()
		gFocusRing.push()
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
		let offset = isFavorites ? CGPoint(x: -12.0, y: 0.0) : gScrollOffset

		if  let d = dragView {
			rootWidget.snp.setLabel("<w> \(rootWidget.widgetZone?.zoneName ?? "unknown")")
			rootWidget.snp.removeConstraints()
			rootWidget.snp.makeConstraints { make in
				make.centerY.equalTo(d).offset(offset.y)
				make.centerX.equalTo(d).offset(offset.x)
			}

            d.setNeedsDisplay()
        }
    }

    func layoutWidgets(for iZone: Any?, _ iKind: ZSignalKind) {
        if kIsPhone && (isFavorites != gShowFavorites) { return }

		let                        here = isFavorites ? gFavoritesHereMaybe : gHereMaybe
        var specificWidget: ZoneWidget? = rootWidget
        var specificView:        ZView? = dragView
        var specificIndex:         Int?
        var                   recursing = true
        specificWidget?     .widgetZone = here
		gTextCapturing                  = false

        if  let          zone  = iZone as? Zone,
            let        widget  = zone.widget,
            widget.isInMap    == !isFavorites {
            specificWidget     = widget
            specificIndex      = zone.siblingIndex
            specificView       = specificWidget?.superview
            recursing          = [.sData, .sRelayout].contains(iKind)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificIndex, recursing: recursing, iKind, inMap: !isFavorites, visited: [])
    }

	// MARK:- events
	// MARK:-

    override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
        if  [.sDatum, .sData, .sRelayout].contains(iKind) { // ignore for preferences, search, information, startup
			prepare(for: iKind)
			layoutForCurrentScrollOffset()
			layoutWidgets(for: iSignalObject, iKind)
			dragView?.setAllSubviewsNeedDisplay()
        }

		gRingView?.setNeedsDisplay()
    }
	
	func prepare(for iKind: ZSignalKind) {
		if  iKind == .sRelayout {
			gWidgets.clearRegistry(forFavorites: isFavorites)
		}

		if  kIsPhone {
			rootWidget.isHidden = gShowFavorites
		}
	}
//	
//	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
//		return (gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture) ||
//			otherGestureRecognizer == edgeGesture
//	}

	override func restartGestureRecognition() {
		gestureView?.gestureHandler = self
		gDraggedZone				= nil
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }
        
        if  gIsGraphOrEditIdeaMode,
			let gesture = iGesture as? ZKeyPanGestureRecognizer,
            let (_, dropNearest, location) = widgetNearest(gesture),
            let flags = gesture.modifiers {
            let state = gesture.state

            dropNearest.widgetZone?.needWrite()

            if isEditingText(at: location) {
                restartGestureRecognition()     // let text editor consume the gesture
            } else if flags.isCommand {
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)
			} else if state == .changed, rubberbandStart != CGPoint.zero {       // changed
                rubberbandRect = CGRect(start: rubberbandStart, end: location)
            } else if state != .began {         // ended, cancelled or failed
                rubberbandRect = nil

				restartGestureRecognition()
				signal([.sDatum]) // so color well and indicators get updated
            } else if let dot = detectDot(iGesture) {
                if  !dot.isReveal {
                    dragStartEvent(dot, iGesture)
                } else if let zone = dot.widgetZone {
                    cleanupAfterDrag()
					zone.revealDotClicked(COMMAND: flags.isCommand, OPTION: flags.isOption)   // no dragging
                }
            } else {                            // began
                rubberbandStartEvent(location, iGesture)
            }
        }
    }
	
	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }
        
        if  gIsGraphOrEditIdeaMode,
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

                let backgroundLocation = gesture.location(in: dragView)
                let           textRect = editWidget!.convert(editWidget!.bounds, to: dragView)
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
								regarding = .sStatus // update selection level and TODO: breadcrumbs

								zone.dragDotClicked(COMMAND, SHIFT, clickManager.isDoubleClick(on: zone))
							}
						}
					}
				} else {
					let   rect = CGRect(origin: gesture.location(in: dragView), size: CGSize())
					let inRing = gRingView?.anItemIsWithin(rect) ?? false

					// //////////////////////
					// click in background //
					// //////////////////////

					if !inRing {
						gTextEditor.stopCurrentEdit()

						if  clickManager.isDoubleClick() {
							recenter()
						} else if !kIsPhone {	// default reaction to click on background: select here
							gHereMaybe?.grab()  // safe version of here prevent crash early in launch
						}
					}
                }

                signal([regarding])
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

	func isDoneGesture(_ iGesture: ZGestureRecognizer?) -> Bool { return doneStates.contains(iGesture!.state) }

    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragDropMaybe(iGesture) {
            cleanupAfterDrag()
            
            if  isDoneGesture(iGesture) {
				signal([.sPreferences, .sCrumbs]) // so color well gets updated
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
    
    
    func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
        rubberbandStart = location
        gDraggedZone    = nil
        
        // ///////////////////
        // detect SHIFT key //
        // ///////////////////
        
        if let gesture = iGesture, gesture.isShiftDown {
            rubberbandPreGrabs.append(contentsOf: gSelecting.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }
        
        gTextEditor.stopCurrentEdit()
        gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
    }

    func dragDropMaybe(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let draggedZone       = gDraggedZone {
            if  draggedZone.userCanMove,
                let (isMap, dropNearest, location) = widgetNearest(iGesture) {
                var      dropZone = dropNearest.widgetZone
                let dropIsGrabbed = gSelecting.currentGrabs.contains(dropZone!)
                let     dropIndex = dropZone?.siblingIndex
                let          here = isMap ? gHere : gFavoritesHereMaybe
                let      dropHere = dropZone == here
				let      relation = dropZone?.widget?.controller?.relationOf(location, to: dropNearest.textWidget) ?? .upon
                let useDropParent = relation != .upon && !dropHere
                ;        dropZone = dropIsGrabbed ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gListsGrowDown || dropIsGrabbed) ? 0 : lastDropIndex)
                ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let     dragIndex = draggedZone.siblingIndex
                let     sameIndex = dragIndex == index || dragIndex == index - 1
                let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
                let    spawnCycle = dropZone?.spawnCycle ?? false
                let        isNoop = dropIsGrabbed || spawnCycle || (sameIndex && dropIsParent) || index < 0
                let         prior = gDragDropZone?.widget
                let       dropNow = isDoneGesture(iGesture)
                gDragDropIndices  = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
                gDragDropZone     = isNoop || dropNow ? nil : dropZone
                gDragRelation     = isNoop || dropNow ? nil : relation
                gDragPoint        = isNoop || dropNow ? nil : location

                if !isNoop && !dropNow && !dropHere && index > 0 {
                    gDragDropIndices?.add(index - 1)
                }

                prior?           .displayForDrag() // erase  child lines
                dropZone?.widget?.displayForDrag() // relayout child lines
				gDragDropZone?.widget?.controller?.dragView?.setNeedsDisplay() // relayout drag: line and dot, in the appropriate drag view

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
						// TODO: favorites editor
                        gGraphEditor.moveGrabbedZones(into: drop, at: dropAt, CONTROL) {
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


    // MARK:- large indicators
    // MARK:-

//    func showSpinner(_ show: Bool) {
//		spinnerView?.isHidden = !show
//
//		if  show {
//			spinner?.startAnimating()
//		} else {
//			spinner?.stopAnimating()
//		}
//    }

    
    // MARK:- internals
    // MARK:-


    func widgetNearest(_ iGesture: ZGestureRecognizer?, inMap: Bool = true) -> (Bool, ZoneWidget, CGPoint)? {
        if  let mapLocation = iGesture?.location(in: dragView),
			let mapWidget   = rootWidget.widgetNearestTo(mapLocation, in: dragView, isFavorites ? gFavoritesHereMaybe : gHereMaybe) {
            if  inMap, !kIsPhone,

                // /////////////////////////////////////
				// recurse once: with isThought false //
                // /////////////////////////////////////

				let (_, favoritesWidget, favoritesLocation) = gFavoritesController?.widgetNearest(iGesture, inMap: false) {

                // ////////////////////////////////////////////
                //     target zone found in both graphs      //
                // deterimine which zone is closer to cursor //
                // ////////////////////////////////////////////

				let locationT =  mapWidget.dragDot
                let locationF = favoritesWidget.dragDot
                let twoSidesT = locationT.convert(locationT.bounds.center, to: view) - mapLocation
                let twoSidesF = locationF.convert(locationF.bounds.center, to: view) - mapLocation
                let   scalarT = twoSidesT.hypontenuse
                let   scalarF = twoSidesF.hypontenuse

                if  scalarT > scalarF {
                    return (false, favoritesWidget, favoritesLocation)
                }
            }

            return (true, mapWidget, mapLocation)
        }

        return nil
    }

    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: dragView)

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

        rootWidget.setNeedsDisplay()
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
		var          hit : ZoneWidget?
		var     smallest = CGSize.big
        if  let        d = dragView,
            let location = iGesture?.location(in: d), d.bounds.contains(location) {
			let     dict = gWidgets.getWidgetsDict(forFavorites: isFavorites)
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

        if  let                d = dragView,
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

