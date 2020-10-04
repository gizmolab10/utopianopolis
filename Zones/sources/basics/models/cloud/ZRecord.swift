//  ZRecord.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

class ZRecord: NSObject {

	var             _record: CKRecord?
	var      _tooltipRecord: Any?
    var   writtenModifyDate: Date?
    var          kvoContext: UInt8 = 1
    var          databaseID: ZDatabaseID?
    var  isInPublicDatabase: Bool               { guard let dbID = databaseID else { return false } ; return dbID == .everyoneID }
    var     showingChildren: Bool               { return isExpanded(recordName) }
	var     isFavoritesRoot: Bool               { return recordName == kFavoritesRootName }
	var     isFavoritesHere: Bool               { return recordName == gFavoritesHereMaybe?.recordName() }
	var       isRecentsHere: Bool               { return recordName == gRecentsHereMaybe?.recordName() }
	var       isRecentsRoot: Bool               { return recordName == kRecentsRootName }
	var           isMapRoot: Bool               { return recordName == kRootName }
	var             isARoot: Bool               { return record != nil && kRootNames.contains(recordName!) }
	var        isNonMapHere: Bool               { return isFavoritesHere || isRecentsHere }
	var        isNonMapRoot: Bool               { return isFavoritesRoot || isRecentsRoot }
    var          isBookmark: Bool               { return record?.isBookmark ?? false }
    var           isFetched: Bool               { return !hasState(.notFetched) }
    var           needsSave: Bool               { return  hasState(.needsSave) }
    var           needsRoot: Bool               { return  hasState(.needsRoot) }
    var          notFetched: Bool               { return  hasState(.notFetched) }
    var          needsCount: Bool               { return  hasState(.needsCount) }
    var          needsColor: Bool               { return  hasState(.needsColor) }
    var          needsFetch: Bool               { return  hasState(.needsFetch) }
    var          needsMerge: Bool               { return  hasState(.needsMerge) }
    var         needsTraits: Bool               { return  hasState(.needsTraits) }
    var         needsParent: Bool               { return  hasState(.needsParent) }
    var        needsDestroy: Bool               { return  hasState(.needsDestroy) }
    var        needsProgeny: Bool               { return  hasState(.needsProgeny) }
    var       needsWritable: Bool               { return  hasState(.needsWritable) }
    var       needsChildren: Bool               { return  hasState(.needsChildren) }
	var       needsAdoption: Bool               { return  hasState(.needsAdoption) }
	var      needsBookmarks: Bool               { return  hasState(.needsBookmarks) }
    var canSaveWithoutFetch: Bool               { return !hasState(.requiresFetchBeforeSave) }
    var             records: ZRecords?          { return gRemoteStorage.zRecords(for: databaseID) }
    var               cloud: ZCloud?            { return records as? ZCloud }
    var          recordName: String?            { return record?.recordID.recordName }
	var unwrappedRecordName: String             { return recordName ?? "" }
    var       unwrappedName: String             { return recordName ?? emptyName }
    var           emptyName: String             { return "currently has no name" } // overwritten by subclasses: Zone and ZTrait

    var record: CKRecord? {
        get {
            return _record
        }

        set {
			guard newValue != nil else {
				return
			}

            if  _record != newValue {

                // ///////////////////////////////////////////////
                // old registrations are likely no longer valid //
                // ///////////////////////////////////////////////

                clearAllStates() // is this needed or wanted?
                gBookmarks.unregisterBookmark(self as? Zone)
                cloud?.unregisterCKRecord(_record)

                _record = newValue

                updateInstanceProperties()

				if !register() {
					bam("zone is a duplicate")
				} else {
					updateState()
				}
            }

			if  _record == nil {
				print("nil")
			}
        }
    }

	func updateState() {
		maybeMarkAsFetched()

		if  notFetched {
			setupLinks()
		}

		// //////////////////
		// debugging tests //
		// //////////////////

		let name = (self as? Zone)?.zoneName ?? recordName ?? kEmptyIdea

		if !canSaveWithoutFetch &&  isFetched {
			bam("new record, ALLOW SAVE WITHOUT FETCH " + name)
			allowSaveWithoutFetch()
		} else if canSaveWithoutFetch && notFetched {
			bam("require FETCH BEFORE SAVE " + name)
			fetchBeforeSave()

			if  name != emptyName || recordName == kRootName {
				bam("new named record, should ALLOW SAVING")
			}
		}

		needSave()
	}

	func storageDictionary() throws -> ZStorageDictionary {
		if  let dbID = databaseID,
			let dict = try createStorageDictionary(for: dbID, includeRecordName: false) {

			return dict
		}

		return [:]
	}

	func isExpanded(_ iRecordName: String?) -> Bool {
        if  let                      name   = iRecordName,
            gExpandedZones.firstIndex(of: name) != nil {
            return true
        }

        return false
    }

	func revealChildren() {
        var expansionSet = gExpandedZones

        if  let name = recordName, !isBookmark, !expansionSet.contains(name) {
            expansionSet.append(name)

            gExpandedZones = expansionSet
        }
    }

	func concealChildren() {
        var expansionSet = gExpandedZones

        if let  name = recordName {
            while let index = expansionSet.firstIndex(of: name) {
                expansionSet.remove(at: index)
            }
        }

        if  gExpandedZones.count != expansionSet.count {
            gExpandedZones        = expansionSet
        }
    }

    func toggleChildrenVisibility() {
        if  showingChildren {
            concealChildren()
        } else {
            revealChildren()
        }
    }

    // MARK:- overrides
    // MARK:-

    override init() {
        super.init()
        self.setupKVO();
    }

    convenience init(record: CKRecord?, databaseID: ZDatabaseID?) {
        self.init()

        self.databaseID = databaseID

		if  let r = record {
            self.record = r

			if  isAdoptable {
				self.needAdoption()
				adopt()
			}
		}
	}

    deinit {
        teardownKVO()
    }

	var isAdoptable: Bool { return false }

    func orphan() {}
    func adopt(moveOrphansToLost: Bool = false) {}
    func maybeNeedRoot() {}
    func debug(_  iMessage: String) {}
	var cloudProperties: [String] { return ZRecord.cloudProperties }
	var optionalCloudProperties: [String] { return ZRecord.optionalCloudProperties }
    func ignoreKeyPathsForStorage() -> [String] { return [kpParent, kpOwner] }
    func   register() -> Bool { return cloud?.registerZRecord(self) ?? false }
    func unregister() { cloud?.unregisterZRecord(self) }
    func hasMissingChildren() -> Bool { return true }
    func hasMissingProgeny()  -> Bool { return true }
    class var cloudProperties: [String] { return [] }
	class var optionalCloudProperties: [String] { return [] }

	class func cloudProperties(for className: String) -> [String] {
		switch className {
		case kZoneType:     return Zone     .cloudProperties
		case kTraitType:    return ZTrait   .cloudProperties
		case kManifestType: return ZManifest.cloudProperties
		default:			return []
		}
	}

    // MARK:- properties
    // MARK:-

    func setupLinks() {}

    func temporarilyMarkNeeds(_ closure: Closure) {
        cloud?.temporarilyForRecordNamed(recordName, ignoreNeeds: false, closure)
    }

    func temporarilyIgnoreNeeds(_ closure: Closure) {
        cloud?.temporarilyForRecordNamed(recordName, ignoreNeeds: true, closure)
    }

    func updateInstanceProperties() {
        if  let r = record {
            for keyPath in cloudProperties {
                if  let    cloudValue  = r[keyPath] as! NSObject? {
                    let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                    if  propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }

    func updateCKRecordProperties() {
        if  let r = record {
            for keyPath in cloudProperties {
                let    cloudValue  = r[keyPath] as! NSObject?
                let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                if  propertyValue != nil && propertyValue != cloudValue {
                    r[keyPath] = propertyValue as? CKRecordValue
                }
            }
        }
    }

    func useBest(record iRecord: CKRecord) {
        let myDate      = record?.modificationDate ?? writtenModifyDate
        if  record     != iRecord,
            let newDate = iRecord.modificationDate,
            (myDate    == nil || newDate.timeIntervalSince(myDate!) > 10.0) {
            
            if  let   r = record,
                r.recordID.recordName != iRecord.recordID.recordName {
                records?.addCKRecord(record, for: [.needsDestroy])
            }

            record      = iRecord
        }
    }

    func copy(into iCopy: ZRecord) {
        iCopy.maybeNeedSave() // so KVO won't set needsMerge
        updateCKRecordProperties()
        record?.copy(to: iCopy.record, properties: cloudProperties)
        iCopy.updateInstanceProperties()
    }

    func mergeIntoAndTake(_ iRecord: CKRecord) {
        updateCKRecordProperties()

        if  let r = record, r.copy(to: iRecord, properties: cloudProperties) {
            record  = iRecord

            maybeNeedSave()
        }
    }

    // MARK:- states
    // MARK:-

    func    hasState(_ state: ZRecordState) -> Bool { return records?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        records?.addZRecord(self,     for: [state]) }
    func removeState(_ state: ZRecordState)         {        records?.clearRecordName(recordName, for:[state]) }
    func clearAllStates()                           {        records?.clearRecordName(recordName, for: records?.allStates ?? []) }

    func needRoot()              {    addState(.needsRoot) }
    func needFound()             {    addState(.needsFound) }
    func needFetch()             {    addState(.needsFetch) }
    func needCount()             {    addState(.needsCount) }
    func needAdoption()          {    addState(.needsAdoption) }
    func markNotFetched()        {    addState(.notFetched) }
    func fetchBeforeSave()       {    addState(.requiresFetchBeforeSave) }
    func allowSaveWithoutFetch() { removeState(.requiresFetchBeforeSave)}
	func clearSave() 			 { removeState(.needsSave) }
    func needColor()             {} //    if !gAssumeAllFetched { addState(.needsColor) } }
    func needTraits()            {} //    if !gAssumeAllFetched { addState(.needsTraits) } }
    func needParent()            {} //    if !gAssumeAllFetched { addState(.needsParent) } }
    func needWritable()          {} //    if !gAssumeAllFetched { addState(.needsWritable) } }

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

	func needProgeny() {

		// use reallyNeedProgeny. depricated for performance

//		addState(.needsProgeny)
//		removeState(.needsChildren)
	}

    func reallyNeedProgeny() {
		
		// N.B., make sure your need is worth the performance hit

		addState(.needsProgeny)
        removeState(.needsChildren)
    }

    func needChildren() {
        if !isBookmark && // all bookmarks are childless, by design
            showingChildren &&
            false, // !gAssumeAllFetched,     N.B., depricated for performance ... use reallyNeedChildren
            !needsProgeny {
            addState(.needsChildren)
        }
    }

    func reallyNeedChildren() {
        if !isBookmark && // all bookmarks are childless, by design
            showingChildren &&
            !needsProgeny {
            addState(.needsChildren)
        }
    }

    func maybeNeedSave() {
        if !needsDestroy, !needsSave, gHasFinishedStartup, (canSaveWithoutFetch || !needsFetch) {
            removeState(.needsMerge)
			addState   (.needsSave)
			updateCKRecordProperties()
        }

        needWrite()
    }

    func needWrite() {
        gFiles.needWrite(for: databaseID)
    }

    func maybeMarkNotFetched() {
        if  record?.creationDate == nil {
            markNotFetched()
        }
    }

    func maybeNeedMerge() {
        if  isFetched, canSaveWithoutFetch, !needsSave, !needsMerge, !needsDestroy {
            addState(.needsMerge)
        }
    }

    func maybeMarkAsFetched() {
        if  let r = record {
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
        for keyPath in cloudProperties {
            removeObserver(self, forKeyPath: keyPath)
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

            if let value: NSObject = observer.value(forKey: keyPath!) as! NSObject? {
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
        case kpRecordName:       return recordName as NSObject?      // except for the record name
        case kpModificationDate: return record?.modificationDate?.timeIntervalSince1970 as Double? as NSObject?
        default:                 return record?[iKeyPath] as? NSObject
        }
    }

    func prepare(_ iObject: NSObject, of iType: ZStorageType) -> NSObject? {
        let object = iObject

		switch iType {
			case .link, .parentLink:
				if  let link = object as? String, !isValid(link) {
					return nil
				}
			case .text:
				if  var string = object as? String { // plain [ causes file read to treat it as an array-starts-here symbol
					string = string.replacingStrings(["["], with: "(")
					string = string.replacingStrings(["]"], with: ")")
					string = string.replacingStrings(["\""], with: "'")
					string = string.replacingStrings(["“"], with: "'")
					string = string.replacingStrings(["”"], with: "'")

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

    func stringForNeeds(in iDatabaseID: ZDatabaseID) -> String? {
        if  let       r = record,
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

	func createStorageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> ZStorageDictionary? {
		try gThrowOnUserActivity()

		guard record != nil else {
			printDebug(.dFile, "missing record")

			return nil
		}

		guard let name = recordName else {
			printDebug(.dFile, "fubar record name \(self)")

			return nil
		}

		if  gFiles.writtenRecordNames.contains(name) {
			printDebug(.dFile, "avoid duplicating record name \(self)")

			return nil
		}

		gFiles.writtenRecordNames.append(name)

		let   keyPaths = cloudProperties + (includeRecordName ? [kpRecordName] : []) + [kpModificationDate]
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
    

	func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) throws {
		try gThrowOnUserActivity()

		// case 1: name is nil
		// case 2: ck record already exists
		// case 3: name is not nil

		let    cloud = gRemoteStorage.zRecords(for: iDatabaseID)
		var ckRecord = CKRecord(recordType: iRecordType)           // case 1
		let     name = dict[.recordName] as? String
		databaseID   = iDatabaseID

		if  let recordName = name {
			if  let r = cloud?.maybeCKRecordForRecordName(name) {
				ckRecord = r				        		       // case 2
			} else {		        		        		       // case 3
				ckRecord = CKRecord(recordType: iRecordType, recordID: CKRecord.ID(recordName: recordName)) // YIKES this may be wildly out of date
			}
		}

		for keyPath in cloudProperties + [kpModificationDate] {
			if  let   type = type(from: keyPath),
				let object = dict[type],
				let  value = object as? CKRecordValue {

				switch type {
					case .type: // convert essay trait to note trait
						if  var string = object as? String,
							let trait = ZTraitType(rawValue: string),
							trait == .tEssay {
							string = ZTraitType.tNote.rawValue
							ckRecord[keyPath] = string as CKRecordValue
						} else {
							ckRecord[keyPath] = value
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
								ckRecord[keyPath] = assets
							}
					}

					default:
						ckRecord[keyPath] = value
				}
			}
		}

		record = ckRecord    // any subsequent changes into any of this object's cloudProperties will save this record to iCloud

		if  let needs = dict[.needs] as? String {
			addNeedsFromString(needs)
		}

	}

	class func createStorageArray(for iItems: [AnyObject]?, from dbID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false, allowEach: ZRecordToBooleanClosure? = nil) throws -> [ZStorageDictionary]? {
        if  let   items = iItems,
            items.count > 0 {
            var   array = [ZStorageDictionary] ()

            for item in items {
				if  let zRecord = item as? ZRecord {
					if  zRecord.record == nil {
						printDebug(.dFile, "no record: \(zRecord)")
					} else if (allowEach == nil || allowEach!(zRecord)),
						let dict = try zRecord.createStorageDictionary(for: dbID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {

						if  dict.count != 0 {
							array.append(dict)
						} else {
							printDebug(.dFile, "empty storage dictionary: \(zRecord)")

							if  let dict2 = try zRecord.createStorageDictionary(for: dbID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
								print("gotcha \(dict2.count)")
							}
						}
					} else if !zRecord.isBookmark {
						printDebug(.dFile, "no storage dictionary: \(zRecord)")
					}
				}
            }

            if  array.count > 0 {
                return array
            }
        }

        return nil
    }

}
