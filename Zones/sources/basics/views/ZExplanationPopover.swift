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

func gExplanation(showFor key: String? = nil) { gMapView?.explainPopover?.explain(for: key) }

class ZExplanationPopover : ZView {

	@IBOutlet var      hideButton : ZButton?
	@IBOutlet var instructionView : ZTextField?
	@IBOutlet var       titleView : ZTextField?
	var   key : String?
	var  zone :   Zone? { return gSelecting.firstGrab }
	var color :  ZColor { return zone?.color ?? kDefaultIdeaColor.lighter(by: 6.0) }

	func explain(for iKey: String? = nil) {
		key      = iKey
		isHidden = key == nil

		if  let (t, i) = key?.titleAndInstruction {
			applyText(t, to: titleView, isTitle: true)
			applyText(i, to: instructionView)
		}

		relocate()
	}

	func relocate() {
		if  let     s = superview, !isHidden,
			let  rect = zone?.widget?.pseudoTextWidget?.absoluteFrame {
			let point = rect.centerTop

			removeFromSuperview()
			s.addSubview(self) // so is drawn in front of widget text

			snp.removeConstraints()
			snp.makeConstraints { make in
				make.centerX.equalTo(s.snp  .left).offset( point.x)
				make .bottom.equalTo(s.snp.bottom).offset(-point.y)
			}
		}
	}

	func applyText(_ text: String, to control: ZTextField?, isTitle: Bool = false) {
		if  let c = control {
			let a = NSMutableAttributedString(string: text)
			let r = NSRange(location: 0, length: text.length)

			if  isTitle {
				let       s = NSMutableParagraphStyle()
				s.alignment = .center

				a.addAttribute(.strokeWidth,    value: 3.0, range: r)
				a.addAttribute(.paragraphStyle, value: s,   range: r)
			}

			a.addAttribute(.strokeColor, value: color, range: r)
			c.attributedStringValue = a
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		let         delta = 15.0
		let           big = bounds.insetBy(dx: .zero, dy: delta).offsetBy(dx: .zero, dy: delta)
		var         small = bounds.insetBy(dx: (big.width / 2.0) - delta, dy: delta / 1.25)
		small.size.height = delta * 1.25
		let         short = small.offsetBy(dx: .zero, dy: 1.0)
		let          path = ZBezierPath.init(roundedRect: big, xRadius: delta, yRadius: delta)
		let         erase = ZBezierPath.trianglePath(pointingDown: true, in: short)
		path    .flatness = kDefaultFlatness
		path   .lineWidth = 0.7

		path.appendTriangle(pointingDown: true, in: small, full: false)
		gBackgroundColor.setFill()
		color.setStroke()
		path.fill()
		path.stroke()
		erase.fill()
		super.draw(dirtyRect)
	}

}

extension String {

	var titleAndInstruction: (String, String) {
		let state = gIsEditIdeaMode ? "edited" : "selected"
		let  save = gIsEditIdeaMode ? "saves your changes and exits editing" : "begins editing"

		switch self {
			case "a": return ("Foo", "Bar")
			default:  return ("Currently \(state) idea", "Arrow and modifier keys work. TAB creates a sibling idea. RETURN \(save).")
		}
	}

}
