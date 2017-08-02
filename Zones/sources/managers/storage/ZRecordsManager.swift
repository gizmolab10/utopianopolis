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
    case needsParent
    case needsCreate
    case needsDestroy
    case needsProgeny
    case needsChildren
    case needsBookmarks
}


let batchSize = 250


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


    func recordsForState(_ state: ZRecordState) -> [ZRecord] {
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


    func clearRecords(_ records: [CKRecord], for states: [ZRecordState]) {
        for record in records {
            clearStatesForRecordID(record.recordID, forStates:states)
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

                recordsByState[state] = records
            }
        }
    }


    func clearStatesForRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState]) {
        findRecordByRecordID(iRecordID, forStates: forStates, onEach: { (state: ZRecordState, record: ZRecord) in
            var records = self.recordsForState(state)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.recordsByState[state] = records
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
        recordsByState[state] = []
    }


    func recordIDsWithMatchingStates( _ states: [ZRecordState], pull: Bool = false) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { state, record in
            if  let identifier = record.record?.recordID, identifiers.count <= batchSize, !identifiers.contains(identifier) {
                identifiers.append(identifier)
            }
        }

        if pull {
            clearStates(states)
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var parents = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { state, record in
            if parents.count <= batchSize {
                let zone: Zone = record as! Zone

                if  let reference = zone.parent {
                    let  parentID = reference.recordID

                    if !parents.contains(parentID) {
                        parents.append(parentID)
                    }
                }
            }
        }

        return parents
    }


    func pullRecordsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord] {
        var results = [CKRecord] ()

        findRecordsWithMatchingStates(states) { state, record in
            if  results.count <= batchSize && !results.contains(record.record) {
                results.append(record.record)

                record.debug("saving")
            }
        }

        clearRecords(results, for: states)
        
        return results
    }


    func pullReferencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        let references = referencesWithMatchingStates(states)

        clearReferences(references, for: states)

        return references
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        var references = [CKReference] ()

        findRecordsWithMatchingStates(states) { state, record in
            if references.count < batchSize, let identifier = record.record?.recordID {
                let reference: CKReference = CKReference(recordID: identifier, action: .none)

                references.append(reference)
            }
        }

        return references
    }


    // MARK:- batch lookup
    // MARK:-


    func findRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState], onEach: StateRecordClosure?) {
        if let soughtName = iRecordID?.recordName {
            findRecordsWithMatchingStates(forStates) { state, record in
                if let name = record.record?.recordID.recordName, name == soughtName {
                    onEach?(state, record)
                }
            }
        }
    }


    func findRecordsWithMatchingStates(_ states: [ZRecordState], onEach: StateRecordClosure) {
        for state in states {
            for record in recordsForState(state) {
                onEach(state, record)
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
