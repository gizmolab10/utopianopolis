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

	var           linesLevel = 0
	let         widgetObject = ZWidgetObject  ()
	var      childrenWidgets = ZoneWidgetArray()
	var       highlightFrame = CGRect .zero
	var        childrenLines = [ZoneLine]()
	var         childrenView :     ZPseudoView?
	var            linesView :     ZPseudoView?
	var           parentLine :        ZoneLine?
	var     pseudoTextWidget : ZPseudoTextView?
	var         parentWidget :      ZoneWidget? { return widgetZone?.parentZone?.widget }
	var           textWidget :  ZoneTextWidget? { return pseudoTextWidget?.actualTextWidget }
	var            sizeToFit :          CGSize  { return drawnSize + CGSize(frame.origin) }
	var   hasVisibleChildren :            Bool  { return widgetZone?.hasVisibleChildren ?? false }
	var          hideDragDot :            Bool  { return widgetZone?.onlyShowRevealDot ?? false }
	var             isBigMap :            Bool  { return controller?.isBigMap ?? true }
	var                ratio :         CGFloat  { return type.isBigMap ? 1.0 : kSmallMapReduction }
	override var description :          String  { return widgetZone?.description ?? kEmptyIdea }

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
			widgetObject                  .zone = newValue
			if  let                        name = widgetZone?.zoneName {
				identifier                      = NSUserInterfaceItemIdentifier("<z> \(name)")
				childrenView?       .identifier = NSUserInterfaceItemIdentifier("<c> \(name)")
//				revealDot?          .identifier = NSUserInterfaceItemIdentifier("<r> \(name)")
				parentLine?.dragDot?.identifier = NSUserInterfaceItemIdentifier("<d> \(name)")
				textWidget?         .identifier = NSUserInterfaceItemIdentifier("<t> \(name)")
			}
		}
	}

    deinit {
        childrenWidgets.removeAll()
    }

	// MARK:- view hierarchy
	// MARK:-

	@discardableResult func layoutAllPseudoViews(parentPseudoView: ZPseudoView?, for mapType: ZWidgetType, atIndex: Int?, recursing: Bool, _ kind: ZSignalKind, visited: ZoneArray) -> Int {
		var count = 1

		if  let v = parentPseudoView,
		   !v.subpseudoviews.contains(self) {
			v.addSubpseudoview(self)
		}

		#if os(iOS)
		backgroundColor = kClearColor
		#endif

		gStartupController?.fullStartupUpdate()
		gWidgets.setWidgetForZone(self, for: mapType)
		addTextView()
		addLinesView()
		addChildrenView()
		addChildrenWidgets()
		addChildrenLines()

		if  recursing,
			let  zone = widgetZone, !visited.contains(zone), zone.hasVisibleChildren {
			var index = childrenWidgets.count
			let vplus = visited + [zone]

			while index           > 0 {
				index            -= 1 // go backwards down the children arrays, bottom and top constraints expect it
				let child         = childrenWidgets[index]
				child.widgetZone  =            zone[index]
				count            += child.layoutAllPseudoViews(parentPseudoView: childrenView, for: mapType, atIndex: index, recursing: true, kind, visited: vplus)
			}
		}

		textWidget?.layoutText()
		updateChildrenLinesDrawnSize()
		updateChildrenViewDrawnSize()
		updateSize()

		return count
	}

	func updateChildrenLinesDrawnSize() {
		var     width = CGFloat(0.0)
		var    height = CGFloat(0.0)

		for line in childrenLines {
			line.updateSize()

			let  size = line.drawnSize
			height   += size.height
			if  width < size.width {
				width = size.width
			}
		}

		linesView?.drawnSize = CGSize(width: width, height: height)
	}

	func addTextView() {
		if  pseudoTextWidget == nil {
			pseudoTextWidget  = ZPseudoTextView(view: absoluteView)
		}

		if  let         t = textWidget {
			if  t.widget == nil {
				t.widget  = self

				gMapView?.addSubview(t)
				addSubpseudoview(pseudoTextWidget)
			}

			if  t.superview == nil {
				gMapView?.addSubview(t)
			}

			t.setup()
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

	func addLinesView() {
		if  linesView == nil {
			linesView  = ZPseudoView(view: absoluteView)
		}

		if  let v = linesView, !subpseudoviews.contains(v) {
			addSubpseudoview(v)
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


	func addChildrenLines() {
		let     level = (parentWidget?.linesLevel ?? -1) + 1
		let sharedDot = gIsLinearMapLayout ? ZoneDot(view: absoluteView) : nil


		childrenLines.removeAll()
		linesView?.removeAllSubpseudoviews()

		func addLineFor(_ child: ZoneWidget?) {
			let          line = ZoneLine(view: absoluteView)
			line .childWidget = child
			line.parentWidget = self
			child?.parentLine = line
			child?.linesLevel = level

			line.addDots(sharedDot: sharedDot)
			childrenLines.append(line)
			linesView?.addSubpseudoview(line)
		}

		if  !(widgetZone?.hasVisibleChildren ?? false) {
			addLineFor(nil)
		} else {
			for child in childrenWidgets {
				addLineFor(child)
			}
		}
	}

	func traverseAllWidgetProgeny(inReverse: Bool = false, _ block: ZoneWidgetClosure) {
		safeTraverseWidgetProgeny(visited: [], inReverse: inReverse) { iWidget -> ZTraverseStatus in
			block(iWidget)

			return .eContinue
		}
	}

	@discardableResult func traverseWidgetProgeny(inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		return safeTraverseWidgetProgeny(visited: [], inReverse: inReverse, block)
	}

	@discardableResult func safeTraverseWidgetProgeny(visited: ZoneWidgetArray, inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
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

			status = child.safeTraverseWidgetProgeny(visited: visited + [self], inReverse: inReverse, block)

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

	func updateFrameSize() {
		setFrameSize(drawnSize)
	}

	func updateAllFrames(_ absolute: Bool = false) {
		traverseAllWidgetProgeny(inReverse: !absolute) { iWidget in
			iWidget.updateSubframes(absolute)
		}
	}

	func updateSubframes(_ absolute: Bool = false) {
		updateChildrenVectors  (absolute)
		updateChildrenFrames   (absolute)
		updateTextViewFrame    (absolute)
		updateDotFrames        (absolute)
		updateHighlightRect    (absolute)
		updateChildrenViewFrame(absolute)
	}

	fileprivate func updateDotFrames(_ absolute: Bool) {
		if  let textFrame = textWidget?.frame, absolute {

			if !hideDragDot {
				parentLine?.dragDot?.updateFrame(relativeTo: textFrame)
			}

			for childLine in childrenLines {
				childLine.revealDot?.updateFrame(relativeTo: textFrame)
				childLine.updateLineKind()
			}
		}
	}

    func dot(at iIndex: Int) -> ZoneDot? {
        if  let zone = widgetZone {
            if  zone.count == 0 || iIndex < 0 {
                return nil
            }

            let  index = min(iIndex, zone.count - 1)
            let target = zone.children[index]

            return target.widget?.parentLine?.dragDot
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

	// MARK:- draw
	// MARK:-

    override func draw(_ phase: ZDrawPhase) {
		if (gIsMapOrEditIdeaMode || !type.isBigMap),
			let zone = widgetZone {

			switch phase {
				case .pLines:
					if  zone.isExpanded {
						for child in childrenLines {   // this is after child dots have been autolayed out
							child.drawLine()
						}
					}
				case .pDotsAndHighlight:
					parentLine?    .dragDot?.draw(phase)

					for childLine in childrenLines {
						childLine.revealDot?.draw(phase)
					}

					if  let          t = textWidget {
						let  isGrabbed = zone.isGrabbed
						let  isEditing = t.isFirstResponder
						let isHovering = t.isHovering

						if  (isGrabbed || isEditing || isHovering) && !gIsPrinting {
							drawSelectionHighlight(isEditing, isHovering && !isGrabbed)
						}

						if  gDebugDraw {
							absoluteFrame              .drawColoredRect(.green)
							childrenView?.absoluteFrame.drawColoredRect(.orange)
						}
					}
			}
		}
    }

}
