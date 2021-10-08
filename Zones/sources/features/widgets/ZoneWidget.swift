//
//  ZoneWidget.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/7/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

enum ZLineKind: Int {
    case below    = -1
    case straight =  0
    case above    =  1
}

struct ZWidgetType: OptionSet, CustomStringConvertible {
	static var structValue = 0
	static var   nextValue : Int { if structValue == 0 { structValue = 1 } else { structValue *= 2 }; return structValue }
	let           rawValue : Int

	init() { rawValue = ZWidgetType.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let tExemplar = ZWidgetType()
	static let tFavorite = ZWidgetType()
	static let   tBigMap = ZWidgetType()
	static let   tRecent = ZWidgetType()
	static let    tTrash = ZWidgetType()
	static let    tEssay = ZWidgetType()
	static let     tNote = ZWidgetType()
	static let     tIdea = ZWidgetType()
	static let     tLost = ZWidgetType()
	static let     tNone = ZWidgetType()

	var isBigMap:   Bool { return contains(.tBigMap) }
	var isRecent:   Bool { return contains(.tRecent) }
	var isFavorite: Bool { return contains(.tFavorite) }
	var isExemplar: Bool { return contains(.tExemplar) }

	var description: String {
		return [(.tNone,        "    none"),
				(.tLost,        "    lost"),
				(.tIdea,        "    idea"),
				(.tNote,        "    note"),
				(.tEssay,       "   essay"),
				(.tTrash,       "   trash"),
				(.tRecent,      "  recent"),
				(.tBigMap,      " big map"),
				(.tFavorite,    "favorite"),
				(.tExemplar,    "exemplar")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: ", ")
	}

	var identifier: String {
		let parts = description.components(separatedBy: ", ")
		var result = kEmpty

		for part in parts {
			let strip = part.spacesStripped
			var short = strip[0]

			switch strip {
				case "none":     short = "?"
				case "exemplar": short = "x"
				default:         break
			}

			result.append(short)
		}

		return result
	}
}

class ZWidgetObject: NSObject {

	var note: ZNote?
	var zone: Zone?

	var type: ZWidgetType? {
		return note == nil ? (zone == nil ? nil : .tIdea) : (zone == nil ? .tNote : [.tNote, .tIdea])
	}
}

class ZoneWidget: ZView {

    let                 dragDot = ZoneDot        ()
    let               revealDot = ZoneDot        ()
    let              textWidget = ZoneTextWidget ()
    let            childrenView = ZView          ()
	let            widgetObject = ZWidgetObject  ()
    private var childrenWidgets = [ZoneWidget]   ()
	var            parentWidget : ZoneWidget? { return widgetZone?.parentZone?.widget }
	var                   ratio :    CGFloat  { return type.isBigMap ? 1.0 : kSmallMapReduction }
	override var    description :     String  { return widgetZone?.description ?? kEmptyIdea }

	var type : ZWidgetType {
		var result    = widgetZone?.widgetType

		if  result   == nil {
			result    = .tBigMap
		}

		if  let oType = widgetObject.type {
			result?.insert(oType)
		}

		return result!
	}

	var controller: ZMapController? {
		if type.isBigMap   { return      gMapController }
		if type.isRecent   { return gSmallMapController }
		if type.isFavorite { return gSmallMapController }

		return nil
	}

	var widgetZone : Zone? {
		get { return widgetObject.zone }
		set {
			widgetObject          .zone = newValue
			if  let                name = widgetZone?.zoneName {
				identifier              = NSUserInterfaceItemIdentifier("<z> \(name)")
				childrenView.identifier = NSUserInterfaceItemIdentifier("<c> \(name)")
				textWidget  .identifier = NSUserInterfaceItemIdentifier("<t> \(name)")
				revealDot   .identifier = NSUserInterfaceItemIdentifier("<r> \(name)")
				dragDot     .identifier = NSUserInterfaceItemIdentifier("<d> \(name)")
			}
		}
	}

    deinit {
        childrenWidgets.removeAll()
		removeAllSubviews()
    }

    // MARK:- layout
    // MARK:-

	func layoutInView(_ inView: ZView?, for mapType: ZWidgetType, atIndex: Int?, recursing: Bool, _ kind: ZSignalKind, visited: ZoneArray) -> Int {
		var count = 1

		if  let thisView = inView,
            !thisView.subviews.contains(self) {
            thisView.addSubview(self)
        }

        #if os(iOS)
            backgroundColor = kClearColor
        #endif

		gStartupController?.fullStartupUpdate()
		gWidgets.setWidgetForZone(self, for: mapType)
        addTextView()
		addDots()
        textWidget.layoutText()
        layoutDots()

		if  let zone = widgetZone {
			addChildrenView()
			prepareChildrenWidgets()

			if  recursing && !visited.contains(zone), zone.isExpanded, zone.count > 0 {
				count += layoutChildren(kind, mapType: mapType, visited: visited + [zone])
			}
		}

		return count
    }

    func layoutChildren(_ kind: ZSignalKind, mapType: ZWidgetType, visited: ZoneArray) -> Int {
		var count = 0

        if  let  zone = widgetZone, zone.isExpanded {
            var index = childrenWidgets.count
            var previous: ZoneWidget?

            while index > 0 {
                index                 -= 1 // go backwards down the children arrays, bottom and top constraints expect it
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone =            zone[index]

				count += childWidget.layoutInView(childrenView, for: mapType, atIndex: index, recursing: true, kind, visited: visited)
				childWidget.snp.setLabel("<p> \(childWidget.widgetZone?.zoneName ?? kUnknown)")
                childWidget.snp.removeConstraints()
                childWidget.snp.makeConstraints { make in
                    if  previous == nil {
                        make.bottom.equalTo(childrenView)
                    } else {
                        make.bottom.equalTo(previous!.snp.top)
                    }

                    if  index == 0 {
                        make.top.equalTo(childrenView).priority(ConstraintPriority(250))
                    }

                    make.left.right.equalTo(childrenView)
                }

                previous = childWidget
            }
        }

		return count
    }

	func addDots() {
		let hideDragDot = widgetZone?.onlyShowRevealDot ?? false

		if !hideDragDot,
		   !subviews.contains(dragDot) {
			insertSubview(dragDot, belowSubview: textWidget)
		}

		if !subviews.contains(revealDot) {
			insertSubview(revealDot, belowSubview: textWidget)
		}
	}

    func layoutDots() {
		let hideDragDot = widgetZone?.onlyShowRevealDot ?? false
		let verticalDotOffset = 0.5

		if !hideDragDot {
			dragDot.innerDot?.snp.removeConstraints()
			dragDot.innerDot?.snp.setLabel("<d> \(widgetZone?.zoneName ?? kUnknown)")
			dragDot.setupForWidget(self, asReveal: false)
			dragDot.innerDot?.snp.makeConstraints { make in
				make.right.equalTo(textWidget.snp.left).offset(-6.0)
				make.centerY.equalTo(textWidget).offset(verticalDotOffset)
			}
		}

		revealDot.innerDot?.snp.setLabel("<r> \(widgetZone?.zoneName ?? kUnknown)")
        revealDot.innerDot?.snp.removeConstraints()
        revealDot.setupForWidget(self, asReveal: true)
        revealDot.innerDot?.snp.makeConstraints { make in
            make.left.equalTo(textWidget.snp.right).offset(6.0)
            make.centerY.equalTo(textWidget).offset(verticalDotOffset)
        }
    }

	@discardableResult func updateFrame() -> CGRect {
		var     childrenSize : CGSize?
		var biggestChildSize = CGSize.zero
		var    childrenWidth = CGFloat.zero

		for child in childrenWidgets {			// traverse progeny, updating their frames
			let childSize = child.updateFrame().size

			if  childSize.width  > biggestChildSize.width {
				biggestChildSize = childSize
			}
		}

		if  let     zone = widgetZone, zone.isExpanded {
			let   height = biggestChildSize.height * CGFloat(childrenWidgets.count)
			childrenSize = CGSize(width: biggestChildSize.width, height: height)
		}

		// text view
		let textSize = textWidget.drawnSize
		let   offset = gGenericOffset.add(width: 4.0, height: 0.5) // why?
		let        x = offset.width  * ratio
		var        y = offset.height * ratio

		if  let      size = childrenSize {
			childrenWidth =  size.width
			y             = (size.height - textSize.height) / 2.0
		}

		// reveal dot x == textwidget.frame.maxX
		// inner dot height == width ==                   14
		// reveal dot width is related to generic offset: 25.5
		// dot height       is related to generic offset: 25
		// drag dot x value is:                           12
		// drag dot widths are both 3.5 smaller:          22   and 10.5 (outer and inner)
		// dots y values are:                             -0.5 and  5.5 "
		// inner dots x values are:                        6   and  5.5 (reveal and drag)

		let   textOrigin = CGPoint(x: x, y: y)
		textWidget         .frame = CGRect(origin: textOrigin, size: textSize)
		dragDot            .frame = CGRect(x:  11.5, y: -0.5, width: 22.0, height: 24.5) // why?
		dragDot  .innerDot?.frame = CGRect(x:   6.0, y:  5.5, width: 10.5, height: 13.5) // why?
		revealDot          .frame = CGRect(x: 109.0, y: -0.5, width: 25.5, height: 24.5) // why?
		revealDot.innerDot?.frame = CGRect(x:   5.5, y:  5.5, width: 14.0, height: 13.5) // why?
		childrenView       .frame = CGRect(x: 280.5, y:  0.0, width: 16.5, height: 25.0) // why?

		// use all but children's view to compute frame

		return CGRect.zero
	}

    // MARK:- view hierarchy
    // MARK:-

    func addTextView() {
        if !subviews.contains(textWidget) {
            textWidget.widget = self

            addSubview(textWidget)
        }

        textWidget.setup()
    }

    func addChildrenView() {
        if !subviews.contains(childrenView) {
            insertSubview(childrenView, belowSubview: textWidget)
        }

		childrenView.snp.setLabel("<c> \(widgetZone?.zoneName ?? kUnknown)")
        childrenView.snp.removeConstraints()
        childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            let ratio = type.isBigMap ? 1.0 : kSmallMapReduction / 3.0

            make.left.equalTo(textWidget.snp.right).offset(gChildrenViewOffset * Double(ratio))
            make.bottom.top.right.equalTo(self)
        }
    }

    func prepareChildrenWidgets() {
        if  let zone = widgetZone {

            if !zone.isExpanded {
                childrenWidgets.removeAll()

                for view in childrenView.subviews {
                    view.removeFromSuperview()
                }
            } else {
                var count = zone.count

                if  count > 60 {
                    count = 60
                }

                while childrenWidgets.count < count {
                    childrenWidgets.append(ZoneWidget())
                }

                while childrenWidgets.count > count {
                    let widget = childrenWidgets.removeLast()

                    widget.removeFromSuperview()
                }
            }
        }
    }

    // MARK:- drag
    // MARK:-

    var hitRect: CGRect? {
        if  let  start =   dragDot.innerOrigin,
			let extent = revealDot.innerExtent {
            return CGRect(start: convert(start, from: dragDot), extent: convert(extent, from: revealDot))
        }

        return nil
    }

    var outerHitRect: CGRect {
		return CGRect(start: dragDot.convert(.zero, to: self), extent: revealDot.convert(revealDot.bounds.extent, to: self))
    }

    var floatingDropDotRect: CGRect {
        var rect = CGRect()

        if  let zone = widgetZone {
            if !zone.isExpanded || zone.count == 0 {

                // //////////////////////
                // DOT IS STRAIGHT OUT //
                // //////////////////////

                if  let            dot = revealDot.innerDot {
                    let         insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
                    rect               = dot.convert(dot.bounds, to: self).insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
                }
            } else if let      indices = gDropIndices, indices.count > 0 {
                let         firstindex = indices.firstIndex

                if  let       firstDot = dot(at: firstindex) {
                    rect               = firstDot.convert(firstDot.bounds, to: self)
                    let      lastIndex = indices.lastIndex

                    if  indices.count == 1 || lastIndex >= zone.count {

                        // ////////////////////////
                        // DOT IS ABOVE OR BELOW //
                        // ////////////////////////

                        let   relation = gDragRelation
                        let    isAbove = relation == .above || (!gListsGrowDown && (lastIndex == 0 || relation == .upon))
                        let multiplier = (isAbove ? 1.0 : -1.0) * gVerticalWeight
                        let    gHeight = Double(gGenericOffset.height)
                        let      delta = (gHeight + gDotWidth) * multiplier
                        rect           = rect.offsetBy(dx: 0.0, dy: CGFloat(delta))

                    } else if lastIndex < zone.count, let secondDot = dot(at: lastIndex) {

                        // ///////////////
                        // DOT IS TWEEN //
                        // ///////////////

                        let secondRect = secondDot.convert(secondDot.bounds, to: self)
                        let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
                        rect           = rect.offsetBy(dx: 0.0, dy: -delta)
                    }
                }
            }
        }

        return rect
    }

    func lineKind(for delta: Double) -> ZLineKind {
        let threshold = 2.0   * gVerticalWeight
        let  adjusted = delta * gVerticalWeight
        
        if adjusted > threshold {
            return .above
        } else if adjusted < -threshold {
            return .below
        }
        
        return .straight
    }

    func dot(at iIndex: Int) -> ZoneDot? {
        if  let zone = widgetZone {
            if  zone.count == 0 || iIndex < 0 {
                return nil
            }

            let  index = min(iIndex, zone.count - 1)
            let target = zone.children[index]

            return target.widget?.dragDot.innerDot
        } else {
            return nil
        }
    }

	func dragHitRect(in view: ZView, _ here: Zone) -> CGRect {
		let widget = textWidget
		let isHere = widgetZone == here
		let cFrame =        convert(childrenView.frame, to: view)
		let tFrame = widget.convert(     widget.bounds, to: view)
		let   left =    isHere ? 0.0                                  : tFrame.minX - (gGenericOffset.width * 0.8)
		let bottom =  (!isHere && widgetZone?.hasZonesBelow ?? false) ? cFrame.minY : 0.0
		let    top = ((!isHere && widgetZone?.hasZonesAbove ?? false) ? cFrame      : view.bounds).maxY
		let  right =                                                                  view.bounds .maxX

		return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
	}

    func widgetNearestTo(_ point: CGPoint, in iView: ZView?, _ iHere: Zone?, _ visited: [ZoneWidget] = []) -> ZoneWidget? {
		if  !visited.contains(self),
			let view = iView,
			let here = iHere,
			dragHitRect(in: view, here).contains(point) {

			for child in childrenWidgets {
				if  self        != child,
					let    found = child.widgetNearestTo(point, in: view, here, visited + [self]) { // recurse into child
					return found
				}
			}

			return self
		}

        return nil
    }

    func displayForDrag() {
        revealDot.innerDot?        .setNeedsDisplay()
        parentWidget?              .setNeedsDisplay() // sibling lines
        self                       .setNeedsDisplay() // children lines

        for child in childrenWidgets {
            child.dragDot.innerDot?.setNeedsDisplay()
            child                  .setNeedsDisplay() // grandchildren lines
        }
    }

    // MARK:- child lines
    // MARK:-

    func lineKind(to dragRect: CGRect) -> ZLineKind? {
        var kind: ZLineKind?
        if  let    toggleDot = revealDot.innerDot {
            let   toggleRect = toggleDot.convert(toggleDot.bounds,  to: self)
            let        delta = Double(dragRect.midY - toggleRect.midY)
            kind             = lineKind(for: delta)
        }

        return kind
    }

    func lineKind(to widget: ZoneWidget?) -> ZLineKind {
        var kind:    ZLineKind = .straight

        if  let           zone = widgetZone,
            zone        .count > 1,
            let        dragDot = widget?.dragDot.innerDot {
            let       dragRect = dragDot.convert(dragDot.bounds, to: self)
            if  let   dragKind = lineKind(to: dragRect) {
                kind           = dragKind
            }
        }

        return kind
    }

    func lineRect(to dragRect: CGRect, in iView: ZView) -> CGRect? {
        var rect: CGRect?

        if  let kind = lineKind(to: dragRect) {
            rect     = lineRect(to: dragRect, kind: kind)
            rect     = convert (rect!,          to: iView)
        }

        return rect
    }

    func lineRect(to widget: ZoneWidget?) -> CGRect {
        let  hasIndent = widget?.widgetZone?.isCurrentFavorite ?? false
        let      inset = CGFloat(hasIndent ? -5.0 : 0.0)
        var      frame = CGRect ()
        if  let    dot = widget?.dragDot.innerDot {
            let dFrame = dot.bounds.insetBy(dx: inset, dy: 0.0)
            let   kind = lineKind(to: widget)
            frame      = dot.convert(dFrame, to: self)
            frame      = lineRect(to: frame, kind: kind)
        }

        return frame
    }

    func straightPath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
        if  !isDragLine,
            let   zone = widgetZone,
            zone.count > 1 {
            ZBezierPath(rect: bounds).setClip()
        }

        let path = ZBezierPath()

        path.move(to: CGPoint(x: iRect.minX, y: iRect.midY))
        path.line(to: CGPoint(x: iRect.maxX, y: iRect.midY))

        return path
    }

    func linePath(in iRect: CGRect, kind: ZLineKind?, isDragLine: Bool) -> ZBezierPath {
        if  let    k = kind {
            switch k {
            case .straight: return straightPath(in: iRect, isDragLine)
            default:        return   curvedPath(in: iRect, kind: k)
            }
        }

        return ZBezierPath()
    }

	// MARK:- draw
	// MARK:-

    func line(on path: ZBezierPath?) {
        if  path != nil {
            path!.lineWidth = CGFloat(gLineThickness)

            path!.stroke()
        }
    }

	func drawSelectionHighlight(_ dashes: Bool, _ thin: Bool) {
        let            gap = gGenericOffset.height
        let       gapInset =  gap         /  8.0
		let     widthInset = (gap + 32.0) / -2.0
        let    widthExpand = (gap + 24.0) /  6.0
		let innerRevealDot = revealDot.innerDot
        let revealDotDelta = innerRevealDot?.isVisible ?? false ? CGFloat(0.0) : innerRevealDot!.bounds.size.width + 3.0      // expand around reveal dot, only if it is visible
		var           rect = textWidget.frame.insetBy(dx: (widthInset - gapInset - 2.0) * ratio, dy: -gapInset)               // get size from text widget
		rect.size .height += (gHighlightHeightOffset + 2.0) / ratio
        rect.size  .width += (widthExpand - revealDotDelta) / ratio
		rect               = rect.offsetBy(dx: -1.0, dy: 0.0)
        let         radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
        let          color = widgetZone?.color
        let      fillColor = color?.withAlphaComponent(0.01)
        let    strokeColor = color?.withAlphaComponent(0.30)
        let           path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
        path    .lineWidth = CGFloat(gDotWidth) / 3.5
        path     .flatness = 0.0001

        if  dashes || thin {
            path.addDashes()

			if thin {
				path.lineWidth = CGFloat(1.5)
			}
		}

        strokeColor?.setStroke()
        fillColor?  .setFill()
        path.stroke()
        path.fill()
    }

    func drawDragLine(to dotRect: CGRect, in iView: ZView) {
        if  let rect = lineRect(to: dotRect, in:iView),
            let kind = lineKind(to: dotRect) {
            let path = linePath(in: rect, kind: kind, isDragLine: true)

            line(on: path)
        }
    }

    func drawLine(to child: ZoneWidget) {
        if  let  zone = child.widgetZone {
            let color = zone.color
            let  rect = lineRect(to: child)
            let  kind = lineKind(to: child)
            let  path = linePath(in: rect, kind: kind, isDragLine: false)

            color?.setStroke()
            line(on: path)
        }
    }

    // lines need CHILD dots drawn first.
    // extra pass through hierarchy to do lines

    var nowDrawLines = false

    override func draw(_ iDirtyRect: CGRect) {
        super.draw(iDirtyRect)

		if (gIsMapOrEditIdeaMode || !type.isBigMap),
			let       zone = widgetZone {
            let  isGrabbed = zone.isGrabbed
            let  isEditing = textWidget.isFirstResponder
			let isHovering = textWidget.isHovering
			let   expanded = zone.isExpanded

			if !nowDrawLines {
				nowDrawLines = true

				if  gDebugDraw {
					drawColoredRect(iDirtyRect, .purple)
				}

				textWidget.updateTextColor()

				if  (isGrabbed || isEditing || isHovering) && !gIsPrinting {
					drawSelectionHighlight(isEditing, isHovering && !isGrabbed)
				}

				if    expanded {
					draw(iDirtyRect)             // recurse
				}
			} else if expanded {
				for child in childrenWidgets {   // this is after child dots have been autolayed out
					drawLine(to: child)
                }
            }

            nowDrawLines = false
        }
    }

}
