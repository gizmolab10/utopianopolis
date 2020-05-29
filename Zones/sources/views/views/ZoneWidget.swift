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

	static let     tIdea = ZWidgetType()
	static let     tMain = ZWidgetType()
	static let   tRecent = ZWidgetType()
	static let tFavorite = ZWidgetType()
	static let    tEssay = ZWidgetType()
	static let     tNote = ZWidgetType()

	var isMain:     Bool { return contains(.tMain) }
	var isRecent:   Bool { return contains(.tRecent) }
	var isFavorite: Bool { return contains(.tFavorite) }

	var description: String {
		return [(.tIdea,     "    idea"),
				(.tMain,     "    main"),
				(.tNote,     "    note"),
				(.tEssay,    "   essay"),
				(.tRecent,   "  recent"),
				(.tFavorite, "favorite")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: ", ")
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
	var                   ratio :    CGFloat  { return type.isMain ? 1.0 : kFavoritesReduction }
	override var    description :     String  { return widgetZone?.description ?? kEmptyIdea }

	var type : ZWidgetType {
		var result    = widgetZone? .type

		if  result   == nil {
			result    = .tMain
		}

		if  let oType = widgetObject.type {
			result?.insert(oType)
		}

		return result!
	}

	var controller: ZGraphController? {
		if type.isMain     { return     gGraphController }
		if type.isRecent   { return   gRecentsController }
		if type.isFavorite { return gFavoritesController }

		return nil
	}

	var widgetZone : Zone? {
		get { return widgetObject.zone }
		set {
			widgetObject          .zone = newValue
			if  let                name = widgetZone?.zoneName {
				identifier              = NSUserInterfaceItemIdentifier("<w> \(name)") // gosh. i wish these would help with snap kit errors !!!!!!!!!!!
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

	func layoutInView(_ inView: ZView?, atIndex: Int?, recursing: Bool, _ iKind: ZSignalKind, visited: ZoneArray) {
        if  let thisView = inView,
            !thisView.subviews.contains(self) {
            thisView.addSubview(self)
        }

        #if os(iOS)
            backgroundColor = kClearColor
        #endif

		gWidgets.registerWidget(self, for: type)
        addTextView()
        textWidget.layoutText()
        layoutDots()
        addChildrenView()

        if  recursing && (widgetZone == nil || !visited.contains(widgetZone!)) {
            let    more = widgetZone == nil ? [] : [widgetZone!]

            prepareChildrenWidgets()
            layoutChildren(iKind, visited: visited + more)
        }
    }

    func layoutChildren(_ iKind: ZSignalKind, visited: ZoneArray) {
        if  let  zone = widgetZone, zone.showingChildren {
            var index = childrenWidgets.count
            var previous: ZoneWidget?

            while index > 0 {
                index                 -= 1 // go backwards down the children arrays, bottom and top constraints expect it
                let childWidget        = childrenWidgets[index]
                childWidget.widgetZone =            zone[index]

				childWidget.layoutInView(childrenView, atIndex: index, recursing: true, iKind, visited: visited)
				childWidget.snp.setLabel("<w> \(childWidget.widgetZone?.zoneName ?? "unknown")")
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

                    make.left.equalTo(childrenView)
                    make.right.equalTo(childrenView)
                }

                previous = childWidget
            }
        }
    }

    func layoutDots() {
		let hideDragDot = widgetZone?.onlyShowRevealDot ?? true

		if !hideDragDot {
			if !subviews.contains(dragDot) {
				insertSubview(dragDot, belowSubview: textWidget)
			}
			
			dragDot.innerDot?.snp.removeConstraints()
			dragDot.innerDot?.snp.setLabel("<d> \(widgetZone?.zoneName ?? "unknown")")
			dragDot.setupForWidget(self, asReveal: false)
			dragDot.innerDot?.snp.makeConstraints { make in
				make.right.equalTo(textWidget.snp.left).offset(-4.0)
				make.centerY.equalTo(textWidget).offset(1.5)
			}
		}

        if !subviews.contains(revealDot) {
            insertSubview(revealDot, belowSubview: textWidget)
        }

		revealDot.innerDot?.snp.setLabel("<r> \(widgetZone?.zoneName ?? "unknown")")
        revealDot.innerDot?.snp.removeConstraints()
        revealDot.setupForWidget(self, asReveal: true)
        revealDot.innerDot?.snp.makeConstraints { make in
            make.left.equalTo(textWidget.snp.right).offset(3.0)
            make.centerY.equalTo(textWidget).offset(1.5)
        }
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

		childrenView.snp.setLabel("<c> \(widgetZone?.zoneName ?? "unknown")")
        childrenView.snp.removeConstraints()
        childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            let ratio = type.isMain ? 1.0 : kFavoritesReduction / 3.0

            make.left.equalTo(textWidget.snp.right).offset(gChildrenViewOffset * Double(ratio))
            make.bottom.top.right.equalTo(self)
        }
    }

    func prepareChildrenWidgets() {
        if  let zone = widgetZone {

            if !zone.showingChildren {
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
        if  let start = dragDot.innerOrigin, let end = revealDot.innerExtent {
            return CGRect(start: dragDot.convert(start, to: self), end: revealDot.convert(end, to: self))
        }

        return nil
    }

    var outerHitRect: CGRect {
		return CGRect(start: dragDot.convert(CGPoint.zero, to: self), end: revealDot.convert(revealDot.bounds.extent, to: self))
    }

    var floatingDropDotRect: CGRect {
        var rect = CGRect()

        if  let zone = widgetZone {
            if !zone.showingChildren || zone.count == 0 {

                // //////////////////////
                // DOT IS STRAIGHT OUT //
                // //////////////////////

                if  let        dot = revealDot.innerDot {
                    let     insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
                    rect           = dot.convert(dot.bounds, to: self).insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
                }
            } else if let      indices = gDragDropIndices, indices.count > 0 {
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
            if zone.count == 0 || iIndex < 0 {
                return nil
            }

            let  index = min(iIndex, zone.count - 1)
            let target = zone.children[index]

            return target.widget?.dragDot.innerDot
        } else {
            return nil
        }
    }

    func widgetNearestTo(_ iPoint: CGPoint, in iView: ZView?, _ iHere: Zone?, _ visited: [ZoneWidget] = []) -> ZoneWidget? {
        if  let    here = iHere,
            !visited.contains(self),
            dragHitFrame(in: iView, here).contains(iPoint) {

			for child in childrenWidgets {
				if  self        != child,
					let    found = child.widgetNearestTo(iPoint, in: iView, here, visited + [self]) {
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

    func isDropIndex(_ iIndex: Int?) -> Bool {
        if  iIndex != nil {
            let isIndex = gDragDropIndices?.contains(iIndex!)
            let  isDrop = widgetZone == gDragDropZone

            if isDrop && isIndex! {
                return true
            }
        }

        return false
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

    func linePath(in iRect: CGRect, kind iKind: ZLineKind?, isDragLine: Bool) -> ZBezierPath {
        if iKind != nil {
            switch iKind! {
            case .straight: return straightPath(in: iRect, isDragLine)
            default:        return   curvedPath(in: iRect, kind: iKind!)
            }
        }

        return ZBezierPath()
    }

    func line(on path: ZBezierPath?) {
        if  path != nil {
            path!.lineWidth = CGFloat(gLineThickness)

            path!.stroke()
        }
    }

    // MARK:- draw
    // MARK:-

    func drawSelectionHighlight(_ pale: Bool) {
        let      thickness = CGFloat(gDotWidth) / 3.5
        let       rightDot = revealDot.innerDot
        let         height = gGenericOffset.height
        let          delta = height / 8.0
        let          inset = (height / -2.0) - 16.0
        let         shrink =  3.0 + (height / 6.0)
        let hiddenDotDelta = rightDot?.revealDotIsVisible ?? false ? CGFloat(0.0) : rightDot!.bounds.size.width + 3.0   // expand around reveal dot, only if it is visible
        var           rect = textWidget.frame.insetBy(dx: (inset * ratio) - delta, dy: -0.5 - delta).offsetBy(dx: -0.75, dy: 0.5)  // get size from text widget
        rect.size .height += -0.5 + gHighlightHeightOffset + (type.isMain ? 0.0 : 1.0)
        rect.size  .width += shrink - hiddenDotDelta
        let         radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
        let     colorRatio = CGFloat(pale ? 0.5 : 1.0)
        let          color = widgetZone?.color
        let      fillColor = color?.withAlphaComponent(colorRatio * 0.02)
        let    strokeColor = color?.withAlphaComponent(colorRatio * 0.60)
        let           path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
        path    .lineWidth = thickness
        path     .flatness = 0.0001
		var          debug = "[UNDASH] "

        if  pale {
            path.addDashes()
			debug = "[DASH]   "
        }
        
		printDebug(.dEdit, debug + (widgetZone?.unwrappedName ?? ""))
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

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

		if (gIsGraphOrEditIdeaMode || !type.isMain),
			let      zone = widgetZone {
            let isGrabbed = zone.isGrabbed
            let isEditing = textWidget.isFirstResponder

			textWidget.updateTextColor()

			if  (isGrabbed || isEditing) && !gIsPrinting {
                drawSelectionHighlight(isEditing)
            }

            if  zone.showingChildren {
				if !nowDrawLines && !gIsDragging && !gRubberband.showRubberband {
                    nowDrawLines = true
                    
                    draw(dirtyRect) // recurse
                } else {
                    for child in childrenWidgets { // this is after child dots have been autolayed out
                        drawLine(to: child)
                    }
                }
            }

            nowDrawLines = false
        }
    }

}
