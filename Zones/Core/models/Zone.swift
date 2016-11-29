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


    dynamic var    cloudZone:      String?
    dynamic var     zoneName:      String?
    dynamic var     crossRef: CKReference?
    dynamic var       parent: CKReference?
    dynamic var showSubzones:    NSNumber?
    var             children:       [Zone] = []
    var          _parentZone:        Zone?

    var showChildren: Bool {
        get { return showSubzones?.int64Value == 1 }
        set {
            if newValue != showChildren {
                showSubzones = NSNumber(integerLiteral: newValue ? 1 : 0)

                recordState.insert(.needsMerge)
            }
        }
    }


    var crossLink: Zone? { get { return nil } }

    
    var parentZone: Zone? {
        set {
            _parentZone  = newValue

            if let parentRecord = newValue?.record {
                parent          = CKReference(record: parentRecord, action: .none)
            }
        }
        get {
            if parent == nil && _parentZone?.record != nil {
                needsSave()

                parent          = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil {
                _parentZone = cloudManager.objectForRecordID((parent?.recordID)!) as? Zone
            }

            return _parentZone
        }
    }


    convenience init(dict: ZStorageDict) {
        self.init(record: nil, storageMode: travelManager.storageMode)

        storageDict = dict
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(zoneName), #keyPath(parent), #keyPath(showSubzones)]
    }

    
    func normalize() {
        var index = children.count

        while index > 0 {
            index -= 1
            let child = children[index]

            if let testParent = child.parentZone {
                if testParent != self {
                    children.remove(at: index) // remove is ok since index is decreasing, and therefore stays valid
                    testParent.children.append(child)
                }
            } else {
                reportError(child)
            }
            
            child.normalize()
        }
    }


    func siblingIndex() -> Int {
        if let progeny: [Zone] = parentZone?.children {
            if let index = progeny.index(of: self) {
                return index
            }
        }

        return -1
    }


    override func saveToCloud() {
        cloudManager.currentDB?.save(record) { (iRecord: CKRecord?, iError: Error?) in
            if iError != nil {
                print(iError)
            } else {
                self.record = iRecord
            }
        }
    }


    override func updateZoneProperties() {
        if record != nil {
            if let name = record[zoneNameKey] as? String {
                if name != zoneName {
                    zoneName = name
                }
            }

            if let show = record["showSubzones"] as? NSNumber {
                if show != showSubzones {
                    showSubzones = show
                }
            }

            if let cloudParent = record["parent"] as? CKReference {
                if cloudParent != parent {
                    parent = cloudParent
                }
            }
        }
    }


    override func updateCloudProperties() {
        if record != nil {
            let        name = record[zoneNameKey] as? String
            let        show = record["showSubzones"] as? NSNumber
            let cloudParent = record["parent"] as? CKReference

            if zoneName != nil && zoneName != name {
                record[zoneNameKey] = zoneName as? CKRecordValue
            }

            if showSubzones != nil && showSubzones?.int64Value != show?.int64Value {
                record["showSubzones"] = showSubzones as? CKRecordValue
            }

            if parent != nil && parent != cloudParent {
                record["parent"] = parent
            }
        }
    }

    
    override func setStorageDictionary(_ dict: ZStorageDict) {
        if let string = dict[    zoneNameKey] as!   String? { zoneName     = string }
        if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

        if let childrenStore: [ZStorageDict] = dict[childrenKey] as! [ZStorageDict]? {
            for childStore: ZStorageDict in childrenStore {
                let        child = Zone(dict: childStore)
                child.parentZone = self

                children.append(child)
            }
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed to cloud
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
