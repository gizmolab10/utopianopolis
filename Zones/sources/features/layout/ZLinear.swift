//
//  ZLinear.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK: - widget
// MARK: -

extension ZoneWidget {

	func linearUpdateWidgetDrawnSize() {
		if  let       c = controller,
			let       t = textWidget,
			let   lSize = linesView?   .drawnSize {
			let   cSize = childrenView?.drawnSize
			var   width = cSize?.width  ?? .zero
			var  height = cSize?.height ?? .zero
			let   extra = width != .zero ? .zero : c.horizontalGap / 2.0
			width      += t.drawnSize.width
			let lheight = lSize.height
			let  lWidth = lSize.width * 2.0
			width      += lWidth + extra - (hideDragDot ? 5.0 : 4.0)

			if  height  < lheight {
				height  = lheight
			}

			drawnSize   = CGSize(width: width, height: height)
		}
	}

	func linearUpdateChildrenViewDrawnSize() {
		var  childrenSize = CGSize.zero

		if  hasVisibleChildren {
			var    height = CGFloat.zero
			var     width = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]
				let  size = child.drawnSize
				height   += size.height + ((index == 0) ? .zero : gapDistance)
				if  width < size.width {
					width = size.width
				}
			}

			childrenSize  = CGSize(width: width, height: height)
		}

		childrenView?    .drawnSize = childrenSize
		childrenView?.absoluteFrame = .zero
		childrenView?        .frame = .zero
		linesView?   .absoluteFrame = .zero
		linesView?           .frame = .zero
	}

	func linearUpdateLinesViewDrawnSize() {
		var     width = CGFloat.zero
		var    height = CGFloat.zero

		for line in childrenLines {
			line.updateLineSize()

			let  size = line.drawnSize
			height   += size.height
			if  width < size.width {
				width = size.width
			}
		}

		linesView?.drawnSize = CGSize(width: width, height: height)
	}

	func linearRelayoutChildrenWidgetFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var         y = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.convertFrameToAbsolute(relativeTo: controller)
				} else {
					let    size = child.drawnSize
					let  origin = CGPoint(x: .zero, y: y)
					y          += size.height + gapDistance
					let    rect = CGRect(origin: origin, size: size)
					child.frame = rect
				}
			}
		}
	}

	func linearRelayoutTextViewFrame(_ absolute: Bool = false) {
		if  let          t = pseudoTextWidget,
			let          w = textWidget,
			let          c = controller {
			if  absolute {
				t.convertFrameToAbsolute(relativeTo: c)

				w   .frame = t.absoluteFrame
			} else {
				let   size = w.drawnSize.insetBy(.zero, c.dotWidth * 0.1)
				let      x = hideDragDot ? 20.0 : c.horizontalGap + c.fontSize + c.coreThickness * 5.0 - 20.0
				let      y = (drawnSize.height - size.height) / 2.0
				let origin = CGPoint(x: x, y: y)
				t   .frame = CGRect(origin: origin, size: size)
			}
		}
	}

	func linearRelayoutChildrenViewFrame(_ absolute: Bool = false) {
		if  hasVisibleChildren, let c = childrenView {
			if  absolute {
				c.convertFrameToAbsolute(relativeTo: controller)
			} else if let tFrame = pseudoTextWidget?.frame {
				let    reduction = mapType.isMainMap ? 0.8 : kFavoritesMapReduction / 1.5
				let            x = tFrame.maxX + dotPlusGap * reduction
				let       origin = CGPoint(x: x, y: .zero)
				let       cFrame = CGRect(origin: origin, size: c.drawnSize)
				c         .frame = cFrame
			}
		}
	}

	func linearRelayoutLinesViewFrame(_ absolute: Bool = false) {

	}

	func linearRelayoutAbsoluteHitRect() {
		if  let            c = controller {
			var rect         = absoluteFrame
			let hasReveal    = widgetZone?.showRevealDot ?? false
			let deltaX       = c.dotWidth * (hasReveal ? 3.0 : 1.0)    // why 3?
			let extra        = CGSize(width: deltaX, height: .zero)
			for child in childrenWidgets {
				if  let zone = child.widgetZone, zone.isVisible {
					rect     = rect.union(child.absoluteHitRect)
				}
			}
			absoluteHitRect  = rect.expandedBy(extra).offsetBy(extra)
//			debug(absoluteHitRect, "HIT RECT ")
		}
	}

	func linearRelayoutHighlightRect() {
		if  let     frame = textWidget?.frame,
			let      zone = widgetZone,
			let         c = controller {
			let     thick = c.coreThickness
			let hasReveal = zone.showRevealDot
			let  multiple = zone.hasMultipleTraits
			let    narrow = zone.hasNarrowRevealDot
			let    oWidth = c.dotThirdWidth * (multiple ? -12.0 : (narrow ? 1.0 : -10.6))
			let    eWidth = c.dotThirdWidth * (multiple ?   1.5 : (narrow ? 1.0 :   1.3))
			let   yExpand = c.dotHeight / -25.0 * mapReduction
			let   wExpand = hasReveal ? -0.1 : -2.5
			let   hExpand = hasReveal ?  4.4 :  2.0
			let   xOffset = oWidth * wExpand + thick * 3.0
			let   xExpand = eWidth * hExpand + thick * 4.0
			highlightRect = frame.offsetBy(dx: xOffset, dy: .zero).expandedBy(dx: xExpand, dy: yExpand + 2.0)
		}
	}

	var linearSelectionHighlightPath: ZBezierPath {
		let   rect = highlightRect
		let radius = rect.minimumDimension / 2.08 - 1.0
		let   path = ZBezierPath(roundedRect: rect, cornerRadius: radius)

		return path
	}

	func linearRelayoutBothDotFrames(_ absolute: Bool) {
		if  absolute,
			let textFrame = pseudoTextWidget?.absoluteFrame {

			if !hideDragDot,
			    let    dot = parentLine?.dragDot,
			    let center = textFrame.center(of: dot) {

				dot.linearRelayoutDotAbsoluteFrame(relativeTo: center)
			}

			for line in childrenLines {
				if  let    dot = line.revealDot,
					let center = textFrame.center(of: dot) {

					dot.linearRelayoutDotAbsoluteFrame(relativeTo: center)
				}
			}
		}
	}

	// this is called twice in grand update
	// first with absolute false, then with true

	func linearRelayoutAllFrames(_ absolute: Bool = false) {
		traverseAllWidgetProgeny(inReverse: !absolute) { widget in
			widget.linearRelayoutSubrames(absolute)
		}

		if  absolute  {
			traverseAllWidgetProgeny(inReverse: true) { widget in
				if  let zone = widget.widgetZone, zone.isVisible {
					widget.linearRelayoutHighlightRect()
					widget.linearRelayoutAbsoluteHitRect()
				}
			}
		}
	}

	func linearRelayoutSubrames(_ absolute: Bool = false) {
		linearRelayoutTextViewFrame       (absolute)
		linearRelayoutChildrenWidgetFrames(absolute)
		linearRelayoutBothDotFrames       (absolute)
		linearRelayoutChildrenViewFrame   (absolute)
		linearRelayoutLinesViewFrame      (absolute)
	}

	func linearGrandRelayout() {
		linearRelayoutAllFrames()
		updateFrameSize()
		convertFrameToAbsolute(relativeTo: controller)
		linearRelayoutAllFrames(true)
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var linearLineRect : CGRect {
		return .zero
	}

	var linearDraggingDotAbsoluteFrame: CGRect {
		var rect = CGRect()

		if  let zone = parentWidget?.widgetZone,
			let    c = controller {
			if !zone.hasVisibleChildren {

				// /////////////////// //
				// DOT IS STRAIGHT OUT //
				// /////////////////// //

				if  let            dot = revealDot {
					let         insetX = CGFloat((c.dotHeight - c.dotWidth) / 2.0)
					rect               = dot.absoluteFrame.insetBy(dx: insetX, dy: .zero).offsetBy(dx: c.horizontalGap, dy: .zero)
				}
			} else if let      indices = gDragging.dropIndices, indices.count > 0 {
				let         firstindex = indices.firstIndex

				if  let       firstDot = parentWidget?.dot(at: firstindex) {
					rect               = firstDot.absoluteFrame
					let      lastIndex = indices.lastIndex

					if  indices.count == 1 || lastIndex >= zone.count {

						// ///////////////////// //
						// DOT IS ABOVE OR BELOW //
						// ///////////////////// //

						let   relation = gDragging.dropRelation
						let    isAbove = relation == .above || (!gListsGrowDown && (lastIndex == 0 || relation == .upon))
						let multiplier = CGFloat(isAbove ? 1.0 : -1.0)
						let      delta = dotPlusGap * multiplier * kVerticalWeight * 0.5
						rect           = rect.offsetBy(dx: .zero, dy: delta)

					} else if lastIndex < zone.count, let secondDot = parentWidget?.dot(at: lastIndex) {

						// /////////////// //
						// DOT IS STRAIGHT //
						// /////////////// //

						let secondRect = secondDot.absoluteFrame
						let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
						rect           = rect.offsetBy(dx: .zero, dy: -delta)
					}
				}
			}
		}

		return rect
	}

	func linearStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		guard let c = controller else { return ZBezierPath() }
		let    rect = iRect.centeredHorizontalLine(thick: c.coreThickness)
		let    path = ZBezierPath(rect: rect)

		path.setClip()

		return path
	}

	func linearLineKind(for delta: CGFloat) -> ZLineCurveKind {
		let   threshold =  CGFloat(2.0)
		if        delta >  threshold {
			return .above
		} else if delta < -threshold {
			return .below
		}

		return .straight
	}

	func linearLineKind(to targetRect: CGRect) -> ZLineCurveKind? {
		let  rect = revealDot?.absoluteFrame ?? .zero
		let delta = targetRect.midY - rect.midY

		return linearLineKind(for: delta)
	}

	func linearUpdateLineSize() {
		// all lines have at least a reveal dot
		drawnSize = revealDot?.updateDotDrawnSize() ?? .zero
	}

}

// MARK: - dot
// MARK: -

extension CGRect {

	func center(of dot: ZoneDot) -> CGPoint? {
		if  let      controller = dot.controller {
			if !dot.isReveal {
				return centerLeft.offsetBy(-controller.dotHalfWidth, .zero)
			} else if let zone = dot.widgetZone {
				let      width = zone.hasMultipleTraits ? controller.dotExtraHeight : zone.hasNarrowRevealDot ? controller.dotThirdWidth : controller.dotWidth

				return centerRight.offsetBy(width + controller.coreThickness * 5.0, .zero)
			}
		}

		return nil
	}
}

extension ZoneDot {

	var linearIsDragDrop : Bool {
		if  let    d  = gDragging.dropWidget?.widgetZone {
			return d == widgetZone
		}

		return false
	}

	func linearDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		guard let    c = controller ?? gHelpController else { return } // for help dots, widget and thus controller are nil; so use help controller
		let  thickness = c.coreThickness * 2.0
		var       path = ZBezierPath                (ovalIn: iDirtyRect.insetEquallyBy(fraction: 0.1))

		if  parameters.isReveal, !parameters.isCircle {
			path       = ZBezierPath.bloatedTrianglePath(in: iDirtyRect, aimedRight:  parameters.showList)
		}

		path.lineWidth = thickness
		path .flatness = kDefaultFlatness

		path.stroke()
		path.fill()
	}

	func linearRelayoutDotAbsoluteFrame(relativeTo center: CGPoint) {
		absoluteFrame   = CGRect(origin: center, size: .zero).expandedBy(drawnSize.dividedInHalf)
		absoluteHitRect = absoluteFrame.expandedEquallyBy(drawnSize.width / 2.0)

		if  isReveal, traitWidgets.count > 1 {
			for traitWidget in traitWidgets {
				traitWidget.linearRelayoutTraitWidgetAbsoluteFrame(relativeTo: absoluteFrame)
			}
		}
	}

}

extension ZTraitWidget {

	func linearRelayoutTraitWidgetAbsoluteFrame(relativeTo absoluteDotFrame: CGRect) {
		if  let         c = dot?.widget?.controller ?? gHelpController {
			let    radius = c.dotExtraHeight
			let    offset = drawnSize.dividedInHalf.multiplyBy(CGSize(width: 1.0, height: 0.7))
			let    origin = absoluteDotFrame.center.offsetBy(radius: radius, angle: angle) - offset
			absoluteFrame = CGRect(origin: origin, size: drawnSize)
		}
	}

}

// MARK: - dragging
// MARK: -

extension ZDragging {

	func debug(_ message: String? = nil) {
		if  let     z = dropWidget?.widgetZone,
			let     i = dropIndices,
			let     c = dropKind {
			var show  = false
			if  let p = debugDrop,    p != z {
				show  = true
			}

			if  let k = debugKind,    k != c {
				show  = true
			}

			if  let d = debugIndices, d != i {
				show  = true
			}

			if  show {
				print((message ?? "") + i.string + " \(z)")
			}
		}
	}

	func linearDropMaybeOntoWidget(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		var            totalGrabs = draggedZones
		totalGrabs.appendUnique(contentsOf: gSelecting.currentMapGrabs)
		if  let           gesture = iGesture,
			let   (widget, point) = controller.linearNearestWidget(by: gesture, locatedInMainMap: controller.isMainMap),
			var       nearestZone = widget?.widgetZone, !totalGrabs.contains(nearestZone),
			var     nearestWidget = widget {
			let relationToNearest = controller.relationOf(point, to: nearestWidget)
			let  neitherOnNorHere = !nearestWidget.isHere && (relationToNearest != .upon)
			let  draggedFromIndex = (draggedZones.count < 1) ? nil : draggedZones[0].siblingIndex
			let      nearestIndex = nearestZone.indexInRelation(relationToNearest)
			let         sameIndex = draggedFromIndex == nearestIndex || draggedFromIndex == nearestIndex - 1

			if  let    dropParent = nearestZone.parentZone, neitherOnNorHere,
				let   otherWidget = dropParent.widget {
				nearestWidget     = otherWidget
				nearestZone       = dropParent
			}

			let   nearestIsParent = nearestZone.children.intersects(draggedZones)
			let        spawnCycle = nearestZone.spawnCycle
			let       isForbidden = gIsEssayMode && nearestZone.isInMainMap
			let            isNoop = spawnCycle || (sameIndex && nearestIsParent) || nearestIndex < 0 || isForbidden
			var dropAt:      Int? = nearestIndex

			if  nearestZone.isBookmark {
				dropAt            = gListsGrowDown ? nil : 0
			} else if nearestIsParent,
					  draggedFromIndex  != nil,
					  draggedFromIndex! <= nearestIndex {
				dropAt!          -= 1
			}

			gMapController?.setNeedsDisplay() // draw drag line and dot

			if  !isNoop {
				if  gesture.isDone {
					dropOnto(nearestZone, at: dropAt, iGesture)

					return true
				} else {
					dropRelation  = relationToNearest
					dropIndices   = NSMutableIndexSet(index: nearestIndex)
					dropWidget    = nearestWidget
					dragPoint     = point
					dragLine      = nearestWidget.createDragLine()
					dropKind      = relationToNearest.lineCurveKind

					if  nearestIndex > 0, neitherOnNorHere {
						dropIndices?.add(nearestIndex - 1)
					}
				}
			}
		}

		return false
	}

}

// MARK: - map controller
// MARK: -

extension ZMapController {

	func linearNearestWidget(by gesture: ZGestureRecognizer?, locatedInMainMap: Bool = true) -> (ZoneWidget?, CGPoint)? {
		if  let         viewG = gesture?.view,
			let     locationM = gesture?.location(in: viewG),
			let       widgetM = hereWidget?.widgetNearestTo(locationM) {
			let     alternate = isMainMap ? gFavoritesMapController : gMapController
			if  let  mapViewA = alternate?.mapPseudoView, !kIsPhone,
				let locationA = mapPseudoView?.convertPoint(locationM, toRootPseudoView: mapViewA),
				let   widgetA = alternate?.hereWidget?.widgetNearestTo(locationA),
				let  dragDotM = widgetM.parentLine?.dragDot,
				let  dragDotA = widgetA.parentLine?.dragDot {
				let   vectorM = dragDotM.absoluteCenter - locationM
				let   vectorA = dragDotA.absoluteCenter - locationM
				let   lengthM = vectorM.length
				let   lengthA = vectorA.length

				// ////////////////////////////////////////////////////// //
				// determine which drag dot's center is closest to cursor //
				// ////////////////////////////////////////////////////// //

				if  lengthA < lengthM {
					return (widgetA, locatedInMainMap ? locationM : locationA)
				}
			}

			return (widgetM, locationM)
		}

		return nil
	}

}
