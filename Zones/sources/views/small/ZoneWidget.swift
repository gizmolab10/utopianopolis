//
//  ZoneWidget.swift
//  Thoughtful
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


class ZoneWidget: ZView {


    let                 dragDot = ZoneDot        ()
    let               revealDot = ZoneDot        ()
    let              textWidget = ZoneTextWidget ()
    let            childrenView = ZView          ()
    private var childrenWidgets = [ZoneWidget]   ()
    var              isInPublic = false
    var              widgetZone :       Zone?
    var            parentWidget : ZoneWidget? { return widgetZone?.parentZone?.widget }
    var                   ratio :     CGFloat { return isInPublic ? 1.0 : kFavoritesReduction }

    deinit {
        childrenWidgets.removeAll()

        widgetZone = nil
    }


    // MARK:- layout
    // MARK:-


    func layoutInView(_ iView: ZView?, atIndex: Int?, recursing: Bool, _ iKind: ZSignalKind, isThought: Bool, visited: ZoneArray) {
//		gWindow?.protectViews([self])
		
        if  let inView = iView,
            inView.window != window {
            inView.addSubview(self)
        }

        isInPublic = isThought

        #if os(iOS)
            backgroundColor = kClearColor
        #endif

        addTextView()
        textWidget.layoutText()
        layoutDots()
        addChildrenView()

        if  recursing && (widgetZone == nil || !visited.contains(widgetZone!)) {
            let more = widgetZone == nil ? [] : [widgetZone!]

            prepareChildrenWidgets()
            layoutChildren(iKind, visited: visited + more)
        }
    }


    func layoutChildren(_ iKind: ZSignalKind, visited: ZoneArray) {
        if  let  zone = widgetZone, zone.showingChildren {
            var index = childrenWidgets.count
            var previous: ZoneWidget?

            while index > 0 {
                index          -= 1 // go backwards down the children arrays, bottom and top constraints expect it
                let childWidget = childrenWidgets[index]

                childWidget.layoutInView(childrenView, atIndex: index, recursing: true, iKind, isThought: isInPublic, visited: visited)

				if  childWidget.window != nil, childrenView.window != nil {
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
			dragDot.setupForWidget(self, asReveal: false)
			dragDot.innerDot?.snp.makeConstraints { make in
				make.right.equalTo(textWidget.snp.left).offset(-4.0)
				make.centerY.equalTo(textWidget).offset(1.5)
			}
		}

        if !subviews.contains(revealDot) {
            insertSubview(revealDot, belowSubview: textWidget)
        }

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

        childrenView.snp.removeConstraints()
        childrenView.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            let ratio = isInPublic ? 1.0 : kFavoritesReduction / 3.0

            make.left.equalTo(textWidget.snp.right).offset(gChildrenViewOffset * Double(ratio))
            make.bottom.top.right.equalTo(self)
        }
    }


    func prepareChildrenWidgets() {
        if  let zone = widgetZone {
			childrenWidgets.removeAll()
			childrenView.removeAllSubviews()

            if  zone.showingChildren {
                var count = zone.count

                if  count > 60 {
                    count = 60
                }

				for index in 0 ..< count {
					let      child = zone.children[index]
					if  let widget = child.widget {
						childrenWidgets.append(widget)
					}
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
        return CGRect(start: dragDot.convert(dragDot.bounds.origin, to: self), end: revealDot.convert(revealDot.bounds.extent, to: self))
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


    func widgetNearestTo(_ iPoint: CGPoint, in iView: ZView?, _ iHere: Zone?, _ visited: ZoneArray = []) -> ZoneWidget? {
        if  let    here = iHere,
            let    zone = widgetZone,
            !visited.contains(zone),
            (zone == gDraggedZone || !zone.spawnedBy(gDraggedZone)),
            dragHitFrame(in: iView, here).contains(iPoint) {

            if zone.showingChildren {
                for child in zone.children {
					if  let   widget = child.widget,
						self        != widget,
                        let    found = widget.widgetNearestTo(iPoint, in: iView, here, visited + [zone]) {
                        return found
                    }
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


    func drawSelectionHighlight(_ showAsDashes: Bool) {
        let      thickness = CGFloat(gDotWidth) / 3.5
        let       rightDot = revealDot.innerDot
        let         height = gGenericOffset.height
        let          delta =  height / 8.0
        let          inset = (height / -2.0) - 16.0
        let         shrink =  3.0 + (height / 6.0)
        let hiddenDotDelta = rightDot?.revealDotIsVisible ?? false ? CGFloat(0.0) : rightDot!.bounds.size.width + 3.0   // expand around reveal dot, only if it is visible
        var           rect = textWidget.frame.insetBy(dx: (inset * ratio) - delta, dy: -0.5 - delta).offsetBy(dx: -0.75, dy: 0.5)  // get size from text widget
        rect.size .height += -0.5 + gHighlightHeightOffset + (isInPublic ? 0.0 : 1.0)
        rect.size  .width += shrink - hiddenDotDelta
        let         radius = min(rect.size.height, rect.size.width) / 2.08 - 1.0
        let     colorRatio = CGFloat(showAsDashes ? 0.5 : 1.0)
        let          color = widgetZone?.color
        let      fillColor = color?.withAlphaComponent(colorRatio * 0.02)
        let    strokeColor = color?.withAlphaComponent(colorRatio * 0.30)
        let           path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
        path    .lineWidth = thickness
        path     .flatness = 0.0001

        if  showAsDashes {
            let pattern: [CGFloat] = [4.0, 4.0]
            path.setLineDash(pattern, count: 2, phase: 4.0)
        }

//		printDebug(.edit, "[highlight]")
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

		if  gIsGraphOrEditIdeaMode,
			let             zone = widgetZone {
            let        isGrabbed = zone.isGrabbed
			let        isEditing = textWidget == gCurrentlyEditingWidget
            textWidget.textColor = isGrabbed ? zone.grabbedTextColor : gDefaultTextColor

            if  gMathewStyleUI,
                let color = zone.color?.cgColor {
                addBorder(thickness: CGFloat(gLineThickness), radius: CGFloat(50.0) / CGFloat(zone.level + 1), color: color)
            }

			if  (isGrabbed || isEditing) && !gIsPrinting {
                drawSelectionHighlight(isEditing)
            }

            if  zone.showingChildren {
                if !nowDrawLines && !gIsDragging && gDragView?.rubberbandRect == nil {
                    nowDrawLines = true
                    
                    draw(dirtyRect)
                } else if !gMathewStyleUI {
                    for child in childrenWidgets {
                        drawLine(to: child)
                    }
                }
            }

            nowDrawLines = false
        }
    }
}
