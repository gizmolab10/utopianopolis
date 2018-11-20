//
//  ZRecordsManager.swift
//  Zones
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
    case needsBookmarks          = "bookmarks"
    case needsCount              = "count"
    case needsChildren           = "children"
    case needsColor              = "color"
    case needsDestroy            = "destroy"
    case needsMerge              = "merge"
    case needsParent             = "parent"
    case needsProgeny            = "progeny"
    case needsRoot               = "root"
    case needsSave               = "save"
    case needsFound              = "found"
    case needsTraits             = "traits"
    case needsWritable           = "writable"
    case needsUnorphan           = "unorphan"
}


class ZRecordsManager: NSObject {


    var              databaseID : ZDatabaseID
    var              duplicates =                  [ZRecord]  ()
    var            nameRegistry = [String       : [CKRecord]] ()
    var          recordRegistry = [String       :   ZRecord]  ()
    var      recordNamesByState = [ZRecordState :   [String]] ()
    var            lastSyncDate = Date(timeIntervalSince1970: 0)
    var lostAndFoundZone: Zone? = nil
    var    favoritesZone: Zone? = nil // only for .mineID manager
    var      destroyZone: Zone? = nil
    var        trashZone: Zone? = nil
    var         rootZone: Zone? = nil
    var      hereIsValid: Bool { return maybeZoneForRecordName(hereRecordName) != nil }


    var hereRecordName: String? {
        get { return gSelectionManager.hereRecordName(for: databaseID) }
        set { gSelectionManager.setHereRecordName(newValue ?? kRootName, for: databaseID) }
    }


    var hereZone: Zone {
        get { return maybeZoneForRecordName(hereRecordName) ?? rootZone! }
        set { hereRecordName = newValue.recordName ?? kRootName }
    }


    init(_ idatabaseID: ZDatabaseID) {
        databaseID = idatabaseID
    }


    func createRandomLost() -> Zone {
        let lost = Zone.randomZone(in: databaseID)

        lostAndFoundZone?.addChild(lost, at: nil)

        return lost
    }


    func updateLastSyncDate() {
        var date = lastSyncDate

        for zRecord in recordRegistry.values {
            if  let modificationDate = zRecord.record.modificationDate,
                modificationDate.timeIntervalSince(date) > 0 {

                date = modificationDate
            }
        }

        lastSyncDate = date
    }


    func recount() {  // all progenyCounts for all progeny in all roots
        hereZone         .updateCounts()
        trashZone?       .updateCounts()
        favoritesZone?   .updateCounts()
        lostAndFoundZone?.updateCounts()
    }
    

    // MARK:- registries
    // MARK:-


    func apply(to iName: String, onEach: RecordsToRecordsClosure) {
        for part in iName.components(separatedBy: " ") {
            if  part != "" {
                var records  = nameRegistry[part]

                if  records == nil {
                    records  = []
                }

                records            = onEach(records!)
                nameRegistry[part] = records
            }
        }
    }


    func registerName(of iZone: Zone?) {
        if  let record = iZone?.record,
            let   name = iZone?.zoneName {
            apply(to: name) { iRecords -> ([CKRecord]) in
                var records = iRecords

                records.append(record)

                return records
            }
        }
    }


    func unregisterName(of iZone: Zone?) {
        if  let record = iZone?.record,
            let   name = iZone?.zoneName {
            apply(to: name) { iRecords -> ([CKRecord]) in
                var records = iRecords

                if let index = records.index(of: record) {
                    records.remove(at: index)
                }

                return records
            }
        }
    }


    func searchLocal(for name: String) -> [CKRecord] {
        var results = [CKRecord] ()

        apply(to: name) { iRecords -> ([CKRecord]) in
            results.appendUnique(contentsOf: iRecords)

            return iRecords
        }

        return results
    }


    func registerZRecord(_  iRecord : ZRecord?) -> Bool {
        if  let      zRecord  = iRecord,
            let           id  = zRecord.recordName {
            if let oldRecord  = recordRegistry[id] {
                if oldRecord != zRecord {

                    ///////////////////////////////////////
                    // if already registered, must erase //
                    ///////////////////////////////////////

                    duplicates.append(zRecord)
                }
            } else {
                if  let bookmark = zRecord as? Zone, bookmark.isBookmark {
                    gBookmarksManager.registerBookmark(bookmark)
                }

                recordRegistry[id]  = zRecord

                registerName(of: zRecord as? Zone)

                return true
            }
        }

        return false
    }


    func unregisterCKRecord(_ ckRecord: CKRecord?) {
        if  let      name  = ckRecord?.recordID.recordName {
            clearRecordName(name, for: allStates)

            recordRegistry[name] = nil
        }
    }


    func unregisterZRecord(_ zRecord: ZRecord?) {
        unregisterCKRecord(zRecord?.record)
        unregisterName(of: zRecord as? Zone)
        gBookmarksManager.unregisterBookmark(zRecord as? Zone)
    }


    func notRegistered(_ recordID: CKRecord.ID?) -> Bool {
        return maybeZoneForRecordID(recordID) == nil
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
        let zRecords = recordRegistry.values
        var   uCount = zRecords.count
        var   nCount = 0

        for zRecord in zRecords {
            if  let zone = zRecord as? Zone { // ONLY count zones
                if !zone.canSaveWithoutFetch {
                    nCount += 1
                } else if let root = zone.root, !root.isTrash, !root.isRootOfFavorites, !root.isRootOfLostAndFound {
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


    func recordNamesForState(_ state: ZRecordState) -> [String] {
        var recordNames               = recordNamesByState[state]

        if  recordNames              == nil {
            recordNames               = []
            recordNamesByState[state] = recordNames
        }

        return recordNames!
    }


    func states(for iRecord: CKRecord) -> [ZRecordState] {
        let   name = iRecord.recordID.recordName
        var states = [ZRecordState] ()

        applyToAllRecordNamesWithAnyMatchingStates(allStates) { (iState, iName) in
            if !states.contains(iState) && iName == name {
                states.append(iState)
            }
        }

        return states
    }


    func unorphanAll() {
        let states = [ZRecordState.needsUnorphan]

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iRecordName in
            if  let zRecord = maybeZRecordForRecordName(iRecordName) {
                clearRecordName(iRecordName, for: states)
                zRecord.unorphan()
            }
        }
    }


    func hasCKRecordName(_ iName: String, forAnyOf iStates: [ZRecordState]) -> Bool {
        return registeredCKRecordForName(iName, forAnyOf: iStates) != nil
    }


    func hasCKRecordID(_ iRecordID: CKRecord.ID, forAnyOf iStates: [ZRecordState]) -> Bool {
        return registeredCKRecordForID(iRecordID, forAnyOf: iStates) != nil
    }


    func hasCKRecord(_ ckRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        return registeredCKRecord(ckRecord, forAnyOf: iStates) != nil
    }


    func hasZRecord(_ iRecord: ZRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        if  let ckRecord = iRecord.record {
            return hasCKRecord(ckRecord, forAnyOf: iStates)
        }

        return false
    }


    func registeredCKRecordForName(_ iName: String, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        var found: CKRecord? = nil

        applyToCKRecordByRecordName(iName, forAnyOf: iStates) { (state: ZRecordState, record: CKRecord) in
            found = record
        }

        return found
    }


    func registeredCKRecordForID(_ iRecordID: CKRecord.ID, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        return registeredCKRecordForName(iRecordID.recordName, forAnyOf: iStates)
    }


    func registeredCKRecord(_ iRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        return registeredCKRecordForID(iRecord.recordID, forAnyOf: iStates)
    }


    // MARK:- set state
    // MARK:-


    var ignoredRecordName: String? = nil
    let kIgnoreAllRecordNames = "all record names"


    func temporarilyForRecordNamed(_ iRecordName: String?, ignoreNeeds: Bool, _ closure: Closure) {
        let         saved = ignoredRecordName
        ignoredRecordName = ignoreNeeds ? iRecordName ?? kIgnoreAllRecordNames : nil
        closure()
        ignoredRecordName = saved
    }


    func temporarilyIgnoring(_ iName: String?) -> Bool {
        if  let   ignore = ignoredRecordName {
            let    names = [kIgnoreAllRecordNames] + (iName == nil ? [] : [iName!])
            return names.contains(ignore)
        }

        return false
    }


    func addZRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if  let ckrecord = iRecord.record {
            addCKRecord(ckrecord, for: states)
        }
    }


    @discardableResult func addCKRecord(_ iRecord: CKRecord, for states: [ZRecordState]) -> Bool {
        var added = false

        if !temporarilyIgnoring(iRecord.recordID.recordName) {
            for state in states {
                if  let  record  = registeredCKRecord(iRecord, forAnyOf: [state]) {
                    if   record != iRecord {
                        var name =  record.decoratedName
                        if  name == "" {
                            name = iRecord.decoratedName
                        }

//                        columnarReport("PREVENTING ADDING TWICE!", name + " (for: \(state))")
                    }
                } else {
                    var names = recordNamesForState(state)
                    let  name = iRecord.recordID.recordName

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


    func add(states: [ZRecordState], to iReferences: [CKRecord.Reference]) {
        for reference in iReferences {
            if let zRecord = maybeZRecordForRecordID(reference.recordID) {
                addZRecord(zRecord, for: states)
            }
        }
    }

	
	func clear() {
		clearAllStatesForAllRecords()
		recordRegistry = [:]
		nameRegistry = [:]
	}
	

    // MARK:- clear state
    // MARK:-


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


    func clearReferences(_ references: [CKRecord.Reference], for states: [ZRecordState]) {
        for reference in references {
            clearRecordName(reference.recordID.recordName, for:states)
        }
    }


    func clearRecordIDs(_ recordIDs: [CKRecord.ID], for states: [ZRecordState]) {
        for recordID in recordIDs {
            clearRecordName(recordID.recordName, for:states)
        }
    }


    func clearCKRecords(_ iRecords: [CKRecord], for states: [ZRecordState]) {
        for record in iRecords {
            clearRecordName(record.recordID.recordName, for: states)
        }
    }


    func clearRecordNames(_ iNames: [String], for iStates: [ZRecordState]) {
        for name in iNames {
            clearRecordName(name, for: iStates)
        }
    }


    func clearZRecords(_ records: [ZRecord], for states: [ZRecordState]) {
        for record in records {
            if let name = record.recordName {
                clearRecordName(name, for: states)
            }
        }
    }


    func clearRecordName(_ iName: String?, for iStates: [ZRecordState]) {
        if  let name   = iName {
            for state in iStates {
                var names = self.recordNamesForState(state)

                if let index = names.index(of: name) {
                    names.remove(at: index)

                    self.recordNamesByState[state] = names
                }
            }
        }
    }


    func pullRecordIDsWithHighestLevel(for states: [ZRecordState], batchSize: Int = kBatchSize) -> [CKRecord.ID] {
        var found = [Int : [CKRecord.ID]] ()
        var results = [CKRecord.ID] ()

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


    func recordIDsWithMatchingStates( _ states: [ZRecordState], pull: Bool = false, batchSize: Int = kBatchSize) -> [CKRecord.ID] {
        var identifiers = [CKRecord.ID] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            let identifier = CKRecord.ID(recordName: iName)
            let       name = iName

            if  identifiers.count < batchSize {
                var appended = false

                for id in identifiers {
                    if id.recordName == name {
                        appended = true

                        break
                    }
                }

                if !appended {
                    identifiers.append(identifier)
                }
            }
        }

        if pull {
            clearRecordIDs(identifiers, for: states)
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord.ID] {
        var parents = [CKRecord.ID] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  parents.count < kBatchSize,
                let      zone = maybeZoneForRecordName(iName),
                let reference = zone.parent {
                let  parentID = reference.recordID

                if !parents.contains(parentID) {
                    parents.append(parentID)
                }
            }
        }

        return parents
    }


    func pullCKRecordsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord] {
        var results = [CKRecord] ()

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            if  results.count < kBatchSize && !results.contains(iCKRecord) {
                results.append(iCKRecord)
            }
        }

        clearCKRecords(results, for: states)
        
        return results
    }


    func pullReferencesWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord.Reference] {
        let references = referencesWithMatchingStates(states)

        clearReferences(references, for: states)

        return references
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord.Reference] {
        var references = [CKRecord.Reference] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  references.count < kBatchSize {
                let reference = CKRecord.Reference(recordID: CKRecord.ID(recordName: iName), action: .none)

                references.append(reference)
            }
        }

        return references
    }


    func pullChildrenRefsWithMatchingStates(_ states: [ZRecordState], batchSize: Int) -> [CKRecord.Reference] {
        let references = childrenRefsWithMatchingStates(states, batchSize: batchSize)

        clearReferences(references, for: states)

        return references
    }


    func hasAnyRecordsMarked(with states: [ZRecordState]) -> Bool {
        var found = false

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            found = true
        }

        return found
    }


    func childrenRefsWithMatchingStates(_ states: [ZRecordState], batchSize: Int) -> [CKRecord.Reference] {
        var references = [CKRecord.Reference] ()
        var  expecting = 0

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            if  let fetchable = (iCKRecord[kpZoneCount] as? NSNumber)?.intValue,
                !iCKRecord.isBookmark, (fetchable + expecting) < batchSize {
                expecting    += fetchable

                references.append(CKRecord.Reference(recordID: iCKRecord.recordID, action: .none))
            }
        }

        return references
    }


    // MARK:- batch lookup
    // MARK:-


    func fullUpdate(for states: [ZRecordState], _ onEach: StateRecordClosure) {
        var names = [String] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if let record = maybeZRecordForRecordName(iName) {
                onEach(iState, record)
            }

            names.append(iName)
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
        for state in iStates {
            let names = recordNamesForState(state)

            for name in names {
                if let ckRecord = maybeCKRecordForRecordName(name) {
                    onEach(state, ckRecord)
                }
            }
        }
    }


    func applyToAllRecordNamesWithAnyMatchingStates(_ iStates: [ZRecordState], onEach: StateRecordNameClosure) {
        for state in iStates {
            let names = recordNamesForState(state)

            for name in names {
                onEach(state, name)
            }
        }
    }


    // MARK:- debug
    // MARK:-


    func stringForRecordIDs(_ recordIDs: [CKRecord.ID]?) -> String {
        return recordIDs?.apply()  { object -> (String?) in
            if  let recordID = object as? CKRecord.ID,
                let    name  = stringForRecordID(recordID) {
                return name
            }

            return nil
        } ?? ""
    }

    
    func stringForRecordID(_ iID: CKRecord.ID) -> String? {
        if  let  zRecord = maybeZRecordForRecordID(iID) {
            let    name  = zRecord.record.decoratedName
            if     name != "" {
                return name
            }
        }
        
        return nil
        
    }


    // MARK:- lookups
    // MARK:-


    func  maybeZRecordForRecordName (_ iRecordName:    String?) ->  ZRecord? { return iRecordName == nil ? nil : recordRegistry[iRecordName!] }
    func maybeCKRecordForRecordName (_ iRecordName:    String?) -> CKRecord? { return maybeZRecordForRecordName (iRecordName)?.record }
    func     maybeZoneForRecordName (_ iRecordName:    String?) ->     Zone? { return maybeZRecordForRecordName (iRecordName) as? Zone }
    func       maybeZoneForRecordID (_ iRecordID:  CKRecord.ID?) ->     Zone? { return maybeZRecordForRecordID   (iRecordID)   as? Zone }
    func      maybeZoneForReference (_ iReference: CKRecord.Reference) ->     Zone? { return maybeZoneForRecordID      (iReference.recordID) }
    func       maybeZoneForCKRecord (_ iRecord:      CKRecord?) ->     Zone? { return maybeZoneForRecordID      (iRecord?.recordID) }
    func    maybeZRecordForCKRecord (_ iRecord:      CKRecord?) ->  ZRecord? { return maybeZRecordForRecordName (iRecord?.recordID.recordName) }
    func    maybeZRecordForRecordID (_ iRecordID:  CKRecord.ID?) ->  ZRecord? { return maybeZRecordForRecordName (iRecordID?.recordName) }


    func zoneForReference(_ reference: CKRecord.Reference) -> Zone {
        var zone  = maybeZoneForReference(reference)

        if  zone == nil {
            zone  = Zone(record: CKRecord(recordType: kZoneType, recordID: reference.recordID), databaseID: databaseID)

            zone?.fetchBeforeSave() // POTENTIALLY BAD DUMMY
            zone?.needFetch()
        }

        return zone!
    }


    func zoneForCKRecord(_ ckRecord: CKRecord) -> Zone {
        var     zone = maybeZoneForCKRecord(ckRecord)

        if let z = zone {
            z.useBest(record: ckRecord)
        } else {
            zone = Zone(record: ckRecord, databaseID: databaseID)

            zone?.fetchBeforeSave() // POTENTIALLY BAD DUMMY
            zone?.needFetch()
        }

        return zone!
    }

}
