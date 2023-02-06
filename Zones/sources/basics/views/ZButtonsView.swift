//
//  ZButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZButtonsView : ZView {

	var            clipped : Bool { return false }
	var           centered : Bool { return false }
	var distributedEqually : Bool { return false }
	var  verticalLineIndex : Int? { return nil }
	var            buttons = [ZButton]()

	func updateButtons() {}

	func setupButtons() {
		removeButtons()
	}

	func removeButtons() {
		for button in buttons {
			button.removeFromSuperview()
		}
	}

	func setupAndRedraw() {
		zlayer.backgroundColor = kClearColor.cgColor

		setupButtons() // customize this in subclass
		updateAndRedraw()
	}

	func updateAndRedraw() {
		updateButtons()
		layoutButtons()
		setNeedsLayout()
		setNeedsDisplay()
	}

	func layoutButtons() {
		var  prior : ZButton?
		let  plain = verticalLineIndex == nil
		let  array = buttons
		let  count = array.count
		let    max = count - 1
		let margin = plain ? 4.0 : 1.0
		let    gap = plain ? 3.0 : 8.0
		let  extra = plain ? 0.0 : 8.0
		let  total = bounds.size.width - CGFloat(gap * Double(max)) - CGFloat(margin * 2.0) - extra
		var  width = total / CGFloat(count) // use this value when distributing equally

		for (index, button) in array.enumerated() {
			addSubview(button)
			button.snp.removeConstraints()
			button.snp.makeConstraints { make in
				if !distributedEqually {
					let title = button.title
					let range = NSRange(location: 0, length: title.length)
					let  rect = title.rect(using: button.font!, for: range, atStart: true)
					width     = rect.width + 20.0 // why 20?
				}

				make.width.equalTo(width)
				make.centerY.equalToSuperview()

				let offset = gap + ((index == verticalLineIndex) ? extra : 0.0)

				if  let p = prior {
					make.left.equalTo(p.snp.right).offset(offset)
				} else {
					make.left.equalToSuperview()  .offset(margin)
				}

				if  index == max { // now supply the trailing constraint
					make.right.lessThanOrEqualTo(self).offset(margin)
				}
			}

			prior = button
		}
	}

}
