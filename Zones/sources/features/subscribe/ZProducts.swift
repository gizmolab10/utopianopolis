//
//  ZProducts.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import StoreKit

enum ZProductType: String {
	case     pFree = "com.seriously.introductory"
	case   pAnnual = "com.seriously.annual"
	case  pMonthly = "com.seriously.monthly"
	case pLifetime = "com.seriously.lifetime"

	static var all: [ZProductType] {
		return [.pFree, .pAnnual, .pMonthly, .pLifetime]
	}

	var title: String { return "\(duration) ($\(cost))" }

	var duration: String {
		switch self {
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

class ZProducts: NSObject, SKProductsRequestDelegate {

	static let shared = ZProducts()
	var      products = [SKProduct]()

	func typeFor(_ index: Int) -> ZProductType {
		let p = products[index]

		return ZProductType(rawValue: p.productIdentifier) ?? .pFree
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

	func purchaseProduct(at index: Int) -> ZToken {
		// send purchase request
		return ZToken(date: Date(), type: typeFor(index), state: .sSubscribed, value: nil)
	}

}
