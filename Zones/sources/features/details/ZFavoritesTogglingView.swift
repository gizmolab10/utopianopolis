//
//  ZFavoritesTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/13/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

class ZFavoritesTogglingView : ZTogglingView {

	@IBOutlet var buttonsView : ZView?
	@IBOutlet var rightButton : ZButton?
	@IBOutlet var  leftButton : ZButton?

	@IBAction override func buttonAction(_ button: ZButton) {
		switch identity {
			case .vFavorites: gFavoritesCloud.showNextList(down: button == leftButton)
			default:          super.buttonAction(button)
		}
	}

	func detectUpDownButton(at location: CGPoint, inView: ZView) -> Bool? { // true means down
		if  let right = rightButton,
			let  left = leftButton {
			let  both = [left, right]

			for button in both {
				let  flag = button == left
				let frame = button.convert(button.bounds, to: inView)
				if  frame.contains(location) {
					return flag
				}
			}
		}

		return nil
	}

	func unhighlightButtons() {
		rightButton?.highlight(false)
		leftButton? .highlight(false)
	}

	func highlightButton(_ left: Bool) {
		let button = left ? leftButton : rightButton

		button?.highlight(true)
	}

	override func updateColors() {
		super.updateColors()

		leftButton? .zlayer.backgroundColor = gDarkAccentColor.cgColor
		rightButton?.zlayer.backgroundColor = gDarkAccentColor.cgColor
	}

	override func updateTitleBarButtons() {
		let        bothHidden = gFavoritesCloud.hideButtonsView || hideHideable
		let        leftHidden = gFavoritesCloud.hideLeftButton
		buttonsView?.isHidden = bothHidden

		if !bothHidden {
			leftButton? .attributedTitle = gFavoritesCloud.nextListAttributedTitle(forward: false)
			rightButton?.attributedTitle = gFavoritesCloud.nextListAttributedTitle(forward: true)
		}

		if  let t = titleButton {
			t.snp.removeConstraints()
			t.snp.makeConstraints{ make in
				if  bothHidden {
					make.right.equalToSuperview() .offset(-1.0)
				} else if let v = buttonsView {
					make.right.equalTo(v.snp.left).offset(-1.0)
				}
			}
		}

		if  let d = leftButton {
			d.snp.removeConstraints()
			d.snp.makeConstraints{ make in
				if  leftHidden {
					make.right.equalTo(d.snp.left)
				}
			}
		}
	}

}
