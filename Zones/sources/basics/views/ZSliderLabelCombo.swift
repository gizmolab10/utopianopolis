//
//  ZSliderLabelCombo.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/3/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZDebugAnglesID: Int {
	case aCentral
	case aOuter
	case aDelta
	case aFraction

	var         title:          String  { return "\(self)".lowercased().substring(fromInclusive: 1) }
	static var allIDs: [ZDebugAnglesID] { return [.aCentral, .aOuter, .aDelta, .aFraction] }

	static func idForString(_ string: String?) -> ZDebugAnglesID? {
		if  let s = string {
			for id in allIDs {
				if  id.title == s {
					return id
				}
			}
		}

		return nil
	}
}

class ZSliderLabelCombo: ZControl {

	@IBOutlet var     slider : ZSlider?
	@IBOutlet var  textField : ZTextField?
	@IBOutlet var      label : ZTextField?
	var              closure : IntIntClosure?
	var          sliderValue : Int?            { return slider?.integerValue }
	var              comboId : ZDebugAnglesID? { return ZDebugAnglesID.idForString(viewIdentifierString) }

	override func awakeFromNib() {
		super.awakeFromNib()

		if  let s = slider {
			handleSliderAction(s)
		}
	}

	func feedback() {
		if  let value = sliderValue,
			let    id = comboId?.rawValue {
			closure?(id, value)
		}
	}

	@IBAction func handleTextAction(_ text: ZTextField) {
		if  let value = text.text?.integerValue {
			slider?.integerValue = value
			feedback()
		}
	}

	@IBAction func handleSliderAction(_ slider: ZSlider) {
		textField?.text = String(slider.integerValue)
		feedback()
	}

}
