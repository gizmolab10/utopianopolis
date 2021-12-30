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

struct ZWidgetType: OptionSet, CustomStringConvertible {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let tExemplar = ZWidgetType(rawValue: 1 << 0)
	static let tFavorite = ZWidgetType(rawValue: 1 << 1)
	static let   tBigMap = ZWidgetType(rawValue: 1 << 2)
	static let   tRecent = ZWidgetType(rawValue: 1 << 3)
	static let    tTrash = ZWidgetType(rawValue: 1 << 4)
	static let    tEssay = ZWidgetType(rawValue: 1 << 5)
	static let     tNote = ZWidgetType(rawValue: 1 << 6)
	static let     tIdea = ZWidgetType(rawValue: 1 << 7)
	static let     tLost = ZWidgetType(rawValue: 1 << 8)
	static let     tNone = ZWidgetType(rawValue: 1 << 9)

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

@objc (ZoneWidget)
class ZoneWidget: ZPseudoView {

	var       highlightFrame =     CGRect.zero
	let         widgetObject =   ZWidgetObject()
	var      childrenWidgets = ZoneWidgetArray()
	var        childrenLines =      [ZoneLine]()
	var         childrenView :     ZPseudoView?
	var            linesView :     ZPseudoView?
	var     pseudoTextWidget :     ZPseudoView?
	var           textWidget :  ZoneTextWidget?
	var      sharedRevealDot :         ZoneDot?
	var           parentLine :        ZoneLine?
	var         parentWidget :      ZoneWidget?
	var         mapReduction :         CGFloat  { return type.isBigMap ? 1.0 : kSmallMapReduction }
	override var description :          String  { return widgetZone?.description ?? kEmptyIdea }
	var   hasVisibleChildren :            Bool  { return widgetZone?.hasVisibleChildren ?? false }
	var          hideDragDot :            Bool  { return widgetZone?.onlyShowRevealDot  ?? false }
	var             isBigMap :            Bool  { return controller?.isBigMap ?? true }
	var             isCenter :            Bool  { return linesLevel == 0 }
	var           linesLevel :             Int  { return (parentWidget?.linesLevel ?? -1) + 1 }

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

	override var controller: ZMapController? {
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

	// MARK: - view hierarchy
	// MARK: -

	@discardableResult func layoutAllPseudoViews(parentPseudoView: ZPseudoView?, for mapType: ZWidgetType, atIndex: Int?, recursing: Bool, _ kind: ZSignalKind, visited: ZoneArray) -> Int {
		sharedRevealDot = isLinearMode ? ZoneDot(view: absoluteView) : nil
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

		if  isLinearMode {
			addLinesView()
			addChildrenView()
		}

		addChildrenWidgets()
		addLines()

		if  recursing,
			let  zone = widgetZone, !visited.contains(zone), zone.hasVisibleChildren, zone.isShowing {
			var index = childrenWidgets.count
			let vplus = visited + [zone]

			while index           > 0 {
				index            -= 1 // go backwards down the children arrays, linear mode bottom and top constraints expect it
				let child         = childrenWidgets[index]
				child .widgetZone =            zone[index]
				let    parentView = isLinearMode ? childrenView : parentPseudoView
				count            += child.layoutAllPseudoViews(parentPseudoView: parentView, for: mapType, atIndex: index, recursing: true, kind, visited: vplus)
			}
		}

		textWidget?.updateText()

		if  isLinearMode {
			updateChildrenViewDrawnSize()
			updateLinesViewDrawnSize()
		}

		updateWidgetDrawnSize()

		return count
	}

	func addTextView() {
		if  isCircularMode, !(widgetZone?.isShowing ?? true) { return }

		if  pseudoTextWidget == nil {
			pseudoTextWidget  = ZPseudoView(view: absoluteView)

			addSubpseudoview(pseudoTextWidget)
		}

		if  textWidget == nil {
			textWidget  = ZoneTextWidget()
		}

		if  let         t = textWidget {
			if  t.widget == nil {
				t.widget  = self
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
			for widget in childrenWidgets {
				widget.removeFromSuperpseudoview()
				if  let t = widget.textWidget {
					t.removeFromSuperview()
				}
			}

			childrenWidgets.removeAll()

			var count = zone.count

			if  count > 60 {
				count = 60     // shrink count to what will reasonably fit vertically
			}

			while childrenWidgets.count < count {
				let          child = ZoneWidget(view: absoluteView)
				child.parentWidget = self
				child.widgetZone   = zone.children[childrenWidgets.count]

				childrenWidgets.append(child)      // add missing
			}
		}
	}
	
	func createDragLine() -> ZoneLine {
		let          line = createLineFor(child: nil)
		line.parentWidget = gDragging.dropWidget
		let        reveal = isCircularMode ? ZoneDot(view: absoluteView) : gDragging.dropWidget?.sharedRevealDot

		line.addDots(reveal: reveal, drag:   ZoneDot(view: absoluteView))

		return line
	}

	func createLineFor(child: ZoneWidget?) -> ZoneLine {
		let          line = ZoneLine(view: absoluteView)
		line .childWidget = child
		child?.parentLine = line

		return line
	}

	private func addLine(to child: ZoneWidget?) {
		let        reveal = isLinearMode ? sharedRevealDot : nil
		let          line = createLineFor(child: child)
		line.parentWidget = self

		line.addDots(reveal: reveal)
		childrenLines.append(line)

		if  isLinearMode {
			linesView?.addSubpseudoview(line)
		}
	}

	func addLines() {
		childrenLines.removeAll()
		linesView?.removeAllSubpseudoviews()

		if  let zone = widgetZone, zone.isShowing {
			if !zone.hasVisibleChildren, isLinearMode {
				addLine(to: nil)
			} else {
				for child in childrenWidgets {
					addLine(to: child)
				}
			}
		}
	}

	func traverseAllWidgetAncestors(visited: ZoneWidgetArray = [], _ block: ZoneWidgetClosure) {
		if !visited.contains(self) {
			block(self)
			parentWidget?.traverseAllWidgetAncestors(visited: visited + [self], block)
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

	// MARK: - compute sizes and frames
	// MARK: -

	func updateFrameSize() {
		setFrameSize(drawnSize)
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

	func detect(at location: CGPoint, recursive: Bool = true) -> Any? {
		if  let                z = widgetZone, z.isShowing, detectionFrame.contains(location) {
			if  let            d = parentLine?.dragDot,    d.absoluteFrame.contains(location) {
				return         d
			}
			for line in childrenLines {
				if  let        r = line.revealDot,         r.absoluteFrame.contains(location) {
					return     r
				}
			}
			if  let            t = pseudoTextWidget,       t.absoluteFrame.contains(location) {
				return         textWidget
			}
			if  isCircularMode,                            highlightFrame.contains(location) {
				return         self
			}
			if  recursive {
				for child in childrenWidgets {
					if  let    c = child.detect(at: location) {
						return c
					}
				}
			}
		}

		return nil
	}

	// MARK: - draw
	// MARK: -

	func drawSelectionHighlight(_ style: ZHighlightStyle) {
		if  highlightFrame.hasZeroSize || style == .none {
			return
		}

		let      color = widgetZone?.color?.withAlphaComponent(0.30)
		let       path = selectionHighlightPath
		path.lineWidth = CGFloat(gLineThickness * 3.5)
		path .flatness = 0.0001
		
		switch style {
		case .sDashed:    path.addDashes()
		case .sMedium:    path.lineWidth *= 0.7
		case .sThin:      path.lineWidth *= 0.5
		case .sUltraThin: path.lineWidth *= 0.2
		default:          break
		}

		color?.setStroke()
		path.stroke()
	}

    override func draw(_ phase: ZDrawPhase) {
		if (gIsMapOrEditIdeaMode || !type.isBigMap),
			let zone = widgetZone {

			switch phase {
			case .pLines, .pDots:
				for line in childrenLines {
					line.draw(phase)
				}
			case .pHighlights:
				if  let         t = textWidget {
					let isGrabbed = zone.isGrabbed
					let isEditing = t.isFirstResponder
					let tHovering = t.isHovering
					let ringIdeas = gCirclesDisplayMode.contains(.cIdeas) && isCircularMode
					
					if  isEditing || isHovering || isGrabbed || tHovering || isCircularMode {
						var style = ZHighlightStyle.sNone
						
						if        isEditing      { style = .sDashed
						} else if tHovering      {
							if    isCircularMode { style = .sDashed
							} else               { style = .sThin      }
						} else if isGrabbed      { style = .sThick
						} else if isHovering     { style = .sMedium
						} else if ringIdeas      { style = .sUltraThin }

//						debugDraw(isHovering || tHovering)

						if  style != .sNone {
							drawSelectionHighlight(style)
						}
					}
				}
			}
		}
    }

	func debugDraw(_ extraThick: Bool = false) {
		detectionFrame.drawColoredRect(.green, radius: 0.0, thickness: extraThick ? 5.0 : 1.0)
//		highlightFrame.drawColoredRect(.blue,  radius: 0.0)
//		absoluteFrame .drawColoredRect(.red,   radius: 0.0)
		childrenView?.absoluteFrame.drawColoredRect(.red)
	}

}
