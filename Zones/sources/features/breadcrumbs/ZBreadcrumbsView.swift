//
//  ZBreadcrumbsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import SnapKit

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

var gBreadcrumbsView: ZBreadcrumbsView? { return gBreadcrumbsController?.crumbsView }

class ZBreadcrumbsView : ZButtonsView {

	override  var          clipped : Bool     { return gClipBreadcrumbs }
	@IBOutlet var clipCrumbsButton : ZButton?

	var crumbButtonsWidth: CGFloat {
		var width = CGFloat.zero

		for button in buttons {
			width += button.bounds.width
		}

		return width
	}

	func detectCrumb(_ iGesture: ZGestureRecognizer?) -> ZBreadcrumbButton? {
		var detected: ZBreadcrumbButton?
		if  let location = iGesture?.location(in: self), bounds.contains(location) {
			for button in buttons {
				button.highlight(false)
				let rect = button.frame
				if  rect.contains(location) {
					detected = button as? ZBreadcrumbButton
				}
			}
		}

		return detected
	}

	func fitBreadcrumbsToWindow() {
		gClipBreadcrumbs     = false

		while crumbButtonsWidth > bounds.width {
			gClipBreadcrumbs = true

			buttons.remove(at: 0)
		}
	}

	override func setupButtons() {
		super.setupButtons()

		buttons = [ZBreadcrumbButton]()

		for (index, zone) in gBreadcrumbs.crumbZones.enumerated() {
			let                     name = zone.unwrappedNameWithEllipses(noLongerThan: 20)
			let                    range = NSRange(location:0, length: name.length)
			let                    style = NSMutableParagraphStyle()
			let                   button = ZBreadcrumbButton(title: name, target: self, action: #selector(crumbButtonAction(_:)))
			let               attributed = NSMutableAttributedString(string: name)
			var               attributes = ZAttributesDictionary()
			style         .lineBreakMode = .byClipping
			button                 .font = gFavoritesFont // needed for computing button width
			button                  .tag = index
			button                 .zone = zone
			button           .isBordered = true
			attributes[           .font] = gFavoritesFont
			attributes[.foregroundColor] = zone.color
			attributes[ .paragraphStyle] = style

			if  zone.hasNote {
				attributes[.underlineStyle] = 1
			}

			attributed.addAttributes(attributes, range: range)
			button.setButtonType(.momentaryPushIn)
			button.updateTracking()
			button.updateToolTips(gModifierFlags)
			buttons.append(button)

			button.attributedTitle = attributed
			button.showsBorderOnlyWhileMouseInside = true
		}

		fitBreadcrumbsToWindow()   // side effect: updates clipped
	}

	override func setupAndRedraw() {
		super.setupAndRedraw()   // side effect: updates clipped, used below

		clipCrumbsButton?.image = !clipped ? nil : kDownImage?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
	}

	override func draw(_ iDirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			super.draw(iDirtyRect)

			for (index, button) in buttons.enumerated() {
				if  index > 0,
					let crumb = button as? ZBreadcrumbButton {
					let extra = 14.66 - (gFavoritesMapController.fontSize) / 3.0
					let point = crumb.frame.bottomLeft.offsetBy(.zero, extra)
					let color = crumb.zone.color ?? kDefaultIdeaColor

					">".draw(at: point, withAttributes: [.foregroundColor : color, .font: gFavoritesFont])
				}
			}
		}
	}

	// MARK: - events
	// MARK: -

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
			let  OPTION = flags?.hasOption  ?? false
			let COMMAND = flags?.hasCommand ?? false

			if    zone == gHere, !gIsEssayMode, !COMMAND { return }

			if  gIsEssayMode {
				gEssayView?.done()
			}

			func displayEssay(_ asEssay: Bool = true) {
				gCreateCombinedEssay = !OPTION && asEssay

				if  gCreateCombinedEssay {
					zone.noteMaybe = nil                    // forget note so essay will be constructed
				}

				gEssayView?.resetCurrentEssay(zone.note)    // note creates an essay when gCreateCombinedEssay is true
			}

			gFocusing.grabAndFocusOn(zone) {
				switch gWorkMode {
					case .wResultsMode:
						gExitSearchMode()
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
							gControllers.swapMapAndEssay(force: .wEssayMode)

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
							gEssayControlsView?.enableEssayControls(false)
							gSetMapWorkMode()                                 // no note in zone so exit essay editor
						} else {
							displayEssay(!sameNote)
						}
					default: break
				}

				gSignal([.sSwap, .spDataDetails, .spRelayout])
			}
		}
	}

}
