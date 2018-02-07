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
    case needsTraits
    case needsParent
    case needsDestroy
    case needsProgeny
    case needsWritable
    case needsChildren
    case needsBookmarks
    case requiresFetch
}


class ZRecordsManager: NSObject {


    var              databaseiD : ZDatabaseiD
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


    var hereRecordName: String? {
        get { return gSelectionManager.hereRecordName(for: databaseiD) }
        set { gSelectionManager.setHereRecordName(newValue ?? kRootName, for: databaseiD) }
    }


    var hereZone: Zone {
        get { return maybeZRecordForRecordName(hereRecordName) as? Zone ?? rootZone! }
        set { hereRecordName = newValue.recordName ?? kRootName }
    }


    init(_ idatabaseiD: ZDatabaseiD) {
        databaseiD = idatabaseiD
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
        let        prefix = (databaseiD == .mineID) ? "my " : "public "
        zone.directAccess = .eDefaultName
        zone    .zoneName = prefix + iName

        return zone
    }


    func createRandomLost() -> Zone {
        let lost = Zone.randomZone(in: databaseiD)

        lostAndFoundZone.addChild(lost, at: nil)

        return lost
    }


    // MARK:- record state
    // MARK:-


    var undeletedCounts: (Int, Int) {
        let zRecords = zRecordsByID.values
        var   uCount = zRecords.count
        var   nCount = 0

        for zRecord in zRecords {
            if  let zone = zRecord as? Zone {
                if !zone.canSave || zone.isInTrash {
                    uCount -= 1
                }

                if !zone.canSave {
                    nCount += 1
                }
            }
        }

        return (uCount, nCount)
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


    func hasZRecord(_ iRecord: ZRecord, forAnyOf iStates: [ZRecordState]) -> Bool {
        if let ckRecord = iRecord.record {
            return registeredCKRecord(ckRecord, forAnyOf: iStates) != nil
        }

        return false
    }


    func registeredCKRecord(for iRecordID: CKRecordID, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        var found: CKRecord? = nil

        applyToCKRecordByRecordID(iRecordID, forAnyOf: iStates) { (state: ZRecordState, record: CKRecord) in
            found = record
        }

        return found
    }


    func registeredCKRecord(_ iRecord: CKRecord, forAnyOf iStates: [ZRecordState]) -> CKRecord? {
        return registeredCKRecord(for: iRecord.recordID, forAnyOf: iStates)
    }


    // MARK:- set state
    // MARK:-


    func addZRecord(_ iRecord: ZRecord, for states: [ZRecordState]) {
        if  let ckrecord = iRecord.record {
            addCKRecord(ckrecord, for: states)
        }
    }


    @discardableResult func addCKRecord(_ iRecord: CKRecord, for states: [ZRecordState]) -> Bool {
        var wasAdded = false

        for state in states {
            if  let  record  = registeredCKRecord(iRecord, forAnyOf: [state]) {
                if   record != iRecord {
                    var name =  record.decoratedName
                    if  name == "" {
                        name = iRecord.decoratedName
                    }

                    columnarReport("ADDING TWICE!", name + " (for: \(state))")
                }
            } else {
                var records  = ckRecordsForState(state)

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


    func pullChildrenRefsWithMatchingStates(_ states: [ZRecordState], batchSize: Int) -> [CKReference] {
        let references = childrenRefsWithMatchingStates(states, batchSize: batchSize)

        clearReferences(references, for: states)

        return references
    }


    func hasMatch(with states: [ZRecordState]) -> Bool {
        var found = false

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            found = true
        }

        return found
    }


    func childrenRefsWithMatchingStates(_ states: [ZRecordState], batchSize: Int) -> [CKReference] {
        var references = [CKReference] ()
        var  expecting = 0

        applyToAllCKRecordsWithAnyMatchingStates(states) { iState, iCKRecord in
            if  let fetchable = (iCKRecord["zoneCount"] as? NSNumber)?.intValue,
                !iCKRecord.isBookmark, (fetchable + expecting) < batchSize {
                expecting    += fetchable

                references.append(CKReference(recordID: iCKRecord.recordID, action: .none))
            }
        }

        return references
    }


    // MARK:- batch lookup
    // MARK:-


    func fullUpdate(for states: [ZRecordState], _ onEach: StateRecordClosure) {
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
            if  let zone  = object as? Zone {
                let name  = zone.decoratedName
                if  name != "" {
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


    func stringForReferences(_ references: [CKReference]?, in databaseiD: ZDatabaseiD) -> String {
        return references?.apply()  { object -> (String?) in
            if let reference = object as? CKReference, let zone = gRemoteStoresManager.recordsManagerFor(databaseiD)?.maybeZoneForReference(reference) {
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


    func unregisterCKRecord(_ ckRecord: CKRecord?) {
        clearAllStatesForCKRecord(ckRecord)

        if let name = ckRecord?.recordID.recordName {
            zRecordsByID[name] = nil
        }
    }


    func unregisterZRecord(_ zRecord: ZRecord?) {
        unregisterCKRecord(zRecord?.record)
        gBookmarksManager.unregisterBookmark(zRecord as? Zone)
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
        return maybeZoneForRecordID(recordID) as ZRecord?
    }


    func maybeZRecordForRecordName(_ recordName: String?) -> ZRecord? {
        if  let id = recordName {
            return zRecordsByID[id]
        }

        return nil
    }


    func maybeZoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        return maybeZRecordForRecordName(recordID?.recordName) as? Zone
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
            zone  = Zone(record: CKRecord(recordType: kZoneType, recordID: reference.recordID), databaseiD: databaseiD)

            zone?.requireFetch() // POTENTIALLY BAD DUMMY
            zone?.maybeNeedFetch()
        }

        return zone!
    }


    func zoneForCKRecord(_ ckRecord: CKRecord) -> Zone {
        var     zone = maybeZoneForCKRecord(ckRecord)

        if let z = zone {
            z.useBest(record: ckRecord)
        } else {
            zone = Zone(record: ckRecord, databaseiD: databaseiD)

            zone?.maybeNeedFetch()
        }

        return zone!
    }

}
