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
    case needsSave
    case needsRoot
    case needsMerge
    case needsFetch
    case needsColor
    case needsCount
    case needsParent
    case needsCreate
    case needsDestroy
    case needsProgeny
    case needsWritable
    case needsChildren
    case needsBookmarks
}


class ZRecordsManager: NSObject {


    var recordsByState = [ZRecordState : [CKRecord]] ()
    var      zonesByID = [String       :       Zone] ()
    var storageMode: ZStorageMode
    var   trashZone: Zone? = nil
    var    rootZone: Zone? = nil


    init(_ storageMode: ZStorageMode) {
        self.storageMode = storageMode
    }


    // MARK:- record state
    // MARK:-


    var undeletedCount: Int {
        let values = zonesByID.values
        var  count = values.count

        for zone in values {
            if !zone.isRoot {
                if  zone.isDeleted || zone.parentZone?.storageMode != zone.storageMode {
                    count -= 1
                }
            }
        }

        return count
    }


    var allStates: [ZRecordState] {
        var states = [ZRecordState] ()
        let   keys = recordsByState.keys

        for state in keys {
            states.append(state)
        }

        return states
    }


    func recordsForState(_ state: ZRecordState) -> [CKRecord] {
        var records               = recordsByState[state]

        if  records              == nil {
            records               = []
            recordsByState[state] = records
        }

        return records!
    }


    func hasRecords(for states: [ZRecordState]) -> Bool {
        for state in states {
            let records = recordsForState(state)

            if records.count > 0 {
                return true
            }
        }

        return false
    }


    func hasRecord(_ iRecord: ZRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        if let ckRecord = iRecord.record {
            return hasCKRecord(ckRecord, forAnyOf: iStates)
        }

        return false
    }


    func states(for iRecord: CKRecord) -> [ZRecordState] {
        let   name = iRecord.recordID.recordName
        var states = [ZRecordState] ()

        findAllRecordsWithAnyMatchingStates(allStates) { (iState, iCKRecord) in
            if !states.contains(iState) && iCKRecord.recordID.recordName == name {
                states.append(iState)
            }
        }

        return states
    }


    func hasCKRecord(_ iRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        var found = false

        findRecordByRecordID(iRecord.recordID, forAnyOf: iStates, onEach: { (state: ZRecordState, record: CKRecord) in
            found = true
        })

        return found
    }


    // MARK:- set state
    // MARK:-


    func addRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if  let ckrecord = iRecord.record {
            addCKRecord(ckrecord, for: states)
        }
    }


    func addCKRecord(_ iRecord: CKRecord, for states: [ZRecordState]) {
        for state in states {
            if !hasCKRecord(iRecord, forAnyOf: [state]) {
                var records = recordsForState(state)

                if !records.contains(iRecord) {
                    records.append(iRecord)
                }

                recordsByState[state] = records
            }
        }
    }


    func add(states: [ZRecordState], to iReferences: [CKReference]) {
        for reference in iReferences {
            if let record = recordForRecordID(reference.recordID) {
                addRecord(record, for: states)
            }
        }
    }


    // MARK:- clear state
    // MARK:-


    func clearAllStatesForAllRecords() {
        recordsByState.removeAll()
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        recordsByState[state] = []
    }


    func clearReferences(_ references: [CKReference], for states: [ZRecordState]) {
        for reference in references {
            clearStatesForRecordID(reference.recordID, forStates:states)
        }
    }


    func clearRecordIDs(_ recordIDs: [CKRecordID], for states: [ZRecordState]) {
        for recordID in recordIDs {
            clearStatesForRecordID(recordID, forStates:states)
        }
    }


    func clearCKRecords(_ records: [CKRecord], for states: [ZRecordState]) {
        for record in records {
            clearStatesForRecordID(record.recordID, forStates:states)
        }
    }


    func clearZRecords(_ records: [ZRecord], for states: [ZRecordState]) {
        for record in records {
            if let identifier = record.record?.recordID {
                clearStatesForRecordID(identifier, forStates:states)
            }
        }
    }


    func clearStatesForRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState]) {
        findRecordByRecordID(iRecordID, forAnyOf: forStates, onEach: { (state: ZRecordState, record: CKRecord) in
            var records = self.recordsForState(state)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.recordsByState[state] = records
            }
        })
    }


    func clearAllStatesForRecord(_ iRecord: CKRecord) {
        clearStatesForRecordID(iRecord.recordID, forStates: allStates)
    }


    // MARK:- lookup by state
    // MARK:-


    func recordIDsWithMatchingStates( _ states: [ZRecordState], pull: Bool = false, batchSize: Int = gBatchSize) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        findAllRecordsWithAnyMatchingStates(states) { state, ckrecord in
            let identifier = ckrecord.recordID

            if  identifiers.count < batchSize, !identifiers.contains(identifier) {
                identifiers.append(identifier)
            }
        }

        if pull {
            clearRecordIDs(identifiers, for: states)
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var parents = [CKRecordID] ()

        findAllRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if  parents.count < gBatchSize, let zone = recordForCKRecord(ckrecord) as? Zone, let reference = zone.parent {
                let  parentID = reference.recordID

                if !parents.contains(parentID) {
                    parents.append(parentID)
                }
            }
        }

        return parents
    }


    func pullRecordsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord] {
        var results = [CKRecord] ()

        findAllRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if  results.count < gBatchSize && !results.contains(ckrecord) {
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

        findAllRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if  references.count < gBatchSize {
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

        findAllRecordsWithAnyMatchingStates(states) { state, ckrecord in
            if let record = recordForCKRecord(ckrecord) {
                onEach(state, record)
            }

            records.append(ckrecord)
        }

        clearCKRecords(records, for: states)
    }


    func findRecordByRecordID(_ iRecordID: CKRecordID?, forAnyOf iStates: [ZRecordState], onEach: StateCKRecordClosure?) {
        if let soughtName = iRecordID?.recordName {
            findAllRecordsWithAnyMatchingStates(iStates) { state, ckrecord in
                let name = ckrecord.recordID.recordName

                if  name == soughtName {
                    onEach?(state, ckrecord)
                }
            }
        }
    }


    func findAllRecordsWithAnyMatchingStates(_ iStates: [ZRecordState], onEach: StateCKRecordClosure) {
        for state in iStates {
            let ckrecords = recordsForState(state)

            for ckrecord in ckrecords {
                onEach(state, ckrecord)
            }
        }
    }


    // MARK:- debug
    // MARK:-


    func stringForZones(_ zones: [Zone]?) -> String {
        return zones?.apply()  { object -> (String?) in
            if let zone = object as? Zone {
                return zone.decoratedName
            }

            return nil
        } ?? ""
    }


    func stringForCKRecords(_ records: [CKRecord]?) -> String {
        return records?.apply()  { object -> (String?) in
            if  let record = object as? CKRecord {
                return record.decoratedName
            }

            return nil
        } ?? ""
    }


    func stringForReferences(_ references: [CKReference]?, in storageMode: ZStorageMode) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(storageMode).zoneForReference(reference) {
                return zone.decoratedName
            }

            return nil
        } ?? ""
    }


    func stringForRecordIDs(_ recordIDs: [CKRecordID]?, in storageMode: ZStorageMode) -> String {
        return recordIDs?.apply()  { object -> (String?) in
            if  let recordID = object as? CKRecordID, let record = gRemoteStoresManager.recordsManagerFor(storageMode).recordForRecordID(recordID) {
                return record.record.decoratedName
            }
            
            return nil
        } ?? ""
    }


    // MARK:- zones registry
    // MARK:-


    func isRegistered(_ zone: Zone) -> String? {
        if  zonesByID.values.contains(zone) {
            let keys = zonesByID.keys

            for name in keys {
                let examined = zonesByID[name]

                if examined?.hash == zone.hash {
                    return name
                }
            }
        }

        return nil
    }


    func setZone(_ zone: Zone?, for id: String) {
        zonesByID[id] = zone
    }


    func registerZone(_ zone: Zone?) {
        if  let     record = zone?.record {
            let identifier = record.recordID.recordName
            let registered = isRegistered(zone!)

            if  let    rid = registered, rid != identifier {
                zonesByID[registered!] = nil
            }

            zonesByID[identifier] = zone
        }
    }


    func unregisterZone(_ zone: Zone?) {
        if zone != nil, let record = zone!.record {
            zonesByID[record.recordID.recordName] = nil
        }
    }


    func recordForCKRecord(_ record: CKRecord?) -> ZRecord? {
        var result: ZRecord? = nil

        if let recordID = record?.recordID {
            result      = recordForRecordID(recordID)
        }

        return result
    }


    func recordForRecordID(_ recordID: CKRecordID?) -> ZRecord? {
        var   record = zoneForRecordID(recordID) as ZRecord?
        let manifest = gRemoteStoresManager.manifest(for:  storageMode)

        if  record  == nil && manifest.record?.recordID.recordName == recordID?.recordName {
            record   = manifest
        }

        return record
    }


    func zoneForReference(_ reference: CKReference) -> Zone? {
        var zone  = zonesByID[reference.recordID.recordName]

        if  zone == nil, let record = recordForRecordID(reference.recordID)?.record {
            zone  = Zone(record: record, storageMode: storageMode)
        }

        return zone
    }


    func zoneForRecord(_ iRecord: CKRecord) -> Zone {
        var zone  = zonesByID[iRecord.recordID.recordName]

        if  zone == nil {
            zone  = Zone(record: iRecord, storageMode: storageMode)
        } else if !zone!.isDeleted {
            zone!.record = iRecord
        }

        return zone!
    }


    func zoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        if recordID == nil {
            return nil
        }

        return zonesByID[recordID!.recordName]
    }
}
