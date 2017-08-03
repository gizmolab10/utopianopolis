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
    case needsCount
    case needsParent
    case needsCreate
    case needsDestroy
    case needsProgeny
    case needsChildren
    case needsBookmarks
}


let batchSize = 250


class ZRecordsManager: NSObject {


    var recordsByState = [ZRecordState : [CKRecord]] ()
    var      zonesByID = [String       :       Zone] ()
    var storageMode: ZStorageMode
    var    rootZone: Zone? = nil


    init(_ storageMode: ZStorageMode) {
        self.storageMode = storageMode
    }


    // MARK:- record state
    // MARK:-


    var undeletedCount: Int {
        var count = zonesByID.count

        for zone in zonesByID.values {
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

        for state in recordsByState.keys {
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


    func clearAllStatesForRecords() {
        recordsByState.removeAll()
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


    func hasRecords(for states: [ZRecordState]) -> Bool {
        for state in states {
            let records = recordsForState(state)

            if records.count > 0 {
                return true
            }
        }

        return false
    }


    func hasRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) -> Bool {
        if let ckRecord = iRecord.record {
            return hasCKRecord(ckRecord, forStates: forStates)
        }

        return false
    }


    func hasCKRecord(_ iRecord: CKRecord, forStates: [ZRecordState]) -> Bool {
        var found = false

        findRecordByRecordID(iRecord.recordID, forStates: forStates, onEach: { (state: ZRecordState, record: CKRecord) in
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
            if !hasCKRecord(iRecord, forStates: [state]) {
                var records = recordsForState(state)

                records.append(iRecord)

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


    func clearStatesForRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState]) {
        findRecordByRecordID(iRecordID, forStates: forStates, onEach: { (state: ZRecordState, record: CKRecord) in
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


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        recordsByState[state] = []
    }


    // MARK:- lookup by state
    // MARK:-


    func recordIDsWithMatchingStates( _ states: [ZRecordState], pull: Bool = false) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { state, ckrecord in
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

        findRecordsWithMatchingStates(states) { state, ckrecord in
            if  parents.count < batchSize, let zone = recordForCKRecord(ckrecord) as? Zone, let reference = zone.parent {
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

        findRecordsWithMatchingStates(states) { state, ckrecord in
            if  results.count < batchSize && !results.contains(ckrecord) {
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

        findRecordsWithMatchingStates(states) { state, ckrecord in
            if  references.count < batchSize {
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

        findRecordsWithMatchingStates(states) { state, ckrecord in
            if let record = recordForCKRecord(ckrecord) {
                onEach(state, record)
            }

            records.append(ckrecord)
        }

        clearCKRecords(records, for: states)
    }


    func findRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState], onEach: StateCKRecordClosure?) {
        if let soughtName = iRecordID?.recordName {
            findRecordsWithMatchingStates(forStates) { state, ckrecord in
                let name = ckrecord.recordID.recordName

                if  name == soughtName {
                    onEach?(state, ckrecord)
                }
            }
        }
    }


    func findRecordsWithMatchingStates(_ states: [ZRecordState], onEach: StateCKRecordClosure) {
        for state in states {
            for ckrecord in recordsForState(state) {
                onEach(state, ckrecord)
            }
        }
    }


    // MARK:- debug
    // MARK:-


    func applyTo(_ array: [NSObject]?, closure: ObjectToStringClosure) -> String {
        var separator = ""
        var    string = ""

        if array != nil {
            for object in array! {
                let message = closure(object)

                string.append("\(separator)\(message)")

                if  separator.length == 0 {
                    separator.appendSpacesToLength(gLogTabStop)

                    separator = "\n\(separator)"
                }
            }
        }

        return string
    }


    func stringForZones(_ zones: [Zone]?) -> String {
        return applyTo(zones)  { object -> (String) in
            if let zone = object as? Zone {
                return zone.decoratedName
            }

            return "---"
        }
    }


    func stringForRecords(_ records: [CKRecord]?) -> String {
        return applyTo(records)  { object -> (String) in
            if  let record = object as? CKRecord {
                return record.decoratedName
            }

            return "---"
        }
    }


    func stringForReferences(_ references: [CKReference]?, in storageMode: ZStorageMode) -> String {
        return applyTo(references)  { object -> (String) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(storageMode).zoneForReference(reference) {
                return zone.decoratedName
            }

            return "---"
        }
    }


    func stringForRecordIDs(_ recordIDs: [CKRecordID]?, in storageMode: ZStorageMode) -> String {
        return applyTo(recordIDs)  { object -> (String) in
            if  let recordID = object as? CKRecordID, let record = gRemoteStoresManager.recordsManagerFor(storageMode).recordForRecordID(recordID) {
                return record.record.decoratedName
            }
            
            return "---"
        }
    }


    // MARK:- zones registry
    // MARK:-


    func isRegistered(_ zone: Zone) -> String? {
        if zonesByID.values.contains(zone) {
            for name in zonesByID.keys {
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

            if registered != nil && registered! != identifier {
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
