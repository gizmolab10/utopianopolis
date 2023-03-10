//
//  ZFavoritesTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/13/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

class ZFavoritesTogglingView : ZTogglingView {

	@IBOutlet var upDownView : ZView?
	@IBOutlet var downButton : ZButton?
	@IBOutlet var   upButton : ZButton?

	@IBAction override func buttonAction(_ button: ZButton) {
		switch identity {
			case .vFavorites: gFavorites.showNextList(down: button == downButton)
			default:          super.buttonAction(button)
		}
	}

	func detectUpDownButton(at location: CGPoint, inView: ZView) -> Bool? { // true means down
		if  let down = downButton,
			let   up = upButton {
			let both = [down, up]

			for button in both {
				let  flag = button == down
				let frame = button.convert(button.bounds, to: inView)
				if  frame.contains(location) {
					return flag
				}
			}
		}

		return nil
	}

	func unhighlightUpDownButtons() {
		upButton?  .highlight(false)
		downButton?.highlight(false)
	}

	func highlightUpDownButton(_ down: Bool) {
		let button = down ? downButton : upButton

		button?.highlight(true)
	}

	override func updateColors() {
		super.updateColors()

		downButton?.zlayer.backgroundColor = gDarkAccentColor.cgColor
		upButton?  .zlayer.backgroundColor = gDarkAccentColor.cgColor
	}

	override func updateTitleBarButtons() {
		let       bothHidden = gFavorites.hideUpDownView || hideHideable
		let       downHidden = gFavorites.hideDownButton
		upDownView?.isHidden = bothHidden

		if !bothHidden {
			downButton?.attributedTitle = gFavorites.nextListAttributedTitle(down:  true)
			upButton?  .attributedTitle = gFavorites.nextListAttributedTitle(down: false)
		}

		if  let t = titleButton {
			t.snp.removeConstraints()
			t.snp.makeConstraints{ make in
				if  bothHidden {
					make.right.equalToSuperview() .offset(-1.0)
				} else if let v = upDownView {
					make.right.equalTo(v.snp.left).offset(-1.0)
				}
			}
		}

		if  let d = downButton {
			d.snp.removeConstraints()
			d.snp.makeConstraints{ make in
				if  downHidden {
					make.right.equalTo(d.snp.left)
				}
			}
		}

		if  gIsEditIdeaMode {
			gSignal([.spFavoritesMap])
		}
	}

}
