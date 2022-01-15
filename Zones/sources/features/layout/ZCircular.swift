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
			let extra = CGFloat(linesLevel != 1 ? .zero : -0.5)
			let delta = CGFloat(index) - (count / 2.0) + extra
			let     o = (delta * angle).confine(within: CGFloat(k2PI))

			return  o
		}

		return CGFloat(k2PI)
	}

	var circularSelectionHighlightPath : ZBezierPath {
		if  gDisplayIdeasWithCircles {
			return ZBezierPath(ovalIn: highlightRect)
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
				let          half = size.dividedInHalf
				let        center = bounds.center
				let          rect = CGRect(origin: center, size: .zero).expandedBy(half)
				t          .frame = rect
			}
		}
	}

	func updateAllDotFrames() {
		for line in childrenLines {
			line  .dragDot?.circularUpdateDragDotAbsoluteFrame()
			line.revealDot?.circularUpdateDotAbsoluteFrame()

		}
	}

	func circularUpdateHighlightRect() {
		if  gDisplayIdeasWithCircles {
			let    center = absoluteFrame.center
			let    radius = gCircleIdeaRadius + gDotHalfWidth
			highlightRect = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
		} else if let   t = pseudoTextWidget {
			highlightRect = t.absoluteFrame.expandedBy(dx: gDotHalfWidth, dy: .zero)
		}
	}

	func circularUpdateAbsoluteHitRect() {
		var rect  = absoluteFrame

		if  let z = widgetZone {
			if  z.count      != 0 {
				for child in childrenWidgets {
					let cRect = child.absoluteHitRect
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

		absoluteHitRect = rect
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

		traverseAllWidgetProgeny(inReverse: !absolute) { widget in
			widget.updateTextViewFrame(absolute)
		}

		if  absolute  {
			traverseAllWidgetProgeny(inReverse: true) { widget in
				widget.circularUpdateHighlightRect()
				widget.updateAllDotFrames()
				widget.circularUpdateAbsoluteHitRect()
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

	static func widgetNearest(to vector: CGPoint) -> (ZoneWidget?, CGFloat) {
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

			return (widget, tAngle)
		}

		return (nil, .zero)
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

			for w in self {
				if  absolute {
					w.updateAbsoluteFrame(relativeTo: controller)
				} else if w.linesLevel > 0 {
					let   angle = w.placeAngle
					let rotated = CGPoint(x: .zero, y: radius).rotate(by: Double(angle))
					let  origin = center + rotated
					let    rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(gCircleIdeaRadius)
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

	var      dotToDotAngle : CGFloat { return revealToDragVector?.angle ?? .zero }
	var parentToChildAngle : CGFloat { return parentToChildVector?.angle ?? .zero }

	var revealToDragVector : CGPoint? {
		if  let pCenter = revealDot?.absoluteFrame.center,
			let cCenter =   dragDot?.absoluteFrame.center {
			let    cToC = cCenter - pCenter

			return cToC
		}

		return nil
	}

	var parentToChildVector : CGPoint? {
		if  let pCenter = parentWidget?.frame.center,
			let cCenter =  childWidget?.frame.center {
			let    cToC = cCenter - pCenter

			return cToC
		}

		return nil
	}

	var circularAbsoluteFloatingDotRect: CGRect {
		var rect = CGRect.zero

		if  let  isBig = controller?.isBigMap,
			let widget = parentWidget,
			let  angle = dragAngle {
			let vector = CGPoint(x: length, y: .zero).rotate(by: Double(angle))
			let center = widget.absoluteFrame.center
			let   size = gDotSize(forReveal: false, forBigMap: isBig)
			rect       = CGRect(origin: center + vector, size: .zero).expandedBy(size.dividedInHalf)
		}

		return rect
	}

	func circularStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let   path = ZBezierPath()
		let  start = iRect.origin
		let radius = iRect.size.hypotenuse
		let    end = CGPoint(x: .zero, y: radius).rotate(by: Double(dotToDotAngle)).offsetBy(start)

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

	var circularIsDragDrop : Bool {
		if  let    d  = gDragging.dragLine {
			return d == line
		}

		return false
	}

	var dotHypotenuse : CGFloat {
		if  gDisplayIdeasWithCircles {
			let   width = isReveal ? gDotHeight : gDotWidth

			return gCircleIdeaRadius + 1.5 + (width / 4.0)
		} else if let l = line,
			let    size = l.parentWidget?.highlightRect.expandedBy(dx: gDotHalfWidth, dy: gDotHalfWidth).size {

			return CGFloat(size.ellipticalLengthAt(Double(l.parentToChildAngle))) // apply trigonometry
		}

		return .zero
	}

	func circularUpdateDotAbsoluteFrame() {
		if  let          l = line,
			let     center = l.parentWidget?.frame.center,
			let lineVector = l.parentToChildVector {
			let  hypotenuse = dotHypotenuse
			let      length = lineVector.length
			let       width = isReveal ? gDotHeight : gDotWidth
			let        size = CGSize(width: width, height: gDotWidth).dividedInHalf
			let     divisor = isReveal ? hypotenuse : (length - hypotenuse)
			let       ratio = divisor / length
			let       delta = lineVector * ratio
			let      origin = center + delta - size - CGPoint(x: .zero, y: 1.0)
			l       .length = hypotenuse
			absoluteFrame   = CGRect(origin: origin, size: drawnSize)
			absoluteHitRect = absoluteFrame

			updateTooltips()
		}
	}

	enum ZPosition: Int {
		case above
		case below
		case atLeft
		case atRight

		static func position(for angle: Double) -> ZPosition {
			let adjusted = (angle - (kHalfPI / 2.0)).confine(within: k2PI) // subtract 45 degrees
			let      tid = kHalfPI / 6.0 // 15 degrees

			if        adjusted < (kHalfPI + tid) {
				return .above
			} else if adjusted < kPI {
				return .atLeft
			} else if adjusted < (kPI + kHalfPI - tid) {
				return .below
			}

			return .atRight
		}

		var angle: Double {
			switch self {
			case .above, .below: return kHalfPI
			default:             return .zero
			}
		}
	}

	func ratioForAngle(_ angle: CGFloat) -> CGFloat {
		let a = Double(angle)
		let b = a.confine(within: kPI) - kHalfPI
		let c = b / kHalfPI

		return CGFloat(c)
	}

	func circularUpdateDragDotAbsoluteFrame() {
		if  gDisplayIdeasWithCircles {
			circularUpdateDotAbsoluteFrame()
		} else {
			if  let          l = line,
				let      frame = l.childWidget?.pseudoTextWidget?.absoluteFrame.expandedBy(dx: gDotHalfWidth, dy: .zero),
				let lineVector = l.parentToChildVector {
				let      angle = lineVector.angle
				let   position = ZPosition.position(for: Double(angle))
				let  expansion = gDotSize(forReveal: false, forBigMap: isBigMap).dividedInHalf
				let   halfSize = frame.size.dividedInHalf.expandedBy(.zero, gDotHalfWidth / 2.0)
				let      width = halfSize.width
				let     height = halfSize.height
				let     offset = width * ratioForAngle(angle)
				var     center = frame.center

				switch position {
				case .above:   center = center.offsetBy( offset, -height)
				case .below:   center = center.offsetBy(-offset,  height)
				case .atLeft:  center = center.offsetBy(  width,   .zero)
				case .atRight: center = center.offsetBy( -width,   .zero)
				}

				absoluteFrame   = CGRect(origin: center, size: .zero).expandedBy(expansion)
				absoluteHitRect = absoluteFrame

				updateTooltips()
			}
		}
	}

	func circularDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		if  let     l = line,
			let     p = l.parentWidget?.widgetZone, (p.isExpanded || parameters.isReveal),
			let     z = l .childWidget?.widgetZone {
			var angle = l.dotToDotAngle + CGFloat((z.isShowing && p.isExpanded) ? .zero : kPI)
			let thick = CGFloat(gLineThickness * 2.0)
			let  rect = iDirtyRect.insetEquallyBy(thick)
			var  path = ZBezierPath()
			
			if  parameters.isReveal {
				path  = ZBezierPath.bloatedTrianglePath(in: rect, at: angle)
			} else {
				angle = gDisplayIdeasWithCircles ? angle : CGFloat(ZPosition.position(for: Double(l.parentToChildAngle)).angle)
				path  = ZBezierPath.ovalPath(in: rect, at: angle)
			}
			
			path.lineWidth = thick
			path .flatness = 0.0001
			
			path.stroke()
			path.fill()
		}
	}

}

// MARK: - controller
// MARK: -

extension ZMapController {

	func circularDrawLevelRings() {
		if  let     center = hereWidget?.absoluteFrame.center {
			var      level = 1
			while ZWidgets.hasVisibleChildren   (at: level) {
				let radius = ZWidgets.ringRadius(at: level)
				let   rect = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
				let  color = gAccentColor.withAlpha(0.2)
				level     += 1

				rect.drawColoredCircle(color, thickness: gDotHeight)
			}
		}
	}

}

// MARK: - dragging
// MARK: -

extension ZDragging {

	func circularDropMaybeOntoWidget(_ gesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		clearDragAndDrop()

		if  let       view = gesture?.view,
			let   location = gesture?.location(in: view),
			let       root = controller.hereWidget {
			let     vector = location - root.absoluteFrame.center
			let     (w, a) = ZWidgets.widgetNearest(to: vector)
			if  let widget = w,
				let zone   = widget.widgetZone, !draggedZones.contains(zone) {
				dragLine   = widget.createDragLine(with: a)

				if  gesture?.isDone ?? false {
					dropOnto(zone, gesture)
				}

				return true
			}
		}

		return false
	}
	
}
