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

class ZoneWidget: ZPseudoView {

	let            widgetObject = ZWidgetObject  ()
	private var childrenWidgets = ZoneWidgetArray()
	var          highlightFrame = CGRect.zero
	var                 dragDot : ZoneDot?
	var               revealDot : ZoneDot?
	var            childrenView : ZPseudoView?
	var        pseudoTextWidget : ZPseudoTextView?
	var              textWidget : ZoneTextWidget? { return pseudoTextWidget?.actualTextWidget }
	var               sizeToFit :         CGSize  { return drawnSize + CGSize(frame.origin) }
	var            parentWidget :     ZoneWidget? { return widgetZone?.parentZone?.widget }
	var      hasVisibleChildren :           Bool  { return widgetZone?.hasVisibleChildren ?? false }
	var             hideDragDot :           Bool  { return widgetZone?.onlyShowRevealDot ?? false }
	var                isBigMap :           Bool  { return controller?.isBigMap ?? true }
	var                   ratio :        CGFloat  { return type.isBigMap ? 1.0 : kSmallMapReduction }
	override var    description :         String  { return widgetZone?.description ?? kEmptyIdea }

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
			widgetObject           .zone = newValue
			if  let                 name = widgetZone?.zoneName {
				identifier               = NSUserInterfaceItemIdentifier("<z> \(name)")
				childrenView?.identifier = NSUserInterfaceItemIdentifier("<c> \(name)")
				revealDot?   .identifier = NSUserInterfaceItemIdentifier("<r> \(name)")
				dragDot?     .identifier = NSUserInterfaceItemIdentifier("<d> \(name)")
				textWidget?  .identifier = NSUserInterfaceItemIdentifier("<t> \(name)")
			}
		}
	}

    deinit {
        childrenWidgets.removeAll()
    }

	// MARK:- view hierarchy
	// MARK:-

	@discardableResult func layoutAllPseudoViews(inPseudoView: ZPseudoView?, for mapType: ZWidgetType, atIndex: Int?, recursing: Bool, _ kind: ZSignalKind, visited: ZoneArray) -> Int {
		var count = 1

		if  let v = inPseudoView,
		   !v.subpseudoviews.contains(self) {
			v.addSubpseudoview(self)
		}

		#if os(iOS)
		backgroundColor = kClearColor
		#endif

		gStartupController?.fullStartupUpdate()
		gWidgets.setWidgetForZone(self, for: mapType)
		addTextView()
		addDots()

		if  let zone = widgetZone {
			addChildrenView()
			addChildrenWidgets()

			if  recursing && !visited.contains(zone), zone.hasVisibleChildren {
				var index = childrenWidgets.count
				let vplus = visited + [zone]

				while index           > 0 {
					index            -= 1 // go backwards down the children arrays, bottom and top constraints expect it
					let child         = childrenWidgets[index]
					child.widgetZone  =            zone[index]
					count            += child.layoutAllPseudoViews(inPseudoView: childrenView, for: mapType, atIndex: index, recursing: true, kind, visited: vplus)
				}
			}
		}

		textWidget?.layoutText()
		updateSize()

		return count
	}

	func addTextView() {
		if  pseudoTextWidget == nil {
			pseudoTextWidget  = ZPseudoTextView(view: absoluteView)
		}

		if  let         t = textWidget {
			if  t.widget == nil {
				t.widget  = self

				controller?.mapView?.addSubview(t)
				addSubpseudoview(pseudoTextWidget)
			}

			if  t.superview == nil {
				controller?.mapView?.addSubview(t)
			}

			t.setup()
		}
	}

	func addDots() {
		if  !hideDragDot,
		    dragDot == nil {
			dragDot  = ZoneDot(view: absoluteView)

			addSubpseudoview(dragDot)
			dragDot?.setupForWidget(self, asReveal: false)
		}

		if  revealDot == nil {
			revealDot  = ZoneDot(view: absoluteView)

			addSubpseudoview(revealDot)
			revealDot?.setupForWidget(self, asReveal: true)
		}
	}

	func addChildrenView() {
		if  let zone = widgetZone, !zone.hasVisibleChildren {
			childrenView?.removeFromSuperpseudoview()
		} else {
			if  childrenView == nil {
				childrenView  = ZPseudoView(view: absoluteView)
			}

			if  let v = childrenView, !subpseudoviews.contains(v) {
				addSubpseudoview(v)
			}
		}
	}

	func addChildrenWidgets() {
		if  let zone = widgetZone {
			if !zone.isExpanded, let v = childrenView {
				childrenWidgets.removeAll()

				for view in v.subpseudoviews {
					view.removeFromSuperpseudoview()
					if  let w = view as? ZoneWidget,
						let t = w.textWidget {

						t.removeFromSuperview()
					}
				}
			} else {
				var count = zone.count

				if  count > 60 {
					count = 60     // shrink count to what will reasonably fit vertically
				}

				while childrenWidgets.count > count {         // shrink all beyond count
					let widget = childrenWidgets.removeLast()

					widget.removeFromSuperpseudoview()
				}

				while childrenWidgets.count < count {
					childrenWidgets.append(ZoneWidget(view: absoluteView))      // add missing
				}
			}
		}
	}

	func traverseAllProgeny(inReverse: Bool = false, _ block: ZoneWidgetClosure) {
		safeTraverseProgeny(visited: [], inReverse: inReverse) { iWidget -> ZTraverseStatus in
			block(iWidget)

			return .eContinue
		}
	}

	@discardableResult func traverseProgeny(inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		return safeTraverseProgeny(visited: [], inReverse: inReverse, block)
	}

	@discardableResult func safeTraverseProgeny(visited: ZoneWidgetArray, inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		var status  = ZTraverseStatus.eContinue

		if !inReverse {
			status  = block(self)           // first call block on self, then recurse on each child

			if  status == .eStop {
				return status               // halt traversal
			}
		}

		for child in childrenWidgets {
			if  visited.contains(child) {
				break						// do not revisit or traverse further inward
			}

			status = child.safeTraverseProgeny(visited: visited + [self], inReverse: inReverse, block)

			if  status == .eStop {
				break                       // halt traversal
			}
		}

		if  inReverse {
			status  = block(self)
		}

		return status
	}

	// MARK:- compute sizes and frames
	// MARK:-

	func updateChildrenViewDrawnSize() {
		if !hasVisibleChildren {
			childrenView?.drawnSize = CGSize.zero
		} else {
			var         biggestSize = CGSize.zero
			var              height = CGFloat.zero

			for child in childrenWidgets {			// traverse progeny, updating their frames
				let            size = child.drawnSize
				height             += size.height

				if  size.width      > biggestSize.width {
					biggestSize     = size
				}
			}

			childrenView?.drawnSize = CGSize(width: biggestSize.width, height: height)
		}
	}

	func updateFrameSize() {
		setFrameSize(drawnSize)
	}

	func updateSize() {
		updateChildrenViewDrawnSize()

		if  let       t = textWidget,
			let   dSize = revealDot?.drawnSize {
			var   width = childrenView?.drawnSize.width  ?? 0.0
			var  height = childrenView?.drawnSize.height ?? 0.0
			let   extra = width != 0.0 ? 0.0 : gGenericOffset.width / 2.0
			width      += t.drawnSize.width
			let dheight = dSize.height
			let dWidth  = dSize.width * 2.0
			width      += dWidth + extra - (hideDragDot ? 5.0 : 4.0)

			if  height  < dheight {
				height  = dheight
			}

			drawnSize   = CGSize(width: width, height: height)
		}
	}

	func updateHitRect(_ absolute: Bool = false) {
		if  absolute,
			let              t = textWidget,
			let            dot = revealDot {
			let revealDotDelta = dot.isVisible ? CGFloat(0.0) : dot.drawnSize.width - 6.0    // expand around reveal dot, only if it is visible
			let            gap = gGenericOffset.height
			let       gapInset =  gap         /  8.0
			let     widthInset = (gap + 32.0) / -2.0
			let    widthExpand = (gap + 24.0) /  6.0
			var           rect = t.frame.insetBy(dx: (widthInset - gapInset - 2.0) * ratio, dy: -gapInset)               // get size from text widget
			rect.size .height += (kHighlightHeightOffset + 2.0) / ratio
			rect.size  .width += (widthExpand - revealDotDelta) / ratio
			highlightFrame     = rect
		}
	}

	func updateAllFrames(_ absolute: Bool = false) {
		traverseAllProgeny(inReverse: true) { iWidget in
			iWidget.updateSubframes(absolute)
		}
	}

	func updateSubframes(_ absolute: Bool = false) {
		updateChildrenFrames   (absolute)
		updateTextViewFrame    (absolute)
		updateDotFrames        (absolute)
		updateHitRect          (absolute)
		updateChildrenViewFrame(absolute)
	}

	func updateChildrenFrames(_ absolute: Bool = false) {
		if  hasVisibleChildren {
			var    height = CGFloat.zero
			var     index = childrenWidgets.count
			while   index > 0 {
				index    -= 1 // go backwards [up] the children array
				let child = childrenWidgets[index]

				if  absolute {
					child.updateAbsoluteFrame(toController: controller)
				} else {
					let    size = child.drawnSize
					let  origin = CGPoint(x: .zero, y: height)
					height     += size.height
					let    rect = CGRect(origin: origin, size: size)
					child.frame = rect
				}
			}
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
		if  let                 p = pseudoTextWidget {
			if  absolute {
				p.updateAbsoluteFrame(toController: controller)

				textWidget?.frame = p.absoluteFrame
			} else if let       t = textWidget {
				let      textSize = t.drawnSize
				let        offset = gGenericOffset.add(width: 4.0, height: 0.5).multiplyBy(ratio) // why?
				let             y = (drawnSize.height - textSize.height) / 2.0
				let    textOrigin = CGPoint(x: offset.width, y: y)
				p          .frame = CGRect(origin: textOrigin, size: textSize)
			}
		}
	}

	fileprivate func updateDotFrames(_ absolute: Bool) {
		if  absolute,
			let textFrame = textWidget?.frame {

			if !hideDragDot {
				dragDot?.updateFrame(relativeTo: textFrame)
			}

			revealDot?  .updateFrame(relativeTo: textFrame)
		}
	}

	func updateChildrenViewFrame(_ absolute: Bool = false) {
		if  hasVisibleChildren, let c = childrenView {
			if  absolute {
				c.updateAbsoluteFrame(toController: controller)
			} else if let textFrame = pseudoTextWidget?.frame {
				let           ratio = type.isBigMap ? 1.0 : kSmallMapReduction / 3.0
				let               x = textFrame.maxX + (CGFloat(gChildrenViewOffset) * ratio)
				let          origin = CGPoint(x: x, y: CGFloat.zero)
				let   childrenFrame = CGRect(origin: origin, size: c.drawnSize)
				c            .frame = childrenFrame
			}
		}
	}

	// MARK:- hover
	// MARK:-

	func detectHover(at location: CGPoint) -> Bool {
		if  let       d = dragDot,   d.absoluteFrame.contains(location) {
			gHovering.declareHover(d)
		} else if let r = revealDot, r.absoluteFrame.contains(location) {
			gHovering.declareHover(r)
		} else if let t = pseudoTextWidget, t.absoluteFrame.contains(location) {
			gHovering.declareHover(t.actualTextWidget)
		} else {
			return false
		}

		return true
	}

    // MARK:- drag
    // MARK:-

    var absoluteDropDotRect: CGRect {
        var rect = CGRect()

        if  let zone = widgetZone {
            if !zone.hasVisibleChildren {

                // //////////////////////
                // DOT IS STRAIGHT OUT //
                // //////////////////////

				if  let            dot = revealDot {
					let         insetX = CGFloat((gDotHeight - gDotWidth) / 2.0)
					rect               = dot.absoluteActualFrame.insetBy(dx: insetX, dy: 0.0).offsetBy(dx: gGenericOffset.width, dy: 0.0)
				}
            } else if let      indices = gDropIndices, indices.count > 0 {
                let         firstindex = indices.firstIndex

                if  let       firstDot = dot(at: firstindex) {
                    rect               = firstDot.absoluteActualFrame
                    let      lastIndex = indices.lastIndex

                    if  indices.count == 1 || lastIndex >= zone.count {

                        // ////////////////////////
                        // DOT IS ABOVE OR BELOW //
                        // ////////////////////////

                        let   relation = gDragRelation
                        let    isAbove = relation == .above || (!gListsGrowDown && (lastIndex == 0 || relation == .upon))
                        let multiplier = CGFloat(isAbove ? 1.0 : -1.0) * kVerticalWeight
                        let    gHeight = gGenericOffset.height
                        let      delta = (gHeight + gDotWidth) * multiplier
                        rect           = rect.offsetBy(dx: 0.0, dy: delta)

                    } else if lastIndex < zone.count, let secondDot = dot(at: lastIndex) {

                        // ///////////////
                        // DOT IS TWEEN //
                        // ///////////////

                        let secondRect = secondDot.absoluteActualFrame
                        let      delta = (rect.minY - secondRect.minY) / CGFloat(2.0)
                        rect           = rect.offsetBy(dx: 0.0, dy: -delta)
                    }
                }
            }
        }

        return rect
    }

    func lineKind(for delta: CGFloat) -> ZLineKind {
        let threshold = 2.0   * kVerticalWeight
        let  adjusted = delta * kVerticalWeight
        
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

            return target.widget?.dragDot
        } else {
            return nil
        }
    }

	func dragHitRect(in view: ZPseudoView, _ here: Zone) -> CGRect {
		if  here == widgetZone {
			return view.frame
		}

		return absoluteFrame
	}

    func widgetNearestTo(_ point: CGPoint, in iView: ZPseudoView?, _ iHere: Zone?, _ visited: ZoneWidgetArray = []) -> ZoneWidget? {
		if  let view = iView,
			let here = iHere,
			!visited.contains(self),
			dragHitRect(in: view, here).contains(point) {

			for child in childrenWidgets {
				if  self        != child,
					let    found = child.widgetNearestTo(point, in: view, here, visited + [self]) {    // recurse into child
					return found
				}
			}

			return self
		}

        return nil
    }

    // MARK:- child lines
    // MARK:-

    func lineKind(to dragRect: CGRect) -> ZLineKind? {
		let toggleRect = revealDot?.absoluteActualFrame ?? .zero
		let      delta = dragRect.midY - toggleRect.midY

		return lineKind(for: delta)
    }

    func lineKind(to widget: ZoneWidget?) -> ZLineKind {
        var kind:  ZLineKind = .straight
        if  let         zone = widgetZone,
            zone      .count > 1,
            let      dragDot = widget?.dragDot {
			if  let dragKind = lineKind(to: dragDot.absoluteActualFrame) {
                kind         = dragKind
            }
        }

        return kind
    }

    func lineRect(to dragRect: CGRect) -> CGRect? {
        var rect: CGRect?

        if  let kind = lineKind(to: dragRect) {
            rect     = lineRect(to: dragRect, kind: kind)
        }

        return rect
    }

	func lineRect(to widget: ZoneWidget?, kind: ZLineKind) -> CGRect {
        if  let    dot = widget?.dragDot {
			let dFrame = dot.absoluteActualFrame

			return lineRect(to: dFrame, kind: kind)
        }

		return CGRect.zero
    }

    func straightPath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		let rect = iRect.centeredHorizontalLine(thick: CGFloat(gLineThickness))
        let path = ZBezierPath(rect: rect)

		path.setClip()

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

	func drawSelectionHighlight(_ dashes: Bool, _ thin: Bool) {
		let        rect = highlightFrame
        let      radius = rect.minimumDimension / 2.08 - 1.0
        let       color = widgetZone?.color
        let strokeColor = color?.withAlphaComponent(0.30)
        let        path = ZBezierPath(roundedRect: rect, cornerRadius: radius)
        path .lineWidth = CGFloat(gDotWidth) / 3.5
        path  .flatness = 0.0001

        if  dashes || thin {
            path.addDashes()

			if  thin {
				path.lineWidth = CGFloat(1.5)
			}
		}

        strokeColor?.setStroke()
        path.stroke()
    }

    func drawDragLine(to dotRect: CGRect) {
        if  let       rect = lineRect(to: dotRect),
            let       kind = lineKind(to: dotRect) {
            let       path = linePath(in: rect, kind: kind, isDragLine: true)
			path.lineWidth = CGFloat(gLineThickness)

			path.stroke()
        }
    }

    func drawLine(to child: ZoneWidget) {
        if  let       zone = child.widgetZone {
			let      color = zone.color
			let       kind = lineKind(to: child)
			let       rect = lineRect(to: child, kind: kind)
            let       path = linePath(in:  rect, kind: kind, isDragLine: false)
			path.lineWidth = CGFloat(gLineThickness)

            color?.setStroke()
			path.stroke()
        }
    }

    override func draw(_ phase: ZDrawPhase) {
		if (gIsMapOrEditIdeaMode || !type.isBigMap),
			let zone = widgetZone {

			switch phase {
				case .pLines:
					if  zone.isExpanded {
						for child in childrenWidgets {   // this is after child dots have been autolayed out
							drawLine(to: child)
						}
					}
				case .pDotsAndHighlight:
					dragDot?  .draw(phase)
					revealDot?.draw(phase)

					if  let          t = textWidget {
						let  isGrabbed = zone.isGrabbed
						let  isEditing = t.isFirstResponder
						let isHovering = t.isHovering

						if  (isGrabbed || isEditing || isHovering) && !gIsPrinting {
							drawSelectionHighlight(isEditing, isHovering && !isGrabbed)
						}

						if  !isBigMap, gDebugDraw {
							absoluteFrame              .drawColoredRect(.green)
							childrenView?.absoluteFrame.drawColoredRect(.orange)
						}
					}
			}
		}
    }

}
