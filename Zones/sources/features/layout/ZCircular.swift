//
//  ZCircular.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK: - widget
// MARK: -

extension ZoneWidget {

	var                   placesCount :         Int { return ZWidgets.placesCount(at: linesLevel) }
	var                   spreadAngle :     CGFloat { return parentWidget?.incrementAngle ?? CGFloat(k2PI) }
	var                incrementAngle :     CGFloat { return spreadAngle / CGFloat(max(1, widgetZone?.count ?? 1)) }

	var placeAngle : CGFloat {
		var angle  = siblingAngle
		if  let p  = parentWidget, !isCenter {
			let o  = p.placeAngle
			angle += o
			angle  = angle.confine(within: CGFloat(k2PI))
		}

		return angle
	}

	var siblingAngle : CGFloat {
		if  let angle = parentWidget?.incrementAngle,
			let  zone = widgetZone, !isCenter,
			let index = zone.siblingIndex,
			let     c = zone.parentZone?.count {
			let count = CGFloat(max(0, c - 1))
			let extra = CGFloat(linesLevel != 1 ? 0.0 : -0.5)
			let delta = CGFloat(index) - (count / 2.0) + extra
			let     o = (delta * angle).confine(within: CGFloat(k2PI))

			return  o
		}

		return CGFloat(k2PI)
	}

	var circlesSelectionHighlightPath : ZBezierPath {
		if  gCirclesDisplayMode.contains(.cIdeas) {
			return ZBezierPath(ovalIn: highlightFrame)
		} else {
			return linesSelectionHighlightPath
		}
	}

	// MARK: - update
	// MARK: -

	func circlesUpdateWidgetDrawnSize() {
		if  let  size = textWidget?.frame.size {
			drawnSize = size.insetBy(gDotHeight, gDotHeight)
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
		if  let                 t = pseudoTextWidget {
			if  absolute {
				t.updateAbsoluteFrame(relativeTo: controller)

				textWidget?.frame = t.absoluteFrame
			} else if let    size = textWidget?.drawnSize {
				let          half = size.multiplyBy(0.5)
				let        center = bounds.center
				let          rect = CGRect(origin: center, size: .zero).expandedBy(half)
				t          .frame = rect
			}
		}
	}

	func updateAllDotFrames(_ absolute: Bool) {
		if  absolute {
			for line in childrenLines {
				line.circlesUpdateDotFrames(relativeTo: absoluteFrame, hideDragDot: hideDragDot)
			}
		}
	}

	func circlesUpdateHighlightFrame() {
		let           half = gDotWidth / 2.0
		if  gCirclesDisplayMode.contains(.cIdeas) {
			let     center = absoluteFrame.center
			let     radius = gCircleIdeaRadius + half
			highlightFrame = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
		} else if let    t = pseudoTextWidget {
			highlightFrame = t.absoluteFrame.expandedBy(dx: half, dy: .zero)
		}
	}

	func circlesUpdateDetectionFrame() {
		var rect  = absoluteFrame

		if  let z = widgetZone {
			if  z.count      != 0 {
				for child in childrenWidgets {
					let cRect = child.detectionFrame
					if !cRect.isEmpty {
						rect  = rect.union(cRect)
					}
				}

				for line in childrenLines {
					if  let drag  = line.dragDot {
						let dRect = drag.absoluteFrame
						if !dRect.isEmpty {
							rect  = rect.union(dRect)
						}
					}
				}
			} else if let p = parentLine?.dragDot {
				let pRect   = p.absoluteFrame
				if !pRect.isEmpty {
					rect    = rect.union(pRect)
				}
			}
		}

		detectionFrame = rect
	}

	// MARK: - traverse
	// MARK: -
	
	func circlesGrandUpdate() {
		updateByLevelAllFrames(in: controller)
		updateFrameSize()
		updateByLevelAllFrames(in: controller, true)
		updateAbsoluteFrame(relativeTo: controller)
	}

	func updateByLevelAllFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		traverseAllWidgetsByLevel {          (level, widgets) in
			widgets.updateAllWidgetFrames(at: level, in: controller, absolute)  // sets lineAngle
		}

		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.updateTextAndDotFrames  (absolute)
		}

		if  absolute  {
			traverseAllWidgetProgeny(inReverse: true) { iWidget in
				iWidget.circlesUpdateHighlightFrame()
				iWidget.circlesUpdateDetectionFrame()
			}
		}
	}

	func traverseAllWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var    level = 1
		var  widgets = childrenWidgets
		
		while widgets.count != 0 {
			block(level, widgets)
			
			level   += 1
			var next = ZoneWidgetArray()
			
			for widget in widgets {
				next.append(contentsOf: widget.childrenWidgets)
			}
			
			widgets  = next
		}
	}

	func updateTextAndDotFrames(_ absolute: Bool = false) {
		updateTextViewFrame(absolute)
		updateAllDotFrames (absolute)
	}

}

// MARK: - widgets array
// MARK: -

extension ZoneWidgetArray {

	var scrollOffset : CGPoint { return CGPoint(x: -gScrollOffset.x, y: gScrollOffset.y + 21) }

	func updateAllWidgetFrames(at  level: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		if  let  frame = controller?.mapPseudoView?.frame {
			let radius = ZWidgets.ringRadius(at: level)
			let center = frame.center - scrollOffset
			let   half = gCircleIdeaRadius

			for w in self {
				if  absolute {
					w.updateAbsoluteFrame(relativeTo: controller)
				} else if w.linesLevel > 0 {
					let   angle = Double(-w.placeAngle) - kHalfPI
					let rotated = CGPoint(x: .zero, y: radius).rotate(by: angle)
					let  origin = center + rotated
					let    rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					w   .bounds = CGRect(origin:  .zero, size: rect.size)
					w    .frame = rect
				}
			}
		}
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var lineAngle : CGFloat {
		if  let    angle = parentToChildVector?.angle {
			return angle
		}

		return .zero
	}

	var parentToChildVector : CGPoint? {
		if  let pCenter = parentWidget?.frame.center,
			let cCenter =  childWidget?.frame.center {
			let    cToC = cCenter - pCenter

			return cToC
		}

		return nil
	}

	var circlesAbsoluteDropDragDotRect: CGRect {
		var rect = CGRect()

		if  let zone = parentWidget?.widgetZone {
			if !zone.hasVisibleChildren {

				// //////////////////////
				// DOT IS STRAIGHT OUT //
				// //////////////////////

				if  let            dot = revealDot {
					let         insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
					rect               = dot.absoluteFrame.insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
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
						let    gHeight = gGenericOffset.height
						let      delta = (gHeight + gDotWidth) * multiplier
						rect           = rect.offsetBy(dx: 0.0, dy: delta)

					} else if lastIndex < zone.count, let secondDot = parentWidget?.dot(at: lastIndex) {

						// ///////////////
						// DOT IS TWEEN //
						// ///////////////

						let secondRect = secondDot.absoluteFrame
						let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
						rect           = rect.offsetBy(dx: 0.0, dy: -delta)
					}
				}
			}
		}

		return rect
	}

	func circlesUpdateDotFrames(relativeTo absoluteTextFrame: CGRect, hideDragDot: Bool) {
		dragDot?  .circlesUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
		revealDot?.circlesUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
	}

	func circlesStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let   path = ZBezierPath()
		let  start = iRect.origin
		let radius = iRect.size.hypotenuse
		let    end = CGPoint(x: .zero, y: radius).rotate(by: Double(lineAngle)).offsetBy(start)

		path.move(to: start)
		path.line(to: end)

		return path
	}

	func circlesUpdateLineSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	var circlesIsDragDrop : Bool { return line == gDragging.dropLine }

	// reveal dot is at circle around text, at angle, drag dot is further out along same ray

	var dotToDotLength : CGFloat {
		if  gCirclesDisplayMode.contains(.cIdeas) {
			let width = isReveal ? gDotHeight : gDotWidth

			return gCircleIdeaRadius + 1.5 + (width / 4.0)
		} else if let l = line,
			let    size = l.parentWidget?.pseudoTextWidget?.absoluteFrame.size {

			return size.add(width: gDotHeight, height: gDotHeight).lengthAt(l.lineAngle)
		}

		return .zero
	}

	func circlesUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		if  let          l = line,
			let     center = l.parentWidget?.frame.center,
			let lineVector = l.parentToChildVector {
			let  newLength = dotToDotLength
			let     length = lineVector.length               // line's length determined by parentToChildLine
			let      width = isReveal ? gDotHeight : gDotWidth
			let       size = CGSize(width: width, height: gDotWidth)
			let    divisor = isReveal ? newLength : (length - newLength)
			let      ratio = divisor / length
			let      delta = lineVector * ratio
			let     origin = center + delta - size
			l      .length = newLength
			let       rect = CGRect(origin: origin, size: drawnSize)
			let     offset = rect.height / -9.0
			absoluteFrame  = rect.insetEquallyBy(fraction: 0.22).offsetBy(dx: 0.0, dy: offset)

			updateTooltips()
		}
	}

	func circlesDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		if  let         l = line,
			let         p = l.parentWidget?.widgetZone, (p.isExpanded || parameters.isReveal),
			let         z = l .childWidget?.widgetZone {
			let     angle = l.lineAngle + CGFloat((z.isShowing && p.isExpanded) ? .zero : kPI)
			let thickness = CGFloat(gLineThickness * 2.0)
			let      rect = iDirtyRect.insetEquallyBy(thickness)
			var      path = ZBezierPath()

//			rect.drawColoredRect(.brown)
			
			if  parameters.isReveal {
				path      = ZBezierPath.bloatedTrianglePath(in: rect, at: angle)
			} else {
				path      = ZBezierPath           .ovalPath(in: rect, at: angle)
			}
			
			path.lineWidth = thickness
			path .flatness = 0.0001
			
			path.stroke()
			path.fill()
		}
	}

}
