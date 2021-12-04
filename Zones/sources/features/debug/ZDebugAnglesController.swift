//
//  ZDebugAnglesController.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/2/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

var gDebugAnglesController : ZDebugAnglesController? { return gControllers.controllerForID(.idDebugAngles) as? ZDebugAnglesController }

class ZDebugAnglesController: ZGenericController {

	override  var       controllerID : ZControllerID { return .idDebugAngles }
	@IBOutlet var         outerAngle : ZSliderLabelCombo?
	@IBOutlet var       centralAngle : ZSliderLabelCombo?
	@IBOutlet var    deltaAdjustment : ZSliderLabelCombo?
	@IBOutlet var fractionAdjustment : ZSliderLabelCombo?

	override func awakeFromNib() {
		super.awakeFromNib()

		let closure : IntIntClosure = { (id, value) in
			if  let comboId = ZDebugAnglesID(rawValue: id) {
				let  dValue = Double(value)
				switch comboId {
					case .aDelta:    gAnglesDelta    = dValue
					case .aFraction: gAnglesFraction = dValue // 100.0
					default:         break
				}

				gRelayoutMaps()
			}
		}

		centralAngle?      .closure = closure
		outerAngle?        .closure = closure
		deltaAdjustment?   .closure = closure
		fractionAdjustment?.closure = closure
	}

}
