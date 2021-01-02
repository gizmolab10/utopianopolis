//
//  ZReferenceTransformer.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/1/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

let gReferenceTransformerName = NSValueTransformerName(rawValue: "ZReferenceTransformer")

class ZReferenceTransformer: ValueTransformer {

	override class func       transformedValueClass() -> AnyClass { return NSData.self }
	override class func allowsReverseTransformation() -> Bool     { return true }

	override func transformedValue(_ value: Any?) -> Any? {
		return (value as? CKRefrence)?.recordID.recordName.data(using: .ascii)
	}

	override func reverseTransformedValue(_ value: Any?) -> Any? {
		if  let data = value as? Data, let recordName = String(data: data, encoding: .ascii) {
			return CKRefrence(recordID: CKRecordID(recordName: recordName), action: .none)
		}

		return nil
	}

}
