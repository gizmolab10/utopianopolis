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
    case needsParent
    case needsChildren
}


class ZRecordsManager: NSObject {


    var statesByMode = [ZStorageMode : [ZRecordState : [ZRecord]]] ()
    var zoneRegistry = [ZStorageMode : [String       :      Zone]] ()


    var recordsByState: [ZRecordState : [ZRecord]] {
        set {
            statesByMode[travelManager.storageMode] = newValue
        }

        get {
            var registry = statesByMode[travelManager.storageMode]

            if registry == nil {
                registry            = [:]
                self.recordsByState = registry!
            }

            return registry!
        }
    }


    var zones: [String : Zone] {
        set {
            zoneRegistry[travelManager.storageMode] = newValue
        }

        get {
            var registry: [String : Zone]? = zoneRegistry[travelManager.storageMode]

            if registry == nil {
                registry   = [:]
                self.zones = registry!
            }

            return registry!
        }
    }


    var allStates: [ZRecordState] {
        get {
            var states = [ZRecordState] ()

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


    func addRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) {
        for state in forStates {
            if !hasRecord(iRecord, forStates: [state]) {
                var records = recordsForState(state)

                records.append(iRecord)

                recordsByState[state] = records
            }
        }

    }

    func removeRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState]) {
        findRecordByRecordID(iRecordID, forStates: forStates, onEach: { (state: ZRecordState, record: ZRecord) in
            var records = self.recordsForState(state)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.recordsByState[state] = records
            }
        })
    }


    func clearRecord(_ iRecord: ZRecord) {
        removeRecordByRecordID(iRecord.record?.recordID, forStates: allStates)
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        recordsByState[state] = nil
    }


    func zoneNamesWithMatchingStates(_ states: [ZRecordState]) -> String {
        var names = [String] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: Zone = object as! Zone

            if let name = zone.zoneName, !names.contains(name) {
                names.append(name)
            }
        }

        return names.joined(separator: ", ")
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
        var objects = [CKRecord] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !objects.contains(record) {
                objects.append(record)
            }
        }

        return objects
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        var references = [CKReference] ()

        findRecordsWithMatchingStates(states) { object in
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


    // MARK:- zones registry
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
            if travelManager.manifest.record?.recordID.recordName == recordID?.recordName {
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
