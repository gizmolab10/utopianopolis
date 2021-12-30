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

	var draggedZones =         ZoneArray()
	var dragRelation :         ZRelation?
	var  dropIndices : NSMutableIndexSet?
	var   dropWidget :        ZoneWidget?
	var    dropCrumb : ZBreadcrumbButton?
	var    dragPoint :           CGPoint?
	var     dragLine :          ZoneLine?
	var    dragIndex :               Int? { return (draggedZones.count == 0) ? nil : draggedZones[0].siblingIndex }

	// MARK: - drag
	// MARK: -

	func restartGestureRecognitiono() {
		dropWidget?.controller?.restartGestureRecognition()
	}

	func cleanupAfterDrag() {

		// cursor exited view, remove drag cruft

		dropCrumb?.highlight(false)

		gRubberband.rubberbandStart = .zero

		dragRelation = nil
		dropIndices  = nil
		dropWidget   = nil
		dropCrumb    = nil
		dragPoint    = nil
		dragLine     = nil

		gDragView?.setNeedsDisplay() // erase drag: line and dot
		gMapView?  .setNeedsDisplay()
	}

	func handleDragGesture(_ gesture: ZKeyPanGestureRecognizer, in controller: ZMapController) {
		if  let     flags  = gesture.modifiers {
			let   location = gesture.location(in: gesture.view)
			let     state  = gesture.state

			if  flags.isCommand && !flags.isOption {          // shift background
				controller.scrollEvent(move: state == .changed,  to: location)
			} else if !draggedZones.isEmpty {
				dropMaybeGesture(gesture, in: controller)     // logic for drawing the drop dot, and for dropping dragged idea
			} else if state == .changed,                      // enlarge rubberband
				gRubberband.setRubberbandExtent(to: location) {
				gRubberband.updateGrabs()
				gDragView?.setNeedsDisplay()
				gMapView?.setNeedsDisplay()
			} else if ![.began, .cancelled].contains(state) { // drag ended or failed
				gRubberband.rubberbandRect = nil              // erase rubberband

				cleanupAfterDrag()
				controller.restartGestureRecognition()
				gSignal([.spPreferences, .sDatum])                            // so color well and indicators get updated
			} else if let any = controller.detect(at: location),
				let       dot = any as? ZoneDot {
				if  dot.isReveal {
					cleanupAfterDrag()                        // no dragging
					dot.widgetZone?.revealDotClicked(flags)
				} else {
					dragStartEvent(dot, gesture)             // start dragging a drag dot
				}
			} else {                                          // begin drag
				gRubberband.rubberbandStartEvent(location, gesture)
				gMainWindow?.makeFirstResponder(gMapView)
			}

			gDragView?.setNeedsDisplay()
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
		if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
			let   flags = gesture.modifiers {
			zone.addZones(draggedZones, at: dropAt, undoManager: gMapEditor.undoManager, flags) {
				gSelecting.updateBrowsingLevel()
				gSelecting.updateCousinList()
				self.restartGestureRecognitiono()
				gRelayoutMaps()
			}
		}
	}

	func dropMaybeGesture(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) {
		cleanupAfterDrag()

		if  dropMaybeOntoCrumbButton(iGesture, in: controller) ||
			dropMaybeOntoWidget(iGesture, in: controller) {
		}

		if  iGesture?.isDone ?? false {
			controller.restartGestureRecognition()
			gSignal([.sDatum, .spPreferences, .spCrumbs]) // so color well gets updated
		}
	}

	func dropMaybeOntoWidget(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means done with drags
		if  !draggedZones.containsARoot {
			let         totalGrabs = draggedZones + gSelecting.currentMapGrabs
			if  draggedZones.userCanMoveAll,
				let (inBigMap, zone, location) = controller.widgetHit(by: iGesture, locatedInBigMap: controller.isBigMap),
				var       dropZone = zone, !totalGrabs.contains(dropZone),
				var dropZoneWidget = dropZone.widget {
				let      dropIndex = dropZone.siblingIndex
				let           here = inBigMap ? gHere : gSmallMapHere
				let    notDropHere = dropZone != here
				let       relation = controller.relationOf(location, to: dropZoneWidget)
				let      useParent = relation != .upon && notDropHere

				if  useParent,
					let dropParent = dropZone.parentZone,
					let    pWidget = dropParent.widget {
					dropZone       = dropParent
					dropZoneWidget = pWidget

					if  relation  == .below {
						noop()
					}
				}

				let  lastDropIndex = dropZone.count
				var          index = (useParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : (!gListsGrowDown ? 0 : lastDropIndex)
				;            index = notDropHere ? index : relation != .below ? 0 : lastDropIndex
				let      dragIndex = (draggedZones.count < 1) ? nil : draggedZones[0].siblingIndex
				let      sameIndex = dragIndex == index || dragIndex == index - 1
				let   dropIsParent = dropZone.children.intersects(draggedZones)
				let     spawnCycle = dropZone.spawnCycle
				let    isForbidden = gIsEssayMode && dropZone.isInBigMap
				let         isNoop = spawnCycle || (sameIndex && dropIsParent) || index < 0 || isForbidden
				let         isDone = iGesture?.isDone ?? false
				let      forgetAll = isNoop || isDone
				dragRelation       = forgetAll ? nil : relation
				dropIndices        = forgetAll ? nil : NSMutableIndexSet(index: index)
				dropWidget         = forgetAll ? nil : dropZoneWidget
				dragPoint          = forgetAll ? nil : location
				dragLine           = forgetAll ? nil : dropZoneWidget.createDragLine()

				if !forgetAll && notDropHere && index > 0 {
					dropIndices?.add(index - 1)
				}

				gMapView?.setNeedsDisplay() // relayout drag line and dot, in each drag view

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

	func dropMaybeOntoCrumbButton(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means done with drags
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
