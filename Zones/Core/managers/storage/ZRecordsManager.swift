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
    case needsMerge
    case needsFetch
    case needsCreate
    case needsParent
    case hasChildren
    case needsChildren
}


class ZRecordsManager: NSObject {


    var recordsByState = [ZRecordState : [ZRecord]] ()
    var      zonesByID = [String       :      Zone] ()
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
            if zone.isDeleted {
                count -= 1
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



    func setRecords(_ records: [ZRecord], for state: ZRecordState) {
        recordsByState[state] = records
    }


    func recordsForState(_ state: ZRecordState) -> [ZRecord] {
        var        dict = recordsByState
        var     records = dict[state]

        if records     == nil {
            records     = []
            dict[state] = records
        }

        return records!
    }


    func clearAllStatesForRecords() {
        recordsByState.removeAll()
    }


    func findRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState], onEach: StateRecordClosure?) {
        if iRecordID != nil {
            for state in forStates {
                for record in recordsForState(state) {
                    if record.record != nil && record.record.recordID.recordName == iRecordID?.recordName {
                        onEach?(state, record)
                    }
                }
            }
        }
    }


    func hasRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) -> Bool {
        var found = false

        findRecordByRecordID(iRecord.record?.recordID, forStates: forStates, onEach: { (state: ZRecordState, record: ZRecord) in
            found = true
        })

        return found
    }


    func addRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        for state in states {
            if !hasRecord(iRecord, forStates: [state]) {
                var records = recordsForState(state)

                records.append(iRecord)
                setRecords(records, for: state)
            }
        }
    }


    func clearStatesForRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState]) {
        findRecordByRecordID(iRecordID, forStates: forStates, onEach: { (state: ZRecordState, record: ZRecord) in
            var records = self.recordsForState(state)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.setRecords(records, for: state)
            }
        })
    }


    func clearAllStatesForRecord(_ iRecord: ZRecord) {
        clearStatesForRecordID(iRecord.record?.recordID, forStates: allStates)
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        setRecords([], for: state)
    }


    func recordIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !identifiers.contains(record.recordID) {
                identifiers.append(record.recordID)
            }
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var parents = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: Zone = object as! Zone

            if let reference = zone.parent {
                let parentID = reference.recordID

                if !parents.contains(parentID) {
                    parents.append(parentID)
                }
            }
        }

        return parents
    }


    func recordsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord] {
        var results = [CKRecord] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: ZRecord = object as! ZRecord

            if let     record = zone.record, !results.contains(record) {
                zone.debug("saving")

                results.append(record)
            }
        }

        return results
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        var references = [CKReference] ()

        findRecordsWithMatchingStates(states) { object in
            if  let    record:     ZRecord = object as? ZRecord, record.record != nil {
                let reference: CKReference = CKReference(recordID: record.record.recordID, action: .none)

                references.append(reference)
            }
        }

        return references
    }


    func findRecordsWithMatchingStates(_ states: [ZRecordState], onEach: ObjectClosure) {
        for state in states {
            let records = recordsForState(state)

            for record in records {
                onEach(record)
            }
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
        var zone = zonesByID[reference.recordID.recordName]

        if  zone == nil, let record = recordForRecordID(reference.recordID)?.record {
            zone  = Zone(record: record, storageMode: storageMode)
        }

        return zone
    }


    func zoneForRecord(_ record: CKRecord) -> Zone {
        var zone = zonesByID[record.recordID.recordName]

        if  zone == nil {
            zone  = Zone(record: record, storageMode: storageMode)
        } else if !(zone?.isDeleted ?? false) {
            zone!.record = record
        }

        zone!.maybeNeedChildren()

        return zone!
    }


    func zoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        if recordID == nil {
            return nil
        }

        return zonesByID[recordID!.recordName]
    }
}
