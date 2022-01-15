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
				rect  = rect.expandedEquallyBy(fraction: 0.4)

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

					if  rect.isEmpty {
						noop()
					}
				}
			}
		}

		return rect
	}

	func widgetNearestTo(_ point: CGPoint, _  visited: ZoneWidgetArray = []) -> ZoneWidget? {
		if  !visited.contains(self),
			absoluteDragHitRect.contains(point) {

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
		if  let                z = widgetZone, z.isShowing, absoluteHitRect.contains(location) {
			if  let            d = parentLine?.dragDot,   d.absoluteHitRect.contains(location) {
				return         d
			}
			for line in childrenLines {
				if  let        r = line.revealDot,        r.absoluteHitRect.contains(location) {
					return     r
				}
			}
			if  let            t = pseudoTextWidget,        t.absoluteFrame.contains(location) {
				return         textWidget
			}
			if  isCircularMode,                               highlightRect.contains(location) {
				return         self
			}
			if  recursive {
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

	func detectHit(at location: CGPoint) -> Any? {
		if  isBigMap,
			let    any = gSmallMapController?.detectHit(at: location) {
			return any
		}

		return hereWidget?.detectHit(at: location)
	}

}
