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

	var               numberClipped = 0
	var                 showClipper = false
	@IBOutlet var        clipButton : NSButton?
	@IBOutlet var dbIndicatorButton : NSButton?
	@IBOutlet var  heightConstraint : NSLayoutConstraint?
	@IBOutlet var   widthConstraint : NSLayoutConstraint?

	var crumbButtons : [ZButton] {
		var buttons = [ZButton]()

		removeAllSubviews()

		for (index, crumb) in gBreadcrumbs.crumbs.enumerated() {
			let  button = ZButton(title: crumb, target: self, action: #selector(crumbButtonAction(_:)))
			button.font = gFavoritesFont
			button.tag  = index

			buttons.append(button)
			addSubview(button)
		}

		return buttons
	}

	@objc func crumbButtonAction(_ button: ZButton) {
		go(to: button.tag, COMMAND: false)
	}

	func updateCrumbButtons() {
		layoutButtons()
	}

	func layoutButtons() {
		var   prior : ZButton?
		let buttons = crumbButtons

		for button in buttons {
			button.snp.makeConstraints { make in
				if  let previous = prior {
					make.left.equalTo(previous.snp.right).offset(1.0)
				} else {
					make.left.equalToSuperview()
				}

				let t = button.title
				let w = t.rect(using: button.font!, for: NSRange(location: 0, length: t.length), atStart: true).width
				make.width.equalTo(w + 16.0)
				make.centerY.equalToSuperview()
			}

			prior = button
		}
	}

	// MARK:- output
	// MARK:-

	override func draw(_ dirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			super.draw(dirtyRect)
		}
	}

	func updateAndRedraw() {
		dbIndicatorButton?.isHidden = !gIsGraphOrEditIdeaMode
		dbIndicatorButton?.title    = gDatabaseID == .everyoneID ? "e" : "m"
		clipButton?.image           = !showClipper ? nil : ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
		needsDisplay                = true

		layoutButtons()
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
