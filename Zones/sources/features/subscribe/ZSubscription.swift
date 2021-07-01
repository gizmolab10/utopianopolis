//
//  ZSubscription.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/17/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gSubscription = ZSubscription()
var gIsSubscriptionEnabled : Bool { return gSubscription.zToken?.state != .sExpired }

class ZSubscription: NSObject {

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

	// MARK:- delegation
	// MARK:-

	func purchaseStarted() {

	}

	func purchaseSucceeded(type: ZProductType, state: ZSubscriptionState, on date: Date?) {
		zToken = ZToken(date: date ?? Date(), type: type, state: state, value: nil)

		gSignal([.spSubscription])
	}

	func purchaseFailed(_ error: Error?) {
		noop()
	}

}
