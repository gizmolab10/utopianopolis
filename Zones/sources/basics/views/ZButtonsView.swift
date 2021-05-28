//
//  ZButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZButtonsView : ZView {

	var           clipped : Bool { return false }
	var          centered : Bool { return false }
	var distributeEqually : Bool { return false }
	var           buttons = [ZButton]()

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
		setNeedsDisplay()
		setNeedsLayout()
	}

	func layoutButtons() {
		var prior : ZButton?
		let array = buttons
		let count = array.count
		let   max = count - 1
		let space = 3.0
		let  side = 2.0
		let total = bounds.size.width - CGFloat(space * Double(max)) - CGFloat(side)
		var width = total / CGFloat(count) // use this value when distribute equally = true

		for (index, button) in array.enumerated() {
			addSubview(button)
			button.snp.removeConstraints()
			button.snp.makeConstraints { make in
				if !distributeEqually {
					let title = button.title
					width     = title.rect(using: button.font!, for: NSRange(location: 0, length: title.length), atStart: true).width + 13.0
				}

				make.width.equalTo(width)
				make.centerY.equalToSuperview()

				if  let previous = prior {
					make.left.equalTo(previous.snp.right).offset(space)
				} else {
					make.left.equalTo(self).offset(side)
				}

				if  index == max { // now supply the trailing constraint
					make.right.lessThanOrEqualTo(self) // force window to grow wide enough to fit all breadcrumbs
				}
			}

			prior = button
		}
	}

}
