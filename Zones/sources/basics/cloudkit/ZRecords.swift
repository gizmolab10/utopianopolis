//
//  ZRecords.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/4/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZRecordState: String {
    case requiresFetchBeforeSave = "requires fetch before save"     //
    case needsFetch              = "fetch"                          //
    case notFetched              = "not fetched"                    //
	case needsAdoption           = "adopt"
    case needsBookmarks          = "bookmarks"
    case needsChildren           = "children"
    case needsColor              = "color"
	case needsCount              = "count"
    case needsDestroy            = "destroy"
	case needsFound              = "found"
    case needsMerge              = "merge"
    case needsParent             = "parent"
	case needsProgeny            = "progeny"
    case needsRoot               = "root"
    case needsSave               = "save"
    case needsTraits             = "traits"
    case needsWritable           = "writable"
}

class ZRecords: NSObject {

	var         duplicates = [                 ZRecord]       ()
    var     zRecordsLookup = [String       :   ZRecord]       ()
	var    ckRecordsLookup = [String       :  CKRecordsArray] ()
	var    recordsMistyped = [String       :   ZRecord]       ()
	var  recordNamesByType = [String       :   [String]]      ()
	var recordNamesByState = [ZRecordState :   [String]]      ()
    var       lastSyncDate = Date(timeIntervalSince1970: 0)
	var            orphans = ZoneArray()
    var         databaseID : ZDatabaseID
    var           manifest : ZManifest?
    var   lostAndFoundZone : Zone?
	var      favoritesZone : Zone?
	var        recentsZone : Zone?
	var        destroyZone : Zone?
    var          trashZone : Zone?
    var           rootZone : Zone?
    var        hereIsValid : Bool      { return maybeZoneForRecordName(hereRecordName) != nil }
	var         allProgeny : ZoneArray { return rootZone?.all ?? [] }

	func countBy                                                  (type: String)  -> Int?     { return recordNamesByType[type]?.count }
	func recordNamesForState                             (_ state: ZRecordState)  -> [String] { return recordNamesByState[state] ?? [] }
	func notRegistered                                 (_ recordID: CKRecordID?)  -> Bool     { return maybeZoneForRecordID(recordID) == nil }
	func hasCKRecord     (_ ckRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> Bool     { return registeredCKRecordForName(ckRecord.recordID.recordName, forAnyOf: iStates) != nil }
	func hasCKRecordName      (_ iName: String, forAnyOf iStates: [ZRecordState]) -> Bool     { return registeredCKRecordForName(iName, forAnyOf: iStates) != nil }
	func hasCKRecordID(_ iRecordID: CKRecordID, forAnyOf iStates: [ZRecordState]) -> Bool     { return registeredCKRecordForName(iRecordID.recordName, forAnyOf: iStates) != nil }

	func showRoot() { setHere(to: rootZone) }

	func setHere(to zone: Zone?) {
		if  let newHere = zone {
			hereZoneMaybe?.collapse()

			hereZoneMaybe = newHere

			hereZoneMaybe?.expand()
		}
	}

	func show(_ zone: Zone) {
		let bookmarks = allProgeny.intersection(zone.bookmarksTargetingSelf)
		if  bookmarks.count > 0,
			let parent = bookmarks[0].parentZone {
			setHere(to: parent)
		}
	}

	var allProgenyReferences: CKReferencesArray {
		var references = CKReferencesArray()

		applyToAllProgeny { iZone in
			if  let recordID = iZone.ckRecord?.recordID {
				references.append(CKReference(recordID: recordID, action: .none))
			}
		}

		return references
	}

	var allZones : ZoneArray {
		var array = ZoneArray()

		applyToAllZones { zone in
			array.append(zone)
		}

		return array
	}

	var orphanCount : Int {
		orphans = ZoneArray()

		applyToAllOrphans { zone in
			orphans.append(zone)
		}

		return orphans.count
	}

	var recordCount : Int {

		// when this is called at beginning of read shortly after launch,
		// nothing has yet been registered, so return a default of 100
		// doing so will give a better behavior to the launch progress bar

		let count = zRecordsLookup.count

		return count > 1 ? count : 100
	}

    var hereRecordName: String? {
		set {
			var        references  = allSafeHereReferences
			if  let         index  = databaseID.index,
				let         value  = newValue,
				references[index] != value {
				references[index]  = value
				gHereRecordNames   = references.joined(separator: kColonSeparator)
			}
		}

		get {
			if  let         index = databaseID.index {
				let    references = allSafeHereReferences
				return references[index]
			}
			
			return nil
		}
    }

	var allSafeHereReferences: [String] {
		var     references = gHereRecordNames.components(separatedBy: kColonSeparator)
		var     incomplete = false

		while  references.count < 4 {
			let      index = references.count
			if  let   dbid = ZDatabaseIndex(rawValue: index)?.databaseID,
				let   name = gRemoteStorage.zRecords(for: dbid)?.rootZone?.ckRecordName {
				incomplete = true
				references.append(name)
			}
		}

		// enforce difference between favorites and recents

		if  references[2] == references[3] {
			references[2] = kFavoritesRootName // reset to default
			references[3] = kRecentsRootName
			incomplete    = true
		}

		if  incomplete {
			gHereRecordNames = references.joined(separator: kColonSeparator)
		}

		return references
	}
    
    var hereZoneMaybe: Zone? {
		get { return maybeZoneForRecordName(hereRecordName) }
		set { hereRecordName = newValue?.ckRecordName ?? rootName }
    }

	var rootName: String {
		switch(databaseID) {
			case .favoritesID: return kFavoritesRootName
			case .recentsID:   return kRecentsRootName
			default:           return kRootName
		}
	}

	var defaultRoot: Zone? {
		switch (databaseID) {
			case .favoritesID: return gFavoritesRoot
			case .recentsID:   return gRecentsRoot
			default:           return rootZone
		}
	}
    
    var currentHere: Zone {
        get { return (hereZoneMaybe ?? defaultRoot!) }
        set { hereZoneMaybe = newValue }
    }

	var debugTotal: ZRecordsArray {
		let totalIDS: [ZDebugID] = [.dValid, .dTraits]
		var total = ZRecordsArray()

		for id  in  totalIDS {
			if  let zRecords = debugZRecords(for: id) {
				total.append(contentsOf: zRecords)
			}
		}

		return total
	}

	var debugValid: ZRecordsArray {
		let totalIDS: [ZDebugID] = [.dFavorites, .dRecents, .dProgeny, .dDestroy, .dTrash, .dLost]
		var total = ZRecordsArray()

		for id  in  totalIDS {
			if  let zRecords = debugZRecords(for: id) {
				total.append(contentsOf: zRecords)
			}
		}

		return total
	}

	func zRecords(of type: String) -> ZRecordsArray? {
		var result = ZRecordsArray()

		if  let names = recordNamesByType[type] {
			for name in names {
				if  let zRecord = maybeZRecordForRecordName(name) {
					result.append(zRecord)
				}
			}
		}

		return result
	}

	func debugZRecords(for debugID: ZDebugID) -> ZRecordsArray? {
		switch debugID {
			case .dTraits:     return zRecords(of: kTraitType)
			case .dZones:      return zRecords(of:  kZoneType)
			case .dLost:       return lostAndFoundZone?  .all
			case .dFavorites:  return favoritesZone?     .all
			case .dRecents:    return recentsZone?       .all
			case .dDestroy:    return destroyZone?       .all
			case .dTrash:      return trashZone?         .all
			case .dProgeny:    return allProgeny
			case .dValid:      return debugValid
			case .dTotal:      return debugTotal
			default:           return nil
		}
	}

	func debugValue(for debugID: ZDebugID) -> Int? {
		switch debugID {
			case .dDuplicates: return duplicates                  .count
			case .dRegistry:   return zRecordsLookup              .count
			default:           return debugZRecords(for: debugID)?.count
		}
	}


	init(_ idatabaseID: ZDatabaseID) {
        databaseID = idatabaseID
	}

	func removeAllDuplicates() {
		applyToAllZRecords { zRecord in
			if  let z = zRecord {
				gCoreDataStack.removeAllDuplicates(of: z)
			}
		}

		gCoreDataStack.emptyZones(within: databaseID) { empties in
			for empty in empties {
				empty.needDestroy()
			}
		}
	}

	func markAllNeedSave() {
		applyToAllZRecords { zRecord in
			zRecord?.needSave()
		}
	}

	func createRandomLost() -> Zone {
        let lost = Zone.randomZone(in: databaseID)

        lostAndFoundZone?.addChild(lost, at: nil)

        return lost
    }

	func updateLastSyncDate() {
        var date = lastSyncDate

		applyToAllZRecords { zRecord in
            if  let           record = zRecord?.ckRecord,
                let modificationDate = record.modificationDate,
                modificationDate.timeIntervalSince(date) > 0 {

                date = modificationDate
            }
        }

        lastSyncDate = date
    }

    @discardableResult func recount() -> Int {  // all progenyCounts for all progeny in all roots
		let c = rootZone?.recount() ?? 0
		trashZone?       .recount()
		destroyZone?     .recount()
		recentsZone?     .recount()
		favoritesZone?   .recount()
		lostAndFoundZone?.recount()

		return c
    }

    func className(for recordType: String?) -> String? {
        var     name = nil as String?

        if  let    t = recordType {
            switch t {
            case     kUserType: name = kUserEntityName
            case     kZoneType: name = kZoneType
            case    kTraitType: name = kTraitType
            case kManifestType: name = kManifestType
            default:            break
            }
        }

        return name == nil ? nil : "Seriously." + name!
    }
    
    func properties(for recordType: String?) -> [String] {
        if  let   name = className(for: recordType),
            let  klass = NSClassFromString(name),
            let zClass = klass as? ZRecord.Type {
                return zClass.cloudProperties
        }

		return []
    }

    // MARK:- registries
    // MARK:-

	// ckrecords lookup:
	// initialized with one entry for each word in each zone's name
	// grows with each unique search

	func appendCKRecordsLookup(with iName: String, onEach: @escaping RecordsToRecordsClosure) {
		for part in iName.components(separatedBy: " ") {
			if  part != "" {
				searchCoreData(for: part) { ckRecords in
					self.ckRecordsLookup[part] = onEach(ckRecords)
				}
			}
		}
	}

	func searchCoreData(for match: String, onCompletion: RecordsClosure? = nil) {
		onCompletion?(CKRecordsArray())

//		var   result = CKRecordsArray()
//
//		gCoreDataStack.search(for: match, within: databaseID) { found in
//
//			if  let more = self.ckRecordsLookup[match] {
//				result = more
//			}
//
//			let unique = found.filter { (zRecord) -> Bool in
//				return zRecord.ckRecord != nil
//			}
//
//			let records = unique.map { (zRecord) -> CKRecord in
//				return zRecord.ckRecord!
//			}
//
//			result.appendUnique(contentsOf: records)
//
//			self.ckRecordsLookup[match] = result // accumulate from core data
//		}
	}
	
	func addToLocalSearchIndex(name: String, for iZone: Zone?) {
		if  let record = iZone?.ckRecord {
			appendCKRecordsLookup(with: name) { iRecords -> (CKRecordsArray) in
				var records = iRecords
				
				records.appendUnique(item: record)
				
				return records
			}
		}
	}
	
	func addToLocalSearchIndex(nameOf iZone: Zone?) {
        if  let name = iZone?.zoneName {
			addToLocalSearchIndex(name: name, for: iZone)
        }
    }

    func removeFromLocalSearchIndex(nameOf iZone: Zone?) {
        if  let record = iZone?.ckRecord,
            let   name = iZone?.zoneName {
            appendCKRecordsLookup(with: name) { iRecords -> (CKRecordsArray) in
                var records = iRecords

                if let index = records.firstIndex(of: record) {
                    records.remove(at: index)
                }

                return records
            }
        }
    }

    func searchLocal(for name: String) -> CKRecordsArray {
        var results = CKRecordsArray()

		appendCKRecordsLookup(with: name) { (iRecords: CKRecordsArray) -> (CKRecordsArray) in
			var filtered = CKRecordsArray()

			for record in iRecords {
				if  record.matchesFilterOptions {
					filtered.appendUnique(item: record)
				}
			}

			results.appendUnique(contentsOf: filtered)

            return filtered // add these to name key
        }

        return results
    }

    @discardableResult func registerZRecord(_  iRecord: ZRecord?) -> Bool {
		var                created  = false
		if  let            zRecord  = iRecord,
            let               name  = zRecord.ckRecordName {
			if  let existingRecord  = zRecordsLookup[name] {
                if  existingRecord != zRecord, existingRecord.ckRecord?.recordType == zRecord.ckRecord?.recordType {

                    // /////////////////////////////////////
                    // if already registered, must ignore //
                    // /////////////////////////////////////

					duplicates.appendUnique(item: zRecord)

					return false
				}
            } else {
                zRecordsLookup[name] = zRecord

				registerByType(zRecord)

				if  let        zone = zRecord as? Zone {
					addToLocalSearchIndex(nameOf: zone)
				}

				created = true
            }
			
			if  let bookmark = zRecord as? Zone, bookmark.isBookmark {
				gBookmarks.addToReverseLookup(bookmark)
			}
        }

        return created
    }

	func registerByType(_ iRecord: ZRecord?) {
		if  let      record = iRecord?.ckRecord {
			let        type = record.recordType
			let        name = record.recordID.recordName
			var recordNames = recordNamesByType[type] ?? []

			recordNames.append(name)

			recordNamesByType[type] = recordNames
		}
	}

    func unregisterCKRecord(_ ckRecord: CKRecord?) {
        if  let      name  = ckRecord?.recordID.recordName {
            clearRecordName(name, for: allStates)

			if  ckRecordsLookup[name] != nil {
				ckRecordsLookup[name]  = nil
			}
        }
    }

    func unregisterZRecord(_ zRecord: ZRecord?) {
        unregisterCKRecord(zRecord?.ckRecord)
		removeFromLocalSearchIndex(nameOf: zRecord as? Zone)
        gBookmarks.forget(zRecord as? Zone)
    }

    func removeDuplicates() {
        for duplicate in duplicates {
            duplicate.orphan()

            if  let zone = duplicate as? Zone {
                zone.children.removeAll()
            }
        }

        duplicates.removeAll()
    }

    // MARK:- record state
    // MARK:-

    var undeletedCounts: (Int, Int) {
        let zRecords = zRecordsLookup.values
        var   uCount = zRecords.count
        var   nCount = 0

        for zRecord in zRecords {
            if  let zone = zRecord as? Zone { // ONLY count zones
                if !zone.canSaveWithoutFetch {
                    nCount += 1
                } else if let root = zone.root, !root.isTrashRoot, !root.isFavoritesRoot, !root.isLostAndFoundRoot {
                    continue
                }
            }

            uCount -= 1 // traits, trash, favorites, lost and found
        }

        return (uCount, nCount)
    }

    var allStates: [ZRecordState] {
        var    all = [ZRecordState] ()
        let states = recordNamesByState.keys

        for state in states {
            all.append(state)   // funky: swift cannot convert .keys into an array
        }

        return all
    }

    func states(for iRecord: CKRecord) -> [ZRecordState] {
        let   name = iRecord.recordID.recordName
        var states = [ZRecordState] ()

        applyToAllRecordNamesWithAnyMatchingStates(allStates) { (iState, iName) in
            if !states.contains(iState) && iName == name {
                states.append(iState)
            }

			return false
        }

        return states
    }

	func applyToAllProgeny(closure: ZoneClosure) {
		rootZone?.traverseAllProgeny { zone in
			closure(zone)
		}
	}

	func applyToAllOrphans(closure: ZoneClosure) {
		applyToAllZones { zone in
			if  zone.root == nil {
				closure(zone)
			}
		}
	}

	func applyToAllZones(closure: ZoneClosure) {
		applyToAllZRecords { zRecord in
			if  let zone = zRecord as? Zone {
				closure(zone)
			}
		}
	}

	func applyToAllZRecords(closure: ZRecordClosure) {
		for zRecord in zRecordsLookup.values {
			closure(zRecord)
		}
	}

	func resolve(_ onCompletion: IntClosure? = nil) {
		FOREGROUND {
			let (fixed, found) = self.updateAllInstanceProperties(0, 0)
			printDebug(.dFix, "fixed: \(fixed) found: \(found)")
			onCompletion?(0)
		}
	}

	@discardableResult func updateAllInstanceProperties(_ iFixed: Int, _ iLost: Int) -> (Int, Int) {
		var fixed = 0
		var  lost = 0

		applyToAllZRecords { zRecord in
			if  let zone = zRecord as? Zone {
				let root = zone.ancestralPath.first

				if  zone.zoneName == nil {
					zone.updateInstanceProperties()

					if  let n = root?.ckRecordName,
						![kLostAndFoundName, kDestroyName, kTrashName, kRootName].contains(n) {
						printDebug(.dFix, "fixed: \(n)")
					}

					fixed += 1
				}

				if  let r = root,
				   !r.isARoot,
					r.parent == nil,
					r.parentLink == nil {
					printDebug(.dFix, "found: \(r)")

					lost += 1
				}
			}
		}

		return (iFixed + fixed, iLost + lost)
	}

	func assureAdoption(_ onCompletion: IntClosure? = nil) {
		FOREGROUND {
			self.applyToAllZones { zone in
				zone.adopt()

				if  zone.root == nil {
					printDebug(.dAdopt, "nil root at: \(zone.ancestralString)")
				}
			}

			onCompletion?(0)
		}
	}

    func adoptAllNeedingAdoption() {
        let states = [ZRecordState.needsAdoption] // just one state

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iRecordName in
            if  let zRecord = maybeZRecordForRecordName(iRecordName) {
				zRecord.adopt()
            }

			return false
        }
    }

	func hasZRecord(_ iRecord: ZRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        if  let ckRecord = iRecord.ckRecord {
            return hasCKRecord(ckRecord, forAnyOf: iStates)
        }

        return false
    }

    func registeredCKRecordForName(_ iName: String, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        var found: CKRecord?

        applyToCKRecordByRecordName(iName, forAnyOf: iStates) { (state: ZRecordState, record: CKRecord) in
            found = record
        }

        return found
    }

    // MARK:- set state
    // MARK:-

	var ignoreNone = false
    var ignoredRecordName: String?
    let kIgnoreAllRecordNames = "all record names"

    func temporarilyIgnoreAllNeeds(_ closure: Closure) {
        temporarilyForRecordNamed(kIgnoreAllRecordNames, ignoreNeeds: true, closure)
    }

    func temporarilyForRecordNamed(_ iRecordName: String?, ignoreNeeds: Bool, _ closure: Closure) {
        let         saved =  ignoredRecordName
		ignoredRecordName = !ignoreNeeds ? nil : iRecordName ?? kIgnoreAllRecordNames
        closure()
        ignoredRecordName = saved
    }

    func temporarilyIgnoring(_ iName: String?) -> Bool {
        if !ignoreNone,
			let   ignore = ignoredRecordName {
            let    names = [kIgnoreAllRecordNames] + (iName == nil ? [] : [iName!])
            return names.contains(ignore)
        }

        return false
    }

    func addZRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if  let ckrecord = iRecord.ckRecord {
            addCKRecord(ckrecord, for: states)
        }
    }

    @discardableResult func addCKRecord(_ iRecord: CKRecord?, for states: [ZRecordState]) -> Bool {
        var added = false

        if  let ckRecord = iRecord,
            !temporarilyIgnoring(ckRecord.recordID.recordName) {
            for state in states {
                if  registeredCKRecordForName(ckRecord.recordID.recordName, forAnyOf: [state]) == nil {
                    var names = recordNamesForState(state)
                    let  name = ckRecord.recordID.recordName

                    if !names.contains(name) {
                        names.append(name)

                        recordNamesByState[state] = names

                        added = true
                    }
                }
            }
        }

        return added
    }

    func add(states: [ZRecordState], to iReferences: CKReferencesArray) {
        for reference in iReferences {
            if let zRecord = maybeZRecordForRecordID(reference.recordID) {
                addZRecord(zRecord, for: states)
            }
        }
    }

	// MARK:- clear state
	// MARK:-

	func remove(states: [ZRecordState], from iReferences: CKReferencesArray) {
		for reference in iReferences {
			clearRecordName(reference.recordID.recordName, for:states)
		}
	}

	func clear() {
		clearAllStatesForAllRecords()
		ckRecordsLookup = [:]
		zRecordsLookup  = [:]
	}

    func clearAllStatesForAllRecords() {
        recordNamesByState.removeAll()
    }

    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }

    func clearState(_ state: ZRecordState) {
        recordNamesByState[state] = []
    }

    func clearRecordIDs(_ recordIDs: CKRecordIDsArray, for states: [ZRecordState]) {
        for recordID in recordIDs {
            clearRecordName(recordID.recordName, for:states)
        }
    }

    func clearCKRecords(_ iRecords: CKRecordsArray, for states: [ZRecordState]) {
        for record in iRecords {
            clearRecordName(record.recordID.recordName, for: states)
        }
    }

    func clearRecordNames(_ iNames: [String], for iStates: [ZRecordState]) {
        for name in iNames {
            clearRecordName(name, for: iStates)
        }
    }

    func clearZRecords(_ records: ZRecordsArray, for states: [ZRecordState]) {
        for record in records {
            if  let name = record.recordName {
                clearRecordName(name, for: states)
            }
        }
    }

    func clearRecordName(_ iName: String?, for iStates: [ZRecordState]) {
        if  let name = iName {
            for state in iStates {
                var names = recordNamesForState(state)    // auto-creates keypair for state

                if  let index = names.firstIndex(of: name) {
                    names.remove(at: index)

                    recordNamesByState[state] = names
                }
            }
        }
    }

    func pullRecordIDsWithHighestLevel(for states: [ZRecordState], batchSize: Int = kBatchSize) -> CKRecordIDsArray {
        var found = [Int : CKRecordIDsArray] ()
        var results = CKRecordIDsArray ()

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            var       zoneLevel = 0

            if  let levelString = iCKRecord[kpZoneLevel] as? String,
                let zLevel      = levelString.integerValue {
                zoneLevel       = zLevel
            }

            if  var level = found[zoneLevel] {
                level.append(iCKRecord.recordID)

                found[zoneLevel] = level
            } else {
                found[zoneLevel] = [iCKRecord.recordID]
            }
        }

        for (_, identifiers) in found.values.enumerated().reversed() {
            for identifier in identifiers {
                if  results.count < batchSize {
                    results.append(identifier)
                    clearRecordName(identifier.recordName, for: states)
                }
            }

            break
        }

        return results
    }

    // MARK:- lookup by state
    // MARK:-

    func recordIDsWithMatchingStates( _ states: [ZRecordState], pull: Bool = false, batchSize: Int = kBatchSize) -> CKRecordIDsArray {
        var identifiers = CKRecordIDsArray ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            let identifier = CKRecordID(recordName: iName)

            if  identifiers.count < batchSize {
                var appended = false

                for id in identifiers {
                    if id.recordName == iName {
                        appended = true

                        break
                    }
                }

                if !appended {
                    identifiers.append(identifier)
                }

				return false
            }

			return true
        }

        if  pull {
            clearRecordIDs(identifiers, for: states)
        }

        return identifiers
    }

    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> CKRecordIDsArray {
        var parents = CKRecordIDsArray ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  parents.count < kBatchSize,
                let      zone = maybeZoneForRecordName(iName),
                let reference = zone.parent {
                let  parentID = reference.recordID

                if !parents.contains(parentID) {
                    parents.append(parentID)
                }

				return false
            }

			return true
        }

        return parents
    }

	func pullCKRecordsForZonesAndTraitsWithMatchingStates(_ states: [ZRecordState]) -> CKRecordsArray {
        var results = CKRecordsArray ()

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            if  results.count < kBatchSize && !results.contains(iCKRecord) {
                results.append(iCKRecord)

				// also grab traits
				if  let zone = maybeZoneForCKRecord(iCKRecord) {
					for trait in zone.traitValues {
						if  let ckTraitRecord = trait.ckRecord, !results.contains(ckTraitRecord) {
							results.append(ckTraitRecord)
						}
					}
				}
            }
        }

        clearCKRecords(results, for: states)
        
        return results
    }

	func pullReferencesWithMatchingStates(_ states: [ZRecordState]) -> CKReferencesArray {
        let references = referencesWithMatchingStates(states)

        remove(states: states, from: references)

        return references
    }

	func referencesWithMatchingStates(_ states: [ZRecordState]) -> CKReferencesArray {
        var references = CKReferencesArray()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  references.count < kBatchSize {
                let reference = CKReference(recordID: CKRecordID(recordName: iName), action: .none)

                references.append(reference)

				return false
			}

			return true
        }

        return references
    }

	func hasAnyRecordsMarked(with states: [ZRecordState]) -> Bool {
        var found = false

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            found = true

			return true
        }

        return found
    }

	func referencesWithMatchingStates(_ iStates: [ZRecordState], batchSize: Int) -> CKReferencesArray {
        var references = CKReferencesArray()

		applyToAllRecordNamesWithAnyMatchingStates(iStates) { iState, iName in
			if  references.count < batchSize {
				references.append(CKReference(recordID: CKRecordID(recordName: iName), action: .none))

				return false
			}

			return true
		}

        return references
    }

	// MARK:- batch lookup
    // MARK:-

	func fullUpdate(for states: [ZRecordState], _ onEach: StateRecordClosure) {
        var names = [String] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  let record = maybeZRecordForRecordName(iName) {
                onEach(iState, record)
            }

            names.append(iName)

			return false
        }

        clearRecordNames(names, for: states)
    }

	func applyToCKRecordByRecordName(_ iName: String?, forAnyOf iStates: [ZRecordState], onEach: StateCKRecordClosure?) {
        if let name = iName {
            for state in iStates {
                let names = recordNamesForState(state)

                if  names.contains(name), let ckRecord = maybeCKRecordForRecordName(name) {
                    onEach!(state, ckRecord)
                }
            }
        }
    }

	func applyToAllCKRecordsWithAnyMatchingStates(_ iStates: [ZRecordState], onEach: StateCKRecordClosure) {
		applyToAllRecordNamesWithAnyMatchingStates(iStates) { iState, iName in
			if  let ckRecord = maybeCKRecordForRecordName(iName) {
				onEach(iState, ckRecord)
			}

			return false
		}
	}

	func applyToAllRecordNamesWithAnyMatchingStates(_ iStates: [ZRecordState], onEach: StateStringClosure) {
        for state in iStates {
            let names = recordNamesForState(state)

            for name in names {
				if  onEach(state, name) {
					break
				}
            }
        }
    }

	func focusOnGrab(_ kind: ZFocusKind = .eEdited, _ COMMAND: Bool = false, shouldGrab: Bool = false, _ atArrival: @escaping Closure) {

		// regarding grabbed/edited zone, five states:
		// 1. is a bookmark     -> target becomes here, if in big map then do as for state 2
		// 2. is here           -> update in small map
		// 3. in small map      -> grab here, if grabbed then do as for state 4
		// 4. not here, COMMAND -> become here
		// 5. not COMMAND       -> select here, create a bookmark

		guard  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab else {
			atArrival()

			return
		}

		let finishAndGrab = { (grabMe: Zone) in
			gSmallMapController?.update()
			grabMe.grab() // changes work mode !!!!!!!
			atArrival()
		}

		if  zone.isBookmark {     		// state 1
			zone.focusOnBookmarkTarget() { object, kind in
				gHere = object as! Zone

				finishAndGrab(gHere)
			}
		} else if zone == gHere {       // state 2
			if  let small = gCurrentSmallMapRecords,
				!small.swapBetweenBookmarkAndTarget(doNotGrab: !shouldGrab) {
				if  gSmallMapMode == .favorites {
					gFavorites.addNewBookmark(for: zone, action: .aCreateBookmark)
				}
			}

			atArrival()
		} else if zone.isInSmallMap {   // state 3
			finishAndGrab(gHere)
		} else if COMMAND {             // state 4
			gRecents.refocus {
				atArrival()
			}
		} else {                        // state 5
			if  shouldGrab {
				gHere = zone
			}

			finishAndGrab(zone)
		}
	}

    // MARK:- debug
    // MARK:-

	func stringForRecordIDs(_ recordIDs: CKRecordIDsArray?) -> String {
        return recordIDs?.applyIntoString()  { object -> (String?) in
            if  let recordID = object as? CKRecordID,
                let    name  = stringForRecordID(recordID) {
                return name
            }

            return nil
        } ?? ""
    }

    
    func stringForRecordID(_ iID: CKRecordID) -> String? {
        if  let  zRecord = maybeZRecordForRecordID(iID),
            let        r = zRecord.ckRecord {
            let    name  = r.decoratedName
            if     name != "" {
                return name
            }
        }
        
        return nil
        
    }

	// MARK:- lookups
    // MARK:-

	func      maybeZoneForReference (_ iReference: CKReference) ->     Zone? { return maybeZoneForRecordID      (iReference.recordID) }
    func       maybeZoneForCKRecord (_ iRecord:    CKRecord?)   ->     Zone? { return maybeZoneForRecordID      (iRecord?  .recordID) }
    func    maybeZRecordForCKRecord (_ iRecord:    CKRecord?)   ->  ZRecord? { return maybeZRecordForRecordName (iRecord?  .recordID.recordName) }
    func    maybeZRecordForRecordID (_ iRecordID:  CKRecordID?) ->  ZRecord? { return maybeZRecordForRecordName (iRecordID?.recordName) }
	func      maybeTraitForRecordID (_ iRecordID:  CKRecordID?) ->   ZTrait? { return maybeZRecordForRecordID   (iRecordID)   as? ZTrait }
	func       maybeZoneForRecordID (_ iRecordID:  CKRecordID?) ->     Zone? { return maybeZRecordForRecordID   (iRecordID)   as? Zone }
	func     maybeZoneForRecordName (_ iRecordName:    String?) ->     Zone? { return maybeZRecordForRecordName (iRecordName) as? Zone }
	func maybeCKRecordForRecordName (_ iRecordName:    String?) -> CKRecord? { return maybeZRecordForRecordName (iRecordName)?.ckRecord }

	func  maybeZRecordForRecordName (_ iRecordName:    String?) ->  ZRecord? {
		if  let name = iRecordName {

			if  [.recentsID, .favoritesID].contains(databaseID) {
				return gRemoteStorage.cloud(for: .mineID)?.maybeZRecordForRecordName(iRecordName)     // there is no recents db
			} else if  databaseID.rawValue == name {
				return rootZone
			}

			let zRecord = zRecordsLookup[name]                               // look it up by record name

			if  let recordType = zRecord?.ckRecord?.recordType,              // look for mistakes in object creation
				(zRecord as? ZTrait != nil && recordType == kZoneType) ||
				(zRecord as?   Zone != nil && recordType == kTraitType) {
				recordsMistyped[name] = zRecord

				return nil
			}

			return zRecord
		}

		return nil
	}

    func sureZoneForCKRecord(_ ckRecord: CKRecord, requireFetch: Bool = true, preferFetch: Bool = false) -> Zone {
        var zone = maybeZoneForCKRecord(ckRecord)

        if  let z = zone {
            z.useBest(record: ckRecord)
        } else {
            zone = Zone.create(record: ckRecord, databaseID: databaseID)

//			if  requireFetch {
//				zone?.fetchBeforeSave() // POTENTIALLY BAD DUMMY
//			}

//			if  preferFetch || requireFetch {
//				zone?.needFetch()
//			}
        }

        return zone!
    }

}
