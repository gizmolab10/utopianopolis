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
	var    spreadAngle : CGFloat { return parentWidget?.incrementAngle ?? k2PI.float }
	var incrementAngle : CGFloat { return spreadAngle / CGFloat(max(1, widgetZone?.count ?? 1)) }
	var     placeAngle : CGFloat { return (-rawPlaceAngle - kHalfPI.float).confine(within: k2PI.float) }

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
			let     o = (delta * angle).confine(within: k2PI.float)

			return  o
		}

		return k2PI.float
	}

	var circularSelectionHighlightPath : ZBezierPath {
		if  gDrawCirclesAroundIdeas {
			return ZBezierPath(ovalIn: highlightRect)
		} else {
			return linearSelectionHighlightPath
		}
	}

	// MARK: - update
	// MARK: -

	func circularUpdateWidgetDrawnSize() {
		if  let     c = gMapController,
			let  size = textWidget?.frame.size {
			drawnSize = size.insetBy(c.dotHeight, c.dotHeight)
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
		if  let                 t = pseudoTextWidget {
			if  absolute {
				t.convertFrameToAbsolute(relativeTo: controller)

				textWidget?.frame = t.absoluteFrame
			} else if let    half = textWidget?.drawnSize.dividedInHalf {
				let        center = bounds.center
				let          rect = CGRect(origin: center, size: .zero).expandedBy(half)
				t          .frame = rect
			}
		}
	}

	func updateAllDotFrames() {
		for line in childrenLines {
			line.revealDot?.circularUpdateDotAbsoluteFrame()     // start of line

			if  gDrawCirclesAroundIdeas { // end of line
				line.dragDot?.circularUpdateDotAbsoluteFrame()
			} else {
				line.dragDot?.circularUpdateDragDotAbsoluteFrame()
			}
		}
	}

	func circularUpdateHighlightRect() {
		if  let             c = controller {
			if  gDrawCirclesAroundIdeas {
				let    center = absoluteCenter
				let    radius = c.circleIdeaRadius + c.dotHalfWidth
				highlightRect = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
//				center.printPoint("HIGHLIGHT " + selfInQuotes)
			} else if let   t = pseudoTextWidget {
				highlightRect = t.absoluteFrame.expandedBy(dx: c.dotHalfWidth, dy: .zero)
			}
		}
	}

	func circularRelayoutAbsoluteHitRect() {
		var rect  = highlightRect

		for child in childrenWidgets {
			let cRect = child.absoluteHitRect
			if  cRect.hasSize {
				rect  = rect.union(cRect)
			}
		}

		for line in childrenLines {
			if  let reveal = line.revealDot {
				let rRect = reveal.absoluteHitRect
				if  rRect.hasSize {
					rect  = rect.union(rRect)
				}
			}
		}

		if  let    drag = parentLine?.dragDot {
			let dRect   = drag.absoluteHitRect
			if  dRect.hasSize {
				rect    = rect.union(dRect)
			}
		}

		absoluteHitRect = rect
	}

	// MARK: - draw
	// MARK: -

	func drawInterior(_ color: ZColor) {
		guard let    c = controller ?? gHelpController else { return } // for help dots, widget and controller are nil; so use help controller
		let       path = selectionHighlightPath
		path.lineWidth = CGFloat(c.coreThickness * 2.5)
		path .flatness = kDefaultFlatness

		color.setFill()
		path.fill()
	}

	// MARK: - traverse
	// MARK: -
	
	func circularGrandRelayout() {
		updateAllProgenyFrames(in: controller)
		updateFrameSize()
		convertFrameToAbsolute(relativeTo: controller)
		updateAllProgenyFrames(in: controller, true)    // sets widget absolute frame
	}

	func updateAllProgenyFrames(in controller: ZMapController?, _ absolute: Bool = false) {
		traverseAllWidgetsByLevel {          (level, widgets) in
			widgets.updateAllWidgetFrames(at: level, in: controller, absolute)  // not absolute sets lineAngle
		}

		traverseAllVisibleWidgetProgeny(inReverse: !absolute) { widget in
			widget.updateTextViewFrame(absolute)
		}

		if  absolute  {
			traverseAllVisibleWidgetProgeny(inReverse: true) { widget in
				widget.circularUpdateHighlightRect()
				widget.updateAllDotFrames()
			}

			traverseAllVisibleWidgetProgeny(inReverse: true) { widget in
				widget.circularRelayoutAbsoluteHitRect()
			}
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
				let multiple = 10
				return (total + multiple * maxVisibleChildren(at: iLevel)) / (multiple + 1)   // average
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
		guard let    c = gMapController else { return .zero }
		let  increment = c.circleIdeaRadius * 2.0 + c.dotHeight * 1.5
		var     radius = increment + c.dotHalfWidth

		// need to do this tweak at every level

		for l in 1..<level {
			let places = placesCount(at: l)
			let  needs = CGFloat(places) * increment / k2PI
			let  delta = (needs > increment) ? needs : increment
			radius    += delta
		}

		return radius
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
		var  dAngle = k2PI.float
		var   found : ZoneWidget?

		for widget in widgets {
			let diff      = widget.placeAngle - angle
			if  abs(diff) < abs(dAngle) {
				dAngle    = diff
				found     = widget
			}
		}

		if  let widget = found {
			let oAngle = widget.placeAngle
			let   sign = CGFloat(dAngle >= 0 ? 1 : -1)
			let iAngle = widget.incrementAngle * sign / 2.0
			let tAngle = (oAngle + iAngle).confine(within: k2PI.float)

			return (widget, tAngle)
		}

		return (nil, .zero)
	}

}

// MARK: - widgets array
// MARK: -

extension ZoneWidgetArray {

	func updateAllWidgetFrames(at  level: Int, in controller: ZMapController?, _ absolute: Bool = false) {
		if  let vFrame = controller?.mapPseudoView?.frame,
			let      c = controller {
			let radius = ZWidgets.ringRadius(at: level)
			let offset = CGPoint(x: gMapOffset.x - c.dotHeight, y: -gMapOffset.y - 22.0)
			let center = vFrame.center + offset

			for w in self {
				if  absolute {
					w.convertFrameToAbsolute(relativeTo: controller)
				} else if w.linesLevel > 0 {
					let   angle = w.placeAngle + gMapRotationAngle
					let rotated = CGPoint(x: .zero, y: radius).rotate(by: Double(angle))
					let  origin = center + rotated
					let    rect = CGRect(origin: origin, size:     .zero).expandedEquallyBy(c.circleIdeaRadius)
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

	var      dotToDotAngle : CGFloat { return       dragDotVector .angle }
	var parentToChildAngle : CGFloat { return parentToChildVector?.angle ?? .zero }

	var dragDotVector : CGPoint {
		let item = gDrawCirclesAroundIdeas ? parentWidget : dragDot
		if  let rCenter = revealDot?.absoluteCenter,
			let pCenter = item?     .absoluteCenter {
			let    sign = gDrawCirclesAroundIdeas ? 1.0 : -1.0

			return (rCenter - pCenter) * sign
		}

		return .zero
	}

	var parentToChildVector : CGPoint? {
		if  let cCenter =  childWidget?.absoluteCenter,
			let pCenter = parentWidget?.absoluteCenter {
			let    pToC = cCenter - pCenter

			return pToC
		}

		return nil
	}

	var circularDraggingDotAbsoluteFrame: CGRect {
		var rect = CGRect.zero

		if  let widget = parentWidget,
			let  angle = dragAngle {
			let vector = CGPoint(x: length, y: .zero).rotate(by: Double(angle))
			let center = widget.absoluteCenter
			let   size = controller?.dotSize(forReveal: false) ?? .zero
			rect       = CGRect(origin: center + vector, size: .zero).expandedBy(size.dividedInHalf)
		}

		return rect
	}

	func circularStraightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		return ZBezierPath.linePath(start: iRect.origin, length: iRect.size.hypotenuse, angle: dotToDotAngle)
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
		if  let              c = controller {
			if  gDrawCirclesAroundIdeas {
				let      width = isReveal ? c.dotHeight : c.dotWidth

				return c.circleIdeaRadius + 1.5 + (width / 3.0)
			} else if let    l = line,
					  let size = l.parentWidget?.highlightRect.size.expandedEquallyBy(c.dotHalfWidth) {

				return size.ellipticalLengthAt(Double(l.parentToChildAngle).float )    // apply trigonometry
			}
		}

		return .zero
	}

	func circularUpdateDotAbsoluteFrame() {
		if  let           l = line,
			let     pCenter = l.parentWidget?.absoluteCenter,
			let  lineVector = l.parentToChildVector {
			let betweenDots = lineVector.length

			if  betweenDots == .zero {
				return
			}

			let   acrossDot = dotHypotenuse
			let     divisor = isReveal ? acrossDot : (betweenDots - acrossDot)
			let       ratio = divisor / betweenDots
			let   dotOffset = lineVector * ratio
			let   dotCenter = pCenter + dotOffset
			absoluteFrame   = CGRect(center: dotCenter, size: drawnSize)
			absoluteHitRect = absoluteFrame
		}
	}

	@discardableResult func circularUpdateDotDrawnSize() -> CGSize {
		linearUpdateDotDrawnSize()

		// drawnSize = drawnSize.multiplyBy(1.4)

		return drawnSize
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
		if  let          l = line,
			let          c = controller,
			let      frame = l.childWidget?.pseudoTextWidget?.absoluteFrame.expandedBy(dx: c.dotHalfWidth, dy: .zero),
			let lineVector = l.parentToChildVector {
			let      angle = lineVector.angle
			let   position = ZPosition.position(for: Double(angle))
			let  expansion = controller?.dotSize(forReveal: false).dividedInHalf ?? .zero
			let   halfSize = frame.size.dividedInHalf.expandedEquallyBy(c.dotEighthWidth)
			let     height = halfSize.height
			let      width = halfSize.width
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
		}
	}

	func circularDrawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		if  let     l = line,
			let     c = controller,
			let     p = l.parentWidget?.widgetZone, (p.isExpanded || parameters.isReveal),
			let     z = l .childWidget?.widgetZone {
			var angle = l.dotToDotAngle + CGFloat((z.isShowing && p.isExpanded) ? .zero : kPI)
			let thick = CGFloat(c.coreThickness * 2.0)
			let  rect = iDirtyRect.insetEquallyBy(thick)
			var  path = ZBezierPath()

			if  parameters.isReveal {
				path  = ZBezierPath.bloatedTrianglePath(in: rect, at: angle)
			} else {
				angle = gDrawCirclesAroundIdeas ? angle : ZPosition.position(for: Double(l.parentToChildAngle)).angle.float
				path  = ZBezierPath.ovalPath(in: rect, at: angle)
			}
			
			path.lineWidth = thick
			path .flatness = kDefaultFlatness

			path.stroke()
			path.fill()

//			absoluteHitRect.drawColoredRect(.red)
		}
	}

}

// MARK: - controller
// MARK: -

extension ZMapController {

	func circularDrawLevelRings() {
		if  let     center = hereWidget?.absoluteCenter {
			var      level = 1
			while ZWidgets.hasVisibleChildren   (at: level) {
				let radius = ZWidgets.ringRadius(at: level)
				let   rect = CGRect(origin: center, size: .zero).expandedEquallyBy(radius)
				let  color = gAccentColor.withAlpha(0.5)
				level     += 1

				rect.drawColoredCircle(color, thickness: dotHeight, dashes: true)
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
			let     vector = location - root.absoluteCenter
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

struct ZCirclesDisplayMode: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let cIdeas = ZCirclesDisplayMode(rawValue: 1 << 0)
	static let cRings = ZCirclesDisplayMode(rawValue: 1 << 1)

	static func createFrom(_ set: IndexSet) -> ZCirclesDisplayMode {
		var mode = ZCirclesDisplayMode()

		if  set.contains(0) {
			mode.insert(.cIdeas)
		}

		if  set.contains(1) {
			mode.insert(.cRings)
		}

		return mode
	}

	var indexSet: IndexSet {
		var set = IndexSet()

		if  contains(.cIdeas) {
			set.insert(0)
		}

		if  contains(.cRings) {
			set.insert(1)
		}

		return set
	}

}
