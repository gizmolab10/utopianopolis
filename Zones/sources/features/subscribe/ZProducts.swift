//
//  ZProducts.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import StoreKit

class ZProducts: NSObject, SKProductsRequestDelegate, SKPaymentQueueDelegate {

	static let shared = ZProducts()
	var      products = [SKProduct]()

	func typeFor(_ index: Int) -> ZProductType {
		let p = products[index]

		return ZProductType(rawValue: p.productIdentifier) ?? .pFree
	}

	func paymentQueue(_ paymentQueue: SKPaymentQueue, shouldContinue transaction: SKPaymentTransaction, in newStorefront: SKStorefront) -> Bool {
		gSignal([.sDetails])                 // update subscription controller

		return false
	}

	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		products = response.products
		ZSubscriptionController.shared?.rowsChanged = true

		gSignal([.sDetails])
	}

	func fetch() {   // fetch product data
		let          ids = Set<String>(ZProductType.all.map {$0.rawValue} )
		let      request = SKProductsRequest(productIdentifiers: ids)
		request.delegate = self

		request.start()
	}

	func purchaseProduct(at index: Int) {    // send purchase request
		if  index  >= products.count {
			return                           // no such product, should NEVER happen
		}

		let product = products[index]
		let payment = SKMutablePayment(product: product)

		SKPaymentQueue.default().add(payment)
	}

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

	var cost: String {
		switch self {
			case .pAnnual:   return "20.00"
			case .pMonthly:  return "2.50"
			case .pLifetime: return "65"
			default:         return "Free"
		}
	}

}

enum ZProductError: Swift.Error {
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
