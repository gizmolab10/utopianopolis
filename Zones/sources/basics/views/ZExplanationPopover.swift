//
//  ZExplanationPopover.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/25/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var  gExplainPopover: ZExplanationPopover?    { return gMainController?.explainPopover }
func gExplanation(showFor key: String? = nil) { gExplainPopover?.explain(for: key) }
func gHideExplanation()                       { gExplanation() }

class ZExplanationPopover : ZView {

	@IBOutlet var       titleView : ZTextField?
	@IBOutlet var instructionView : ZTextField?
	@IBOutlet var      hideButton : ZButton?
	var                currentKey : String?

	@IBAction func hideButtonAction(_ sender: ZButton) { gToggleShowExplanations() }
	func reexplain() { explain(for: currentKey) }      // adjust for dark mode and changing preferences

	func explain(for key: String? = nil) {
		currentKey     = key
		if  let (t, i) = key?.titleAndInstruction, gShowExplanations {
			applyText(t, to: titleView, isTitle: true)
			applyText(i, to: instructionView)

			isHidden = false
		} else {
			isHidden = true
		}

		if  let v = gSelecting.firstGrab()?.widget?.textWidget, !isHidden {
			snp.removeConstraints()
			snp.makeConstraints { make in
				make .bottom.equalTo(v.snp.centerY) // .offset(gMapController?.dotHalfHeight ?? (kDefaultDotHeight / 2.0))
				make.centerX.equalTo(v.snp.centerX)
			}
		}

		setNeedsDisplay()
	}

	func applyText(_ text: String, to control: ZTextField?, isTitle: Bool = false) {
		if  let c = control {
			let a = NSMutableAttributedString(string: text)
			let r = NSRange(location: 0, length: text.length)

			if  isTitle {
				let             s = kDefaultEssayTextFontSize
				let             f = ZFont(name: "TimesNewRomanPS-BoldMT", size: s) ?? ZFont.systemFont(ofSize: s)
				let             p = NSMutableParagraphStyle()
				p      .alignment = .center
				c.backgroundColor = gSelecting.currentMoveable.color ?? gBackgroundColor.inverted

				a.addAttribute(.font,            value: f,                                   range: r)
				a.addAttribute(.paragraphStyle,  value: p,                                   range: r)
				a.addAttribute(.foregroundColor, value: gBackgroundColor,                    range: r)
			} else {
				a.addAttribute(.foregroundColor, value: gIsDark ? kWhiteColor : kBlackColor, range: r)
			}

			c.attributedStringValue = a
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		let         delta = CGFloat(15.0)
		let   strokeColor = gIsDark ? kWhiteColor : kBlackColor
		let titleBarColor = gSelecting.currentMoveableMaybe?.color ?? gAccentColor
		let           big = bounds.insetBy(dx: 1.0, dy: delta + 1.0).offsetBy(dx: .zero, dy: delta)
		var         small = bounds.insetBy(dx: (big.width / 2.0) - delta, dy: delta / 1.25)
		var           top = big
		let          path = ZBezierPath.init(roundedRect: big, xRadius: delta, yRadius: delta)
		path    .flatness = kDefaultFlatness
		path   .lineWidth = 0.7
		top     .origin.y = big.height
		top  .size.height = 37.0
		small.size.height = delta * 1.25
		let         short = small.offsetBy(dx: .zero, dy: 1.0)
		let         erase = ZBezierPath.trianglePath(pointingDown: true, in: short)
		let         title = ZBezierPath(rect: top)

		path.appendTriangle(pointingDown: true, in: small, full: false)
		gBackgroundColor.setFill()
		strokeColor.setStroke()
		path.stroke()
		path.fill()
		erase.fill() // remove line between oval rect and triangle and any text clipped by triangle
		path.setClip()
		title.addClip()
		titleBarColor.setFill()
		title.fill()
		reexplain()              // adjust for dark mode, if needed
		super.draw(dirtyRect)    // draw text
	}

}

extension String {

	var titleAndInstruction: (String, String)? {
		if  gIsEssayMode { return nil }

		let  state = gIsEditIdeaMode ? "edited" : "selected"
		let   save = gIsEditIdeaMode ? "save your changes and exit editing" : "begin editing"
		let plural = gSelecting.currentMapGrabs.count < 2 ? "" : "s"

		switch self {
			case "e", "y": return nil
			default:       return ("Currently \(state) idea\(plural)", "Press RETURN to \(save), or press TAB to edit a new sibling idea.")
		}
	}

}
