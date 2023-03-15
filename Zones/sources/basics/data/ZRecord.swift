//  ZRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import CoreData
import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZRootID: String {
	case rootID      = "root"
	case trashID     = "trash"
	case destroyID   = "destroy"
	case favoritesID = "favorites"
	case lostID      = "lost and found"
}

enum ZStorageType: String {
	case lost            = "lostAndFound"    // general
	case bookmarks       = "bookmarks"
	case favorites       = "favorites"
	case manifest        = "manifest"
	case minimal         = "minimal"
	case destroy         = "destroy"
	case userID          = "user ID"
	case model           = "model"
	case graph           = "graph"
	case trash           = "trash"
	case date            = "date"

	case recordName      = "recordName"		 // zones
	case parentLink      = "parentLink"
	case attributes      = "attributes"
	case children        = "children"
	case progeny         = "progeny"
	case strings         = "strings"
	case traits          = "traits"
	case access          = "access"
	case author          = "author"
	case essay           = "essay"
	case order           = "order"
	case color           = "color"
	case count           = "count"
	case needs           = "needs"
	case link            = "link"
	case name            = "name"
	case note            = "note"

	case assetNames      = "assetNames"      // traits
	case assets          = "assets"
	case format          = "format"
	case time            = "time"
	case text            = "text"
	case data            = "data"
	case type            = "type"

	case deleted         = "deleted"         // ZManifest

	var rootName: String? {
		switch self {
			case .favorites: return kFavoritesRootName
			case .lost:      return kLostAndFoundName
			case .trash:     return kTrashName
			case .graph:     return kRootName
			default:         return nil
		}
	}

	var rootID: ZRootID? {
		switch self {
			case .favorites: return .favoritesID
			case .trash:     return .trashID
			case .graph:     return .rootID
			case .lost:      return .lostID
			default:         return nil
		}
	}

}

@objc (ZRecord)
class ZRecord: ZManagedObject {

	@NSManaged var             dbid : String?
	@NSManaged var       recordName : String?
	@NSManaged var modificationDate : Date?
	var              _toolTipRecord : Any?
	var           writtenModifyDate : Date?
	var                       color : ZColor?    // overridden by Zone and ZTrait (latter grabs from its ownerZone)
	var             maybeDatabaseID : ZDatabaseID? { return ZDatabaseID.convert(from: dbid) }
	var                  databaseID : ZDatabaseID  { return maybeDatabaseID! }
	var                    zRecords : ZRecords?    { return gRemoteStorage.zRecords(for: maybeDatabaseID) }
	var         unwrappedRecordName : String       { return recordName ?? kEmpty }
	var               decoratedName : String       { return recordName ?? kNoValue }
	var               unwrappedName : String       { return recordName ?? emptyName }
	var                  typePrefix : String       { return kEmpty }
	var                   emptyName : String       { return "currently has no name" } // overwritten by subclasses: Zone and ZTrait
	var          isInPublicDatabase : Bool         { return databaseID == .everyoneID }
	var                     isAZone : Bool         { return false }
	var                  isBrandNew : Bool         { return true }
	var                 isTrashRoot : Bool         { return recordName == kTrashName }
	var               isMainMapRoot : Bool         { return recordName == kRootName }
	var               isDestroyRoot : Bool         { return recordName == kDestroyName }
	var          isLostAndFoundRoot : Bool         { return recordName == kLostAndFoundName }
	var             isFavoritesRoot : Bool         { return recordName == kFavoritesRootName }
	var             isFavoritesHere : Bool         { return recordName == gFavoritesHereMaybe?.recordName }
	var                isAnyMapRoot : Bool         { return isFavoritesRoot  || isMainMapRoot }
	var                  needsCount : Bool         { return  hasState(.needsCount) }
	var                  needsColor : Bool         { return  hasState(.needsColor) }
	var                needsDestroy : Bool         { return  hasState(.needsDestroy) }
	var               needsAdoption : Bool         { return  hasState(.needsAdoption) }
	var              needsBookmarks : Bool         { return  hasState(.needsBookmarks) }
 
	var isARoot: Bool {
		if  recordName == nil {
			return false
		}

		return kRootNames.contains(recordName!)
	}

	// MARK: - overrides
	// MARK: -

	var isAdoptable          : Bool { return false }
	var passesFilter         : Bool { return true }
	var isInScope            : Bool { return true }
	var isRegistered         : Bool { return zRecords?.isRegistered(self) ?? false }
	var matchesFilterOptions : Bool { return passesFilter && isInScope }
	var               cloudProperties : StringsArray { return ZRecord.cloudProperties }
	var       optionalCloudProperties : StringsArray { return ZRecord.optionalCloudProperties }
	class var         cloudProperties : StringsArray { return [] }
	class var optionalCloudProperties : StringsArray { return [] }

	func orphan() {}
	func maybeNeedRoot() {}
	func debug(_ iMessage: String) {}
	func hasMissingChildren() -> Bool { return true }
	func hasMissingProgeny()  -> Bool { return true }
	func ignoreKeyPathsForStorage() -> StringsArray { return [kpParent, kpOwner] }
	func unregister() { zRecords?.unregisterZRecord(self) }
	func register()   { zRecords?  .registerZRecord(self) }
	func adopt(recursively : Bool = false) {}

	// MARK: - core data
	// MARK: -

	var selfInCurrentBackgroundCDContext: ZRecord? { return gCDCurrentBackgroundContext?.object(with: objectID) as? ZRecord }

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
			gStartupController?.pingRunloop()
		}

		return converted
	}

	// MARK: - initialize
	// MARK: -

	static func uniqueFactoryObject(entityName: String, recordName: String?, in databaseID: ZDatabaseID) -> ZManagedObject {
		switch entityName {
			case kZoneType:     return Zone     .uniqueZone    (recordName: recordName, in: databaseID)
			case kUserType:     return ZUser    .uniqueUser    (recordName: recordName, in: databaseID)
			case kTraitType:    return ZTrait   .uniqueTrait   (recordName: recordName, in: databaseID)
			case kManifestType: return ZManifest.uniqueManifest(recordName: recordName, in: databaseID)
			default:            return ZRecord  .uniqueZRecord (entityName: entityName, recordName: recordName, in: databaseID)
		}
	}

	@nonobjc static func uniqueZRecord(entityName: String, recordName: String?, in databaseID: ZDatabaseID) -> ZRecord {
		let         object = uniqueObject(entityName: entityName, recordName: recordName, in: databaseID)
		let        zRecord = object as! ZRecord
		zRecord.recordName = recordName ?? gUniqueRecordName
		zRecord      .dbid = databaseID.identifier
		
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

		let            saved = zRecords?.ignoreNone ?? false
		zRecords?.ignoreNone = true
		closure()
		zRecords?.ignoreNone = saved
	}

	// MARK: - needs
	// MARK: -

	func temporarilyMarkNeeds(_ closure: Closure) {
		zRecords?.temporarilyForRecordNamed(recordName, ignoreNeeds: false, closure)
	}

	func temporarilyIgnoreNeeds(_ closure: Closure) {

		// ////////////////////////////////////////////// //
		// temporarily causes set needs to have no effect //
		// ////////////////////////////////////////////// //

		zRecords?.temporarilyForRecordNamed(recordName, ignoreNeeds: true, closure)
	}

	func stringForNeeds(in iDatabaseID: ZDatabaseID) -> String? {
		if  let       r = recordName,
			let manager = gRemoteStorage.zRecords(for: iDatabaseID) {
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

    // MARK: - states
    // MARK: -

    func    hasState(_ state: ZRecordState) -> Bool { return zRecords?.isRegistered(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        zRecords?.addZRecord  (self, for:     [state]) }
    func removeState(_ state: ZRecordState)         {        zRecords?.clearRecordName(recordName, for:[state]) }
    func clearAllStates()                           {        zRecords?.clearRecordName(recordName, for: zRecords?.allStates ?? []) }

	func needCount()    { addState(.needsCount); gNeedsRecount = true }
	func needAdoption() { addState(.needsAdoption) }
	func needDestroy()  { addState(.needsDestroy) }

	func updateState() {
		setupLinks()
	}

    // MARK: - files
    // MARK: -

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
			case kpRecordName: return recordName as NSObject?      // except for the record name
			default:           return value(forKeyPath: iKeyPath) as? NSObject
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
							let fileName = asset.fileURL!.lastPathComponent

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
				printDebug(.dFile, "broken keypath for " + selfInQuotes + " : " + keyPath)
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

		gStartupController?.pingRunloop()

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
				}
			}
		}

		if  let needs = dict[.needs] as? String {
			addNeedsFromString(needs)
		}
	}

}
