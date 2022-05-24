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
	var     dropKind :        ZLineCurve?
	var    debugKind :        ZLineCurve?
	var    dragIndex :               Int? { return (draggedZones.count == 0) ? nil : draggedZones[0].siblingIndex }
	var   isDragging :               Bool { return !draggedZones.isEmpty }
	var  showRotator :               Bool { return current != dragStart && !gRubberband.showRubberband && gMapController?.inCircularMode ?? false }

	func isDragged(_ zone: Zone?) -> Bool { return gDragging.dragLine != nil && zone != nil && gDragging.draggedZones.contains(zone!) }
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
		startAngle = .zero
		current    = .zero
		dropCrumb?.highlight(false)
		gRubberband.clearRubberband()
		clearDragAndDrop()
		gMapController?.setNeedsDisplay() // erase drag: line and dot
	}

	func handleDragGesture(_ gesture: ZPanGestureRecognizer, in controller: ZMapController) {
		if  gIgnoreEvents {
			return
		}

		if  let     flags  = gesture.modifiers {
			let   location = gesture.location(in: gesture.view)
			let     state  = gesture.state

			gTextEditor.stopCurrentEdit(forceCapture: true, andRedraw: false) // so drag and rubberband do not lose user's changes

			if  flags.isCommand && !flags.isOption {          // shift background
				controller.offsetEvent(move: state == .changed,  to: location)
			} else if !draggedZones.isEmpty {
				dropMaybeGesture(gesture, in: controller)     // logic for drawing the drop dot, and for dropping dragged idea
			} else if state == .changed {
				if  flags.isControl, controller.inCircularMode {
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
					dot.widgetZone?.revealDotClicked(flags)
				} else {
					dragStartEvent(dot, gesture)              // start dragging a drag dot
				}
			} else {                                          // begin drag
				current    = location
				dragStart  = location
				startAngle = gMapRotationAngle

				draggedZones.removeAll()
				gRubberband.rubberbandStartEvent(gesture)
				gMainWindow?.makeFirstResponder(gMapView)
			}

			gMapController?.setNeedsDisplay()
		}
	}

	func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
		if  var    zone = dot.widgetZone,              // should always be true
			let gesture = iGesture {

			if  gesture.isOptionDown {
				zone    = zone.deepCopy(dbID: .mineID) // option means drag a copy
			}

			if  gesture.isShiftDown {
				zone.addToGrabs()
			} else if !zone.isGrabbed {
				zone.grab()
			}

			draggedZones = gSelecting.currentMapGrabs

			if  gIsEssayMode {
				gMainWindow?.makeFirstResponder(gMapView)
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

		if  dropMaybeOntoCrumbButton(iGesture, in: controller) ||
			dropMaybeOntoWidget     (iGesture, in: controller) {
		}

		if  iGesture?.isDone ?? false {
			controller.restartGestureRecognition()
			gSignal([.sDatum, .spPreferences, .spCrumbs]) // so color well gets updated
		}
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
