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

	var    placesCount :     Int { return ZWidgets.placesCount(at: linesLevel) }
	var    spreadAngle : CGFloat { return parentWidget?.incrementAngle ?? CGFloat(k2PI) }
	var incrementAngle : CGFloat { return spreadAngle / CGFloat(max(1, widgetZone?.count ?? 1)) }
	var     placeAngle : CGFloat { return (-rawPlaceAngle - CGFloat(kHalfPI)).confine(within: CGFloat(k2PI)) }

	var rawPlaceAngle : CGFloat {

		// zero == noon
		// increases clockwise

		var angle  = siblingAngle
		if  let p  = parentWidget, !isCenter {
			let o  = p.rawPlaceAngle
			angle += o
			angle  = angle.confine(within: CGFloat(k2PI))
		}

		return angle
	}

	var siblingAngle : CGFloat { // offset from parent's place angle
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

	var circularSelectionHighlightPath : ZBezierPath {
		if  gCirclesDisplayMode.contains(.cIdeas) {
			return ZBezierPath(ovalIn: highlightFrame)
		} else {
			return linearSelectionHighlightPath
		}
	}

	// MARK: - update
	// MARK: -

	func circularUpdateWidgetDrawnSize() {
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
				line.circularUpdateDotFrames(relativeTo: absoluteFrame, hideDragDot: hideDragDot)
			}
		}
	}

	func circularUpdateHighlightFrame() {
		let           half = gDotHalfWidth
		if  gCirclesDisplayMode.contains(.cIdeas) {
			let     center = absoluteFrame.center
			let     radius = gCircleIdeaRadius + half
			highlightFrame = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
		} else if let    t = pseudoTextWidget {
			highlightFrame = t.absoluteFrame.expandedBy(dx: half, dy: .zero)
		}
	}

	func circularUpdateDetectionFrame() {
		var rect  = absoluteFrame

		if  let z = widgetZone {
			if  z.count      != 0 {
				for child in childrenWidgets {
					let cRect = child.detectionFrame
					if  cRect.hasSize {
						rect  = rect.union(cRect)
					}
				}

				for line in childrenLines {
					if  let drag  = line.dragDot {
						let dRect = drag.absoluteFrame
						if  dRect.hasSize {
							rect  = rect.union(dRect)
						}
					}
				}
			} else if let p = parentLine?.dragDot {
				let pRect   = p.absoluteFrame
				if  pRect.hasSize {
					rect    = rect.union(pRect)
				}
			}
		}

		detectionFrame = rect
	}

	// MARK: - traverse
	// MARK: -
	
	func circularGrandUpdate() {
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
				iWidget.circularUpdateHighlightFrame()
				iWidget.circularUpdateDetectionFrame()
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

// MARK: - widgets static methods
// MARK: -

extension ZWidgets {

	static func placesCount(at iLevel: Int) -> Int {
		var  level = iLevel
		var  total = 1

		while true {
			let cCount = maxVisibleChildren(at: level)
			level     -= 1

			if  cCount > 0 {
				total *= cCount
			}

			if  level  < 0 {
				return total
			}
		}
	}

	static func levelAt(_ radius: CGFloat) -> Int {
		var level = 0

		while ringRadius(at: level) < radius {
			level += 1
		}

		return level
	}

	static func ringRadius(at level: Int) -> CGFloat {
		let increment = gCircleIdeaRadius + gDotHeight
		let  multiple = CGFloat(level) * 1.7

		return gDotHalfWidth + multiple * increment
	}

	static func maxVisibleChildren(at level: Int) -> Int {
		let   children = visibleChildren(at: level - 1)
		var maxVisible = 0

		for child in children {
			if  let  count = child.widgetZone?.visibleChildren.count,
				maxVisible < count {
				maxVisible = count
			}
		}

		return maxVisible
	}

	static func traverseAllVisibleWidgetsByLevel(_ block: IntZoneWidgetsClosure) {
		var   level = 0
		var widgets = visibleChildren(at: level)

		while widgets.count != 0 {
			block(level, widgets)

			level  += 1
			widgets = visibleChildren(at: level)
		}
	}

	static func hasVisibleChildren(at level: Int) -> Bool {
		for widget in gHere.visibleWidgets {
			if  widget.linesLevel == level {
				return true
			}
		}

		return false
	}

	static func visibleChildren(at level: Int) -> ZoneWidgetArray {
		var widgets = ZoneWidgetArray()

		for widget in gHere.visibleWidgets {
			if  widget.linesLevel == level {
				widgets.append(widget)
			}
		}

		return widgets
	}

	static func widgetNearest(to vector: CGPoint) -> (ZoneWidget?, CGFloat, CGFloat) {
		let   angle = vector.angle
		let   level = levelAt(vector.length)
		let widgets = visibleChildren(at: level)
		var  dAngle = CGFloat(k2PI)
		var   found : ZoneWidget?

		for widget in widgets {
			let diff      = widget.placeAngle - angle
			if  abs(diff) < abs(dAngle) {
				dAngle    = diff
				found     = widget
			}
		}

		if  let widget = found {
			let   sign = CGFloat(dAngle >= 0 ? 1 : -1)
			let iAngle = widget.incrementAngle * sign / 2.0
			let tAngle = (widget.placeAngle + iAngle).confine(within: CGFloat(k2PI))

			return (widget, tAngle, gCircleIdeaRadius)
		}

		return (nil, .zero, .zero)
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

	var circularAbsoluteDropDragDotRect: CGRect {
		var rect = CGRect.zero

		if  let  isBig = controller?.isBigMap,
			let widget = parentWidget,
			let  angle = dragAngle {
			let vector = CGPoint(x: length, y: .zero).rotate(by: Double(angle))
			let center = widget.absoluteFrame.center
			let   size = gDotSize(forReveal: false, forBigMap: isBig)
			rect       = CGRect(origin: center + vector, size: .zero).expandedBy(size.multiplyBy(0.5))
		}

		return rect
	}

	func circularUpdateDotFrames(relativeTo absoluteTextFrame: CGRect, hideDragDot: Bool) {
		dragDot?  .circularUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
		revealDot?.circularUpdateDotAbsoluteFrame(relativeTo: absoluteTextFrame)
	}

	func circularStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let   path = ZBezierPath()
		let  start = iRect.origin
		let radius = iRect.size.hypotenuse
		let    end = CGPoint(x: .zero, y: radius).rotate(by: Double(lineAngle)).offsetBy(start)

		path.move(to: start)
		path.line(to: end)

		return path
	}

	func circularUpdateLineSize() {
		// TODO: use radius to create point (vector)
		// use angle to rotate
		// use this to create drawnSize
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	var circularIsDragDrop : Bool { return line == gDragging.dragLine }

	var dotToDotLength : CGFloat {
		if  gCirclesDisplayMode.contains(.cIdeas) {
			let   width = isReveal ? gDotHeight : gDotWidth

			return gCircleIdeaRadius + 1.5 + (width / 4.0)
		} else if let l = line,
			let    size = l.parentWidget?.pseudoTextWidget?.absoluteFrame.size {
			let  larger = size + CGSize(width: gDotHeight, height: gDotHalfWidth)

			return larger.lengthAt(l.lineAngle) // apply trigonometry
		}

		return .zero
	}

	func circularUpdateDotAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		if  let          l = line,
			let     center = l.parentWidget?.frame.center,
			let lineVector = l.parentToChildVector {
			let  newLength = dotToDotLength
			let     length = lineVector.length
			let      width = isReveal ? gDotHeight : gDotWidth
			let       size = CGSize(width: width, height: gDotWidth).multiplyBy(0.5)
			let    divisor = isReveal ? newLength : (length - newLength)
			let      ratio = divisor / length
			let      delta = lineVector * ratio
			let     origin = center + delta - size
			l      .length = newLength
			let       rect = CGRect(origin: origin, size: drawnSize)
			absoluteFrame  = rect.offsetBy(dx: 0.0, dy: -3.0)

			updateTooltips()
		}
	}

	func circularDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
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
					let   angle = w.placeAngle
					let rotated = CGPoint(x: .zero, y: radius).rotate(by: Double(angle))
					let  origin = center + rotated
					let    rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(half)
					w   .bounds = CGRect(origin:  .zero, size: rect.size)
					w    .frame = rect
				}
			}
		}
	}

}

// MARK: - controller
// MARK: -

extension ZMapController {

	func circularDrawLevelRings() {
		if  gCirclesDisplayMode.contains(.cRings),
			let     center = rootWidget?.highlightFrame.center {
			var      level = 1
			while ZWidgets.hasVisibleChildren   (at: level) {
				let radius = ZWidgets.ringRadius(at: level)
				let   rect = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
				let  color = gAccentColor.lighter(by: 2.0)
				level     += 1

				rect.drawColoredCircle(color, thickness: 0.2)
			}
		}
	}

}

// MARK: - dragging
// MARK: -

extension ZDragging {

	func circularDropMaybeOntoWidget(_ gesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		let prior = dragLine?.parentWidget?.widgetZone
		clearDragAndDrop()

		if  let      view = gesture?.view,
			let  location = gesture?.location(in: view),
			let      root = controller.rootWidget {
			let    vector = location - root.absoluteFrame.center
			let (d, a, l) = ZWidgets.widgetNearest(to: vector)
			if  let     w = d,
				let  zone = w.widgetZone,
				!draggedZones.contains(zone) {
				dragLine  = w.createDragLine(with: l, a)

				if  zone != prior {
					print("\(w)")
				}

				if  gesture?.isDone ?? false {
					dropOnto(zone, gesture)
				}

				return true
			}
		}

		return false
	}
	
}
