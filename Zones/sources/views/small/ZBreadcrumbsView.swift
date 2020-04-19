//
//  ZBreadcrumbsView.swift
//  Zones
//
//  Created by Jonathan Sand on 2/15/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import SnapKit

var gBreadcrumbsView: ZBreadcrumbsView? { return gBreadcrumbsController?.crumbsView }

class ZBreadcrumbsView : ZView {

	var            crumbsAreClipped =  false
	var                crumbButtons = [ZBreadcrumbButton]()
	@IBOutlet var  clipCrumbsButton :  ZButton?
	@IBOutlet var dbIndicatorButton :  ZButton?

	var crumbButtonsWidth: CGFloat {
		var width = CGFloat(0.0)

		for button in crumbButtons {
			width += button.bounds.width
		}

		return width
	}

	func fitCrumbButtonsInView() {
		crumbsAreClipped = false

		while crumbButtonsWidth > bounds.width {
			crumbButtons.remove(at: 0)
			crumbsAreClipped = true
		}
	}

	func clearCrumbButtons() {
		for button in crumbButtons {
			button.removeFromSuperview()
		}

		crumbButtons = [ZBreadcrumbButton]()
	}

	func updateCrumbButtons() {
		clearCrumbButtons()

		for (index, zone) in gBreadcrumbs.crumbZones.enumerated() {
			let  button = ZBreadcrumbButton(title: zone.unwrappedName, target: self, action: #selector(crumbButtonAction(_:)))
			let   title = NSMutableAttributedString(string: zone.unwrappedName)
			let   range = NSRange(location:0, length: title.length)
			button.zone = zone
			button.font = gFavoritesFont
			button.tag  = index
			button.isBordered = false

			title.addAttributes([.font : gFavoritesFont], range: range)

			if  let color = zone.color {
				title.addAttributes([.foregroundColor : color], range: range)
			}

			button.attributedTitle = title

			crumbButtons.append(button)
		}

		fitCrumbButtonsInView()
	}

	func layoutCrumbButtons() {
		var   prior : ZButton?
		let buttons = crumbButtons

		for button in buttons {
			addSubview(button)
			button.snp.makeConstraints { make in
				if  let previous = prior {
					make.left.equalTo(previous.snp.right).offset(3.0)
				} else {
					make.left.equalTo(self)
				}

				let title = button.title
				let width = title.rect(using: button.font!, for: NSRange(location: 0, length: title.length), atStart: true).width + 16.0

				make.width.equalTo(width)
				make.centerY.equalToSuperview()
			}

			prior = button
		}
	}

	func updateAndRedraw() {
		dbIndicatorButton?.isHidden = !gIsGraphOrEditIdeaMode
		dbIndicatorButton?.title    = gDatabaseID == .everyoneID ? "e" : "m"
		clipCrumbsButton?.image     = !crumbsAreClipped ? nil : ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)

		updateCrumbButtons()
		layoutCrumbButtons()
		setNeedsDisplay()
		setNeedsLayout()
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
		gGraphEditor.redrawGraph()
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

			self.signal([.sSwap, .sRelayout])
		}
	}

}
