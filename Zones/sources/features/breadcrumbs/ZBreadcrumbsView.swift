//
//  ZBreadcrumbsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import SnapKit

class ZBreadcrumbsView : ZButtonsView {

	override  var          clipped : Bool     { return gClipBreadcrumbs }
	@IBOutlet var clipCrumbsButton : ZButton?

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
			button.isBordered = true
			let         title = NSMutableAttributedString(string: zone.unwrappedName)
			let         range = NSRange(location:0, length: title.length)
			var    attributes = ZAttributesDictionary()
			attributes[.font] = gSmallMapFont

			if  zone.hasNote {
				attributes[.underlineStyle] = 1
			}

			title.addAttributes(attributes, range: range)
			button.showsBorderOnlyWhileMouseInside = true
			button.setButtonType(.momentaryPushIn)

			if  let color = zone.color {
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

		clipCrumbsButton?.image = !clipped ? nil : ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
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

	@IBAction func crumbButtonAction(_ button: ZBreadcrumbButton) {
		let      crumbs = gBreadcrumbs.crumbZones
		let       index = button.tag
		if        index < crumbs.count {
			let    zone = crumbs[index]
			let   flags = button.currentEvent?.modifierFlags
			let  OPTION = flags?.isOption  ?? false
			let COMMAND = flags?.isCommand ?? false

			if    zone == gHere, !gIsEssayMode, !COMMAND { return }

			func displayEssay(_ asEssay: Bool = true) {
				let            saved = gCreateCombinedEssay
				gCreateCombinedEssay = (OPTION && asEssay)

				if  gCreateCombinedEssay {
					zone.noteMaybe   = nil                // forget note so essay will be constructed
				}

				gEssayView?.resetCurrentEssay(zone.note)  // note creates an essay when gCreateCombinedEssay is true

				gCreateCombinedEssay = saved
			}

			zone.focusOn() {
				switch (gWorkMode) {
					case .wSearchMode:
						gSearching.exitSearchMode()
					case .wEditIdeaMode:
						if  let edit = gCurrentlyEditingWidget?.widgetZone {
							let span = gTextEditor.selectedRange()
							edit.editAndSelect(range: span)
						} else {
							gBreadcrumbs.crumbTipZone?.grab()
						}
					case .wMapMode:
						if  COMMAND {
							displayEssay()
							gMainController?.swapMapAndEssay(force: .wEssayMode)

							return
						} else if OPTION {
							zone.grab()
							zone.traverseAllProgeny { child in
								child.collapse()
							}
						}

						gHere.asssureIsVisible()
					case .wEssayMode:
						let sameNote  = (zone == gCurrentEssayZone)
						if  sameNote || !(zone.hasNote || COMMAND) {
							gEssayView?.setControlBarButtons(enabled: false)
							gSetBigMapMode()                                 // no note in zone so exit essay editor
						} else {
							displayEssay(!sameNote)
						}
					default: break
				}

				gMainController?.swapMapAndEssay()
				gSignal([.spData, .sRelayout])
			}
		}
	}

}
