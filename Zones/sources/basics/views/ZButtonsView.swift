//
//  ZButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZButtonsView : ZView {

	var            clipped : Bool    { return false }
	var           centered : Bool    { return false }
	var distributedEqually : Bool    { return false }
	var            buttons = [ZButton]()

	func setupButtons()  {}
	func updateButtons() {}

	func removeButtons() {
		for button in buttons {
			button.removeFromSuperview()
		}
	}

	func setupAndRedraw() {
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
		let  array = buttons
		let  count = array.count
		let    max = count - 1
		let    gap = 3.0
		let margin = 2.0
		let  total = bounds.size.width - CGFloat(gap * Double(max)) - CGFloat(margin)
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

				if  let p = prior {
					make.left.equalTo(p.snp.right).offset(gap)
				} else {
					make.left.equalToSuperview().offset(margin)
				}

				if  index == max { // now supply the trailing constraint
					make.right.lessThanOrEqualTo(self) // force window to grow wide enough to fit all breadcrumbs
				}
			}

			prior = button
		}
	}

}
