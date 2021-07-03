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

	var hasEnabledSubscription: Bool {
		return zToken?.state != .sExpired
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

	var currentReceipt: String? {
		if  let  receiptUrl = Bundle.main.appStoreReceiptURL,
			let receiptData = try? Data(contentsOf: receiptUrl) {
			return receiptData.base64EncodedString()
		}

		return nil
	}

	func teardown() {
		queue.remove(self)
	}

	func setup() {   // fetch product data
		queue.add(self) // for paymentQueue callbacks
		queue.restoreCompletedTransactions()
		fetchProducts()
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
			}
		}
	}

	// MARK:- delegation
	// MARK:-

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
					case .deferred:   purchaseSucceeded(type: type, state: .sDeferred,   on: date)
					default:          purchaseSucceeded(type: type, state: .sSubscribed, on: date, value: currentReceipt)
				}
			}
		}
	}

	func purchaseSucceeded(type: ZProductType, state: ZSubscriptionState, on date: Date?, value: String? = nil) {
		validateCurrentReceipt()
		gSignal([.spSubscription])
	}

	func purchaseStarted() {
		print("purchaseStarted")
	}

	func purchaseFailed(_ error: Error?) {
		var suffix  = ""
		if  let e   = error {
			suffix  = ": \(e)"
		}

		print("purchaseFailed" + suffix)
	}

	// MARK:- internals
	// MARK:-

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

	// MARK:- receipts
	// MARK:-

	func validateCurrentReceipt(_ onCompletion: BoolClosure? = nil) {
		if  let       receipt = currentReceipt {
			let    sandboxURL = "sandbox.itunes.apple.com"
			let productionURL = "buy.itunes.apple.com"

			for baseURL in [productionURL, sandboxURL] {
				sendReceipt(receipt, to: baseURL) { responseDict in
					if  let status  = (responseDict["status"] as? NSNumber)?.intValue {
						if  status == 0 {
							self.unravelReceiptDict(responseDict, receipt)
						}
					}
				}
			}
		}
	}

	func sendReceipt(_ receipt: String, to baseURL: String, _ onCompletion: ZDictionaryClosure? = nil) {
		if  let     url = URL(string: "https://\(baseURL)/verifyReceipt") {
			let session = URLSession(configuration: .default)
			let    dict = ["receipt-data": receipt, "password": kSubscriptionSecret] as [String : Any]
			var request = URLRequest(url: url)
			request.httpMethod = "POST"

			do {
				request.httpBody = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
			} catch {
				print("ERROR: " + error.localizedDescription)
			}

			let task : URLSessionDataTask = session.dataTask(with: request) { data, response, error in
				do {
					let jsonDict = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as! ZStringAnyDictionary

					onCompletion?(jsonDict)

				} catch {
					print("ERROR: " + error.localizedDescription)
				}
			}

			task.resume()
		}
	}

	func unravelReceiptDict(_ dict: ZStringAnyDictionary, _ receipt: String) {
		guard let          t = zToken,
			let            i = dict.transactionID,
			t.transactionID == i else {
			zToken           = dict.createZToken(receipt)

			return
		}
	}

}

extension ZStringAnyDictionary {

	var transactionID: String? { return inAppDict?["original_transaction_id"] as? String }

	var inAppDict: ZStringAnyDictionary? {
		if  let  receipt =    self["receipt"]   as? ZStringAnyDictionary,
			let bundleID = receipt["bundle_id"] as? String, bundleID == "com.seriously.mac",
			let    inApp = receipt["in_app"]    as? [ZStringAnyDictionary], inApp.count > 0 {
			return inApp[0]
		}

		return nil
	}

	func createZToken(_ receipt: String) -> ZToken? {
		if  let        dict = inAppDict,
			let   productID = dict["product_id"] as? String,
			let productType = ZProductType(rawValue: productID),
			let  dateString = dict["original_purchase_date_ms"] as? String,
			let   dateValue = Double(dateString) {
			let receiptDate = Date(timeIntervalSince1970: dateValue / 1000.0)

			return ZToken(date: receiptDate, type: productType, state: .sSubscribed, transactionID: transactionID, value: receipt)
		}

		return nil
	}

}

// MARK:- state and tokens
// MARK:-

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

	var title: String { return "\(duration) (\(cost))" }

	var duration: String {
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
		let time   = type.duration
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
