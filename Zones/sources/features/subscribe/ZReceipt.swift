//
//  ZReceipt.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/3/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation
import Security // CMSDecode

let gReceipt = ZReceipt()

class ZReceipt: NSObject {

//	let d = CMSDecoder()

	var currentReceipt: String? {
		if  let  receiptUrl = Bundle.main.appStoreReceiptURL,
			let receiptData = try? Data(contentsOf: receiptUrl) {
			return receiptData.base64EncodedString()
		}

		return nil
	}

	func unravelReceiptDict(_ dict: ZStringAnyDictionary, transactionID: String?, _ receipt: String) -> ZToken? {
		if  transactionID == nil || transactionID != dict.transactionID {
			return dict.createZToken(with: receipt)
		}

		return nil
	}

	func localValidateForID(_ transactionID: String?, _ onCompletion: ZTokenClosure? = nil) {
		if  let  receipt = currentReceipt,
			let  derData = Data(base64Encoded: receipt, options: .ignoreUnknownCharacters),
			let     cert = SecCertificateCreateWithData(nil, derData as CFData) {
			print(cert)
		}
	}

	func remoteValidateForID(_ transactionID: String?, _ onCompletion: ZTokenClosure? = nil) {
		if  let       receipt = currentReceipt {
			let    sandboxURL = "sandbox.itunes.apple.com"
			let productionURL = "buy.itunes.apple.com"

			for baseURL in [productionURL, sandboxURL] {
				sendReceipt(receipt, to: baseURL) { responseDict in
					if  let status  = (responseDict["status"] as? NSNumber)?.intValue, status == 0 {
						onCompletion?(self.unravelReceiptDict(responseDict, transactionID: transactionID, receipt))
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

	func createZToken(with receipt: String) -> ZToken? {
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
