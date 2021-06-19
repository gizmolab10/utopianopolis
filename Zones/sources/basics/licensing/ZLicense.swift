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

class ZLicense: NSObject {

	var licenseToken: String? {

		set { newValue?.data(using: .utf8)?.storeFor(kLicenseToken) }

		get {
			if  let d = Data.loadFor(kLicenseToken) {
				return String(decoding: d, as: UTF8.self)
			}

			return nil
		}
	}

	var userIsExempt: Bool { return false } // gUser?.isExempt ?? false }
	var isEnabled: Bool { return update() != .sTimedout || userIsExempt }

	func setup() {
		if  licenseToken == nil {
			let     date  = Date()
			let    state  = ZLicenseState.sWaiting
			let     type  = ZLicenseType .tNone
			licenseToken  = String.createToken(date, state, type)
		}

		gTimers.startTimers(for: [.tLicense])
	}

	func stateFrom(_ date: Date, _ type: ZLicenseType, _ value: String?) -> ZLicenseState {
		let duration = Date().timeIntervalSince(date)

		if  duration < 45678.0 || userIsExempt {
			return .sWaiting
		} else {
			return .sTimedout
		}
	}

	@discardableResult func update() -> ZLicenseState {       // called once a minute from timer started in setup above
		if  !userIsExempt,
			let token = licenseToken,
			let (date, state, type, value) = token.splitToken() {
			let newState = stateFrom(date, type, value)

			if  newState == .sTimedout {
				showExpirationAlert()          // license timed out, show expired alert
			}

			if  state != newState {
				licenseToken = String.createToken(date, newState, type)    // state has changed, reconstruct token
			}

			return newState
		}

		return ZLicenseState.sInitial
	}

	func showExpirationAlert() {
		gAlerts.showAlert("Please forgive my interruption",
						  "I hope you are enjoying Seriously.\n\nI also hope you can appreciate the loving work I've put into it and my wish to generate an income by it. Because I do see the value of letting you try before you buy, this alert is being shown to you only after a free period of use. During this period all features of Seriously have been enabled.\n\nIf you wish to continue using Seriously for free, some features [editing notes, search and print] will be disabled. If these features are important to you, you can retain them by purchasing a license.",
						  "Purchase a license",
						  "No thanks, the limited features are perfect") { status in
			if  status == .sYes {
				self.purchaseLicense()
			}
		}
	}

	func purchaseLicense() {

	}

}
