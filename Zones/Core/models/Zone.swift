//
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class Zone : ZRecord {

    
    dynamic var zoneName:       String?
    dynamic var   parent:  CKReference?
    dynamic var    links: [CKReference] = []
    var      _parentZone:         Zone?
    var         children:        [Zone] = []
    var     showChildren:          Bool = true


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(zoneName), #keyPath(links), #keyPath(parent)]
    }


    func resolveParents() {
        for child: Zone in children {
            child.resolveParents()
        }
    }


    var parentZone: Zone? {
        set {
            _parentZone  = newValue

            if let parentRecord = newValue?.record {
                parent          = CKReference(record: parentRecord, action: .none)
            }
        }
        get {
            if parent == nil && _parentZone?.record != nil {
                recordState     = .needsSave
                parent          = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil {
                return cloudManager.objectForRecordID((parent?.recordID)!) as? Zone
            }

            return _parentZone
        }
    }
    

    convenience init(dict: ZStorageDict) {
        self.init(record: nil, database: cloudManager.currentDB)

        storageDict = dict
    }


    override func saveToCloud() {
        cloudManager.currentDB.save(record) { (iRecord: CKRecord?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                self.record = iRecord
            }
        }
    }


    override func updateProperties() {
        if record != nil {
            if let name = record[zoneNameKey] {
                zoneName = name as? String
            }
        }
    }


    override func fetchChildren() {
        cloudManager.fetchReferencesTo(self)
    }


    override func setStorageDictionary(_ dict: ZStorageDict) {
        if let string = dict[    zoneNameKey] as!   String? { zoneName     = string }
        if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

        if let childrenStore: [ZStorageDict] = dict[childrenKey] as! [ZStorageDict]? {
            for child: ZStorageDict in childrenStore {
                let        zone = Zone(dict: child)
                zone.parentZone = self

                children.append(zone)
            }
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed into iCloud
    }


    override func storageDictionary() -> ZStorageDict? {
        var dict: ZStorageDict = super.storageDictionary()!
        dict[zoneNameKey]      = zoneName as NSObject?
        dict[showChildrenKey]  = NSNumber(booleanLiteral: showChildren)

        var childrenStore: [ZStorageDict] = []

        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[childrenKey]      = childrenStore as NSObject?

        return dict
    }
}
