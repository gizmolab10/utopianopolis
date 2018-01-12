//
//  ZRecordsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 12/4/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum ZRecordState: Int {
    case doNotSave
    case needsSave
    case needsRoot
    case needsMerge
    case needsFetch
    case needsColor
    case needsCount
    case needsTraits
    case needsParent
    case needsDestroy
    case needsProgeny
    case needsWritable
    case needsChildren
    case needsBookmarks
}


class ZRecordsManager: NSObject {


    var              storageMode : ZStorageMode
    var             zRecordsByID = [String       :    ZRecord] ()
    var         ckRecordsByState = [ZRecordState : [CKRecord]] ()
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


    init(_ storageMode: ZStorageMode) {
        self.storageMode = storageMode
    }


    func clear() {
        rootZone         = nil
        _trashZone       = nil
        ckRecordsByState = [ZRecordState : [CKRecord]] ()
        zRecordsByID     = [String       :    ZRecord] ()
    }


    func prefixedZone(for iName: String) -> Zone {
        let      recordID = CKRecordID(recordName: iName)
        let        record = CKRecord(recordType: kZoneType, recordID: recordID)
        let          zone = zoneForCKRecord(record)    // get / create trash
        let        prefix = (storageMode == .mineMode) ? "my " : "public "
        zone.directAccess = .eDefaultName
        zone    .zoneName = prefix + iName

        return zone
    }


    func createRandomLost() -> Zone {
        let lost = Zone.randomZone(in: storageMode)

        lostAndFoundZone.add(lost, at: nil)

        return lost
    }


    // MARK:- record state
    // MARK:-


    var undeletedCount: Int {
        let values = zRecordsByID.values
        var  count = values.count

        for zRecord in values {
            if  let zone = zRecord as? Zone, !zone.isRoot, (zone.isInTrash || zone.parentZone?.storageMode != zone.storageMode) {
                count -= 1
            }
        }

        return count
    }


    var allStates: [ZRecordState] {
        var states = [ZRecordState] ()
        let   keys = ckRecordsByState.keys

        for state in keys {
            states.append(state)
        }

        return states
    }


    func ckRecordsForState(_ state: ZRecordState) -> [CKRecord] {
        var records                 = ckRecordsByState[state]

        if  records                == nil {
            records                 = []
            ckRecordsByState[state] = records
        }

        return records!
    }


    func hasZRecord(_ iRecord: ZRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        if let ckRecord = iRecord.record {
            return hasCKRecord(ckRecord, forAnyOf: iStates)
        }

        return false
    }


    func states(for iRecord: CKRecord) -> [ZRecordState] {
        let   name = iRecord.recordID.recordName
        var states = [ZRecordState] ()

        applyToAllCKRecordsWithAnyMatchingStates(allStates) { (iState, iCKRecord) in
            if !states.contains(iState) && iCKRecord.recordID.recordName == name {
                states.append(iState)
            }
        }

        return states
    }


    func hasCKRecord(_ iRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        var found = false

        applyToCKRecordByRecordID(iRecord.recordID, forAnyOf: iStates, onEach: { (state: ZRecordState, record: CKRecord) in
            found = true
        })

        return found
    }


    // MARK:- set state
    // MARK:-


    func addZRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if  let ckrecord = iRecord.record {
            if addCKRecord(ckrecord, for: states) {
//                if ckrecord[kZoneName] == nil {
//                    columnarReport("  REGISTER", "no name")
//                }
            }
        }
    }


    @discardableResult func addCKRecord(_ iRecord: CKRecord, for states: [ZRecordState]) -> Bool {
        var wasAdded = false

        for state in states {
            if !hasCKRecord(iRecord, forAnyOf: [state]) {
                var records = ckRecordsForState(state)

                if !records.contains(iRecord) {
                    records.append(iRecord)

                    wasAdded = true
                }

                ckRecordsByState[state] = records
            }
        }

        return wasAdded
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
        ckRecordsByState.removeAll()
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        ckRecordsByState[state] = []
    }


    func clearReferences(_ references: [CKReference], for states: [ZRecordState]) {
        for reference in references {
            clearRecordID(reference.recordID, for:states)
        }
    }


    func clearRecordIDs(_ recordIDs: [CKRecordID], for states: [ZRecordState]) {
        for recordID in recordIDs {
            clearRecordID(recordID, for:states)
        }
    }


    func clearCKRecords(_ records: [CKRecord], for states: [ZRecordState]) {
        for record in records {
            clearRecordID(record.recordID, for: states)
        }
    }


    func clearZRecords(_ records: [ZRecord], for states: [ZRecordState]) {
        for record in records {
            if let identifier = record.record?.recordID {
                clearRecordID(identifier, for: states)
            }
        }
    }


    func clearAllStatesForCKRecord(_ iRecord: CKRecord?) {
        clearRecordID(iRecord?.recordID, for: allStates)
    }


    func clearRecordID(_ iRecordID: CKRecordID?, for states: [ZRecordState]) {
        applyToCKRecordByRecordID(iRecordID, forAnyOf: states, onEach: { (iState: ZRecordState, iCKRecord: CKRecord) in
            var records = self.ckRecordsForState(iState)

            if let index = records.index(of: iCKRecord) {
                records.remove(at: index)

                self.ckRecordsByState[iState] = records
            }
        })
    }


    func pullRecordIDsWithHighestLevel(for states: [ZRecordState], batchSize: Int = kBatchSize) -> [CKRecordID] {
        var found = [Int : [CKRecordID]] ()
        var results = [CKRecordID] ()

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            var       zoneLevel = 0

            if  let levelString = iCKRecord["zoneLevel"] as? String,
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
                    clearRecordID(identifier, for: states)
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

        applyToAllCKRecordsWithAnyMatchingStates(states) { state, ckrecord in
            let identifier = ckrecord.recordID
            let       name = identifier.recordName

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

        applyToAllCKRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if  parents.count < kBatchSize, let zone = maybeZRecordForCKRecord(ckrecord) as? Zone, let reference = zone.parent {
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

        applyToAllCKRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if  results.count < kBatchSize && !results.contains(ckrecord) {
                results.append(ckrecord)
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

        applyToAllCKRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if  references.count < kBatchSize {
                let reference = CKReference(recordID: ckrecord.recordID, action: .none)

                references.append(reference)
            }
        }

        return references
    }


    // MARK:- batch lookup
    // MARK:-


    func fullUpdate(_ onEach: StateRecordClosure) {
        let  states = [ZRecordState.needsCount]
        var records = [CKRecord] ()

        applyToAllCKRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if let record = maybeZRecordForCKRecord(ckrecord) {
                onEach(state, record)
            }

            records.append(ckrecord)
        }

        clearCKRecords(records, for: states)
    }


    func applyToCKRecordByRecordID(_ iRecordID: CKRecordID?, forAnyOf iStates: [ZRecordState], onEach: StateCKRecordClosure?) {
        if let soughtName = iRecordID?.recordName {
            applyToAllCKRecordsWithAnyMatchingStates(iStates) { state, ckrecord in
                let name = ckrecord.recordID.recordName

                if  name == soughtName {
                    onEach?(state, ckrecord)
                }
            }
        }
    }


    func applyToAllCKRecordsWithAnyMatchingStates(_ iStates: [ZRecordState], onEach: StateCKRecordClosure) {
        for state in iStates {
            let ckrecords = ckRecordsForState(state)

            for ckrecord in ckrecords {
                onEach(state, ckrecord)
            }
        }
    }


    // MARK:- debug
    // MARK:-


    func stringForZones(_ zones: [Zone]?) -> String {
        return zones?.apply()  { object -> (String?) in
            if  let    zone  = object as? Zone {
                let    name  = zone.decoratedName
                if     name != "" {
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


    func stringForReferences(_ references: [CKReference]?, in storageMode: ZStorageMode) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(storageMode)?.maybeZoneForReference(reference) {
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
        if  zRecordsByID.values.contains(zRecord) {
            let hash = zRecord.hash

            for key in zRecordsByID.keys {
                let examined = zRecordsByID[key]

                if  examined?.hash == hash {
                    return key
                }
            }
        }

        return nil
    }


    func registerZRecord(_  iRecord : ZRecord?) {
        if  let           zRecord = iRecord,
            let                id = zRecord.recordName {
            if  let           rid = isRegistered(zRecord), rid != id {
                zRecordsByID[rid] = nil
            }

            if  let      bookmark = zRecord as? Zone, bookmark.isBookmark {
                gBookmarksManager.registerBookmark(bookmark)
            }

            zRecordsByID[id]      = zRecord
        }
    }


    func unregisterZRecord(_ zRecord: ZRecord?) {
        clearAllStatesForCKRecord(zRecord?.record)

        if  let name = zRecord?.recordName {
            zRecordsByID[name] = nil
        }

        if  let       bookmark = zRecord as? Zone, bookmark.isBookmark {
            gBookmarksManager.unregisterBookmark(bookmark)
        }
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
        var   record = maybeZoneForRecordID(recordID) as ZRecord?
        let manifest = gRemoteStoresManager.manifest(for: storageMode)

        if  record  == nil && manifest.recordName == recordID?.recordName {
            record   = manifest
        }

        return record
    }


    func maybeZoneForRecordName(_ recordName: String?) -> Zone? {
        if  let id = recordName {
            return zRecordsByID[id] as? Zone
        }

        return nil
    }


    func maybeZoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        return maybeZoneForRecordName(recordID?.recordName)
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
            zone  = Zone(record: CKRecord(recordType: kZoneType, recordID: reference.recordID), storageMode: storageMode)

            // columnarReport("REFERENCE FETCH", "\(reference.recordID.recordName)")
            zone?.maybeNeedFetch()
        }

        return zone!
    }


    func zoneForCKRecord(_ ckRecord: CKRecord) -> Zone {
        var     zone = maybeZoneForCKRecord(ckRecord)

        if  let    z = zone {
            z.record = ckRecord
        } else {
            zone     = Zone(record: ckRecord, storageMode: storageMode)

            zone?.maybeNeedFetch()
        }

        return zone!
    }

}
