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

	var                showClipper = false
	@IBOutlet var       clipButton : NSButton?
	@IBOutlet var  widthConstraint : NSLayoutConstraint?
	@IBOutlet var heightConstraint : NSLayoutConstraint?

	var crumbsText : String {
		let     limit = bounds.width - 10.0
		var     array = gBreadcrumbs.crumbs
		var    string = kCrumbSeparator + array.joined(separator: kCrumbSeparator) + kCrumbSeparator
		showClipper   = false

		if  let     f = font {
			var tRect = string.rect(using: f, for: NSRange(location: 0, length: string.length), atStart: true)

			while tRect.width > limit {
				showClipper = true

				array.remove(at: 0)

				if !gClipBreadcrumbs {
					break
				}

				string = kCrumbSeparator + array.joined(separator: kCrumbSeparator) + kCrumbSeparator
				tRect  = string.rect(using: f, for: NSRange(location: 0, length: string.length), atStart: true)
			}
		}

		return string
	}

	var crumbRects: [CGRect] {
		var  rects = [CGRect]()
		let string = crumbsText
		font       = gFavoritesFont

		if  let            f = font {
			var        tRect = string.rect(using: f, for: NSRange(location: 0, length: string.length), atStart: true)
			tRect.leftCenter = bounds.leftCenter
			let        delta = gFontSize / -40.0

			for range in crumbRanges {
				let rect = string.rect(using: f, for: range, atStart: true).offsetBy(dx: 2.0, dy: 3.0 - (delta * 5.0)).insetBy(dx: -2.0 + (delta * 4.0), dy: delta)

				rects.append(rect)
			}
		}

		return rects
	}

	var crumbRanges: [NSRange] {
		var result = [NSRange]()
		let string = crumbsText

		for crumb in gBreadcrumbs.crumbs {
			if  let ranges = string.rangesMatching(kCrumbSeparator + crumb + kCrumbSeparator),
				ranges.count > 0 {
				let offset = kCrumbSeparator.length
				var range = ranges[0]
				range.location += offset
				range.length -= offset * 2
				result.append(range)
			}
		}

		return result
	}

	override func awakeFromNib() {
		super.awakeFromNib()

		font = gFavoritesFont
	}

	override func draw(_ dirtyRect: NSRect) {
		if  gHasFinishedStartup {
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
		font                 = gFavoritesFont
		text                 = crumbsText
		textColor            = gBreadcrumbs.crumbsColor
		clipButton?.isHidden = !showClipper
		clipButton?.image    = ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
		needsDisplay         = true
	}

	// MARK:- events
	// MARK:-

	@IBAction func handleClipper(_ sender: Any?) {
		gClipBreadcrumbs = !gClipBreadcrumbs

		updateAndRedraw()
	}

	// TODO: hit test -> index into breadcrumb strings array
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
		let edit = gCurrentlyEditingWidget?.widgetZone
		let next = gBreadcrumbs.crumbZones[index]
		let last = gBreadcrumbs.crumbsRootZone
		let span = gTextEditor.selectedRange()

		gFocusRing.focusOn(next) {
			if  COMMAND {
				next.traverseAllProgeny { child in
					child.concealChildren()
				}
			}

			last?.asssureIsVisible()

			if  let e = edit {
				e.editAndSelect(range: span)
			} else {
				last?.grab()
			}

			if  gWorkMode == .noteMode,
			    let note = next.noteMaybe {
				gCurrentEssay = note

				self.signalRegarding(.eSwap)
			} else {
				self.signalRegarding(.eRelayout)
			}
		}
	}

}
