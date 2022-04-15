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

func gHideExplanation() { gExplanation() }
func gExplanation(showFor key: String? = nil) { gMainController?.explainPopover?.explain(for: key) }

class ZExplanationPopover : ZView {

	@IBOutlet var       titleView : ZTextField?
	@IBOutlet var instructionView : ZTextField?
	@IBOutlet var      hideButton : ZButton?

	@IBAction func hideButtonAction(_ sender: ZButton) { gToggleShowExplanations() }

	func explain(for key: String? = nil) {
		if  let (t, i) = key?.titleAndInstruction, gShowExplanations {
			applyText(t, to: titleView, isTitle: true)
			applyText(i, to: instructionView)

			isHidden = false
		} else {
			isHidden = true
		}

		relocate()
		setNeedsDisplay()
	}

	func relocate() {
		if  let v = gSelecting.firstGrab?.widget?.textWidget, !isHidden {
			snp.removeConstraints()
			snp.makeConstraints { make in
				make .bottom.equalTo(v.snp.bottom)
				make.centerX.equalTo(v.snp.centerX)
			}
		}
	}


	func applyText(_ text: String, to control: ZTextField?, isTitle: Bool = false) {
		if  let c = control {
			let a = NSMutableAttributedString(string: text)
			let r = NSRange(location: 0, length: text.length)

			if  isTitle {
				let       s = kDefaultEssayTextFontSize
				let       f = ZFont(name: "TimesNewRomanPS-BoldMT", size: s) ?? ZFont.systemFont(ofSize: s)
				let       p = NSMutableParagraphStyle()
				p.alignment = .center

				a.addAttribute(.paragraphStyle, value: p,  range: r)
				a.addAttribute(.font,           value: f,  range: r)
			}

			a.addAttribute(.foregroundColor, value: kBlackColor, range: r)

			c.attributedStringValue = a
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		let         delta = CGFloat(15.0)
		let           big = bounds.insetBy(dx: 1.0, dy: delta + 1.0).offsetBy(dx: .zero, dy: delta)
		var         small = bounds.insetBy(dx: (big.width / 2.0) - delta, dy: delta / 1.25)
		let          path = ZBezierPath.init(roundedRect: big, xRadius: delta, yRadius: delta)
		small.size.height = delta * 1.25
		let         short = small.offsetBy(dx: .zero, dy: 1.0)
		let         erase = ZBezierPath.trianglePath(pointingDown: true, in: short)
		path    .flatness = kDefaultFlatness
		path   .lineWidth = 0.7

		path.appendTriangle(pointingDown: true, in: small, full: false)
		gBackgroundColor.setFill()
		kBlackColor.setStroke()
		path.stroke()
		path.fill()
		erase.fill()
		super.draw(dirtyRect)
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
