//
//  ZBreadcrumbsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
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
		removeButtons()

		buttons = [ZBreadcrumbButton]()

		for (index, zone) in gBreadcrumbs.crumbZones.enumerated() {
			let        button = ZBreadcrumbButton(title: zone.unwrappedName, target: self, action: #selector(crumbButtonAction(_:)))
			button.font       = gSmallMapFont
			button.tag        = index
			button.zone       = zone
			button.isBordered = false
			let         title = NSMutableAttributedString(string: zone.unwrappedName)
			let         range = NSRange(location:0, length: title.length)

			title.addAttributes([.font : gSmallMapFont], range: range)

			if  let     color = zone.color {
				title.addAttributes([.foregroundColor : color], range: range)
			}

			button.attributedTitle = title

			button.updateTooltips()
			buttons.append(button)
		}

		fitBreadcrumbsToWindow()   // side effect: updates clipped
	}

	

	override func setupAndRedraw() {
		super.setupAndRedraw()   // side effect: updates clipped, used below

		clipCrumbsButton? .image    = !clipped ? nil : ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
		dbIndicatorButton?.title    =  gDatabaseID.indicator
		dbIndicatorButton?.isHidden = !gIsMapOrEditIdeaMode
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

		setupAndRedraw()
	}

	@IBAction func handleDatabaseIndicatorAction(_ button: ZButton) {
		gMapController?.toggleMaps()
		gRedrawMaps()
		setupAndRedraw()
	}

	@IBAction func crumbButtonAction(_ button: ZBreadcrumbButton) {
		let    next = gBreadcrumbs.crumbZones[button.tag]
		let    last = gBreadcrumbs.crumbsRootZone
		let   flags = button.currentEvent?.modifierFlags
		let  OPTION = flags?.isOption  ?? false
		let COMMAND = flags?.isCommand ?? false

		next.focusOn() {
			switch (gWorkMode) {
				case .editIdeaMode:
					if  let edit = gCurrentlyEditingWidget?.widgetZone {
						let span = gTextEditor.selectedRange()
						edit.editAndSelect(range: span)
					} else {
						last?.grab()
					}
				case .mapsMode:
					if  COMMAND {
						next.grab()
						next.traverseAllProgeny { child in
							child.collapse()
						}
					}

					gHere.asssureIsVisible()
				case .noteMode:
					if  let essayView = gEssayView {
						let sameNext  = (next == gCurrentEssayZone)
						if  sameNext || !(next.hasNote || OPTION) {
							// no note in next so exit essay editor
							essayView.setControlBarButtons(enabled: false)
							gSetMapsMode()
						} else {
							let            saved = gCreateCombinedEssay
							gCreateCombinedEssay = (OPTION && !sameNext)

							if  gCreateCombinedEssay {
								next.noteMaybe   = nil              // forget note so essay will be constructed
							}

							essayView.resetCurrentEssay(next.note)  // note creates an essay when gCreateCombinedEssay is true

							gCreateCombinedEssay = saved
						}
					}
				default: break
			}

			gSignal([.sSwap, .sRelayout])
		}
	}

}
