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
		if  let       t = textWidget,
			let   lSize = linesView?   .drawnSize {
			let   cSize = childrenView?.drawnSize
			var   width = cSize?.width  ?? .zero
			var  height = cSize?.height ?? .zero
			let   extra = width != .zero ? .zero : gHorizontalGap / 2.0
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

	func linearUpdateChildrenWidgetFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var         y = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(relativeTo: controller)
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

	func linearUpdateTextViewFrame(_ absolute: Bool = false) {
		if  let                 t = pseudoTextWidget {
			if  absolute {
				t.updateAbsoluteFrame(relativeTo: controller)

				textWidget?.frame = t.absoluteFrame
			} else if let    size = textWidget?.drawnSize {
				let             x = hideDragDot ? 20.0 : gHorizontalGap + 4.0
				let             y = (drawnSize.height - size.height) / 2.0
				let        origin = CGPoint(x: x, y: y)
				t          .frame = CGRect(origin: origin, size: size)
			}
		}
	}

	func linearUpdateChildrenViewFrame(_ absolute: Bool = false) {
		if  hasVisibleChildren, let c = childrenView {
			if  absolute {
				c.updateAbsoluteFrame(relativeTo: controller)
			} else if let tFrame = pseudoTextWidget?.frame {
				let    reduction = type.isBigMap ? 0.8 : kSmallMapReduction / 1.5
				let            x = tFrame.maxX + dotPlusGap * reduction
				let       origin = CGPoint(x: x, y: .zero)
				let       cFrame = CGRect(origin: origin, size: c.drawnSize)
				c         .frame = cFrame
			}
		}
	}

	func linearUpdateLinesViewFrame(_ absolute: Bool = false) {

	}

	func linearUpdateAbsoluteHitRect() {
		var rect       = absoluteFrame
		let extra      = CGSize(width: gDotHalfWidth, height: .zero)
		if  let  child = childrenView?.absoluteFrame {
			rect       = rect.union(child)
		}
		absoluteHitRect = rect.expandedBy(extra).offsetBy(extra)
	}

	func linearUpdateHighlightRect() {
		if  let     frame = textWidget?.frame,
			let      zone = widgetZone {
			let   fExpand = CGFloat(zone.showRevealDot ? 0.56 : -1.06)
			let   mExpand = CGFloat(zone.showRevealDot ? 1.25 :  0.65)
			let   xExpand = gDotHeight * mExpand
			let   yExpand = gDotHeight / -20.0 * mapReduction
			highlightRect = frame.expandedBy(dx: xExpand, dy: yExpand + 2.0).offsetBy(dx: gDotHalfWidth * fExpand, dy: .zero)
		}
	}

	var linearSelectionHighlightPath: ZBezierPath {
		let   rect = highlightRect
		let radius = rect.minimumDimension / 2.08 - 1.0
		let   path = ZBezierPath(roundedRect: rect, cornerRadius: radius)

		return path
	}

	func linearUpdateBothDotFrames(_ absolute: Bool) {
		if  absolute,
			let textFrame = pseudoTextWidget?.absoluteFrame {

			if !hideDragDot {
				parentLine?.dragDot?.linearUpdateDotAbsoluteFrame(relativeTo: textFrame)
			}

			for line in childrenLines {
				line     .revealDot?.linearUpdateDotAbsoluteFrame(relativeTo: textFrame)
			}
		}
	}

	// this is called twice in grand update
	// first with absolute false, then with true

	func linearUpdateAllFrames(_ absolute: Bool = false) {
		traverseAllWidgetProgeny(inReverse: !absolute) { widget in
			widget.linearUpdateSubframes(absolute)
		}

		if  absolute  {
			traverseAllWidgetProgeny(inReverse: true) { widget in
				widget.linearUpdateHighlightRect()
				widget.linearUpdateAbsoluteHitRect()
			}
		}
	}

	func linearUpdateSubframes(_ absolute: Bool = false) {
		linearUpdateTextViewFrame       (absolute)
		linearUpdateChildrenWidgetFrames(absolute)
		linearUpdateBothDotFrames       (absolute)
		linearUpdateChildrenViewFrame   (absolute)
		linearUpdateLinesViewFrame      (absolute)
	}

	func linearGrandUpdate() {
		linearUpdateAllFrames()
		updateFrameSize()
		linearUpdateAllFrames(true)
		updateAbsoluteFrame(relativeTo: controller)
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var linearLineRect : CGRect {
		return .zero
	}

	var linearAbsoluteFloatingDotRect: CGRect {
		var rect = CGRect()

		if  let zone = parentWidget?.widgetZone {
			if !zone.hasVisibleChildren {

				// //////////////////////
				// DOT IS STRAIGHT OUT //
				// //////////////////////

				if  let            dot = revealDot {
					let         insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
					rect               = dot.absoluteFrame.insetBy(dx: insetX, dy: .zero).offsetBy(dx: gHorizontalGap, dy: .zero)
				}
			} else if let      indices = gDragging.dropIndices, indices.count > 0 {
				let         firstindex = indices.firstIndex

				if  let       firstDot = parentWidget?.dot(at: firstindex) {
					rect               = firstDot.absoluteFrame
					let      lastIndex = indices.lastIndex

					if  indices.count == 1 || lastIndex >= zone.count {

						// ////////////////////////
						// DOT IS ABOVE OR BELOW //
						// ////////////////////////

						let   relation = gDragging.dropRelation
						let    isAbove = relation == .above || (!gListsGrowDown && (lastIndex == 0 || relation == .upon))
						let multiplier = CGFloat(isAbove ? 1.0 : -1.0) * kVerticalWeight
						let      delta = dotPlusGap * multiplier
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
		let rect = iRect.centeredHorizontalLine(thick: CGFloat(gLineThickness))
		let path = ZBezierPath(rect: rect)

		path.setClip()

		return path
	}

	func linearLineKind(for delta: CGFloat) -> ZLineCurve {
		let   threshold =  CGFloat(2.0)
		if        delta >  threshold {
			return .above
		} else if delta < -threshold {
			return .below
		}

		return .straight
	}

	func linearLineKind(to targetRect: CGRect) -> ZLineCurve? {
		let toggleRect = revealDot?.absoluteFrame ?? .zero
		let      delta = targetRect.midY - toggleRect.midY

		return linearLineKind(for: delta)
	}

	func linearUpdateLineSize() {
		// all lines have at least a reveal dot
		drawnSize = revealDot?.updateDotDrawnSize() ?? .zero
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	var linearIsDragDrop : Bool {
		if  let    d  = gDragging.dropWidget?.widgetZone {
			return d == widgetZone
		}

		return false
	}

	func linearUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		let      center = isReveal ? absoluteTextFrame.centerRight.offsetBy(gDotWidth, .zero) : absoluteTextFrame.centerLeft.offsetBy(-gDotHalfWidth, .zero)
		absoluteFrame   = CGRect(origin: center, size: .zero).expandedBy(drawnSize.dividedInHalf)
		absoluteHitRect = absoluteFrame.expandedEquallyBy(gDotHalfWidth)

		updateTooltips()
	}

	func linearDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		let  thickness = CGFloat(gLineThickness) * 2.0
		var       path = ZBezierPath()

		if  parameters.isReveal {
			path       = ZBezierPath.bloatedTrianglePath(in: iDirtyRect, aimedRight: parameters.showList)
		} else {
			path       = ZBezierPath                (ovalIn: iDirtyRect.insetEquallyBy(thickness))
		}

		path.lineWidth = thickness
		path .flatness = 0.0001

//		absoluteFrame.drawColoredRect(.brown)
		path.stroke()
		path.fill()
	}

}

// MARK: - dragging
// MARK: -

extension ZDragging {

	func debug(_ message: String? = nil) {
		if  let     z = dropWidget?.widgetZone,
			let     i = dropIndices {
			var show  = false
			if  let p = debugDrop,    p != z {
				show  = true
			}

			if  let d = debugIndices, d != i {
				show  = true
			}

			if  show {
				print(i.string + (message ?? "") + " \(z)")
			}
		}
	}

	func linearDropMaybeOntoWidget(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		let            totalGrabs = draggedZones + gSelecting.currentMapGrabs
		if  let   (widget, point) = controller.linearNearestWidget(by: iGesture, locatedInBigMap: controller.isBigMap),
			var       nearestZone = widget?.widgetZone, !totalGrabs.contains(nearestZone),
			var     nearestWidget = widget {
			let  nearestIsNotHere = !nearestWidget.isHere
			let relationToNearest = controller.relationOf(point, to: nearestWidget)
			let  draggedFromIndex = (draggedZones.count < 1) ? nil : draggedZones[0].siblingIndex
			let      nearestIndex = nearestZone.siblingIndex! + relationToNearest.rawValue
			let         sameIndex = draggedFromIndex == nearestIndex // || draggedFromIndex == nearestIndex - 1
			let      aboveOrBelow = relationToNearest != .upon

			if  let    dropParent = nearestZone.parentZone, aboveOrBelow, nearestIsNotHere,
				let   otherWidget = dropParent.widget {
				nearestWidget     = otherWidget
				nearestZone       = dropParent
			}

			let   nearestIsParent = nearestZone.children.intersects(draggedZones)
			let        spawnCycle = nearestZone.spawnCycle
			let       isForbidden = gIsEssayMode && nearestZone.isInBigMap
			let            isNoop = spawnCycle || (sameIndex && nearestIsParent) || nearestIndex < 0 || isForbidden
			let            isDone = iGesture?.isDone ?? false

			if  !isNoop {
				if  !isDone {
					dropRelation  = relationToNearest
					dropIndices   = NSMutableIndexSet(index: nearestIndex)
					dropWidget    = nearestWidget
					dragPoint     = point
					dragLine      = nearestWidget.createDragLine()

					if  nearestIndex > 0, nearestIsNotHere {
						dropIndices?.add(nearestIndex - 1)
					}

					debug(aboveOrBelow ? " <<<a||b>>>" : nil)
				}

				gMapView?.setNeedsDisplay() // draw drag line and dot

				if  isDone {
					var dropAt: Int?       = nearestIndex
					if  nearestZone.isBookmark {
						dropAt             = gListsGrowDown ? nil : 0
					} else if nearestIsParent,
						draggedFromIndex  != nil,
						draggedFromIndex! <= nearestIndex {
						dropAt!           -= 1
					}

					dropOnto(nearestZone, at: dropAt, iGesture)

					return true
				}
			}
		}

		return false
	}

}

// MARK: - map controller
// MARK: -

extension ZMapController {

	func linearNearestWidget(by gesture: ZGestureRecognizer?, locatedInBigMap: Bool = true) -> (ZoneWidget?, CGPoint)? {
		if  let         viewG = gesture?.view,
			let     locationM = gesture?.location(in: viewG),
			let       widgetM = hereWidget?.widgetNearestTo(locationM) {
			let     alternate = isBigMap ? gSmallMapController : gMapController
			if  let  mapViewA = alternate?.mapPseudoView, !kIsPhone,
				let locationA = mapPseudoView?.convertPoint(locationM, toRootPseudoView: mapViewA),
				let   widgetA = alternate?.hereWidget?.widgetNearestTo(locationA),
				let  dragDotM = widgetM.parentLine?.dragDot,
				let  dragDotA = widgetA.parentLine?.dragDot {
				let   vectorM = dragDotM.absoluteFrame.center - locationM
				let   vectorA = dragDotA.absoluteFrame.center - locationM
				let   lengthM = vectorM.length
				let   lengthA = vectorA.length

				// ////////////////////////////////////////////////////// //
				// determine which drag dot's center is closest to cursor //
				// ////////////////////////////////////////////////////// //

				if  lengthA < lengthM {
					return (widgetA, locatedInBigMap ? locationM : locationA)
				}
			}

			return (widgetM, locationM)
		}

		return nil
	}

}
