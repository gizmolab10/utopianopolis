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


    var statesByMode = [ZStorageMode : [ZRecordState : [ZRecord]]] ()    // dictionary of dictionaries
    var zoneRegistry = [ZStorageMode : [String       :      Zone]] ()    // dictionary of dictionaries


    // MARK:- record state
    // MARK:-


    func undeletedCount(for storageMode: ZStorageMode) -> Int {
        let       zones = zonesRegistry(for: storageMode)
        var       count = zones.count
        var identifiers = [CKRecordID] ()

        for zone in zones.values {
            let isDeleted = zone.isDeleted

            if isDeleted || identifiers.contains(zone.record.recordID) {
                count -= 1

                if isDeleted, let link = zone.crossLink?.record.recordID {
                    identifiers.append(link)
                }
            }
        }

        return count
    }


    func allStates(for storageMode: ZStorageMode) -> [ZRecordState] {
        var states = [ZRecordState] ()

        for state in recordsByState(for: storageMode).keys {
            states.append(state)
        }

        return states
    }


    func recordsByState(for storageMode: ZStorageMode) -> [ZRecordState : [ZRecord]] {
            if  statesByMode[storageMode] == nil {
                statesByMode[storageMode]  = [:]
            }

            return statesByMode[storageMode]!
        }


    func zonesRegistry(for storageMode: ZStorageMode) -> [String : Zone] {
        var registry: [String : Zone]? = zoneRegistry[storageMode]

        if  registry                 == nil {
            registry                  = [:]
            zoneRegistry[storageMode] = registry!
        }

        return registry!
    }


    func setRecords(_ records: [ZRecord], for state: ZRecordState, in storageMode: ZStorageMode) {
        var                  dict = recordsByState(for: storageMode)
        dict[state]               = records
        statesByMode[storageMode] = dict
    }


    func recordsForState(_ state: ZRecordState, in storageMode: ZStorageMode) -> [ZRecord] {
        var        dict = recordsByState(for: storageMode)
        var     records = dict[state]

        if records     == nil {
            records     = []
            dict[state] = records
        }

        return records!
    }


    func clearAllStatesForRecords(for storageMode: ZStorageMode) {
        var byMode = recordsByState(for: storageMode)

        byMode.removeAll()
    }


    func findRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState], in storageMode: ZStorageMode, onEach: StateRecordClosure?) {
        if iRecordID != nil {
            for state in forStates {
                for record in recordsForState(state, in: storageMode) {
                    if record.record != nil && record.record.recordID.recordName == iRecordID?.recordName {
                        onEach?(state, record)
                    }
                }
            }
        }
    }


    func hasRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) -> Bool {
        var found = false

        if let mode = iRecord.storageMode {
            findRecordByRecordID(iRecord.record?.recordID, forStates: forStates, in: mode, onEach: { (state: ZRecordState, record: ZRecord) in
                found = true
            })
        }

        return found
    }


    func addRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if let mode = iRecord.storageMode {
            for state in states {
                if !hasRecord(iRecord, forStates: [state]) {
                    var records = recordsForState(state, in: mode)

                    records.append(iRecord)
                    setRecords(records, for: state, in: mode)
                }
            }
        }
    }

    func clearStatesForRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState], in storageMode: ZStorageMode) {
        findRecordByRecordID(iRecordID, forStates: forStates, in: storageMode, onEach: { (state: ZRecordState, record: ZRecord) in
            var records = self.recordsForState(state, in: storageMode)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.setRecords(records, for: state, in: storageMode)
            }
        })
    }


    func clearAllStatesForRecord(_ iRecord: ZRecord) {
        if let mode = iRecord.storageMode {
            clearStatesForRecordID(iRecord.record?.recordID, forStates: allStates(for: mode), in: mode)
        }
    }


    func clearStates(_ states: [ZRecordState], in storageMode: ZStorageMode) {
        for state in states {
            clearState(state, in: storageMode)
        }
    }


    func clearState(_ state: ZRecordState, in storageMode: ZStorageMode) {
        setRecords([], for: state, in: storageMode)
    }


    func recordIDsWithMatchingStates(_ states: [ZRecordState], in storageMode: ZStorageMode) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        findRecordsWithMatchingStates(states, in: storageMode) { object in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !identifiers.contains(record.recordID) {
                identifiers.append(record.recordID)
            }
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState], in storageMode: ZStorageMode) -> [CKRecordID] {
        var parents = [CKRecordID] ()

        findRecordsWithMatchingStates(states, in: storageMode) { object in
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


    func recordsWithMatchingStates(_ states: [ZRecordState], in storageMode: ZStorageMode) -> [CKRecord] {
        var results = [CKRecord] ()

        findRecordsWithMatchingStates(states, in: storageMode) { object in
            let zone: ZRecord = object as! ZRecord

            if let     record = zone.record, !results.contains(record) {
                zone.debug("saving")

                results.append(record)
            }
        }

        return results
    }


    func referencesWithMatchingStates(_ states: [ZRecordState], in storageMode: ZStorageMode) -> [CKReference] {
        var references = [CKReference] ()

        findRecordsWithMatchingStates(states, in: storageMode) { object in
            if  let    record:     ZRecord = object as? ZRecord, record.record != nil {
                let reference: CKReference = CKReference(recordID: record.record.recordID, action: .none)

                references.append(reference)
            }
        }

        return references
    }


    func findRecordsWithMatchingStates(_ states: [ZRecordState], in storageMode: ZStorageMode, onEach: ObjectClosure) {
        for state in states {
            let records = recordsForState(state, in: storageMode)

            for record in records {
                onEach(record)
            }
        }
    }


    // MARK:- zones registry
    // MARK:-


    func isRegistered(_ zone: Zone) -> String? {
        var zones = zonesRegistry(for: zone.storageMode!)

        if zones.values.contains(zone) {
            for name in zones.keys {
                let examined = zones[name]

                if examined?.hash == zone.hash {
                    return name
                }
            }
        }

        return nil
    }


    func setZone(_ zone: Zone?, for id: String, in storageMode: ZStorageMode) {
        zoneRegistry[storageMode]?[id] = zone
    }


    func registerZone(_ zone: Zone?) {
        if zone != nil, let record = zone!.record, let mode = zone!.storageMode {
            let identifier = record.recordID.recordName
            let registered = isRegistered(zone!)

            if registered == nil {
                setZone(zone, for: identifier,  in: mode)
            } else if registered!  != identifier {
                setZone(nil,  for: registered!, in: mode)
                setZone(zone, for: identifier,  in: mode)
            }
        }
    }


    func unregisterZone(_ zone: Zone?) {
        if zone != nil, let record = zone!.record {
            var zones = zonesRegistry(for: zone!.storageMode!)

            zones[record.recordID.recordName] = nil
        }
    }


    func applyToAllZones(_ closure: ZoneClosure) {
        for mode: ZStorageMode in [.mine, .everyone, .favorites] {
            let zones = zonesRegistry(for: mode)

            for zone in zones.values {
                closure(zone)
            }
        }
    }


    func bookmarksFor(_ zone: Zone?) -> [Zone] {
        var zoneBookmarks = [Zone] ()

        if zone != nil, let recordID = zone?.record?.recordID {
            applyToAllZones { iZone in
                if let link = iZone.crossLink, recordID == link.record?.recordID {
                    zoneBookmarks.append(iZone)
                }
            }
        }

        return zoneBookmarks
    }


    func recordForCKRecord(_ record: CKRecord?, in storageMode: ZStorageMode) -> ZRecord? {
        var result: ZRecord? = nil

        if let recordID = record?.recordID {
            result      = recordForRecordID(recordID, in: storageMode)
        }

        return result
    }


    func recordForRecordID(_ recordID: CKRecordID?, in storageMode: ZStorageMode) -> ZRecord? {
        var   record = zoneForRecordID(recordID, in: storageMode) as ZRecord?
        let manifest = gTravelManager.manifest(for:  storageMode)

        if  record  == nil && manifest.record?.recordID.recordName == recordID?.recordName {
            record   = manifest
        }

        return record
    }


    func zoneForReference(_ reference: CKReference, in storageMode: ZStorageMode) -> Zone? {
        let zones = zonesRegistry(for: storageMode)
        var  zone = zones[reference.recordID.recordName]

        if  zone == nil, let record = recordForRecordID(reference.recordID, in: storageMode)?.record {
            zone  = Zone(record: record, storageMode: storageMode)
        }

        return zone
    }


    func zoneForRecord(_ record: CKRecord, in storageMode: ZStorageMode) -> Zone {
        let zones = zonesRegistry(for: storageMode)
        var  zone = zones[record.recordID.recordName]

        if  zone == nil {
            zone  = Zone(record: record, storageMode: storageMode)
        } else if !(zone?.isDeleted ?? false) {
            zone!.record = record
        }

        zone!.maybeNeedChildren()

        return zone!
    }


    func zoneForRecordID(_ recordID: CKRecordID?, in storageMode: ZStorageMode) -> Zone? {
        if recordID == nil {
            return nil
        }

        let zones = zonesRegistry(for: storageMode)

        return zones[recordID!.recordName]
    }
}
