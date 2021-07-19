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
	case needsAdoption  = "adopt"
    case needsBookmarks = "bookmarks"
    case needsColor     = "color"
	case needsCount     = "count"
    case needsDestroy   = "destroy"
    case needsWritable  = "writable"
}

class ZRecords: NSObject {

	var            maxLevel = 0
	var          duplicates =  ZRecordsArray                ()
	var       foundInSearch =  ZRecordsArray                ()
	var      zRecordsLookup =  StringZRecordDictionary      ()
	var     recordsMistyped =  StringZRecordDictionary      ()
	var zRecordsArrayLookup =  StringZRecordsDictionary     ()
	var  recordNamesByState = [ZRecordState : StringsArray] ()
	var   recordNamesByType = [String       : StringsArray] ()
    var        lastSyncDate = Date(timeIntervalSince1970: 0)
	var             orphans = ZoneArray()
    var          databaseID : ZDatabaseID
    var            manifest : ZManifest?
    var    lostAndFoundZone : Zone?
	var       favoritesZone : Zone?
	var         recentsZone : Zone?
	var         destroyZone : Zone?
    var           trashZone : Zone?
    var            rootZone : Zone?
	var               count : Int       { return 0 }
	var       zRecordsCount : Int       { return zRecordsLookup.count }
    var         hereIsValid : Bool      { return maybeZoneForRecordName(hereRecordName) != nil }
	var          allProgeny : ZoneArray { return rootZone?.all ?? [] }

	func countBy                      (type: String)  -> Int?     { return recordNamesByType[type]?.count }
	func recordNamesForState (_ state: ZRecordState)  -> StringsArray { return recordNamesByState[state] ?? [] }

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
			var        references  = completeHereRecordNames
			if  let         index  = databaseID.index,
				let         value  = newValue,
				references[index] != value {
				references[index]  = value
				gHereRecordNames   = references.joined(separator: kColonSeparator)
			}
		}

		get {
			if  let          index = databaseID.index {
				let     references = completeHereRecordNames
				return  references[index]
			}
			
			return nil
		}
    }

	var completeHereRecordNames: StringsArray {
		var       references = gHereRecordNames.components(separatedBy: kColonSeparator)
		var          changed = false

		func rootFor(_ index: Int) -> Zone? {
			if  let     dbid = ZDatabaseIndex(rawValue: index)?.databaseID,
				let zRecords = gRemoteStorage.zRecords(for: dbid),
				let     root = zRecords.rootZone {

				return  root
			}

			return nil
		}

		while   references.count < 4 {
			let    index = references.count
			if  let root = rootFor(index),
				let name = root.recordName {
				changed  = true
				references.append(name)
			}
		}

		// detect and fix bad values

		for index in 2...3 {
			let              name = references[index]
			if  let          root = rootFor(index),
				!root.allProgeny.containsAnyOf(name) {
				references[index] = index == 2 ? kFavoritesRootName : kRecentsRootName    // reset to default
				changed           = true
			}
		}

		if  changed {
			gHereRecordNames = references.joined(separator: kColonSeparator)
		}

		return references
	}
    
    var hereZoneMaybe: Zone? {
		get { return maybeZoneForRecordName(hereRecordName) }
		set { hereRecordName = newValue?.recordName ?? rootName }
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

	func updateMaxLevel(with level: Int) {
		maxLevel = max(level, maxLevel)
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
				gCoreDataStack.removeAllDuplicatesOf(z)
			}
		}

		gCoreDataStack.emptyZones(within: databaseID) { empties in
			for empty in empties {
				empty.needDestroy()
			}
		}
	}

	func createRandomLost() -> Zone {
        let lost = Zone.randomZone(in: databaseID)

        lostAndFoundZone?.addChildNoDuplicate(lost, at: nil)

        return lost
    }

    func recount() {  // all progenyCounts for all progeny in all roots
		rootZone?        .recount()
		trashZone?       .recount()
		destroyZone?     .recount()
		recentsZone?     .recount()
		favoritesZone?   .recount()
		lostAndFoundZone?.recount()

		manifest?.count = NSNumber(value: zRecordsCount)
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
    
    func properties(for recordType: String?) -> StringsArray {
        if  let   name = className(for: recordType),
            let  klass = NSClassFromString(name),
            let zClass = klass as? ZRecord.Type {
                return zClass.cloudProperties
        }

		return []
    }

    // MARK:- registries
    // MARK:-

	func appendZRecordsLookup(with iName: String, onEach: @escaping ZRecordsToZRecordsClosure) {
		let names = iName.components(separatedBy: kSpace).filter { $0 != kEmpty }

		gCoreDataStack.searchZRecordsForNames(names, within: databaseID) { (dict: StringZRecordsDictionary) in
			for (name, zRecords) in dict {
				let                    records = onEach(zRecords)
				self.zRecordsArrayLookup[name] = records

				self.foundInSearch.append(contentsOf: records)
			}

			let _ = onEach(nil) // indicates done
		}
	}

    func removeFromLocalSearchIndex(nameOf zone: Zone?) {
		if  let record = zone,
            let   name = record.zoneName {
			appendZRecordsLookup(with: name) { iRecords -> ZRecordsArray in
				if  var records   = iRecords {
					if  let index = records.firstIndex(of: record) {
						records.remove(at: index)
					}

					return records
				}

				return []
            }
        }
    }

	func searchLocal(for name: String, onCompletion: @escaping Closure) {
		appendZRecordsLookup(with: name) { iRecords -> ZRecordsArray in
			guard let records = iRecords else {
				onCompletion()

				return []
			}

			return records // add these to name key
		}
    }

    @discardableResult func registerZRecord(_  iRecord: ZRecord?) -> Bool { // false means did not register
		var                created  = false
		if  let            zRecord  = iRecord,
            let               name  = zRecord.recordName {
			if  let existingRecord  = zRecordsLookup[name] {
                if  existingRecord != zRecord,
					existingRecord.entity.name == zRecord.entity.name {

                    // /////////////////////////////////////
                    // if already registered, must ignore //
                    // /////////////////////////////////////

					duplicates.appendUnique(item: zRecord)

					return false
				}
            } else {
                zRecordsLookup.updateValue(zRecord, forKey: name)
				registerByType(zRecord)

				created = true
            }
			
			if  let bookmark = zRecord as? Zone, bookmark.isBookmark {
				gBookmarks.addToReverseLookup(bookmark)
			} else if let file = zRecord as? ZFile {
				gFilesRegistry.register(file, in: databaseID)
			}
        }

        return created
    }

	func registerByType(_ iRecord: ZRecord?) {
		if  let      record = iRecord,
			let        name = record.recordName {
			let        type = record.emptyName
			var recordNames = recordNamesByType[type] ?? []

			recordNames.append(name)

			recordNamesByType[type] = recordNames
		}
	}

    func unregisterRecordName(_ iName: String?) {
        if  let             name = iName {
            clearRecordName(name, for: allStates)

			if  zRecordsArrayLookup[name] != nil {
				zRecordsArrayLookup[name]  = nil
			}
        }
    }

    func unregisterZRecord(_ zRecord: ZRecord?) {
		unregisterRecordName(zRecord?.recordName)
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

    var allStates: [ZRecordState] { return recordNamesByState.map { $0.key } }

    func states(for recordName: String) -> [ZRecordState] {
        var states = [ZRecordState] ()

        applyToAllRecordNamesWithAnyMatchingStates(allStates) { (iState, iName) in
            if !states.contains(iState) && iName == recordName {
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

	func resolveMissing(_ onCompletion: IntClosure? = nil) {
		gCoreDataStack.resolveMissing(from: databaseID)
		onCompletion?(0)
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

					if  let n = root?.recordName,
						![kLostAndFoundName, kDestroyName, kTrashName, kRootName].contains(n) {
						printDebug(.dFix, "fixed: \(n)")
					}

					fixed += 1
				}

				if  let r = root,
				   !r.isARoot,
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
				if  zone.dbid == nil {
					zone.dbid  = self.databaseID.identifier
				}

				if !zone.isARoot {
					zone.adopt(recursively: true)

					if  zone.root == nil, !zone.isBookmark {
						printDebug(.dAdopt, "lost child: (\(self.databaseID.identifier)) \(zone)")
					}
				}
			}

			onCompletion?(0)
		}
	}

    @discardableResult func adoptAllNeedingAdoption() -> Int {
        let states = [ZRecordState.needsAdoption] // just one state
		var count = 0

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iRecordName in
            if  let zRecord = maybeZRecordForRecordName(iRecordName) {
				zRecord.adopt(recursively: true)
			} else {
				count += 1
			}

			return false // means continue
        }

		return count
    }

	func isRegistered(_ iRecord: ZRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        if  let name = iRecord.recordName {
			return registeredZRecordForName(name, forAnyOf: iStates) != nil
        }

        return false
    }

	func registeredZRecordForName(_ iName: String, forAnyOf iStates: [ZRecordState]) -> ZRecord? {
		var found: ZRecord?

		applyToZRecordByRecordName(iName, forAnyOf: iStates) { (state: ZRecordState, record: ZRecord) in
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

    func addZRecord(_ zRecord: ZRecord, for states: [ZRecordState]) {
        if  !temporarilyIgnoring(zRecord.recordName) {
            for state in states {
				var    names = recordNamesForState(state)

                if  let name = zRecord.recordName, !names.contains(name),
					registeredZRecordForName(name, forAnyOf: [state]) == nil {
					names.append(name)

					recordNamesByState[state] = names
				}
            }
        }
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
		zRecordsArrayLookup = [:]
		zRecordsLookup      = [:]
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

    func clearRecordNames(_ iNames: StringsArray, for iStates: [ZRecordState]) {
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

	// MARK:- batch lookup
    // MARK:-

	func fullUpdate(for states: [ZRecordState], _ onEach: StateRecordClosure) {
        var names = StringsArray ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  let record = maybeZRecordForRecordName(iName) {
                onEach(iState, record)
            }

            names.append(iName)

			return false
        }

        clearRecordNames(names, for: states)
    }

	func applyToZRecordByRecordName(_ iName: String?, forAnyOf iStates: [ZRecordState], onEach: StateRecordClosure?) {
        if let name = iName {
            for state in iStates {
                let names = recordNamesForState(state)

                if  names.contains(name),
					let zRecord = maybeZRecordForRecordName(name) {
                    onEach!(state, zRecord)
                }
            }
        }
    }

	func applyToAllZRecordsWithAnyMatchingStates(_ iStates: [ZRecordState], onEach: StateRecordClosure) {
		applyToAllRecordNamesWithAnyMatchingStates(iStates) { iState, iName in
			if  let zRecord = maybeZRecordForRecordName(iName) {
				onEach(iState, zRecord)
			}

			return false
		}
	}

	func countOfRecordNamesWithAnyMatchintStates(_ iStates: [ZRecordState]) -> Int {
		var count     = 0
		for state in iStates {
			let names = recordNamesForState(state)
			count    += names.count
		}

		return count
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

	func focusOnGrab(_ kind: ZFocusKind = .eEdited, _ NOBOOKMARK: Bool = false, shouldGrab: Bool = false, _ atArrival: @escaping Closure) {

		// regarding grabbed/edited zone, five states:
		// 1. is a bookmark        -> target becomes here, if in big map then do as for state 2
		// 2. is here              -> update in small map
		// 3. in small map         -> grab here, if grabbed then do as for state 4
		// 4. not here, NOBOOKMARK -> change here
		// 5. not NOBOOKMARK       -> select here, create a bookmark

		guard  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab else {
			atArrival()

			return
		}

		let finishAndGrabHere = {
			gSignal([.spSmallMap])
			gHere.grab()               // NOTE: changes work mode
			atArrival()
		}

		if  zone.isBookmark {     		// state 1
			zone.focusOnBookmarkTarget() { object, kind in
				gHere = object as! Zone

				finishAndGrabHere()
			}
		} else if zone == gHere {       // state 2
			if  let small = gCurrentSmallMapRecords,
				!small.swapBetweenBookmarkAndTarget(doNotGrab: !shouldGrab) {
				small.matchOrCreateBookmark(for: zone, autoAdd: true)
			}

			atArrival()
		} else if zone.isInSmallMap {   // state 3
			finishAndGrabHere()
		} else if NOBOOKMARK {          // state 4
			gRecents.refocus {
				atArrival()
			}
		} else {                        // state 5
			gHere = zone

			finishAndGrabHere()
		}
	}

	// MARK:- lookups
    // MARK:-

	func     maybeZoneForRecordName (_ iRecordName:   String?, trackMissing: Bool = true) ->     Zone? { return maybeZRecordForRecordName (iRecordName, trackMissing: trackMissing) as? Zone }
	func    maybeZRecordForRecordID (_ iRecordID: CKRecordID?, trackMissing: Bool = true) ->  ZRecord? { return maybeZRecordForRecordName (iRecordID?.recordName, trackMissing: trackMissing) }

	func maybeZRecordForRecordName (_ recordName: String?, trackMissing: Bool = true) -> ZRecord? {
		if  let r = recordName {
			if  let record = zRecordsLookup[r] {
				return record
			}

			let found = gCoreDataStack.find(type: kZoneType, recordName: r, in: databaseID, trackMissing: trackMissing)
			if  found.count > 0 {
				return found[0] as? ZRecord
			}
		}

		return nil
	}

//	func      maybeZoneForReference (_ iReference: CKReference) ->     Zone? { return maybeZoneForRecordID      (iReference.recordID) }
//    func       maybeZoneForCKRecord (_ iRecord:    CKRecord?)   ->     Zone? { return maybeZoneForRecordID      (iRecord?  .recordID) }
//    func    maybeZRecordForCKRecord (_ iRecord:    CKRecord?)   ->  ZRecord? { return maybeZRecordForRecordName (iRecord?  .recordID.recordName) }
//	func      maybeTraitForRecordID (_ iRecordID:  CKRecordID?) ->   ZTrait? { return maybeZRecordForRecordID   (iRecordID)   as? ZTrait }
//	func       maybeZoneForRecordID (_ iRecordID:  CKRecordID?) ->     Zone? { return maybeZRecordForRecordID   (iRecordID)   as? Zone }
//	func maybeCKRecordForRecordName (_ iRecordName:    String?) -> CKRecord? { return maybeZRecordForRecordName (iRecordName)?.ckRecord }

}
