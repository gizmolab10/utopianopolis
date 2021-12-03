//
//  ZDebugAnglesController.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/2/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZDebugAnglesID: Int {
	case aCentral
	case aOuter
}

var gDebugAnglesController : ZDebugAnglesController? { return gControllers.controllerForID(.idDebugAngles) as? ZDebugAnglesController }

class ZDebugAnglesController: ZGenericController {

	override  var       controllerID : ZControllerID { return .idDebugAngles }
	@IBOutlet var     outerAngleText : ZTextField?
	@IBOutlet var   centralAngleText : ZTextField?
	@IBOutlet var   outerAngleSlider : ZSlider?
	@IBOutlet var centralAngleSlider : ZSlider?

	@IBAction func handleTextAction(_ text: ZTextField) {
		if  let value = text.text?.integerValue,
			let    id = ZDebugAnglesID(rawValue: text.tag) {
			switch id {
				case .aCentral: centralAngleSlider?.integerValue = value
				default:          outerAngleSlider?.integerValue = value
			}
		}
	}

	@IBAction func handleSliderAction(_ slider: ZSlider) {
		let     value = String(slider.integerValue)
		if  let    id = ZDebugAnglesID(rawValue: slider.tag) {
			switch id {
				case .aCentral: centralAngleText?.text = value
				default:          outerAngleText?.text = value
			}
		}
	}

}
