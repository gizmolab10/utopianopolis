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
		let       string = gBreadcrumbs.crumbsText

		if  let        f = font {
			var    tRect = string.rect(using: f, for: NSRange(location: 0, length: string.length), atStart: true)
			tRect.center = bounds.center
			let   deltaX = tRect.minX

			for range in gBreadcrumbs.crumbRanges {
				let rect = string.rect(using: f, for: range, atStart: true).offsetBy(dx: deltaX, dy: 4.0)

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

	// TODO: mouse over hit test -> index into breadcrumb strings array
	// change the color of the string at that index

	// mouse down -> change focus
	func hitCrumb(_ event: NSEvent) -> Int? {
		let point = convert(event.locationInWindow, from: nil)

		for (index, rect) in crumbRects.enumerated() {
			if  rect.contains(point) {
				return index
			}
		}

		return nil
	}

	// mouse down -> change focus
	override func mouseDown(with event: NSEvent) {
		let COMMAND = event.modifierFlags.isCommand

		if  let    index = hitCrumb(event) {
			go(to: index, COMMAND: COMMAND)
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

}
