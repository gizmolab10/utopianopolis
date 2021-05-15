//
//  ZManagedRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let   gReferenceTransformerName = NSValueTransformerName(rawValue: "ZReferenceTransformer")
let  gAssetArrayTransformerName = NSValueTransformerName(rawValue: "ZAssetArrayTransformer")
let gStringArrayTransformerName = NSValueTransformerName(rawValue: "ZStringArrayTransformer")

class ZManagedObject: NSManagedObject {

	convenience init(entityName: String?, databaseID: ZDatabaseID?) {
		let     context = gCoreDataStack.managedContext

		if  let    name = entityName,
			let  entity = NSEntityDescription.entity(forEntityName: name, in: context) {
			self.init(entity: entity, insertInto: context)

			if  let store = gCoreDataStack.persistentStore(for: databaseID) {
				context.assign(self, to: store)
			}
		} else {
			self.init()
		}
	}

	static func uniqueObject(entityName: String, recordName: String?, in dbID: ZDatabaseID) -> ZManagedObject {
		if  let    name = recordName {
			let objects = gCoreDataStack.find(type: entityName, recordName: name, into: dbID)

			if  objects.count > 0 {
				return objects[0]
			}
		}

		return ZManagedObject(entityName: entityName, databaseID: dbID)
	}

}

@objc(ZReferenceTransformer)
class ZReferenceTransformer: ZDataTransformer {

	override class func transformedValueClass() -> AnyClass { return NSData.self }

	override func transformedValue(_ value: Any?) -> Any? {
		return (value as? CKReference)?.recordID.recordName.data(using: .ascii)
	}

	override func reverseTransformedValue(_ value: Any?) -> Any? {
		if  let       data = value as? Data,
			let recordName = String(data: data, encoding: .ascii) {
			return CKReference(recordID: CKRecordID(recordName: recordName), action: .none)
		}

		return nil
	}

}

@objc(ZStringArrayTransformer)
class ZStringArrayTransformer: ZDataTransformer {

	override func transformedValue(_ value: Any?) -> Any? {
		let array = value as! Array<String>
		let  join = array.joined(separator: kArrayTransformSeparator)

		return join.data(using: .ascii)
	}

	override func reverseTransformedValue(_ value: Any?) -> Any? {
		if  let      data = value as? Data,
			let    joined = String(data: data, encoding: .ascii) {
			return joined.components(separatedBy: kArrayTransformSeparator)
		}

		return nil
	}

}

@objc(ZAssetArrayTransformer)
class ZAssetArrayTransformer: ZDataTransformer {

	override func transformedValue(_ value: Any?) -> Any? {
		let array = (value as! Array<CKAsset>).map { $0.fileURL.path }

		return array.joined(separator: kArrayTransformSeparator).data(using: .ascii)
	}

	override func reverseTransformedValue(_ value: Any?) -> Any? {
		if  let       data = value as? Data,
			let     string = String(data: data, encoding: .ascii) {
			let    strings = string.components(separatedBy: kArrayTransformSeparator)
			return strings.map { CKAsset(fileURL: URL(fileURLWithPath: $0)) }
		}

		return nil
	}

}

@objc(ZDataTransformer)
class ZDataTransformer: ValueTransformer {

	override class func       transformedValueClass() -> AnyClass { return NSData.self }
	override class func allowsReverseTransformation() -> Bool     { return true }

}
