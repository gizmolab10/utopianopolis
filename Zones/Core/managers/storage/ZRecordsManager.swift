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


    var recordsByState: [ZRecordState : [ZRecord]] {
        get {
            if  statesByMode[gStorageMode] == nil {
                statesByMode[gStorageMode]  = [:]
            }

            return statesByMode[gStorageMode]!
        }

        set {
            statesByMode[gStorageMode] = newValue
        }
    }


    var zones: [String : Zone] {
        get {
            var registry: [String : Zone]? = zoneRegistry[gStorageMode]

            if  registry                  == nil {
                registry                   = [:]
                zoneRegistry[gStorageMode] = registry!
            }

            return registry!
        }

        set {
            zoneRegistry[gStorageMode] = newValue
        }
    }


    var undeletedCount: Int {
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
        let    dict = recordsByState
        var records = dict[state]       // swift's terse nature has confused me, here

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
            let  zone: ZRecord = object as! ZRecord

            if let      record = zone.record, !objects.contains(record) {
                zone.debug("saving")

                objects.append(record)
            }
        }

        return objects
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


    func registerZone(_ zone: Zone?) {
        if  let     record = zone?.record {
            let registered = isRegistered(zone!)
            let identifier = record.recordID.recordName

            if registered == nil {
                zones[identifier]   = zone
            } else if registered!  != identifier {
                zones[registered!]  = nil
                zones[identifier]   = zone
            }
        }
    }


    func unregisterZone(_ zone: Zone?) {
        if let record = zone?.record {
            zones[record.recordID.recordName] = nil
        }
    }


    func applyToAllZones(_ closure: ZoneClosure) {
        for mode: ZStorageMode in [.mine, .everyone, .favorites] {
            invokeWithMode(mode) {
                for zone in zones.values {
                    closure(zone)
                }
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


    func modeSpecificRecordForRecordID(_ recordID: CKRecordID?) -> ZRecord? {
        var record = modeSpecificZoneForRecordID(recordID) as ZRecord?

        if  record == nil && gManifest.record?.recordID.recordName == recordID?.recordName {
            record  = gManifest
        }

        return record
    }


    func modeSpecificZoneForReference(_ reference: CKReference) -> Zone? {
        var zone = zones[reference.recordID.recordName]

        if  zone == nil, let record = modeSpecificRecordForRecordID(reference.recordID)?.record {
            zone = Zone(record: record, storageMode: gStorageMode)
        }

        return zone
    }


    func modeSpecificZoneForRecord(_ record: CKRecord) -> Zone {
        var zone = zones[record.recordID.recordName]

        if  zone == nil {
            zone = Zone(record: record, storageMode: gStorageMode)
        } else if !(zone?.isDeleted ?? false) {
            zone?.record = record
        }

        zone!.maybeNeedChildren()

        return zone!
    }


    func modeSpecificZoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        if recordID == nil {
            return nil
        }
        
        return zones[recordID!.recordName]
    }
}
