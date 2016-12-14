//
//  ZRecordsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 12/4/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZRecordState: Int {
    case needsSave
    case needsFetch
    case needsMerge
    case needsCreate
    case needsDelete
    case needsParent
    case needsChildren
}


class ZRecordsManager: NSObject {


    var recordsByState: [ZRecordState :       [ZRecord]] = [:]
    var zoneRegistry:   [ZStorageMode : [String : Zone]] = [:]


    var zones: [String : Zone] {
        get {
            var registry: [String : Zone]? = zoneRegistry[travelManager.storageMode]

            if registry == nil {
                registry   = [:]
                self.zones = registry!
            }

            return registry!
        }

        set {
            zoneRegistry[travelManager.storageMode] = newValue
        }
    }


    var allStates: [ZRecordState] {
        get {
            var states: [ZRecordState] = []

            for state in recordsByState.keys {
                states.append(state)
            }

            return states
        }
    }


    // MARK:- record state
    // MARK:-


    func recordsForState(_ state: ZRecordState) -> [ZRecord] {
        var records = recordsByState[state]

        if records == nil {
            records = []

            recordsByState[state] = records
        }

        return records!
    }


    func clear() {
        recordsByState = [:]
    }


    func findRecordByRecordIDFrom(_ iRecord: ZRecord, forStates: [ZRecordState], onEach: StateRecordClosure?) {
        for state in forStates {
            for record in recordsForState(state) {
                if record == iRecord || (record.record != nil && iRecord.record != nil && record.record.recordID.recordName == iRecord.record.recordID.recordName) {
                    onEach?(state, record)
                }
            }
        }
    }


    func hasRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) -> Bool {
        var found = false

        findRecordByRecordIDFrom(iRecord, forStates: forStates, onEach: { (state, record) in
            found = true
        })

        return found
    }


    func addRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) {
        for state in forStates {
            if !hasRecord(iRecord, forStates: [state]) {
                var records = recordsForState(state)

                records.append(iRecord)

                recordsByState[state] = records
            }
        }

    }

    func removeRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) {
        findRecordByRecordIDFrom(iRecord, forStates: forStates, onEach: { (state, record) in
            var records = self.recordsForState(state)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.recordsByState[state] = records
            }
        })
    }


    func clearRecord(_ record: ZRecord) {
        removeRecord(record, forStates: allStates)
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        recordsByState[state] = nil
    }


    func recordIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var identifiers: [CKRecordID] = []

        findRecordsWithMatchingStates(states) { (object) -> (Void) in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !identifiers.contains(record.recordID) {
                identifiers.append(record.recordID)
            }
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var parents: [CKRecordID] = []

        findRecordsWithMatchingStates(states) { (object) -> (Void) in
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
        var objects: [CKRecord] = []

        findRecordsWithMatchingStates(states) { (object) -> (Void) in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !objects.contains(record) {
                objects.append(record)
            }
        }

        return objects
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        var references:  [CKReference] = []

        findRecordsWithMatchingStates(states) { (object) -> (Void) in
            if let record: ZRecord = object as? ZRecord, record.record != nil {
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


    // MARK:- zones
    // MARK:-


    func registerZone(_ zone: Zone?) {
        if let record = zone?.record {
            zones[record.recordID.recordName] = zone
        }
    }


    func unregisterZone(_ zone: Zone?) {
        if let record = zone?.record {
            zones[record.recordID.recordName] = nil
        }
    }


    func recordForRecordID(_ recordID: CKRecordID?) -> ZRecord? {
        var record = zoneForRecordID(recordID) as ZRecord?

        if record == nil {
            if travelManager.manifest.record.recordID.recordName == recordID?.recordName {
                record = travelManager.manifest
            }
        }

        return record
    }


    func zoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        if recordID == nil {
            return nil
        }
        
        return zones[recordID!.recordName]
    }
}
