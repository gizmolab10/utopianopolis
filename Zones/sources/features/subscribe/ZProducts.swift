//
//  ZProducts.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import CryptoKit
import StoreKit

let gProducts = ZProducts()

class ZProducts: NSObject, SKProductsRequestDelegate, SKPaymentQueueDelegate, SKPaymentTransactionObserver {

	let    queue = SKPaymentQueue.default()
	var products = [SKProduct]()
	var acquired : String { return zToken?.acquired ?? kEmpty }
	var   status : String { return zToken?.status   ?? kTryThenBuy }

	var expires : String {
		if !hasEnabledSubscription {
			return "Expired"
		} else if let e = expiresOn {
			return "Expires at \(e.easyToReadDateTime)"
		} else {
			return "Never Expires"
		}
	}

	var expiresOn: Date? {
		if  let d = zToken?.type.duration {
			return zToken?.date.advanced(by: d)
		} else {
			return nil
		}
	}

	var hasEnabledSubscription: Bool {
		return false // true // zToken != nil && zToken!.state != .sExpired
	}

	var zToken: ZToken? {
		get { return zTokenString?.asZToken }
		set { zTokenString = newValue?.asString }
	}

	var zTokenString: String? {
		set { newValue?.data(using: .utf8)?.storeFor(kSubscriptionToken) }
		get {
			if  let d = Data.loadFor(kSubscriptionToken) {
				return String(decoding: d, as: UTF8.self)
			}

			return nil
		}
	}

	func teardown() {
		queue.remove(self)
	}

	func fetchProductData() {   // fetch product data
		queue.add(self) // for paymentQueue callbacks
		queue.restoreCompletedTransactions()
		fetchProducts()
		validateCurrentReceipt()
	}

	func updateForSubscriptionChange() { // called every hour by a timer started in startup
		// examine newly arrived data
	}

	func fetchProducts() {
		let          ids = Set<String>(ZProductType.all.map {$0.rawValue} )
		let      request = SKProductsRequest(productIdentifiers: ids)
		request.delegate = self // productsRequest is the delegate callback

		request.start()
	}

	func purchaseProduct(at index: Int) {    // send purchase request
		if  let product = productAt(index) {
			let payment = SKMutablePayment(product: product)

			queue.add(payment) // always fails!
		}
	}

	func showExpirationAlert() {
		gAlerts.showAlert("Please forgive my interruption", [
							"I hope you are enjoying Seriously.", [
								"I also hope you can appreciate the loving work I've put into it and my wish to generate an income by it.",
								"Because I do see the value of letting you \(kTryThenBuy),",
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
				gSignal([.spSubscription, .sDetails])
			}
		}
	}

	// MARK: - delegation
	// MARK: -

	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		products = response.products
		gSubscriptionController?.rowsChanged = true

		gSignal([.spSubscription])                 // update subscription controller
	}

	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		purchaseFailed(error)
	}

	func paymentQueue(_ queue: SKPaymentQueue, shouldContinue transaction: SKPaymentTransaction, in newStorefront: SKStorefront) -> Bool {
		gSignal([.spSubscription])                 // update subscription controller

		return false  // THIS METHOD IS NEVER CALLED
	}

	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions: [SKPaymentTransaction]) {
		for transaction in updatedTransactions {
			let   payment = transaction.payment
			let      date = transaction.transactionDate
			if  let  type = ZProductType(rawValue: payment.productIdentifier) {
				let state = transaction.transactionState

				switch state {
					case .deferred,
						 .purchasing: break
					default:          queue.finishTransaction(transaction)
				}

				switch state {
					case .purchasing: purchaseStarted()
					case .failed:     purchaseFailed(transaction.error)
					case .deferred:   purchaseDeferred()
					default:          purchaseSucceeded(type: type, state: .sSubscribed, on: date)
				}
			}
		}
	}

	func validateCurrentReceipt() {
		gReceipt.remoteValidateForID(zToken?.transactionID) { token in
			if  let  t = token {
				self.zToken = t

				gSignal([.spSubscription])
			}
		}
	}

	func purchaseSucceeded(type: ZProductType, state: ZSubscriptionState, on date: Date?) {
	}

	func purchaseStarted() {
		print("purchaseStarted")
	}

	func purchaseDeferred() {
		print("purchaseDeferred")
	}

	func purchaseFailed(_ error: Error?) {
		var suffix  = ""
		if  let e   = error {
			suffix  = ": \(e)"
		}

		print("purchaseFailed" + suffix)
	}

	// MARK: - internals
	// MARK: -

	func productAt(_ index: Int) -> SKProduct? {
		if index >= products.count { return nil }

		return products[index]
	}

	func typeFor(_ index: Int) -> ZProductType {
		var type  = ZProductType.pFree
		if  let i = productAt(index)?.productIdentifier,
			let t = ZProductType(rawValue: i) {
			type  = t
		}

		return type
	}

}

// MARK: - state and tokens
// MARK: -

extension SKProduct {

	var type: ZProductType? { return ZProductType(rawValue: productIdentifier) }

}

enum ZProductType: String {
	case     pFree = "com.seriously.promotion"    // missing?
	case    pDaily = "com.seriously.daily"
	case   pAnnual = "com.seriously.annual"
	case  pMonthly = "com.seriously.monthly"
	case pLifetime = "com.seriously.lifetime"

	static var all: [ZProductType] {
		return [.pFree, .pDaily, .pAnnual, .pMonthly, .pLifetime]
	}

	var isAutoRenew: Bool {
		switch self {
			case .pMonthly,
				 .pAnnual: return true
			default:       return false
		}
	}

	var title: String { return "\(durationString) (\(cost))" }

	var duration: Double {
		switch self {
			case .pDaily:    return Double(kOneDay)
			case .pAnnual:   return Double(kOneYear)
			case .pMonthly:  return Double(kOneMonth)
			default:         return .nan
		}
	}

	var durationString: String {
		switch self {
			case .pDaily:    return "One Day"
			case .pAnnual:   return "One Year"
			case .pMonthly:  return "One Month"
			case .pLifetime: return "Lifetime"
			default:         return "Introductory"
		}
	}

	var threshold: Int {
		switch self {
			case .pDaily:    return kOneDay
			case .pAnnual:   return kOneYear
			case .pMonthly:  return kOneMonth
			default:         return Int.max
		}
	}

	var cost: String {
		switch self {
			case .pDaily:    return  "$0.99"
			case .pAnnual:   return "$24.99"
			case .pMonthly:  return  "$2.49"
			case .pLifetime: return "$64.99"
			default:         return   "Free"
		}
	}

}

enum ZSubscriptionState: Int {

	case sExpired    = -1
	case sWaiting    =  0
	case sDeferred   =  1
	case sSubscribed =  2

	var title: String {
		switch self {
			case .sExpired:    return "expired"
			case .sDeferred:   return "deferred"
			case .sSubscribed: return "subscribed"
			default:           return kTryThenBuy
		}
	}

}

struct ZToken {

	var          date : Date
	var          type : ZProductType
	var         state : ZSubscriptionState
	var transactionID : String?
	var         value : String?
	var      acquired : String { return "Acquired \(date.easyToReadDateTime)" }

	var asString: String {
		var array = StringsArray()

		array.append("\(date.timeIntervalSinceReferenceDate)")
		array.append("\(state.rawValue)")
		array.append("\(type .rawValue)")
		array.append(transactionID ?? "-")
		array.append(value         ?? "-")

		return array.joined(separator: kColonSeparator)
	}

	var status: String {
		let time   = type.durationString
		if  state == .sSubscribed {
			return time
		}

		return "\(time) (\(state.title))"
	}

}

extension String {

	var asZToken: ZToken? {
		let array           = components(separatedBy: kColonSeparator)
		if  array.count     > 4,
			let   dateValue = Double(array[0]),
			let  stateValue =    Int(array[1]) {
			let   typeValue =        array[2]
			let    idString =        array[3]
			let valueString =        array[4]
			let        date = Date(timeIntervalSinceReferenceDate: dateValue)
			let       state = ZSubscriptionState(rawValue: stateValue) ?? .sExpired
			let        type = ZProductType      (rawValue:  typeValue) ?? .pFree
			let       value : String? = valueString == "-" ? nil : valueString
			let     xtranID : String? = idString == "-" ? nil : idString

			return ZToken(date: date, type: type, state: state, transactionID: xtranID, value: value)
		}

		return nil
	}

}

enum ZProductError : Error {
	case noSubscriptionPurchased
	case noProductsAvailable

	var localizedDescription: String {
		switch self {
			case .noSubscriptionPurchased:
				return "No subscription purchased"
			case .noProductsAvailable:
				return "No products available"
		}
	}
}
