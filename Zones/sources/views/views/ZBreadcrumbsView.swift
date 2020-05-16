//
//  ZBreadcrumbsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import SnapKit

var gBreadcrumbsView: ZBreadcrumbsView? { return gBreadcrumbsController?.crumbsView }

class ZBreadcrumbsView : ZButtonsView {

	override  var           clipped :  Bool { return gClipBreadcrumbs }
	@IBOutlet var  clipCrumbsButton :  ZButton?
	@IBOutlet var dbIndicatorButton :  ZButton?

	var crumbButtonsWidth: CGFloat {
		var width = CGFloat(0.0)

		for button in buttons {
			width += button.bounds.width
		}

		return width
	}

	func fitBreadcrumbsToWindow() {
		gClipBreadcrumbs     = false

		while crumbButtonsWidth > bounds.width {
			gClipBreadcrumbs = true

			buttons.remove(at: 0)
		}
	}

	override func setupButtons() {
		buttons = [ZBreadcrumbButton]()

		for (index, zone) in gBreadcrumbs.crumbZones.enumerated() {
			let        button = ZBreadcrumbButton(title: zone.unwrappedName, target: self, action: #selector(crumbButtonAction(_:)))
			button.font       = gFavoritesFont
			button.tag        = index
			button.zone       = zone
			button.isBordered = false
			let         title = NSMutableAttributedString(string: zone.unwrappedName)
			let         range = NSRange(location:0, length: title.length)

			title.addAttributes([.font : gFavoritesFont], range: range)

			if  let     color = zone.color {
				title.addAttributes([.foregroundColor : color], range: range)
			}

			button.attributedTitle = title

			buttons.append(button)
		}

		fitBreadcrumbsToWindow()   // side effect: updates clipped
	}

	override func updateAndRedraw() {
		super.updateAndRedraw()   // side effect: updates clipped, used below

		clipCrumbsButton? .image    = !clipped ? nil : ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
		dbIndicatorButton?.title    =  gDatabaseID.indicator
		dbIndicatorButton?.isHidden = !gIsGraphOrEditIdeaMode
	}

	override func draw(_ dirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			super.draw(dirtyRect)
		}
	}

	// MARK:- events
	// MARK:-

	@IBAction func handleClipper(_ sender: Any?) {
		gClipBreadcrumbs = !gClipBreadcrumbs

		updateAndRedraw()
	}

	@IBAction func handleDatabaseIndicatorAction(_ button: ZButton) {
		gGraphController?.toggleGraphs()
		gRedrawGraph()
		updateAndRedraw()
	}

	@IBAction func crumbButtonAction(_ button: ZButton) {
		let    edit = gCurrentlyEditingWidget?.widgetZone
		let    next = gBreadcrumbs.crumbZones[button.tag]
		let    last = gBreadcrumbs.crumbsRootZone
		let    span = gTextEditor.selectedRange()
		let COMMAND = false

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

			if  gWorkMode == .noteMode {
				if  let note = next.noteMaybe {
					gEssayView?.resetCurrentEssay(note)
				} else {
					gSetGraphMode()
				}
			}

			gSignal([.sSwap, .sRelayout])
		}
	}

}
