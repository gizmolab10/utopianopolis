//
//  ZBreadcrumbsView.swift
//  Zones
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZBreadcrumbsView : ZTextField {

	var crumbRects: [CGRect] {
		var        rects = [CGRect]()

		if  let        f = font {
			var    tRect = gBreadcrumbs.crumbsText.rect(using: f, for: NSRange(location: 0, length: gBreadcrumbs.crumbsText.length), atStart: true)
			tRect.center = bounds.center
			let   deltaX = tRect.minX

			for range in gBreadcrumbs.crumbRanges {
				let rect = gBreadcrumbs.crumbsText.rect(using: f, for: range, atStart: true).offsetBy(dx: deltaX, dy: 4.0)

				rects.append(rect)
			}
		}

		return rects
	}

//	override func draw(_ dirtyRect: NSRect) {
//		super.draw(dirtyRect)
//
//		for rect in crumbRects {
//			let path = ZBezierPath.init(rect: rect)
//
//			ZColor.blue.setStroke()
//			path.stroke()
//		}
//	}

	func updateCrumbs() {
		text      = gBreadcrumbs.crumbsText
		textColor = gBreadcrumbs.crumbsColor
	}

	// mouse down -> change focus
	override func mouseDown(with event: NSEvent) {
		let COMMAND = event.modifierFlags.isCommand
		let   point = convert(event.locationInWindow, from: nil)

		for (index, rect) in crumbRects.enumerated() {
			if  rect.contains(point) {
				go(to: index, COMMAND: COMMAND)

				break
			}
		}
	}

	func go(to index: Int, COMMAND: Bool) {
		let next = gBreadcrumbs.crumbZones[index]
		let last = gBreadcrumbs.crumbsRootZone
		let here = gHere

		switch gWorkMode {
			case .graphMode:
				gFocusRing.focusOn(next) {
					if  COMMAND {
						next.traverseAllProgeny { child in
							child.concealChildren()
						}
					}

					if  here != next {
						last?.grab()
						last?.asssureIsVisible()
					}

					gControllers.signalFor(next, regarding: .eRelayout)
			}
			default:
				gCurrentEssay = next.noteMaybe
		}
	}

	// mouse over hit test -> index into breadcrumb strings array
	// change the color of the string at that index

}
