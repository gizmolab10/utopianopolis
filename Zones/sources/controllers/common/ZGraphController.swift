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
	var                   widgetType : ZWidgetType   { return .tIdea }
	var                        isMap : Bool          { return true }
	var                     hereZone : Zone?         { return gHereMaybe }
	@IBOutlet var            spinner : ZProgressIndicator?
	@IBOutlet var           dragView : ZDragView?
	@IBOutlet var        spinnerView : ZView?
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
		gestureView                      = dragView // do this before calling super setup
		view     .layer?.backgroundColor = kClearColor.cgColor
		dragView?.layer?.backgroundColor = kClearColor.cgColor

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

		if  let d = dragView {
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
        var specificView:        ZView? = dragView
        var specificIndex:         Int?
        var                   recursing = true
        specificWidget?     .widgetZone = here
		gTextCapturing                  = false

        if  let          zone  = iZone as? Zone,
            let        widget  = zone.widget,
			widget.type       == zone.widgetTypeForRoot {
            specificWidget     = widget
            specificIndex      = zone.siblingIndex
            specificView       = specificWidget?.superview
            recursing          = [.sData, .sRelayout].contains(iKind)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificIndex, recursing: recursing, iKind, widgetType, visited: [])
    }

	// MARK:- events
	// MARK:-

    override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  !gDeferringRedraw,
			[.sDatum, .sData, .sRelayout].contains(iKind) { // ignore for preferences, search, information, startup
			prepare(for: iKind)
			layoutForCurrentScrollOffset()
			layoutWidgets(for: iSignalObject, iKind)
			dragView?.setAllSubviewsNeedDisplay()
        }
    }
	
	func prepare(for iKind: ZSignalKind) {
		if  iKind == .sRelayout {
			gWidgets.clearRegistry(for: widgetType)
		}

		if  kIsPhone {
			rootWidget.isHidden = gShowFavorites
		}

		view     .layer?.backgroundColor = kClearColor.cgColor
		dragView?.layer?.backgroundColor = kClearColor.cgColor
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return (gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture) ||
			otherGestureRecognizer == edgeGesture
	}

	override func restartGestureRecognition() {
		gestureView?.gestureHandler = self
		gDraggedZone				= nil
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
		if !isMap,
			let    g = gGraphController {
			return g.handleDragGesture(iGesture)
		}

        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if  gIsGraphOrEditIdeaMode,
			let gesture = iGesture as? ZKeyPanGestureRecognizer,
            let (_, dropNearest, location) = widgetNearest(gesture),
            let flags = gesture.modifiers {
            let state = gesture.state

            dropNearest.widgetZone?.needWrite()

            if  isEditingText(at: location) {
                restartGestureRecognition()           // let text editor consume the gesture
            } else if flags.isCommand {               // shift background
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)          // logic for drawing the drop dot
			} else if state == .changed,              // enlarge rubberband
				gRubberband.rubberbandStart != .zero {
                gRubberband.rubberbandRect = CGRect(start: gRubberband.rubberbandStart, end: location)
				gRubberband.updateGrabs(in: dragView)
				dragView?.setAllSubviewsNeedDisplay()
            } else if state != .began {               // drag ended, failed or was cancelled
                gRubberband.rubberbandRect = nil      // erase rubberband

				restartGestureRecognition()
				dragView?.setAllSubviewsNeedDisplay()
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

                prior?                          .displayForDrag() // erase    child lines
                dropZone?.widget?               .displayForDrag() // relayout child lines
				gGraphController?    .dragView?.setNeedsDisplay() // relayout drag line and dot, in each drag view
				gRecentsController?  .dragView?.setNeedsDisplay()
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

    // MARK:- internals
    // MARK:-

    func widgetNearest(_ iGesture: ZGestureRecognizer?) -> (Bool, ZoneWidget, CGPoint)? {
        if  let location = iGesture?.location(in: dragView),
			let   widget = rootWidget.widgetNearestTo(location, in: dragView, hereZone) {
            if  isMap, !kIsPhone,

                // ////////////////////////// //
				// recurse once into subclass //
                // ////////////////////////// //

				let (_, subclassWidget, subclassLocation) = gFavoritesController?.widgetNearest(iGesture) {
				let  dragDotM =         widget.dragDot
                let  dragDotS = subclassWidget.dragDot
                let   vectorM = dragDotM.convert(dragDotM.bounds.center, to: view) - location
                let   vectorS = dragDotS.convert(dragDotS.bounds.center, to: view) - location
                let distanceM = vectorM.hypontenuse
                let distanceS = vectorS.hypontenuse

				// ////////////////////////////////////////////////////// //
				// determine which drag dot's center is closest to cursor //
				// ////////////////////////////////////////////////////// //

                if  distanceM > distanceS {
                    return (false, subclassWidget, subclassLocation)
                }
            }

            return (true, widget, location)
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
		gRubberband.rubberbandStart = CGPoint.zero

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
		if  isMap,
			let    widget = gFavoritesController?.detectWidget(iGesture) {
			return widget
		}

		var          hit : ZoneWidget?
		var     smallest = CGSize.big
        if  let        d = dragView,
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

