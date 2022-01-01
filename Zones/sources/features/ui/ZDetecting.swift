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

	func dragHitRect(in view: ZPseudoView, _ here: Zone) -> CGRect {
		if  here == widgetZone {
			return view.frame
		}

		return absoluteFrame
	}

}

extension ZMapController {

	func detect(at location: CGPoint) -> Any? {
		if  isBigMap,
			let    any = gSmallMapController?.detect(at: location) {
			return any
		}

		return rootWidget?.detect(at: location)
	}

	func widgetHit(by gesture: ZGestureRecognizer?, locatedInBigMap: Bool = true) -> (Bool, Zone?, CGPoint)? {
		if  let         viewG = gesture?.view,
			let     locationM = gesture?.location(in: viewG),
			let       widgetM = rootWidget?.widgetNearestTo(locationM, in: mapPseudoView, hereZone) {
			let     alternate = isBigMap ? gSmallMapController : gMapController
			if  let  mapViewA = alternate?.mapPseudoView, !kIsPhone,
				let locationA = mapPseudoView?.convertPoint(locationM, toRootPseudoView: mapViewA),
				let   widgetA = alternate?.rootWidget?.widgetNearestTo(locationA, in: mapViewA, alternate?.hereZone),
				let  dragDotM = widgetM.parentLine?.dragDot,
				let  dragDotA = widgetA.parentLine?.dragDot {
				let   vectorM = dragDotM.absoluteFrame.center - locationM
				let   vectorA = dragDotA.absoluteFrame.center - locationM
				let   lengthM = vectorM.length
				let   lengthA = vectorA.length

				// ////////////////////////////////////////////////////// //
				// determine which drag dot's center is closest to cursor //
				// ////////////////////////////////////////////////////// //

				if  lengthA < lengthM {
					return (false, widgetA.widgetZone, locatedInBigMap ? locationM : locationA)
				}
			}

			return (true, widgetM.widgetZone, locationM)
		}

		return nil
	}

}
