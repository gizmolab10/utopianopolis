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
	var           databaseID: ZDatabaseID?
	var           kvoContext: UInt8 = 1
	var             ckRecord: CKRecord?
	var       _tooltipRecord: Any?
	var    writtenModifyDate: Date?
	var              records: ZRecords? { return gRemoteStorage.zRecords(for: databaseID) }
	var                cloud: ZCloud?   { return records as? ZCloud }
	var         ckRecordName: String?   { return ckRecord?.recordID.recordName }
	var  unwrappedRecordName: String    { return ckRecordName ?? "" }
	var        unwrappedName: String    { return ckRecordName ?? emptyName }
	var            emptyName: String    { return "currently has no name" } // overwritten by subclasses: Zone and ZTrait
	var   isInPublicDatabase: Bool      { guard let dbID = databaseID else { return false } ; return dbID == .everyoneID }
	var            isMapRoot: Bool      { return ckRecordName == kRootName }
	var          isTrashRoot: Bool      { return ckRecordName == kTrashName }
	var        isDestroyRoot: Bool      { return ckRecordName == kDestroyName }
	var        isRecentsRoot: Bool      { return ckRecordName == kRecentsRootName }
	var   isLostAndFoundRoot: Bool      { return ckRecordName == kLostAndFoundName }
	var      isFavoritesRoot: Bool      { return ckRecordName == kFavoritesRootName }
	var      isFavoritesHere: Bool      { return ckRecordName == gFavoritesHereMaybe?.ckRecordName }
	var        isRecentsHere: Bool      { return ckRecordName == gRecentsHereMaybe?.ckRecordName }
	var       isSmallMapHere: Bool      { return isFavoritesHere || isRecentsHere }
	var       isSmallMapRoot: Bool      { return isFavoritesRoot || isRecentsRoot }
	var      isEitherMapRoot: Bool      { return isSmallMapRoot || isMapRoot }
	var  canSaveWithoutFetch: Bool      { return !hasState(.requiresFetchBeforeSave) }
	var            isFetched: Bool      { return !hasState(.notFetched) }
	var            needsSave: Bool      { return  hasState(.needsSave) }
	var            needsRoot: Bool      { return  hasState(.needsRoot) }
	var           notFetched: Bool      { return  hasState(.notFetched) }
	var           needsCount: Bool      { return  hasState(.needsCount) }
	var           needsColor: Bool      { return  hasState(.needsColor) }
	var           needsFetch: Bool      { return  hasState(.needsFetch) }
	var           needsMerge: Bool      { return  hasState(.needsMerge) }
	var          needsTraits: Bool      { return  hasState(.needsTraits) }
	var          needsParent: Bool      { return  hasState(.needsParent) }
	var         needsDestroy: Bool      { return  hasState(.needsDestroy) }
	var         needsProgeny: Bool      { return  hasState(.needsProgeny) }
	var        needsChildren: Bool      { return  hasState(.needsChildren) }
	var        needsAdoption: Bool      { return  hasState(.needsAdoption) }
	var       needsBookmarks: Bool      { return  hasState(.needsBookmarks) }

	var isARoot: Bool {
		if  recordName == nil || ckRecordName == nil {
			return false
		}

		return kRootNames.contains(recordName!) || (ckRecord != nil && kRootNames.contains(ckRecordName!))
	}

	// MARK:- overrides
	// MARK:-

	var isAdoptable: Bool { return false }
	var cloudProperties: [String] { return ZRecord.cloudProperties }
	var optionalCloudProperties: [String] { return ZRecord.optionalCloudProperties }
	class var   cloudProperties: [String] { return [] }
	class var optionalCloudProperties: [String] { return [] }

	func orphan() {}
	func adopt(recursively: Bool = false) {}
	func maybeNeedRoot() {}
	func debug(_  iMessage: String) {}
	func hasMissingChildren() -> Bool { return true }
	func hasMissingProgeny()  -> Bool { return true }
	func ignoreKeyPathsForStorage() -> [String] { return [kpParent, kpOwner] }
	func unregister() { cloud?.unregisterZRecord(self) }
	@discardableResult func register() -> Bool { return records?.registerZRecord(self) ?? false }

	class func cloudProperties(for className: String) -> [String] {
		switch className {
			case kZoneType:     return Zone     .cloudProperties
			case kTraitType:    return ZTrait   .cloudProperties
			case kManifestType: return ZManifest.cloudProperties
			default:			return []
		}
	}

	// MARK:- core data
	// MARK:-

	@discardableResult func updateFromCoreDataHierarchyRelationships(visited: [String]?) -> [String] { return [String]() }

	func updateCKRecordFromCoreData() {
		if  gUseCoreData,
			let    dID = dbid {
			databaseID = ZDatabaseID.convert(from: dID)
		}
	}

	@discardableResult func convertFromCoreData(into type: String, visited: [String]?) -> [String] {
		var         v = visited ?? [String]()
		var converted = [String]()

		assureCKRecordAndName(for: type)

		if  let name = recordName {
			if (v.isEmpty || !v.contains(name)),
				records?.maybeZRecordForRecordName(name) == nil {
				updateCKRecordProperties()                                                      // filled
				updateCKRecordFromCoreData()
				converted.appendUnique(item: name)
				v        .appendUnique(item: name)
			}

			converted.append(contentsOf: updateFromCoreDataHierarchyRelationships(visited: v))
		}

		return converted
	}

	// MARK:- initialize
	// MARK:-

	static func uniqueZRecord(entityName: String, recordName: String?, in dbID: ZDatabaseID) -> ZRecord {
		let        zRecord = uniqueObject(entityName: entityName, recordName: recordName, in: dbID) as! ZRecord
		zRecord.recordName = recordName ?? gUniqueRecordName

		return zRecord
	}

	// todo todo: eliminate this constructor, use unique z record

	convenience init(record: CKRecord? = nil, entityName: String? = nil, databaseID: ZDatabaseID?) {
		if  gUseCoreData, let eName = record?.entityName ?? entityName {
			self.init(entityName: eName, databaseID: databaseID) // ckRecordName: record?.recordID.recordName, databaseID: databaseID) // initialize managed object from ck record or explicit entity name
		} else {
			self.init()
		}

		self.databaseID = databaseID

		if  gUseCoreData,
			let t = record?.recordType, t != kUserRecordType,
			let d = databaseID?.identifier {
			dbid  = d
		}

		if  let r = record {
			self.setRecord(r)
		}

		self.setupKVO();
	}

	deinit {
		teardownKVO()
	}

	func copyIntoZRecord(_ other: ZRecord) {
		updateCKRecordProperties()
		ckRecord?.copy(to: other.ckRecord, properties: cloudProperties)
		other.updateInstanceProperties()
	}

	func copyInto(_ other: ZRecord) {
		for keyPath in cloudProperties {
			let copied = value(forKeyPath: keyPath)

			other.setValue(copied, forKeyPath: keyPath)
		}
	}

	func assureCKRecordAndName(for type: String) {
		if  ckRecord         == nil {
			if  recordName   != nil {
				ckRecord      = CKRecord(recordType: type, recordID: CKRecordID(recordName: recordName!))
			} else {
				ckRecord      = CKRecord(recordType: type)
				recordName    = ckRecord!.recordID.recordName
			}
		} else if recordName == nil {
			recordName        = ckRecord!.recordID.recordName
		}
	}

	func updateCKRecordProperties() {
		return
		if  let                     r = ckRecord {
			for keyPath in cloudProperties {
				if  let   recordValue =        r[keyPath]          as! NSObject?,
					let propertyValue = value(forKeyPath: keyPath) as! NSObject?,
					recordValue      != propertyValue {
					r[keyPath]        = propertyValue as? CKRecordValue
				}
			}
		}
	}

	func updateInstanceProperties() {
		if  let                      r = ckRecord {
			for keyPath in cloudProperties {
				if  var    cloudValue  = r[keyPath] as! NSObject? {
					let propertyValue  = value(forKeyPath: keyPath) as? NSObject

					if  propertyValue != cloudValue {
						switch keyPath {
							case "writeAccess": cloudValue = NSNumber(value: Int(cloudValue  as! String) ?? 0)
							default:            break
						}

						setValue(cloudValue, forKeyPath: keyPath)
					}
				}
			}
		}
	}

	@objc func setRecord(_ newValue: CKRecord?) {
		guard newValue != nil else {
			return
		}

		if  ckRecord != newValue {

			// ///////////////////////////////////////////////
			// old registrations are likely no longer valid //
			// ///////////////////////////////////////////////

//			clearAllStates() // is this needed or wanted?
//			gBookmarks.forget(self as? Zone)
//			cloud?.unregisterCKRecord(ckRecord)

			if  let      r = newValue {
				ckRecord   = r
				recordName = r.recordID.recordName

				updateInstanceProperties()
			}

			if !register() {
				bam("zone is a duplicate")
			} else {
				updateState()
			}

			if  isAdoptable {
				needAdoption()
			}
		}


		if  ckRecord == nil {
			print("nil")
		}
	}

	static func hasZRecordAsync(recordName: String, entityName: String, databaseID: ZDatabaseID?, onExistence: @escaping ZRecordClosure) {
		if  let       dbid = databaseID,
			let      cloud = gRemoteStorage.cloud(for: dbid),
			let    zRecord = cloud.maybeZRecordForRecordName(recordName) {
			onExistence(zRecord)
		} else {
			let z = ZEntityDescriptor(entityName: entityName, recordName: recordName, databaseID: databaseID)
			gCoreDataStack.zRecordExistsAsync(for: z, onExistence: onExistence)
		}
	}

	static func hasMaybeAsync(record: CKRecord, entityName: String, databaseID: ZDatabaseID?, onExistence: ZRecordClosure? = nil) {
		hasZRecordAsync(recordName: record.recordID.recordName, entityName: entityName, databaseID: databaseID) { has in       // first check if already exists
			has?.useBest(record: record)
			has?.needAdoption()
			onExistence?(has)
		}
	}

	static func hasZRecord(recordName: String, entityName: String, databaseID: ZDatabaseID?) -> ZRecord? {
		if  let       dbid = databaseID,
			let      cloud = gRemoteStorage.cloud(for: dbid),
			let    zRecord = cloud.maybeZRecordForRecordName(recordName) {
			return zRecord
		} else {
			return gCoreDataStack.hasExisting(entityName: entityName, recordName: recordName, databaseID: databaseID) as? ZRecord
		}
	}

	static func hasMaybe(record: CKRecord, entityName: String? = nil, databaseID: ZDatabaseID?) -> ZRecord? {
		if  let name = entityName,
			let  has = hasZRecord(recordName: record.recordID.recordName, entityName: name, databaseID: databaseID) {        // first check if already exists
			has.useBest(record: record)

			return has
		}

		return nil
	}

	func useBest(record iRecord: CKRecord?) {
		if  let    r = iRecord,
			let best = chooseBest(record: r) {
			setRecord(best)
		}
	}

	func mergeIntoAndTake(_ iRecord: CKRecord) {
		updateCKRecordProperties()

		if  let r = ckRecord, r.copy(to: iRecord, properties: cloudProperties) {
			setRecord(iRecord)
			maybeNeedSave()
		}
	}

	func chooseBest(record newRecord: CKRecord) -> CKRecord? {
		var     current = ckRecord
		let     newDate = newRecord.modificationDate
		let currentDate = current? .modificationDate ?? writtenModifyDate
		let      noDate = currentDate == nil
		if  noDate || (newRecord != current && newDate != nil && newDate!.timeIntervalSince(currentDate!) > 10.0) {
			if  current?.recordID.recordName == "3FA3E961-663F-4825-ADD1-ABD5A268D9D9" {
				noop()
			}
			current     = newRecord
		}

		return current
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
		cloud?.temporarilyForRecordNamed(ckRecordName, ignoreNeeds: false, closure)
	}

	func temporarilyIgnoreNeeds(_ closure: Closure) {

		// ////////////////////////////////////////////// //
		// temporarily causes set needs to have no effect //
		// ////////////////////////////////////////////// //

		cloud?.temporarilyForRecordNamed(ckRecordName, ignoreNeeds: true, closure)
	}

	func stringForNeeds(in iDatabaseID: ZDatabaseID) -> String? {
		if  let       r = ckRecord,
			let manager = gRemoteStorage.cloud(for: iDatabaseID) {
			let  states = manager.states(for: r)
			var   marks = [String] ()

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

    func    hasState(_ state: ZRecordState) -> Bool { return records?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        records?.addZRecord(self,     for: [state]) }
    func removeState(_ state: ZRecordState)         {        records?.clearRecordName(ckRecordName, for:[state]) }
    func clearAllStates()                           {        records?.clearRecordName(ckRecordName, for: records?.allStates ?? []) }

    func needRoot()              {    addState(.needsRoot) }
    func needFound()             {    addState(.needsFound) }
    func needFetch()             {    addState(.needsFetch) }
    func needCount()             {    addState(.needsCount) }
    func markNotFetched()        {    addState(.notFetched) }
	func needColor()             {    addState(.needsColor) }
	func needTraits()            {    addState(.needsTraits) }
	func needParent()            {    addState(.needsParent) }
	func needWritable()          {    addState(.needsWritable) }
	func needAdoption()          {    addState(.needsAdoption) }
    func fetchBeforeSave()       {    addState(.requiresFetchBeforeSave) }
    func allowSaveWithoutFetch() { removeState(.requiresFetchBeforeSave)}
	func clearSave() 			 { removeState(.needsSave) }

	func updateState() {
		maybeMarkAsFetched()

		if  notFetched {
			setupLinks()
		}
	}

	func needProgeny() {
		addState(.needsProgeny)
		removeState(.needsChildren)
	}

    func needSave() {
        allowSaveWithoutFetch()
        maybeNeedSave()
    }

    func needDestroy() {
        if  canSaveWithoutFetch {
            addState   (.needsDestroy)
            removeState(.needsSave)
            removeState(.needsMerge)
        }
    }

    func maybeNeedSave() {
		updateCKRecordProperties()    // make sure relevant data is in place to be saved

        if !needsDestroy, !needsSave, gHasFinishedStartup, (canSaveWithoutFetch || !needsFetch) {
            removeState(.needsMerge)
			addState   (.needsSave)

			if  gUseCoreData {
				modificationDate = Date()
			}

			needWrite()
        }
    }

    func needWrite() {
        gFiles.needWrite(for: databaseID)
    }

    func maybeMarkNotFetched() {
        if  ckRecord?.creationDate == nil {
            markNotFetched()
        }
    }

    func maybeNeedMerge() {
        if  isFetched, canSaveWithoutFetch, !needsSave, !needsMerge, !needsDestroy {
            addState(.needsMerge)
        }
    }

    func maybeMarkAsFetched() {
        if  let r = ckRecord {
            r.maybeMarkAsFetched(databaseID)
        }
    }

    // MARK:- accessors and KVO
    // MARK:-

    func setValue(_ value: NSObject, for property: String) {
        cloud?.setIntoObject(self, value: value, for: property)
    }

    func get(propertyName: String) {
        cloud?.getFromObject(self, valueForPropertyName: propertyName)
    }

    func teardownKVO() {
        for keyPath in cloudProperties { // freaking stupid KVO does not let me check if observer actually exists and if it doesn't then not call remove, gack!
			addObserver   (self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext) // make sure observer exists
			removeObserver(self, forKeyPath: keyPath, context: &kvoContext)
        }
    }

	func setupKVO() {
        for keyPath in cloudProperties {
            addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext)
        }
    }

	override func observeValue(forKeyPath keyPath: String?, of iObject: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            let observer = iObject as! NSObject

            if  let value: NSObject = observer.value(forKey: keyPath!) as! NSObject? {
				if keyPath == "assets", let values = value as? NSArray, values.count == 0 { return }

				setValue(value, for: keyPath!)
            }
        }
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
        case kpRecordName:       return ckRecordName as NSObject?      // except for the record name
        case kpModificationDate: return ckRecord?.modificationDate?.timeIntervalSince1970 as Double? as NSObject?
        default:                 return ckRecord?[iKeyPath] as? NSObject
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
					var strings = [String]()

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
		try gThrowOnUserActivity()

		guard ckRecord != nil else {
			printDebug(.dFile, "missing record")

			return nil
		}

		guard let name = ckRecordName else {
			printDebug(.dFile, "fubar record name \(self)")

			return nil
		}

		if  gFiles.writtenRecordNames.contains(name) {
			printDebug(.dFile, "avoid duplicating record name \(self)")

			return nil
		}

		gFiles.writtenRecordNames.append(name)

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
		if  let dbID = databaseID,
			let dict = try createStorageDictionary(for: dbID, includeRecordName: false) {

			return dict
		}

		return [:]
	}

	func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) throws {
		try gThrowOnUserActivity()

		// case 1: name is nil
		// case 2: ck record already exists
		// case 3: name is not nil

		let     cloud = gRemoteStorage.zRecords(for: iDatabaseID)
		var newRecord = CKRecord(recordType: iRecordType)           // case 1
		let      name = dict.recordName
		databaseID    = iDatabaseID

		if  let recordName = name {
			if  let r = cloud?.maybeCKRecordForRecordName(recordName) {
				newRecord = r				        		       // case 2
			} else {		        		        		       // case 3
				newRecord = CKRecord(recordType: iRecordType, recordID: CKRecordID(recordName: recordName)) // YIKES this may be wildly out of date
			}
		}

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
							newRecord[keyPath] = string as CKRecordValue
						} else {
							newRecord[keyPath] = value
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
								newRecord[keyPath] = assets
							}
						}

					default:
						newRecord[keyPath] = value
				}
			}
		}

		setRecord(newRecord)    // any subsequent changes into any of this object's cloudProperties will save this record to iCloud

		if  let needs = dict[.needs] as? String {
			addNeedsFromString(needs)
		}

		updateCKRecordFromCoreData()

	}

}
