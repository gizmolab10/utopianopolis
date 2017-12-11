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


    dynamic var          here :  String?
    dynamic var zonesExpanded : [String]?
    var          manifestMode :  ZStorageMode?
    var             _hereZone :  Zone?
    var          currentGrabs = [Zone] ()


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(here), #keyPath(zonesExpanded)]
    }


    var hereZone: Zone {
        get {
            if  _hereZone == nil && here != nil {
                _hereZone  = Zone(record: CKRecord(recordType: gZoneTypeKey, recordID: CKRecordID(recordName: here!)), storageMode: manifestMode)
            }

            return _hereZone!
        }

        set {
            if  _hereZone != newValue {
                _hereZone  = newValue
            }

            if  let   name = _hereZone?.recordName {
                here       = name

                needSave()
            }

            _hereZone?.maybeNeedRoot()
            if manifestMode == _hereZone?.storageMode {
                gFavoritesManager.updateCurrentFavorite() // so user will know
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
        if  let name = iZone.recordName,
            let    _ = expanded.index(of: name) {
            return true
        }

        return false
    }


    func displayChildren(in iZone: Zone) {
        var expansionSet = expanded

        if  let name = iZone.recordName, !expansionSet.contains(name) {
            expansionSet.append(name)

            zonesExpanded = expansionSet
            
            needSave()
        }
    }


    func hideChildren(in iZone: Zone) {
        var expansionSet = expanded

        if let  name = iZone.recordName {
            while let index = expansionSet.index(of: name) {
                expansionSet.remove(at: index)
            }
        }

        if  expanded.count != expansionSet.count {
            zonesExpanded   = expansionSet

            needSave()
        }
    }
    

    override func addState(_ state: ZRecordState) {
        if manifestMode != .favoritesMode {
            super.addState(state)
        }
    }

}
