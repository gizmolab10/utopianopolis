//
//  ZManagedRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/8/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

let   gReferenceTransformerName = NSValueTransformerName(rawValue: "ZReferenceTransformer")
let  gAssetArrayTransformerName = NSValueTransformerName(rawValue: "ZAssetArrayTransformer")
let gStringArrayTransformerName = NSValueTransformerName(rawValue: "ZStringArrayTransformer")

typealias ZManagedObject = NSManagedObject

extension ZManagedObject {

	@objc var isActualChild: Bool { return true }

	convenience init(entityName: String?, databaseID: ZDatabaseID) {
		if  let    name = entityName,
			let context = gCDCurrentBackgroundContext,
			let  entity = NSEntityDescription.entity(forEntityName: name, in: context) {
			self.init(entity: entity, insertInto: context)

			if  databaseID == .sharedID {
				noop()
			}

			if  let store = gCoreDataStack.persistentStore(for: databaseID.scope) {
				context.assign(self, to: store)
			}
		} else {
			self.init()
		}
	}

	static func uniqueManagedObject(entityName: String, recordName: String?, in databaseID: ZDatabaseID, checkCDStore: Bool = false) -> ZManagedObject {
		let       check = gIsUsingCD && !gFiles.isReading(for: databaseID)
		if  let    name = recordName, (checkCDStore || check) {
			let objects = gCoreDataStack.find(type: entityName, recordName: name, in: databaseID, onlyOne: true, trackMissing: false)

			if  objects.count > 0 {
				return objects[0]
			}
		}

		return ZManagedObject(entityName: entityName, databaseID: databaseID)
	}

	func isPublicRootDefault(recordName: String = kEmpty, into databaseID: ZDatabaseID) -> Bool {
		if  recordName == kRootName, databaseID == .everyoneID,
			let zone = self as? Zone, zone.zoneName == kFirstIdeaTitle {
			return true
		}
		return false
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
		let array = (value as! Array<CKAsset>).map { $0.fileURL!.path }

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
