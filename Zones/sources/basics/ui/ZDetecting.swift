//
//  ZDetecting.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/1/22.
//  Copyright © 2022 Zones. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

extension ZoneWidget {

	var absoluteDragHitRect : CGRect {
		var     rect  = absoluteHitRect
		if  let view  = controller?.mapPseudoView {
			let vRect = view.frame
			if  isHere {
				rect  = vRect
			} else if gDragging.isDragging {
				rect  = rect.expandedEquallyBy(gDotHeight / 3.0).expandedEquallyBy(fraction: 0.05)

				if  parentWidget?.isHere ?? false {
					rect.size.width = vRect.width
					rect  .origin.x = .zero
				}

				if  let z = widgetZone {     // if widget is at top or bottom, extend vertically to furthest edge
					if  z.isFirstSibling {
						rect.size.height = vRect.maxY - rect.minY
					}

					if  z.isLastSibling {
						rect.size.height = rect.maxY
						rect   .origin.y = .zero
					}
				}
			}
		}

		return rect
	}

	func widgetNearestTo(_ point: CGPoint, _  visited: ZoneWidgetArray = []) -> ZoneWidget? {
		if  !visited.contains(self),
			absoluteDragHitRect.contains(point) {

			if  let name = widgetZone?.zoneName, name == "stay-centered is broken" {
				noop()
			}

			for child in childrenWidgets {
				if  self        != child,
					let    found = child.widgetNearestTo(point, visited + [self]) {    // recurse into child
					return found
				}
			}

			return self
		}

		return nil
	}

	func detectHit(at location: CGPoint, recursive: Bool = true) -> Any? {
		if                                                  absoluteHitRect.contains(location) {
			if  let            d = parentLine?.dragDot,   d.absoluteHitRect.contains(location) {
				return         d
			} else if isCircularMode {
				if                                            highlightRect.contains(location) {
					return     self
				}
				for line in childrenLines {
					if  let    r = line.revealDot,        r.absoluteHitRect.contains(location) {
						return r
					}
				}
			}
			if  let            s = sharedRevealDot,       s.absoluteHitRect.contains(location) {
				return         s
			}
			if  let            t = pseudoTextWidget,        t.absoluteFrame.contains(location) {
				return         textWidget
			}
			if  recursive, widgetZone?.isExpanded ?? false {
				for child in childrenWidgets {
					if  let    c = child.detectHit(at: location) {
						return c
					}
				}
			}
		}

		return nil
	}

}

extension ZMapController {

	@objc func detectHit(at location: CGPoint) -> Any? {
		if  isBigMap,
			let    any = gFavoritesController?.detectHit(at: location) {
			return any
		}

		return hereWidget?.detectHit(at: location)
	}

}

extension ZHelpDotsExemplarController {

	override func detectHit(at location: CGPoint) -> Any? {
		return hereWidget?.detectHit(at: location)
	}

}

class ZTrackedArea : NSObject {

	var area: NSTrackingArea?
	var view: ZView?

	init(_ iView: ZView, _ iArea: NSTrackingArea) {
		view = iView
		area = iArea
	}

}

var gTrackedAreas = [ZTrackedArea]()

func gRemoveAllTracking() {
	while gTrackedAreas.count > 0 {
		let  tracked = gTrackedAreas.removeFirst()
		if  let area = tracked.area {
			tracked.view?.removeTrackingArea(area)
		}
	}
}

extension ZView {

	func addTracking(for rect: CGRect, clearFirst: Bool = false) {
		if  clearFirst {
			gRemoveAllTracking()
		}

		let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate]
		let    area = NSTrackingArea(rect:rect, options: options, owner: self, userInfo: nil)
		let tracked = ZTrackedArea(self, area)

		gTrackedAreas.append(tracked)
		addTrackingArea(area)
	}

}

extension ZTooltipButton {

	func updateTracking() { addTracking(for: frame) }

}

extension ZoneTextWidget {

	func updateTracking() { addTracking(for: frame) }

}

extension ZMapView {

	func updateTracking() {
		addTracking(for: frame, clearFirst: true)
	}

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		addTracking(for: bounds)
	}

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)

		if  let view = gMainWindow?.contentView, !view.frame.contains(event.locationInWindow) {
			gRubberband.rubberbandRect = nil
			gDragging      .dropWidget = nil

			setNeedsDisplay()
		}
	}

}
