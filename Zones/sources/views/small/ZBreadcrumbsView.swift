//
//  ZBreadcrumbsView.swift
//  Zones
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

class ZBreadcrumbsView : ZTextField {

	var crumbZones: [Zone]      { return crumbsRootZone?.crumbZones ?? [] }
	var crumbDBID: ZDatabaseID? { return crumbsRootZone?.databaseID }
	var crumbsText: String      { return crumbs.joined(separator: " ⇨ ") }

	var crumbs: [String] {
		var result = [String]()

		for zone in crumbZones {
			result.append(zone.unwrappedName)
		}

		return result
	}

	var crumbsRootZone: Zone? {
		switch gWorkMode {
			case .graphMode: return gSelecting.firstGrab
			default:		 return gCurrentEssay?.zone
		}
	}

	var crumbsColor: ZColor {
		var color = gBackgroundColor

		if  crumbDBID == .mineID {
			color = color + gRubberbandColor
		}

		return color.darker(by: 5.0)
	}

	var crumbRanges: [NSRange] {
		var result = [NSRange]()

		for crumb in crumbs {
			if  let ranges = crumbsText.rangesMatching(crumb),
				ranges.count > 0 {
				result.append(ranges[0])
			}
		}

		return result
	}

	var crumbRects: [CGRect] {
		var        rects = [CGRect]()

		if  let        f = font {
			var    tRect = crumbsText.rect(using: f, for: NSRange(location: 0, length: crumbsText.length), atStart: true)
			tRect.center = bounds.center
			let   deltaX = tRect.minX

			for range in crumbRanges {
				let rect = crumbsText.rect(using: f, for: range, atStart: true).offsetBy(dx: deltaX, dy: 4.0)

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
		text      = crumbsText
		textColor = crumbsColor
	}

	// mouse down -> change focus
	override func mouseDown(with event: NSEvent) {
		let point = convert(event.locationInWindow, from: nil)

		for (index, rect) in crumbRects.enumerated() {
			if  rect.contains(point) {
				go(to: index)

				break
			}
		}
	}

	func go(to index: Int) {
		let last = crumbsRootZone
		let next = crumbZones[index]

		switch gWorkMode {
			case .graphMode:
				gFocusRing.focusOn(next) {
					last?.grab()
					last?.asssureIsVisible()
					gControllers.signalFor(next, regarding: .eRelayout)
			}
			default:
				gCurrentEssay = next.noteMaybe
		}
	}

	// mouse over hit test -> index into breadcrumb strings array
	// change the color of the string at that index

}
