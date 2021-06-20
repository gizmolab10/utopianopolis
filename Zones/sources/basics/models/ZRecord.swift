//  ZRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

class ZRecord: ZManagedObject { // NSObject {

	@NSManaged var             dbid: String?
	@NSManaged var       recordName: String?
	@NSManaged var modificationDate: Date?
	var           databaseID: ZDatabaseID { return ZDatabaseID.convert(from: dbid)! }
	var           kvoContext: UInt8 = 1
	var       _tooltipRecord: Any?
	var    writtenModifyDate: Date?
	var             zRecords: ZRecords? { return gRemoteStorage.zRecords(for: databaseID) }
	var                cloud: ZCloud?   { return zRecords as? ZCloud }
	var  unwrappedRecordName: String    { return recordName ?? kEmpty }
	var        decoratedName: String    { return recordName ?? kNoValue }
	var        unwrappedName: String    { return recordName ?? emptyName }
	var           typePrefix: String    { return kEmpty }
	var            emptyName: String    { return "currently has no name" } // overwritten by subclasses: Zone and ZTrait
	var   isInPublicDatabase: Bool      { return databaseID == .everyoneID }
	var              isAZone: Bool      { return false }
	var            isMapRoot: Bool      { return recordName == kRootName }
	var          isTrashRoot: Bool      { return recordName == kTrashName }
	var        isDestroyRoot: Bool      { return recordName == kDestroyName }
	var        isRecentsRoot: Bool      { return recordName == kRecentsRootName }
	var   isLostAndFoundRoot: Bool      { return recordName == kLostAndFoundName }
	var      isFavoritesRoot: Bool      { return recordName == kFavoritesRootName }
	var      isFavoritesHere: Bool      { return recordName == gFavoritesHereMaybe?.recordName }
	var        isRecentsHere: Bool      { return recordName == gRecentsHereMaybe?.recordName }
	var       isSmallMapHere: Bool      { return isFavoritesHere || isRecentsHere }
	var       isSmallMapRoot: Bool      { return isFavoritesRoot || isRecentsRoot }
	var      isEitherMapRoot: Bool      { return isSmallMapRoot || isMapRoot }
	var           needsCount: Bool      { return  hasState(.needsCount) }
	var           needsColor: Bool      { return  hasState(.needsColor) }
	var         needsDestroy: Bool      { return  hasState(.needsDestroy) }
	var        needsAdoption: Bool      { return  hasState(.needsAdoption) }
	var       needsBookmarks: Bool      { return  hasState(.needsBookmarks) }

	var isARoot: Bool {
		if  recordName == nil {
			return false
		}

		return kRootNames.contains(recordName!)
	}

	// MARK:- overrides
	// MARK:-

	var isAdoptable: Bool { return false }
	var matchesFilterOptions: Bool { return true }
	var cloudProperties: StringsArray { return ZRecord.cloudProperties }
	var optionalCloudProperties: StringsArray { return ZRecord.optionalCloudProperties }
	class var   cloudProperties: StringsArray { return [] }
	class var optionalCloudProperties: StringsArray { return [] }

	func orphan() {}
	func adopt(recursively: Bool = false) {}
	func maybeNeedRoot() {}
	func debug(_  iMessage: String) {}
	func hasMissingChildren() -> Bool { return true }
	func hasMissingProgeny()  -> Bool { return true }
	func ignoreKeyPathsForStorage() -> StringsArray { return [kpParent, kpOwner] }
	func unregister() { cloud?.unregisterZRecord(self) }
	func register() { zRecords?.registerZRecord(self) }

	class func cloudProperties(for className: String) -> StringsArray {
		switch className {
			case kZoneType:     return Zone     .cloudProperties
			case kTraitType:    return ZTrait   .cloudProperties
			case kManifestType: return ZManifest.cloudProperties
			default:			return []
		}
	}

	// MARK:- core data
	// MARK:-

	@discardableResult func updateFromCoreDataHierarchyRelationships(visited: StringsArray?) -> StringsArray { return StringsArray() }

	@discardableResult func convertFromCoreData(visited: StringsArray?) -> StringsArray {
		var         v = visited ?? StringsArray()
		var converted = StringsArray()

		if  let name  = recordName {
			if  v.isEmpty || !v.contains(name) {
				converted.appendUnique(item: name)
				v        .appendUnique(item: name)
			}

			converted.append(contentsOf: updateFromCoreDataHierarchyRelationships(visited: v))
			gStartupController?.fullStartupUpdate()
		}

		return converted
	}

	// MARK:- initialize
	// MARK:-

	static func uniqueFactoryObject(entityName: String, recordName: String?, in dbID: ZDatabaseID) -> ZManagedObject {
		switch entityName {
			case kZoneType:     return Zone     .uniqueZone    (recordName: recordName, in: dbID)
			case kUserType:     return ZUser    .uniqueUser    (recordName: recordName, in: dbID)
			case kTraitType:    return ZTrait   .uniqueTrait   (recordName: recordName, in: dbID)
			case kManifestType: return ZManifest.uniqueManifest(recordName: recordName, in: dbID)
			default:            return ZRecord  .uniqueZRecord (entityName: entityName, recordName: recordName, in: dbID)
		}
	}

	static func uniqueZRecord(entityName: String, recordName: String?, in dbID: ZDatabaseID) -> ZRecord {
		let        zRecord = uniqueObject(entityName: entityName, recordName: recordName, in: dbID) as! ZRecord
		zRecord.recordName = recordName ?? gUniqueRecordName
		zRecord      .dbid = dbID.identifier

		zRecord.register()

		return zRecord
	}

	func copyInto(_ other: ZRecord) {
		for keyPath in cloudProperties {
			let copied = value(forKeyPath: keyPath)

			other.setValue(copied, forKeyPath: keyPath)
		}
	}

    func setupLinks() {}

	func temporarilyOverrideIgnore(_ closure: Closure) {

		// ////////////////////////////////////////////////////////////////// //
		// temporarily overrides subsequent calls to temporarily ignore needs //
		// ////////////////////////////////////////////////////////////////// //

		let         saved = cloud?.ignoreNone ?? false
		cloud?.ignoreNone = true
		closure()
		cloud?.ignoreNone = saved
	}

	// MARK:- needs
	// MARK:-

	func temporarilyMarkNeeds(_ closure: Closure) {
		cloud?.temporarilyForRecordNamed(recordName, ignoreNeeds: false, closure)
	}

	func temporarilyIgnoreNeeds(_ closure: Closure) {

		// ////////////////////////////////////////////// //
		// temporarily causes set needs to have no effect //
		// ////////////////////////////////////////////// //

		cloud?.temporarilyForRecordNamed(recordName, ignoreNeeds: true, closure)
	}

	func stringForNeeds(in iDatabaseID: ZDatabaseID) -> String? {
		if  let       r = recordName,
			let manager = gRemoteStorage.cloud(for: iDatabaseID) {
			let  states = manager.states(for: r)
			var   marks = StringsArray ()

			for state in states {
				marks.append("\(state.rawValue)")
			}

			if  marks.count > 0 {
				return marks.joined(separator: kCommaSeparator)
			}
		}

		return nil
	}

	func addNeedsFromString(_ iNeeds: String) {
		let needs = iNeeds.components(separatedBy: kCommaSeparator)

		temporarilyMarkNeeds {
			for need in needs {
				if  let state = ZRecordState(rawValue: need) {
					addState(state)
				}
			}
		}
	}

    // MARK:- states
    // MARK:-

    func    hasState(_ state: ZRecordState) -> Bool { return zRecords?.isRegistered(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        zRecords?.addZRecord  (self, for:     [state]) }
    func removeState(_ state: ZRecordState)         {        zRecords?.clearRecordName(recordName, for:[state]) }
    func clearAllStates()                           {        zRecords?.clearRecordName(recordName, for: zRecords?.allStates ?? []) }

    func needCount()    { addState(.needsCount) }
	func needAdoption() { addState(.needsAdoption) }
	func needDestroy()  { addState(.needsDestroy) }

	func updateState() {
		setupLinks()
	}

    // MARK:- files
    // MARK:-

    func type(from keyPath: String) -> ZStorageType? {
        func extractType(_ ignored: String) -> (ZStorageType?) {
            let     parts = keyPath.lowercased().components(separatedBy: ignored)

            for     part in parts {
                if  part.length > 0,
                    let type = ZStorageType(rawValue: part) {
                    return type
                }
            }

            return nil
        }

        if      ignoreKeyPathsForStorage().contains(keyPath) { return nil       // must be first ... ZStorageType now ignores owner and parent
		} else if keyPath == kpEssay                         { return .note
		} else if keyPath == kpModificationDate              { return .date
		} else if let type = ZStorageType(rawValue: keyPath) { return type
        } else if let type = extractType(  kpZonePrefix) 	 { return type      // this deals with owner and parent
        } else if let type = extractType(kpRecordPrefix)	 { return type
        } else                                               { return nil
        }
    }

    func extract(valueOf iType: ZStorageType, at iKeyPath: String) -> NSObject? {     // all properties are extracted from record, using iKeyPath as key
        switch iKeyPath {
        case kpRecordName:       return recordName as NSObject?      // except for the record name
        default:                 return value(forKeyPath: iKeyPath) as? NSObject
        }
    }

    func prepare(_ iObject: NSObject, of iType: ZStorageType) -> NSObject? {
        let object = iObject

		switch iType {
			case .link, .parentLink:
				if  let link = object as? String, !link.isValidLink {
					return nil
				}
			case .text:
				if  var string = object as? String { // plain [ causes file read to treat it as an array-starts-here symbol
					string = string.replacingOccurrences(of:  "[",                with: "(")
					string = string.replacingOccurrences(of:  "]",                with: ")")
					string = string.replacingEachString (in: [kDoubleQuote, "“"], with: "'")

					return string as NSObject
				}
			case .assets:
				if  let  assets = object as? [CKAsset] {
					var strings = StringsArray()

					for asset in assets {
						if  let base64 = asset.data?.base64EncodedString() {
							let fileName = asset.fileURL.lastPathComponent

							printDebug(.dImages, "DICT     " + fileName)

							strings.append(fileName + gSeparatorAt(level: 1) + base64)
						}
					}

					if  strings.count != 0 {
						let string = strings.joined(separator: gSeparatorAt(level: 2))

						return string as NSObject
					}
				}

				return nil

			default: break
		}

        return object
    }

	func createStorageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> ZStorageDictionary? {
		guard recordName != nil else {
			printDebug(.dFile, "fubar record name \(self)")

			return nil
		}

		let   keyPaths = cloudProperties + [kpModificationDate, kpDBID] + (includeRecordName ? [kpRecordName] : [])
		let  optionals = optionalCloudProperties + [kpModificationDate]
		var       dict = ZStorageDictionary()

		for keyPath in keyPaths {
			if  let    type = type(from: keyPath),
				let extract = extract(valueOf: type, at: keyPath),
				let  object = prepare(extract, of: type) {
				dict[type]  = object
			} else if !optionals.contains(keyPath){
				printDebug(.dFile, "broken keypath for \"\(self)\" : \(keyPath)")
			}
		}

		if  let   needs  = stringForNeeds(in: iDatabaseID) {
			dict[.needs] = needs as NSObject?
		}

		return dict
    }

	func storageDictionary() throws -> ZStorageDictionary {
		if  let dict = try createStorageDictionary(for: databaseID, includeRecordName: false) {

			return dict
		}

		return [:]
	}

	func extractFromStorageDictionary(_ dict: ZStorageDictionary, of entityName: String, into iDatabaseID: ZDatabaseID) throws {
		FOREGROUND(forced: true) { gStartupController?.fullStartupUpdate() }

		// case 1: name is nil
		// case 2: ck record already exists
		// case 3: name is not nil

		for keyPath in cloudProperties + [kpModificationDate, kpDBID] {
			if  let   type = type(from: keyPath),
				let object = dict[type],
				let  value = object as? CKRecordValue {

				switch type {
					case .type: // convert essay trait to note trait
						if  var string = object as? String,
							let trait = ZTraitType(rawValue: string),
							trait == .tEssay {
							string = ZTraitType.tNote.rawValue
							setValue(string, forKeyPath: keyPath)
						} else {
							setValue(value,  forKeyPath: keyPath)
						}
					case .date:
						if  let      interval = object as? Double {
							writtenModifyDate = Date(timeIntervalSince1970: interval)
						}
					case .assets:
						if  let      assetStrings = (object as? String)?.componentsSeparatedAt(level: 2), assetStrings.count > 0,
							let             trait = self as? ZTrait {
							var            assets = [CKAsset]()
							for assetString in assetStrings {
								let         parts = assetString.componentsSeparatedAt(level: 1)
								if  parts.count   > 1 {
									let  fileName = parts[0]
									let    base64 = parts[1]
									if  let  data = Data(base64Encoded: base64),
										let image = ZImage(data: data),
										let asset = trait.assetFromImage(image, for: fileName) {
										assets.append(asset)
									}
								}
							}

							if  assets.count > 0 {
								setValue(assets, forKeyPath: keyPath)
							}
						}
					default:
						setValue(value, forKeyPath: keyPath)

//						if  keyPath == "zoneColor",
//							(dict[.name] as? String) == "jonathan" {
//							noop()
//						}
				}
			}
		}

		if  let needs = dict[.needs] as? String {
			addNeedsFromString(needs)
		}
	}

}