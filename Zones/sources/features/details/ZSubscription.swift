//
//  ZSubscription.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/17/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import StoreKit

let gSubscription = ZSubscription()

class ZSubscription: NSObject {

	var    isEnabled: Bool { return update() != .sExpired || gUserIsExempt }
//	private let productIdentifiers: Set<ProductIdentifier>?

	var licenseToken: String? {

		set { newValue?.data(using: .utf8)?.storeFor(kSubscriptionToken) }

		get {
			if  let d = Data.loadFor(kSubscriptionToken) {
				return String(decoding: d, as: UTF8.self)
			}

			return nil
		}
	}

	func setup() {
		if  licenseToken == nil {
			licenseToken  = ZToken(date: Date(), type: .tNone, state: .sStartup, value: nil).asString
		} else if var   t = licenseToken?.asZToken {
			t     .state  = .sStartup
			licenseToken  = t.asString
		}
	}

	@discardableResult func update() -> ZSubscriptionState {  // called once a minute from timer started in setup above
		if  let        token  = licenseToken?.asZToken {
			if  !gUserIsExempt,
				let    zToken = token.newToken {
				licenseToken  = zToken.asString
				let newState  = zToken.state
				if  newState == .sExpired {
					showExpirationAlert()                // license timed out, show expired alert
				}

				return newState
			}

			return token.state
		}

		return .sStartup
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
				gShowDetailsView = true

				gDetailsController?.toggleViewsFor(ids: [.vSubscribe])
			}
		}
	}

}

enum ZSubscriptionState: String {

	case sReady      = "r"
	case sStartup    = "-"
	case sWaiting    = "w"
	case sExpired   = "t"
	case sSubscribed = "s"

	var title: String {
		switch self {
			case .sExpired:    return "expired"
			case .sSubscribed: return "subscribed"
			case .sReady:      return "ready for purchase"
			default:           return "no subscription"
		}
	}

}

enum ZSubscriptionType: String {

	case tNone     = "-"
	case tMonthly  = "m"
	case tAnnual   = "y"
	case tLifetime = "!"

	var title: String {
		switch self {
			case .tAnnual:   return "one year"
			case .tMonthly:  return "one month"
			case .tLifetime: return "forever"
			default:         return "no license"
		}
	}

}

struct ZToken {

	var  date: Date
	var  type: ZSubscriptionType
	var state: ZSubscriptionState
	var value: String?

	var newState: ZSubscriptionState {
		let  duration = Int(Date().timeIntervalSince(date))
		let threshold = gSubscriptionTimeout ? 100 : kOneMonth
		let    isGood = duration < threshold || gUserIsExempt
		return isGood ? .sWaiting : .sExpired
	}

	var newToken: ZToken? {
		let   nState = newState
		let changed  = nState != state
		if  changed  {
			var    t = self
			t.state  = nState

			return t         // state changed, reconstruct token
		}

		return nil
	}

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
			let       state = ZSubscriptionState(rawValue: stateValue) ?? .sExpired
			let        type = ZSubscriptionType (rawValue:  typeValue) ?? .tNone
			let       value : String? = valueString == "-" ? nil : valueString

			return ZToken(date: date, type: type, state: state, value: value)
		}

		return nil
	}

}
