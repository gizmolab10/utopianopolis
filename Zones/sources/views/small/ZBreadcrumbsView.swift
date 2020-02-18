//
//  ZBreadcrumbsView.swift
//  Zones
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

var gBreadcrumbsLabel: ZBreadcrumbsView? { return gBreadcrumbsController?.crumbsLabel }

class ZBreadcrumbsView : ZTextField {

	@IBOutlet var heightConstraint: NSLayoutConstraint?

	var crumbRects: [CGRect] {
		var  rects = [CGRect]()
		let string = gBreadcrumbs.crumbsText
		font       = gFavoritesFont

		if  let            f = font {
			var        tRect = string.rect(using: f, for: NSRange(location: 0, length: string.length), atStart: true)
			tRect.leftCenter = bounds.leftCenter
			let        delta = gFontSize / -40.0

			for range in gBreadcrumbs.crumbRanges {
				let rect = string.rect(using: f, for: range, atStart: true).offsetBy(dx: 2.0, dy: 3.0 - (delta * 5.0)).insetBy(dx: -2.0 + (delta * 4.0), dy: delta)

				rects.append(rect)
			}
		}

		return rects
	}

	override func awakeFromNib() {
		super.awakeFromNib()

		font = gFavoritesFont
	}

	override func draw(_ dirtyRect: NSRect) {
		if  gHasCompletedStartup {
			super.draw(dirtyRect)
			drawEncirclements()
		}
	}

	func drawEncirclements() {
		heightConstraint?.constant = gFontSize * kFavoritesReduction * 1.8

		gNecklaceSelectionColor.setStroke()

		if  let hIndex = gBreadcrumbs.indexOfHere {
			for (index, rect) in crumbRects.enumerated() {
				if index >= hIndex {
					let  path = ZBezierPath(roundedRect: rect.insetBy(dx: -4.0, dy: 0.0), cornerRadius: rect.height / 2.0)

					path.stroke()
				}
			}
		}
	}

	func updateAndRedraw() {
		font         = gFavoritesFont
		text         = gBreadcrumbs.crumbsText
		textColor    = gBreadcrumbs.crumbsColor
		needsDisplay = true
	}

	// TODO: mouse over hit test -> index into breadcrumb strings array
	// change the color of the string at that index

	// mouse down -> change focus
	func hitCrumb(_ iPoint: CGPoint) -> Int? {
		let point = convert(iPoint, from: nil)

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
		let   point = event.locationInWindow

		if  let    index = hitCrumb(point) {
			go(to: index, COMMAND: COMMAND)
		}
	}

	func go(to index: Int, COMMAND: Bool) {
		let next = gBreadcrumbs.crumbZones[index]
		let last = gBreadcrumbs.crumbsRootZone

		switch gWorkMode {
			case .noteMode:
				gCurrentEssay = next.noteMaybe
			default:
				gFocusRing.focusOn(next) {
					if  COMMAND {
						next.traverseAllProgeny { child in
							child.concealChildren()
						}
					}

					last?.asssureIsVisible()
					last?.grab()
					gControllers.signalFor(nil, regarding: .eRelayout)
			}
		}
	}

}
