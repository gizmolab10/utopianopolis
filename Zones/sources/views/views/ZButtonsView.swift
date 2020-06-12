//
//  ZButtonsView.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/15/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

class ZButtonsView : ZView {

	var  buttons = [ZButton]()
	var  clipped : Bool { return false }
	var centered : Bool { return false }

	func clearButtons() {
		for button in buttons {
			button.removeFromSuperview()
		}
	}

	func clear() {
		zlayer.backgroundColor = .clear
	}

	func setupButtons() {}

	func updateAndRedraw() {
//		clear()
		clearButtons()
		setupButtons() // customize this in subclass
		layoutButtons()
		setNeedsDisplay()
		setNeedsLayout()
	}

	func layoutButtons() {
		var   prior : ZButton?
		let   array = buttons
		let lastOne = array.count - 1

		for (index, button) in array.enumerated() {
			addSubview(button)
			button.snp.removeConstraints()
			button.snp.makeConstraints { make in
				let title = button.title
				let width = title.rect(using: button.font!, for: NSRange(location: 0, length: title.length), atStart: true).width + 17.0

				make.width.equalTo(width)
				make.centerY.equalToSuperview()

				if  let previous = prior {
					make.left.equalTo(previous.snp.right).offset(3.0)
				} else {
					make.left.equalTo(self)
				}

				if  index == lastOne {
					if  centered {
						make.right.equalTo(self)
					} else if !clipped {
						make.right.lessThanOrEqualTo(self) // force window to grow wide enough to fit all breadcrumbs
					}
				}
			}

			prior = button
		}
	}

}
