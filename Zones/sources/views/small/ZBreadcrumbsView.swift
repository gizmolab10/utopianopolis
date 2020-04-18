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

	var               numberClipped =  0
	var                 showClipper =  false
	var                crumbButtons = [ZButton]()
	@IBOutlet var        clipButton :  ZButton?
	@IBOutlet var dbIndicatorButton :  ZButton?
	@IBOutlet var  heightConstraint : NSLayoutConstraint?
	@IBOutlet var   widthConstraint : NSLayoutConstraint?

	func clearCrumbButtons() {
		for button in crumbButtons {
			button.removeFromSuperview()
		}

		crumbButtons = [ZButton]()
	}

	func setupCrumbButtons() {
		clearCrumbButtons()

		for (index, zone) in gBreadcrumbs.crumbZones.enumerated() {
			let  button = ZButton(title: zone.unwrappedName, target: self, action: #selector(crumbButtonAction(_:)))
			let   title = NSMutableAttributedString(string: zone.unwrappedName)
			let   range = NSRange(location:0, length: title.length)
			button.font = gFavoritesFont
			button.tag  = index
			button.cell?.backgroundStyle = .raised

			title.addAttributes([.font : gFavoritesFont], range: range)

			if  let color = zone.color {
				title.addAttributes([.foregroundColor : color], range: range)
			}

			button.attributedTitle = title

			crumbButtons.append(button)
		}
	}

	var crumbButtonsWidth: CGFloat {
		var width = CGFloat(0.0)

		for button in crumbButtons {
			width += button.bounds.width
		}

		return width
	}

	func sizeCrumbButtonsToFit() {
		while crumbButtonsWidth > bounds.width {
			crumbButtons.remove(at: 0)
		}
	}

	func layoutCrumbButtons() {
		var   prior : ZButton?
		let buttons = crumbButtons

		for button in buttons {
			addSubview(button)
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

	func updateAndRedraw() {
		dbIndicatorButton?.isHidden = !gIsGraphOrEditIdeaMode
		dbIndicatorButton?.title    = gDatabaseID == .everyoneID ? "e" : "m"
		clipButton?.image           = !showClipper ? nil : ZImage(named: kTriangleImageName)?.imageRotatedByDegrees(gClipBreadcrumbs ? 90.0 : -90.0)
		needsDisplay                = true

		setupCrumbButtons()
		sizeCrumbButtonsToFit()
		layoutCrumbButtons()
	}

	override func draw(_ dirtyRect: NSRect) {
		if  gIsReadyToShowUI {
			super.draw(dirtyRect)
		}
	}

	// MARK:- events
	// MARK:-

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
		go(to: button.tag, COMMAND: false)
	}

}
