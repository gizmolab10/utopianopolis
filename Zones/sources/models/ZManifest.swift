//
//  ZManifest.swift
//  Zones
//
//  Created by Jonathan Sand on 12/3/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZManifest: ZRecord {


    dynamic var here:           CKReference?
    dynamic var zonesExpanded: [String]?
    var         currentGrabs = [Zone] ()
    var        _hereZone:       Zone?
    var   manifestMode: ZStorageMode?


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(here), #keyPath(zonesExpanded)]
    }


    var hereZone: Zone {
        get {
            if _hereZone == nil {
                let hereRecord: CKRecord? = (here == nil) ? nil : CKRecord(recordType: zoneTypeKey, recordID: (here?.recordID)!)
                _hereZone                 = Zone(record: hereRecord, storageMode: manifestMode)
            }

            return _hereZone!
        }

        set {
            if  _hereZone != newValue {
                _hereZone  = newValue
            }

            if let record = _hereZone?.record, record.recordID.recordName != here?.recordID.recordName {
                here = CKReference(record: record, action: .none)

                needFlush()
            }
        }
    }


    var expanded: [String] {
        if  zonesExpanded == nil {
            zonesExpanded = [String] ()
        }

        return zonesExpanded!
    }


    func showsChildren(_ iZone: Zone) -> Bool {
        if  let name = iZone.record?.recordID.recordName,
            let    _ = expanded.index(of: name) {
            return true
        }

        return false
    }


    func displayChildren(in iZone: Zone) {
        var expansionSet = expanded

        if  let name = iZone.record?.recordID.recordName, !expansionSet.contains(name) {
            expansionSet.append(iZone.record.recordID.recordName)

            zonesExpanded = expansionSet
            
            needFlush()
        }
    }


    func hideChildren(in iZone: Zone) {
        var expansionSet = expanded

        if iZone.isRoot {
            expansionSet.removeAll()
        } else if let  name = iZone.record?.recordID.recordName {
            while let index = expansionSet.index(of: name) {
                expansionSet.remove(at: index)
            }
        }

        if  expanded.count != expansionSet.count {
            zonesExpanded   = expansionSet

            needFlush()
        }
    }
    

    override func markForAllOfStates (_ states: [ZRecordState]) {
        if manifestMode != .favorites {
            super.markForAllOfStates(states)
        }
    }

}
