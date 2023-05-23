//
//  ZDragging.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/24/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gDragging = ZDragging()

class ZDragging: NSObject {

	var   startAngle =       CGFloat.zero
	var    dragStart =       CGPoint.zero
	var      current =       CGPoint.zero
	var draggedZones =         ZoneArray()
	var dropRelation :         ZRelation?
	var debugIndices : NSMutableIndexSet?
	var  dropIndices : NSMutableIndexSet?
	var   dropWidget :        ZoneWidget?
	var    debugDrop :              Zone?
	var    dropCrumb : ZBreadcrumbButton?
	var    dragPoint :           CGPoint?
	var     dragLine :          ZoneLine?
	var     dropKind :        ZLineCurveKind?
	var    debugKind :        ZLineCurveKind?
	var    dragIndex :               Int? { return (draggedZones.count == 0) ? nil : draggedZones[0].siblingIndex }
	var   isDragging :               Bool { return !draggedZones.isEmpty }
	var  showRotator :               Bool { return current != dragStart && !gRubberband.showRubberband && gMapController?.inCircularMode ?? false }

	func isDragged(_ zone: Zone?) -> Bool { return dragLine != nil && zone != nil && draggedZones.contains(zone!) }
	func restartGestureRecognitiono()     { dropWidget?.controller?.restartGestureRecognition() }

	func drawRotator() {
		if  let origin = gMapController?.mapOrigin, showRotator {
			let    ray = current - origin
			let radius = CGSize(ray).hypotenuse
			let  color = gActiveColor.lighter(by: 3.0)
			let   line = ZBezierPath.linePath   (start: origin,  length: 5000.0, angle: gMapRotationAngle + kHalfPI)
			let circle = ZBezierPath.circlePath(origin: origin,  radius: radius)
			let   knob = ZBezierPath.circlePath(origin: current, radius: 5.0)
			circle.lineWidth = 3.0
			line  .lineWidth = 2.0

			gActiveColor.setFill()
			color .setStroke()
			circle.addDashes()
			circle.stroke()
			line  .stroke()
			knob  .fill()
		}
	}

	// MARK: - drag
	// MARK: -

	func clearDragAndDrop() {
		if  let z = dropWidget?.widgetZone {
			debugDrop = z
		}

		if  let i = dropIndices {
			debugIndices = i
		}

		if  let k = dropKind {
			debugKind = k
		}

		dropRelation = nil
		dropIndices  = nil
		dropWidget   = nil
		dropCrumb    = nil
		dragPoint    = nil
		dragLine     = nil
		dropKind     = nil
	}

	func cleanupAfterDrag() {   // cursor exited view, remove drag cruft
		let   view = gDetailsController?.view(for: .vFavorites) as? ZFavoritesTogglingView
		startAngle = .zero
		current    = .zero
		dropCrumb?.highlight(false)
		gRubberband.clearRubberband()
		view?.unhighlightButtons()
		clearDragAndDrop()
		gMapController?.setNeedsDisplay() // erase drag: line and dot
	}

	func handleDragGesture(_ gesture: ZPanGestureRecognizer, in controller: ZMapController) {
		if  gPreferencesAreTakingEffect {
			return
		}

		if  let    flags = gesture.modifiers {
			let    state = gesture.state
			let location = gesture.location(in: gesture.view)
			let  COMMAND = flags.hasCommand
			let  CONTROL = flags.hasControl
			let   OPTION = flags.hasOption

			gTextEditor.stopCurrentEdit(forceCapture: true, andRedraw: false) // so drag and rubberband do not lose user's changes

			if  COMMAND && !OPTION {                          // shift background
				controller.offsetEvent(move: state == .changed, to: location)
			} else if !draggedZones.isEmpty {
				dropMaybeGesture(gesture, in: controller)     // logic for drawing the drop dot, and for dropping dragged idea
			} else if state == .changed {
				if  CONTROL, controller.inCircularMode {
					controller.rotationEvent(location)
				} else if gRubberband.setRubberbandExtent(to: location) {  // enlarge rubberband
					gRubberband.updateGrabs()
				}
			} else if ![.began, .cancelled].contains(state) { // drag ended or failed
				gRubberband.rubberbandRect = nil              // erase rubberband

				cleanupAfterDrag()
				controller.restartGestureRecognition()
				gSignal([.spPreferences, .sData])             // so color well and indicators get updated
			} else if let any = controller.detectHit(at: location),
				let       dot = any as? ZoneDot {
				if  dot.isReveal {
					cleanupAfterDrag()                        // no dragging
					dot.widgetZone?.handleDotClicked(flags, isReveal: true)
				} else {
					dragStartEvent(dot, gesture)              // start dragging a drag dot
				}
			} else {                                          // begin drag
				current    = location
				dragStart  = location
				startAngle = gMapRotationAngle

				draggedZones.removeAll()
				gRubberband.rubberbandStartEvent(gesture)
				assignAsFirstResponder(gMapView)
			}

			gMapController?.setNeedsDisplay()
		}
	}

	func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
		if  var    zone = dot.widgetZone,              // should always be true
			let gesture = iGesture {

			if  gesture.isOptionDown {
				zone    = zone.deepCopy(into: .mineID) // option means drag a copy
			}

			if  gesture.isShiftDown {
				zone.addToGrabs()
			} else if !zone.isGrabbed {
				zone.grab()
			}

			draggedZones = gSelecting.currentMapGrabs

			if  gIsEssayMode {
				assignAsFirstResponder(gMapView)
			}
		}
	}

	// MARK: - drop
	// MARK: -

	func dropOnto(_ zone: Zone, at dropAt: Int? = nil, _ iGesture: ZGestureRecognizer?) {
		if  let gesture = iGesture as? ZPanGestureRecognizer,
			let   flags = gesture.modifiers {
			zone.addZones(draggedZones, at: dropAt, undoManager: gMapEditor.undoManager, flags) { [self] in
				gSelecting.updateBrowsingLevel()
				gSelecting.updateCousinList()
				cleanupAfterDrag()
				restartGestureRecognitiono()
				gRelayoutMaps()
			}
		}
	}

	func dropMaybeGesture(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) {
		cleanupAfterDrag()

		if  dropMaybeOntoFavoritesButton(iGesture, in: controller) ||
			dropMaybeOntoCrumbButton    (iGesture, in: controller) ||
			dropMaybeOntoWidget         (iGesture, in: controller) {
		}

		if  iGesture?.isDone ?? false {
			controller.restartGestureRecognition()
			gSignal([.sDatum, .spPreferences, .spCrumbs]) // so color well gets updated
		}
	}

	func dropMaybeOntoFavoritesButton(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		if  let gesture = iGesture as? ZPanGestureRecognizer,
		    let    view = gDetailsController?.view(for: .vFavorites) as? ZFavoritesTogglingView,
			let    left = view.detectLeftButton(at: gesture.location(in: controller.view), inView: controller.view) {
			let  isDone = iGesture?.isDone ?? false
			let CONTROL = gesture.isControlDown

			if  !isDone {
				view.highlightLeftButton(left)
			} else if let parent = gFavoritesCloud.showNextList(down: !left, travel: CONTROL) {
				var zones = draggedZones

				if  controller.isMainMap {
					zones = draggedZones.map { $0.isBookmark ? $0 : gFavoritesCloud.matchOrCreateBookmark(for: $0, addToRecents: false) }
				}

				zones.moveInto(parent, travel: CONTROL) { flag in }   // move dragged zone into the new focused list
			}

			return true
		}

		return false
	}

	func dropMaybeOntoCrumbButton(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		if  let crumb = gBreadcrumbsView?.detectCrumb(iGesture),
			!draggedZones.containsARoot,
			!draggedZones.contains(crumb.zone),
			!draggedZones.anyParentMatches(crumb.zone) {

			if  iGesture?.isDone ?? false {
				dropOnto(crumb.zone, iGesture)
			} else {
				dropCrumb = crumb

				crumb.highlight(true)
			}

			return true
		}

		return false
	}

}
