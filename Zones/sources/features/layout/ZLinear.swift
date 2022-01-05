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
			var   width = cSize?.width  ?? 0.0
			var  height = cSize?.height ?? 0.0
			let   extra = width != 0.0 ? 0.0 : gHorizontalGap / 2.0
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
		var     width = CGFloat(0.0)
		var    height = CGFloat(0.0)

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

	func linearUpdateDetectionFrame() {
		var rect       = absoluteFrame
		let extra      = CGSize(width: gDotHalfWidth, height: .zero)
		if  let  child = childrenView?.absoluteFrame {
			rect       = rect.union(child)
		}
		detectionFrame = rect.expandedBy(extra).offsetBy(extra)
	}

	func linearUpdateHighlightFrame() {
		if  let      frame = textWidget?.frame,
			let       zone = widgetZone {
			let    fExpand = CGFloat(zone.showRevealDot ? 0.56 : -1.06)
			let    mExpand = CGFloat(zone.showRevealDot ? 1.25 :  0.65)
			let    xExpand = gDotHeight * mExpand
			let    yExpand = gDotHeight / -20.0 * mapReduction
			highlightFrame = frame.expandedBy(dx: xExpand, dy: yExpand + 2.0).offsetBy(dx: gDotHalfWidth * fExpand, dy: .zero)
		}
	}

	var linearSelectionHighlightPath: ZBezierPath {
		let   rect = highlightFrame
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
		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.linearUpdateSubframes(absolute)
		}

		if  absolute  {
			traverseAllWidgetProgeny(inReverse: true) { iWidget in
				iWidget.linearUpdateHighlightFrame()
				iWidget.linearUpdateDetectionFrame()
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

	var linearAbsoluteDropDragDotRect: CGRect {
		var rect = CGRect()

		if  let zone = parentWidget?.widgetZone {
			if !zone.hasVisibleChildren {

				// //////////////////////
				// DOT IS STRAIGHT OUT //
				// //////////////////////

				if  let            dot = revealDot {
					let         insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
					rect               = dot.absoluteFrame.insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gHorizontalGap, dy: 0.0)
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

						let   relation = gDragging.dragRelation
						let    isAbove = relation == .above || (!gListsGrowDown && (lastIndex == 0 || relation == .upon))
						let multiplier = CGFloat(isAbove ? 1.0 : -1.0) * kVerticalWeight
						let      delta = dotPlusGap * multiplier
						rect           = rect.offsetBy(dx: 0.0, dy: delta)

					} else if lastIndex < zone.count, let secondDot = parentWidget?.dot(at: lastIndex) {

						// /////////////// //
						// DOT IS STRAIGHT //
						// /////////////// //

						let secondRect = secondDot.absoluteFrame
						let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
						rect           = rect.offsetBy(dx: 0.0, dy: -delta)
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

	var linearIsDragDrop : Bool { return widget == gDragging.dropWidget }

	func linearUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		let     center = isReveal ? absoluteTextFrame.centerRight.offsetBy(gDotWidth, 0.0) : absoluteTextFrame.centerLeft.offsetBy(-gDotHalfWidth, 0.0)
		absoluteFrame  = CGRect(origin: center, size: .zero).expandedBy(drawnSize.multiplyBy(0.5))
		detectionFrame = absoluteFrame.expandedEquallyBy(gDotHalfWidth)

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

extension ZDragging {

	func linearDropMaybeOntoWidget(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		clearDragAndDrop()

		let         totalGrabs = draggedZones + gSelecting.currentMapGrabs
		if  let (inBigMap, zone, location) = controller.widgetHit(by: iGesture, locatedInBigMap: controller.isBigMap),
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

			if  !isNoop, !isDone {
				dragRelation   = relation
				dropIndices    = NSMutableIndexSet(index: index)
				dropWidget     = dropZoneWidget
				dragPoint      = location
				dragLine       = dropZoneWidget.createDragLine()

				if  notDropHere && index > 0 {
					dropIndices?.add(index - 1)
				}
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

		return false
	}

}

