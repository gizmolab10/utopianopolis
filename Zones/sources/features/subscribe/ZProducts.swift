//
//  ZProducts.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import StoreKit

let gProducts = ZProducts()

class ZProducts: NSObject, SKProductsRequestDelegate, SKPaymentQueueDelegate, SKPaymentTransactionObserver {

	let                   queue = SKPaymentQueue.default()
	var                products = [SKProduct]()
	var isSubscriptionAvailable = false

	func setup() {   // fetch product data
		let          ids = Set<String>(ZProductType.all.map {$0.rawValue} )
		let      request = SKProductsRequest(productIdentifiers: ids)
		request.delegate = self

		queue.add(self)
		queue.restoreCompletedTransactions()
		request.start()
	}

	func purchaseProduct(at index: Int) {    // send purchase request
		if  let product = productAt(index) {
			let payment = SKMutablePayment(product: product)
			payment.simulatesAskToBuyInSandbox = true

			queue.add(payment)

			//			if  let type = product.type {
			//				gSubscription.zToken = ZToken(date: Date(), type: type, state: .sSubscribed, value: nil)
		}
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

	// MARK:- delegation
	// MARK:-

	func paymentQueue(_ queue: SKPaymentQueue, shouldContinue transaction: SKPaymentTransaction, in newStorefront: SKStorefront) -> Bool {
		gSignal([.spSubscription])                 // update subscription controller

		return false
	}

	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions: [SKPaymentTransaction]) {
		for transaction in updatedTransactions {
			let  payment = transaction.payment
			let     date = transaction.transactionDate
			if  let type = ZProductType(rawValue: payment.productIdentifier) {
				switch transaction.transactionState {
					case .purchasing:
						gSubscription.purchaseStarted()
					case .failed:
						gSubscription.purchaseFailed(transaction.error)
						queue.finishTransaction(transaction)
					case .purchased:
						queue.finishTransaction(transaction)
						updateSubscriptionStatus()
						gSubscription.purchaseSucceeded(type: type, on: date)
					case .restored:
						queue.finishTransaction(transaction)
						updateSubscriptionStatus()
						gSubscription.purchaseSucceeded(type: type, on: date)
					case .deferred:
						gSubscription.purchaseSucceeded(type: type, on: date)
				}
			}
		}
	}

	func checkSubscriptionAvailability(_ completionHandler: @escaping (Bool) -> Void) {
		guard let receiptUrl = Bundle.main.appStoreReceiptURL,
			  let receipt = try? Data(contentsOf: receiptUrl).base64EncodedString() as AnyObject else {
			completionHandler(false)
			return
		}

//		let sandboxURL = "https:sandbox.itunes.apple.com"

//		let _ = Router.User.sendReceipt(receipt: receipt).request(baseUrl: sandboxURL).responseObject { (response: DataResponse<RTSubscriptionResponse>) in
//			switch response.result {
//				case .success(let value):
//					guard let expirationDate = value.expirationDate,
//						  let productId = value.productId else {completionHandler(false); return}
//					self.expirationDate = expirationDate
//					self.isTrialPurchased = value.isTrial
//					self.purchasedProduct = ProductType(rawValue: productId)
//					completionHandler(Date().timeIntervalSince1970 < expirationDate.timeIntervalSince1970)
//				case .failure(let error):
//					completionHandler(false)
//			}
//		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		gSubscription.purchaseFailed(error)
	}

	func updateSubscriptionStatus() {
		checkSubscriptionAvailability { [weak self] (isSubscribed) in
			self?.isSubscriptionAvailable = isSubscribed
		}
	}

	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		products = response.products
		gSubscriptionController?.rowsChanged = true

		gSignal([.spSubscription])
	}

}

extension SKProduct {

	var type: ZProductType? { return ZProductType(rawValue: productIdentifier) }

}

enum ZProductType: String {
	case     pFree = "com.seriously.promotion"    // missing?
	case    pDaily = "com.seriously.daily"        // missing?
	case   pAnnual = "com.seriously.annual"
	case  pMonthly = "com.seriously.monthly"
	case pLifetime = "com.seriously.lifetime"     // missing?

	static var all: [ZProductType] {
		return [.pFree, .pDaily, .pAnnual, .pMonthly, .pLifetime]
	}

	var title: String { return "\(duration) ($\(cost))" }

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
			case .pAnnual:   return "20.00"
			case .pMonthly:  return "2.50"
			case .pLifetime: return "65"
			default:         return "Free"
		}
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
