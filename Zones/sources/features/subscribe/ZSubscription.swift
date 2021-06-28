//
//  ZSubscription.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/17/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gSubscription = ZSubscription()
var gIsSubscriptionEnabled : Bool { return gUserIsExempt || gSubscription.update() != .sExpired }

class ZSubscription: NSObject {

	func setup() {
		gProducts.fetch()
		if  var   t = zToken {
			t.state = .sExpired
			zToken  = t
		} else {
			zToken  = ZToken(date: Date(), type: .pFree, state: .sStartup, value: nil)
		}
	}

	@discardableResult func update() -> ZSubscriptionState {  // called once a minute from timer started in setup above
		if  let        token  = zToken {
			if  !gUserIsExempt,
				let  changed  = token.newToken { // non-nil means changed
				zToken        = changed
				let newState  = changed.state
				if  newState == .sExpired {
					showExpirationAlert()                // license timed out, show expired alert
				}

				return newState
			}

			return token.state
		}

		return .sStartup
	}

	var status: String {
		if  let z = zToken {
			let s = z.state.title
			let t = z.type.duration
			let d = z.date.easyToReadDateTime
			let r = "Purchased \(d)\n\n\(t)"
			if  z.state == .sSubscribed {
				return r
			}

			return "\(r) (\(s))"
		}

		return "Unsubscribed"
	}

	var zToken: ZToken? {
		get { return licenseToken?.asZToken }
		set { licenseToken = newValue?.asString }
	}

	var licenseToken: String? {
		set { newValue?.data(using: .utf8)?.storeFor(kSubscriptionToken) }
		get {
			if  let d = Data.loadFor(kSubscriptionToken) {
				return String(decoding: d, as: UTF8.self)
			}

			return nil
		}
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
						  "Purchase a subscription",
						  "No thanks, the limited features are perfect") { status in
			if  status              == .sYes {
				gShowDetailsView     = true
				gShowMySubscriptions = false

				gDetailsController?.showViewFor(.vSubscribe)
			}
		}
	}

}

enum ZSubscriptionState: String {

	case sReady      = "r"
	case sStartup    = "-"
	case sWaiting    = "w"
	case sExpired    = "x"
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

struct ZToken {

	var  date: Date
	var  type: ZProductType
	var state: ZSubscriptionState
	var value: String?

	var newState: ZSubscriptionState {
		let  duration = Int(Date().timeIntervalSince(date))
		let threshold = gSubscriptionTimeout ? kOneMinute : type.threshold
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
			let        type = ZProductType      (rawValue:  typeValue) ?? .pFree
			let       value : String? = valueString == "-" ? nil : valueString

			return ZToken(date: date, type: type, state: state, value: value)
		}

		return nil
	}

}
