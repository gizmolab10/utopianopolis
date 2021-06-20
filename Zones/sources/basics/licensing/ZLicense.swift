//
//  ZLicense.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/17/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import CryptoKit

let gLicense = ZLicense()

enum ZLicenseState: String {
	case sInitial  = "i"
	case sWaiting  = "w"
	case sTimedout = "t"
	case sLicensed = "l"
}

enum ZLicenseType: String {
	case tNone     = "-"
	case tMonthly  = "m"
	case tAnnual   = "y"
	case tLifetime = "!"
}

struct ZToken {

	var  date: Date
	var  type: ZLicenseType
	var state: ZLicenseState
	var value: String?

}

class ZLicense: NSObject {

	var userIsExempt: Bool { return gUserLicensing ? false : gUser?.isExempt ?? false }
	var    isEnabled: Bool { return update() != .sTimedout || userIsExempt }

	var licenseToken: String? {

		set { newValue?.data(using: .utf8)?.storeFor(kLicenseToken) }

		get {
			if  let d = Data.loadFor(kLicenseToken) {
				return String(decoding: d, as: UTF8.self)
			}

			return nil
		}
	}

	func setup() {
		if  licenseToken == nil {
			let    token  = ZToken(date: Date(), type: ZLicenseType.tNone, state: ZLicenseState.sInitial, value: nil)
			licenseToken  = token.asString
		} else if var   t = licenseToken?.asZToken {
			t     .state  = .sInitial
			licenseToken  = t.asString
		}
	}

	func stateFrom(_ token: ZToken) -> ZLicenseState {
		let  duration = Int(Date().timeIntervalSince(token.date))
		let threshold = gLicenseTimeout ? 100 : kOneMonth
		let    isGood = duration < threshold || userIsExempt
		return isGood ? .sWaiting : .sTimedout
	}

	func stateChangedWithin(_ token: ZToken) -> Bool {
		let newState = stateFrom(token)
		let changed  = newState != token.state
		if  changed  {
			var        t = token
			t.state      = newState
			licenseToken = t.asString         // state changed, reconstruct token
		}

		return changed
	}

	@discardableResult func update() -> ZLicenseState {  // called once a minute from timer started in setup above
		if  let        token  = licenseToken?.asZToken {
			if  !userIsExempt, stateChangedWithin(token),
				let newState  = licenseToken?.asZToken?.state {
				if  newState == .sTimedout {
					showExpirationAlert()                // license timed out, show expired alert
				}

				return newState
			}

			return token.state
		}

		return ZLicenseState.sInitial
	}

	func showExpirationAlert() {
		gAlerts.showAlert("Please forgive my interruption", [
							"I hope you are enjoying Seriously.", [
								"I also hope you can appreciate the loving work I've put into it and my wish to generate an income by it.",
								"Because I do see the value of letting you try before you buy,",
								"this alert is being shown to you only after a free period of use.",
								"During this period all features of Seriously have been enabled."].joined(separator: " "), [
									"If you wish to continue using Seriously for free,",
									"some features [editing notes, search and print] will be disabled.",
									"If these features are important to you,",
									"you can retain them by purchasing a license."].joined(separator: " ")].joined(separator: "\n\n"),
						  "Purchase a license",
						  "No thanks, the limited features are perfect") { status in
			if  status == .sYes {
				self.purchaseLicense()
			}
		}
	}

	func purchaseLicense() {
		licenseToken = ZToken(date: Date(), type: .tMonthly, state: .sLicensed, value: nil).asString
	}

}

extension ZToken {

	var asString: String {
		var array = StringsArray()

		array.append("\(date.timeIntervalSinceReferenceDate)")
		array.append("\(state.rawValue)")
		array.append("\(type .rawValue)")
		array.append(value ?? "-")

		return array.joined(separator: kColonSeparator)
	}

}

extension String {

	var asZToken: ZToken? {
		let array           = components(separatedBy: kColonSeparator)
		if  array.count     > 2,
			let   dateValue = Double(array[0]) {
			let  stateValue = array[1]
			let   typeValue = array[2]
			let valueString = array[3]
			let        date = Date(timeIntervalSinceReferenceDate: dateValue)
			let       state = ZLicenseState(rawValue: stateValue) ?? .sTimedout
			let        type = ZLicenseType (rawValue:  typeValue) ?? .tNone
			let       value : String? = valueString == "-" ? nil : valueString

			return ZToken(date: date, type: type, state: state, value: value)
		}

		return nil
	}

}
