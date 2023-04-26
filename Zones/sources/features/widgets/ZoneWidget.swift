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

enum ZMapType: Int {

	case tExemplar
	case tFavorite
	case tMainMap

	var isMainMap:  Bool { return self == .tMainMap  }
	var isFavorite: Bool { return self == .tFavorite }
	var isExemplar: Bool { return self == .tExemplar }

	var root: Zone? {
		switch self {
			case .tFavorite: return gFavoritesRoot
			case .tExemplar: return gHelpDotsExemplarController?.rootZone
			default:         return nil // needs databaseID to determine which root !!!
		}
	}

}

@objc (ZoneWidget)
class ZoneWidget: ZPseudoView, ZToolTipper {

	var        highlightRect =     CGRect.zero
	var      childrenWidgets = ZoneWidgetArray()
	var        childrenLines =      [ZoneLine]()
	var         childrenView :     ZPseudoView?
	var            linesView :     ZPseudoView?
	var     pseudoTextWidget :     ZPseudoView?
	var           textWidget :  ZoneTextWidget?
	var      sharedRevealDot :         ZoneDot?
	var           parentLine :        ZoneLine?
	var         parentWidget :      ZoneWidget?
	var              mapType :        ZMapType  { return widgetZone?.mapType ?? .tMainMap }
	var         mapReduction :         CGFloat  { return mapType.isMainMap ? 1.0 : kFavoritesMapReduction }
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

	override var controller : ZMapController? {
		if mapType.isMainMap  { return              gMapController }
		if mapType.isFavorite { return     gFavoritesMapController }
		if mapType.isExemplar { return gHelpDotsExemplarController }

		return nil
	}

	var widgetZone : Zone? {
		didSet {
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

	@discardableResult func createPseudoViews(for parentPseudoView: ZPseudoView?, for mapType: ZMapType, atIndex: Int?, _ kind: ZSignalKind, visited: ZoneArray) -> Int {
		let     mapView = absoluteView as? ZMapView
		sharedRevealDot = isLinearMode ? ZoneDot(view: mapView?.decorationsView) : nil
		var       count = 1 // begin with self

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

		removeChildrenPseudoViews()
		addChildrenWidgets()
		addLines()

		if  let  zone = widgetZone, !visited.contains(zone), zone.isShowing, zone.hasVisibleChildren {
			var index = childrenWidgets.count
			let vplus = visited + [zone]

			while index          > 0 {
				index           -= 1 // go backwards down the children arrays, linear mode bottom and top constraints expect it
				let child        = childrenWidgets[index]
				child.widgetZone =            zone[index]
				let   parentView = isLinearMode ? childrenView : parentPseudoView
				count           += child.createPseudoViews(for: parentView, for: mapType, atIndex: index, kind, visited: vplus)
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

	func removeChildrenPseudoViews() {
		for widget in childrenWidgets {
			widget.removeFromSuperpseudoview()
			if  let t = widget.textWidget {
				t.removeFromSuperview()
			}
		}
	}

	func addChildrenWidgets() {
		if  let zone = widgetZone {
			childrenWidgets.removeAll()

			var count = zone.count

			if  count > 60 {
				count = 60     // shrink count to what will reasonably fit vertically
			}

			while childrenWidgets.count < count {
				let          child = ZoneWidget(view: absoluteView)
				child.parentWidget = self
				child  .widgetZone = zone.children[childrenWidgets.count]

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
		line      .length = (controller?.circleIdeaRadius ?? .zero) + (controller?.dotHalfWidth ?? .zero)

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
		guard let c = controller ?? gHelpController else { return } // for help dots, widget and controller are nil; so use help controller
		if  highlightRect.hasZeroSize || style == .none {
			return
		}

		let      color = widgetZone?.highlightColor
		let       path = selectionHighlightPath
		path.lineWidth = CGFloat(c.coreThickness * 2.5)
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
		if (gCanDrawWidgets || !mapType.isMainMap),
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

					if  isEditing || isHovering || isGrabbed || tHovering || isCircularMode {
						var style = ZHighlightStyle.sNone
						
						if        isEditing      { style = .sThickDashed
						} else if isGrabbed      { style = .sThick
						} else if tHovering      {
							if    isCircularMode { style = .sDashed
							} else               { style = .sThin        }
						} else if isHovering     {
							if    isCircularMode { style = .sDashed
							} else               { style = .sMedium      }
						} else if isCircularMode { style = .sUltraThin   }

						if  style != .sNone {
							drawSelectionHighlight(style)
						}
					}

					if  gDrawCirclesAroundIdeas,
						controller?.inCircularMode ?? false,
						let color = zone.lighterColor {
						drawInterior(color)
					}

//					debugDraw(isHovering || tHovering)
				}
			}
		}
    }

	func debugDraw(_ extraThick: Bool = false) {
//		if isLinearMode { return }
//		absoluteFrame              .drawColoredRect(.orange, thickness: extraThick ? 5.0 : 1.0)
//		absoluteHitRect            .drawColoredRect(.green,  thickness: extraThick ? 5.0 : 1.0)
		highlightRect              .drawColoredRect(.blue,   thickness: extraThick ? 5.0 : 1.0)
		childrenView?.absoluteFrame.drawColoredRect(.red,    thickness: extraThick ? 5.0 : 1.0)
	}

}
