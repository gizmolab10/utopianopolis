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
//	static let   tRecent = ZWidgetType(rawValue: 1 << 3)
	static let    tTrash = ZWidgetType(rawValue: 1 << 4)
	static let    tEssay = ZWidgetType(rawValue: 1 << 5)
	static let     tNote = ZWidgetType(rawValue: 1 << 6)
	static let     tIdea = ZWidgetType(rawValue: 1 << 7)
	static let     tLost = ZWidgetType(rawValue: 1 << 8)
	static let     tNone = ZWidgetType(rawValue: 1 << 9)

	var isBigMap:   Bool { return contains(.tBigMap) }
//	var isRecent:   Bool { return contains(.tRecent) }
	var isFavorite: Bool { return contains(.tFavorite) }
	var isExemplar: Bool { return contains(.tExemplar) }

	var description: String {
		return [(.tNone,        "    none"),
				(.tLost,        "    lost"),
				(.tIdea,        "    idea"),
				(.tNote,        "    note"),
				(.tEssay,       "   essay"),
				(.tTrash,       "   trash"),
//				(.tRecent,      "  recent"),
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

	var        highlightRect =     CGRect.zero
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
	override var description :          String  { return widgetZone?       .description ?? kEmptyIdea }
	var   hasVisibleChildren :            Bool  { return widgetZone?.hasVisibleChildren ?? false }
	var          hideDragDot :            Bool  { return widgetZone?       .hideDragDot ?? false }
	var               isHere :            Bool  { return controller?.hereWidget == self }
	var             isCenter :            Bool  { return linesLevel == 0 }
	var           linesLevel :             Int  { return (parentWidget?.linesLevel ?? -1) + 1 }

	override func debug(_ rect: CGRect, _ message: String = kEmpty) {
		if  widgetZone == gHere {
			rect.printRect(message + kSpace + selfInQuotes)
		}
	}

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

	override var controller : ZMapController? {
		if type.isBigMap   { return              gMapController }
		if type.isFavorite { return        gFavoritesController }
		if type.isExemplar { return gHelpDotsExemplarController }

		return nil
	}

	var widgetZone : Zone? {
		get { return widgetObject.zone }
		set {
			widgetObject                  .zone = newValue
			if  let                        name = widgetZone?.zoneName {
				identifier                      = NSUserInterfaceItemIdentifier("<z> \(name)")
				childrenView?       .identifier = NSUserInterfaceItemIdentifier("<c> \(name)")
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

	@discardableResult func createChildPseudoViews(for parentPseudoView: ZPseudoView?, for mapType: ZWidgetType, atIndex: Int?, recursing: Bool, _ kind: ZSignalKind, visited: ZoneArray) -> Int {
		let     mapView = absoluteView as? ZMapView
		sharedRevealDot = isLinearMode ? ZoneDot(view: mapView?.decorationsView) : nil
		var       count = 1

		if  let v = parentPseudoView,
		   !v.subpseudoviews.contains(self) {
			v.addSubpseudoview(self)
		}

		#if os(iOS)
		backgroundColor = kClearColor
		#endif

		gStartupController?.startupUpdate()
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

			while index          > 0 {
				index           -= 1 // go backwards down the children arrays, linear mode bottom and top constraints expect it
				let child        = childrenWidgets[index]
				child.widgetZone =            zone[index]
				let   parentView = isLinearMode ? childrenView : parentPseudoView
				count           += child.createChildPseudoViews(for: parentView, for: mapType, atIndex: index, recursing: true, kind, visited: vplus)
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
				controller?.mapView?.addSubview(t)
			}

			t.controllerSetup(with: controller?.mapView)
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
	
	func createDragLine(with  angle: CGFloat? = nil) -> ZoneLine {
		let          line = createLineFor(child: nil)
		let         aView = line.absoluteView
		line   .dragAngle = angle
		line.parentWidget = self
		let        reveal = isCircularMode ? ZoneDot(view: aView) : gDragging.dropWidget?.sharedRevealDot
		line      .length = gCircleIdeaRadius + gDotHalfWidth

		line.addDots(reveal: reveal, drag:   ZoneDot(view: aView))

		return line
	}

	func createLineFor(child: ZoneWidget?) -> ZoneLine {
		let       mapView = absoluteView as? ZMapView
		let          line = ZoneLine(view: mapView?.decorationsView)
		line .childWidget = child
		child?.parentLine = line

		return line
	}

	private func addLine(connectingTo child: ZoneWidget?) {
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
				addLine(connectingTo: nil)
			} else {
				for child in childrenWidgets {
					addLine(connectingTo: child)
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

	func traverseAllVisibleWidgetProgeny(inReverse: Bool = false, _ block: ZoneWidgetClosure) {
		traverseAllWidgetProgeny { widget in
			if  let zone = widget.widgetZone, zone.isVisible {
				block(widget)
			}
		}
	}

	func traverseAllWidgetProgeny(inReverse: Bool = false, _ block: ZoneWidgetClosure) {
		safeTraverseWidgetProgeny(visited: [], inReverse: inReverse) { widget -> ZTraverseStatus in
			block(widget)

			return .eContinue
		}
	}

	@discardableResult func traverseWidgetProgeny(inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		return safeTraverseWidgetProgeny(visited: [], inReverse: inReverse, block)
	}

	@discardableResult func safeTraverseWidgetProgeny(visited: ZoneWidgetArray, inReverse: Bool = false, _ block: ZWidgetToStatusClosure) -> ZTraverseStatus {
		var status  = ZTraverseStatus.eContinue

		if  visited.contains(self) {
			return status			        // do not revisit or traverse further inward
		}

		if !inReverse {
			status  = block(self)           // first call block on self, then recurse on each child

			if  status == .eStop {
				return status               // halt traversal
			}
		}

		for child in childrenWidgets {
			status = child.safeTraverseWidgetProgeny(visited: visited + [self], inReverse: inReverse, block)

			if  status == .eStop {
				return status               // halt traversal
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

	// MARK: - draw
	// MARK: -

	struct ZHighlightStyle: OptionSet {
		let rawValue : Int

		init(rawValue: Int) { self.rawValue = rawValue }

		static let sThickDashed = ZHighlightStyle(rawValue: 1 << 0)
		static let sUltraThin   = ZHighlightStyle(rawValue: 1 << 1)
		static let sDashed      = ZHighlightStyle(rawValue: 1 << 2)
		static let sMedium      = ZHighlightStyle(rawValue: 1 << 3)
		static let sThick       = ZHighlightStyle(rawValue: 1 << 4)
		static let sThin        = ZHighlightStyle(rawValue: 1 << 5)
		static let sNone        = ZHighlightStyle([])
	}

	func drawSelectionHighlight(_ style: ZHighlightStyle) {
		if  highlightRect.hasZeroSize || style == .none {
			return
		}

		let      color = widgetZone?.highlightColor
		let       path = selectionHighlightPath
		path.lineWidth = CGFloat(gLineThickness * 3.5)
		path .flatness = kDefaultFlatness
		
		switch style {
			case .sThick:       path.lineWidth *= 1.5
			case .sThickDashed: path.lineWidth *= 1.5; fallthrough
			case .sDashed:      path.addDashes()
			case .sMedium:      path.lineWidth *= 0.7
			case .sThin:        path.lineWidth *= 0.5
			case .sUltraThin:   path.lineWidth *= 0.2
			default:            break
		}

		color?.setStroke()
		path.stroke()
	}

    override func draw(_ phase: ZDrawPhase) {
		if (gIsMapOrEditIdeaMode || !type.isBigMap || !gShowsSearchResults),
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
					let ringIdeas = gDisplayIdeasWithCircles && isCircularMode
					
					if  isEditing || isHovering || isGrabbed || tHovering || isCircularMode {
						var style = ZHighlightStyle.sNone
						
						if        isEditing      { style = .sThickDashed
						} else if tHovering      {
							if    isCircularMode { style = .sDashed
							} else               { style = .sThin        }
						} else if isGrabbed      { style = .sThick
						} else if isHovering     {
							if    isCircularMode { style = .sDashed
							} else               { style = .sMedium      }
						} else if ringIdeas      { style = .sUltraThin   }

						if  style != .sNone {
							drawSelectionHighlight(style)
						}
					}

					if  controller?.inCircularMode ?? false,
						let color = zone.widgetColor?.withAlphaComponent(0.30) {
						drawInterior(color)
					}

//					debugDraw(isHovering || tHovering)
				}
			}
		}
    }

	func debugDraw(_ extraThick: Bool = false) {
		absoluteDragHitRect.drawColoredRect(.green, radius: .zero, thickness: extraThick ? 5.0 : 1.0)
//		highlightRect.drawColoredRect(.blue,  radius: .zero)
//		absoluteFrame.drawColoredRect(.red,   radius: .zero)
//		childrenView?.absoluteFrame.drawColoredRect(.orange)
	}

	func printWidget() {
		if  let prior = controller?.mapView?.frame {
			controller?.mapView?.frame = bounds.expandedBy(dx: 40.0, dy: 40.0)

			gDetailsController?.temporarilyHideView(for: .vFavorites) {
				gMapController?.layoutForCurrentScrollOffset()
				controller?.mapView?.printView()
			}

			controller?.mapView?.frame = prior

			gRelayoutMaps()
		}
	}

}
