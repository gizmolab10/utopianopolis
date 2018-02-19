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
    case needsBookmarks = "bookmarks"
    case needsCount     = "count"
    case needsChildren  = "children"
    case needsColor     = "color"
    case needsDestroy   = "destroy"
    case needsFetch     = "fetch"           //
    case needsMerge     = "merge"
    case notFetched     = "not fetched"     //
    case needsParent    = "parent"
    case needsProgeny   = "progeny"
    case requiresFetch  = "requires fetch"  //
    case needsRoot      = "root"
    case needsSave      = "save"
    case needsTraits    = "traits"
    case needsWritable  = "writable"
}


class ZRecordsManager: NSObject {


    var               databaseID : ZDatabaseID
    var                 registry = [String       :  ZRecord] ()
    var       recordNamesByState = [ZRecordState : [String]] ()
    var _lostAndFoundZone: Zone? = nil
    var        _trashZone: Zone? = nil
    var          rootZone: Zone? = nil


    var lostAndFoundZone: Zone {
        if  _lostAndFoundZone == nil {
            _lostAndFoundZone = prefixedZone(for: kLostAndFoundName)
        }

        return _lostAndFoundZone!
    }


    var trashZone: Zone {
        if  _trashZone == nil {
            _trashZone  = prefixedZone(for: kTrashName)
        }

        return _trashZone!
    }


    var hereRecordName: String? {
        get { return gSelectionManager.hereRecordName(for: databaseID) }
        set { gSelectionManager.setHereRecordName(newValue ?? kRootName, for: databaseID) }
    }


    var hereZone: Zone {
        get { return maybeZRecordForRecordName(hereRecordName) as? Zone ?? rootZone! }
        set { hereRecordName = newValue.recordName ?? kRootName }
    }


    init(_ idatabaseID: ZDatabaseID) {
        databaseID = idatabaseID
    }


    func clear() {
        rootZone           = nil
        _trashZone         = nil
        recordNamesByState = [ZRecordState : [String]] ()
        registry           = [String       :  ZRecord] ()
    }


    func prefixedZone(for iName: String) -> Zone {
        let      recordID = CKRecordID(recordName: iName)
        let        record = CKRecord(recordType: kZoneType, recordID: recordID)
        let          zone = zoneForCKRecord(record)    // get / create trash
        let        prefix = (databaseID == .mineID) ? "my " : "public "
        zone.directAccess = .eDefaultName
        zone    .zoneName = prefix + iName

        return zone
    }


    func createRandomLost() -> Zone {
        let lost = Zone.randomZone(in: databaseID)

        lostAndFoundZone.addChild(lost, at: nil)

        return lost
    }


    // MARK:- record state
    // MARK:-


    var undeletedCounts: (Int, Int) {
        let zRecords = registry.values
        var   uCount = zRecords.count
        var   nCount = 0

        for zRecord in zRecords {
            if  let zone = zRecord as? Zone {
                if !zone.canSave {
                    nCount += 1
                } else if let root = zone.root, !root.isTrash, !root.isLostAndFound, !root.isRootOfFavorites {
                    continue
                }

                uCount -= 1
            }
        }

        return (uCount - 2, nCount)
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


    func hasCKRecordName(_ iName: String, forAnyOf iStates: [ZRecordState]) -> Bool {
        return registeredCKRecordForName(iName, forAnyOf: iStates) != nil
    }


    func hasCKRecordID(_ iRecordID: CKRecordID, forAnyOf iStates: [ZRecordState]) -> Bool {
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


    func registeredCKRecordForID(_ iRecordID: CKRecordID, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        return registeredCKRecordForName(iRecordID.recordName, forAnyOf: iStates)
    }


    func registeredCKRecord(_ iRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        return registeredCKRecordForID(iRecord.recordID, forAnyOf: iStates)
    }


    // MARK:- set state
    // MARK:-


    func addZRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if  let ckrecord = iRecord.record {
            addCKRecord(ckrecord, for: states)
        }
    }


    @discardableResult func addCKRecord(_ iRecord: CKRecord, for states: [ZRecordState]) -> Bool {
        for state in states {
            if  let  record  = registeredCKRecord(iRecord, forAnyOf: [state]) {
                if   record != iRecord {
                    var name =  record.decoratedName
                    if  name == "" {
                        name = iRecord.decoratedName
                    }

                    columnarReport("PREVENTING ADDING TWICE!", name + " (for: \(state))")

                    return false
                }
            } else {
                var names = recordNamesForState(state)
                let  name = iRecord.recordID.recordName

                if !names.contains(name) {
                    names.append(name)

                    recordNamesByState[state] = names

                    return true
                }
            }
        }

        return false
    }


    func add(states: [ZRecordState], to iReferences: [CKReference]) {
        for reference in iReferences {
            if let zRecord = maybeZRecordForRecordID(reference.recordID) {
                addZRecord(zRecord, for: states)
            }
        }
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


    func clearReferences(_ references: [CKReference], for states: [ZRecordState]) {
        for reference in references {
            clearRecordName(reference.recordID.recordName, for:states)
        }
    }


    func clearRecordIDs(_ recordIDs: [CKRecordID], for states: [ZRecordState]) {
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


    func pullRecordIDsWithHighestLevel(for states: [ZRecordState], batchSize: Int = kBatchSize) -> [CKRecordID] {
        var found = [Int : [CKRecordID]] ()
        var results = [CKRecordID] ()

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


    func recordIDsWithMatchingStates( _ states: [ZRecordState], pull: Bool = false, batchSize: Int = kBatchSize) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            let identifier = CKRecordID(recordName: iName)
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


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var parents = [CKRecordID] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  parents.count < kBatchSize,
                let      zone = maybeZRecordForRecordName(iName) as? Zone,
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


    func pullReferencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        let references = referencesWithMatchingStates(states)

        clearReferences(references, for: states)

        return references
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        var references = [CKReference] ()

        applyToAllRecordNamesWithAnyMatchingStates(states) { iState, iName in
            if  references.count < kBatchSize {
                let reference = CKReference(recordID: CKRecordID(recordName: iName), action: .none)

                references.append(reference)
            }
        }

        return references
    }


    func pullChildrenRefsWithMatchingStates(_ states: [ZRecordState], batchSize: Int) -> [CKReference] {
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


    func childrenRefsWithMatchingStates(_ states: [ZRecordState], batchSize: Int) -> [CKReference] {
        var references = [CKReference] ()
        var  expecting = 0

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            if  let fetchable = (iCKRecord[kpZoneCount] as? NSNumber)?.intValue,
                !iCKRecord.isBookmark, (fetchable + expecting) < batchSize {
                expecting    += fetchable

                references.append(CKReference(recordID: iCKRecord.recordID, action: .none))
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
        for state in iStates {
            let names = recordNamesForState(state)

            for name in names {
                if name == iName, let ckRecord = maybeCKRecordForRecordName(name) {
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


    func stringForZones(_ zones: [Zone]?) -> String {
        return zones?.apply()  { object -> (String?) in
            if  let zone  = object as? Zone {
                let name  = zone.decoratedName
                if  name != "" {
                    return name
                }
            }

            return nil
        } ?? ""
    }


    func stringForCKRecords(_ records: [CKRecord]?) -> String {
        return records?.apply() { object -> (String?) in
            if  let  record  = object as? CKRecord {
                let    name  = record.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
        } ?? ""
    }


    func stringForReferences(_ references: [CKReference]?, in databaseID: ZDatabaseID) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(databaseID)?.maybeZoneForReference(reference) {
                let    name  = zone.decoratedName
                if     name != "" {
                    return name
                }
            }

            return nil
        } ?? ""
    }


    func stringForRecordIDs(_ recordIDs: [CKRecordID]?) -> String {
        return recordIDs?.apply()  { object -> (String?) in
            if  let recordID = object as? CKRecordID,
                let    name  = stringForRecordID(recordID) {
                return name
            }

            return nil
        } ?? ""
    }

    
    func stringForRecordID(_ iID: CKRecordID) -> String? {
        if  let  zRecord = maybeZRecordForRecordID(iID) {
            let    name  = zRecord.record.decoratedName
            if     name != "" {
                return name
            }
        }
        
        return nil
        
    }


    // MARK:- registry
    // MARK:-


    func isRegistered(_ zRecord: ZRecord) -> String? {
        if  registry.values.contains(zRecord) {
            let hash = zRecord.hash

            for key in registry.keys {
                let examined = registry[key]

                if  examined?.hash == hash {
                    return key
                }
            }
        }

        return nil
    }


    func registerZRecord(_  iRecord : ZRecord?) {
        if  let       zRecord = iRecord,
            let            id = zRecord.recordName {
            if  let       rid = isRegistered(zRecord), rid != id {
                registry[rid] = nil
            }

            if  let  bookmark = zRecord as? Zone, bookmark.isBookmark {
                gBookmarksManager.registerBookmark(bookmark)
            }

            registry[id]      = zRecord
        }
    }


    func unregisterCKRecord(_ ckRecord: CKRecord?) {
        if  let      name  = ckRecord?.recordID.recordName {
            clearRecordName(name, for: allStates)
            registry[name] = nil
        }
    }


    func unregisterZRecord(_ zRecord: ZRecord?) {
        unregisterCKRecord(zRecord?.record)
        gBookmarksManager.unregisterBookmark(zRecord as? Zone)
    }


    func notRegistered(_ recordID: CKRecordID?) -> Bool {
        return maybeZoneForRecordID(recordID) == nil
    }


    func maybeZRecordForCKRecord(_ record: CKRecord?) -> ZRecord? {
        var zRecord: ZRecord? = nil

        if  let recordID = record?.recordID {
            zRecord      = maybeZRecordForRecordID(recordID)
        }

        return zRecord
    }


    func maybeZRecordForRecordID(_ recordID: CKRecordID?) -> ZRecord? {
        return maybeZoneForRecordID(recordID) as ZRecord?
    }


    func maybeCKRecordForRecordName(_ recordName: String?) -> CKRecord? {
        return maybeZRecordForRecordName(recordName)?.record
    }


    func maybeZRecordForRecordName(_ iRecordName: String?) -> ZRecord? {
        return iRecordName == nil ? nil : registry[iRecordName!]
    }


    func maybeZoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        return maybeZRecordForRecordName(recordID?.recordName) as? Zone
    }


    func maybeZoneForReference(_ reference: CKReference) -> Zone? {
        return maybeZoneForRecordID(reference.recordID)
    }


    func maybeZoneForCKRecord(_ record: CKRecord?) -> Zone? {
        return maybeZoneForRecordID(record?.recordID)
    }


    func zoneForReference(_ reference: CKReference) -> Zone {
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
