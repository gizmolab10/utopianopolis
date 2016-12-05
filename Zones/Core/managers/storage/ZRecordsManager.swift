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
    case needsChildren
}


class ZRecordsManager: NSObject {


    var recordsByState: [ZRecordState : [ZRecord]] = [:]
    var          zones: [CKRecordID   :      Zone] = [:]


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


    func hasRecord(_ record: ZRecord, forState: ZRecordState) -> Bool {
        return recordsForState(forState).contains(record)
    }


    func addRecord(_ record: ZRecord, forState: ZRecordState) {
        var records = recordsForState(forState)

        records.append(record)

        recordsByState[forState] = records
    }


    func removeRecord(_ record: ZRecord, forState: ZRecordState) {
        var records = recordsForState(forState)

        if let index = records.index(of: record) {
            records.remove(at: index)

            recordsByState[forState] = records
        }
    }


    func clearRecord(_ record: ZRecord) {
        for state in recordsByState.keys {
            if var records = recordsByState[state], let index = records.index(of: record) {
                records.remove(at: index)

                recordsByState[state] = records
            }
        }
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        recordsByState[state] = nil
    }


    func recordIDsMatching(_ states: [ZRecordState]) -> [CKRecordID] {
        var identifiers: [CKRecordID] = []

        findRecordsMatching(states) { (object) -> (Void) in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record {
                identifiers.append(record.recordID)
            }
        }

        return identifiers
    }


    func recordsMatching(_ states: [ZRecordState]) -> [CKRecord] {
        var objects: [CKRecord] = []

        findRecordsMatching(states) { (object) -> (Void) in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !objects.contains(record) {
                objects.append(record)
            }
        }

        return objects
    }


    func referencesMatching(_ states: [ZRecordState]) -> [CKReference] {
        var references:  [CKReference] = []

        findRecordsMatching(states) { (object) -> (Void) in
            let zone:          ZRecord = object as! ZRecord
            let reference: CKReference = CKReference(recordID: zone.record.recordID, action: .none)

            references.append(reference)
        }

        return references
    }


    func findRecordsMatching(_ states: [ZRecordState], onEach: ObjectClosure) {
        for state in states {
            for record in recordsForState(state) {
                onEach(record)
            }
        }
    }


    // MARK:- zones
    // MARK:-


    func registerZone(_ zone: Zone) {
        if let record = zone.record {
            zones[record.recordID] = zone
        }
    }
    
    
    func zoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        if recordID == nil {
            return nil
        }
        
        return zones[recordID!]
    }
}
