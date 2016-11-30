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
    dynamic var    zoneOrder:    NSNumber?
    dynamic var showSubzones:    NSNumber?
    var             children:       [Zone] = []
    var          _parentZone:        Zone?


    // MARK:- properties
    // MARK:-


    var crossLink: Zone? { get { return nil } } // compute from cross ref and cloud zone


    var order: Double {
        get {
            if zoneOrder == nil {
                updateZoneProperties()

                if zoneOrder == nil {
                    zoneOrder = NSNumber(value: 0.0)
                }
            }

            return Double((zoneOrder?.doubleValue)!)
        }

        set {
            if newValue != order {
                zoneOrder = NSNumber(value: newValue)

                recordState.insert(.needsMerge)
            }
        }
    }


    var showChildren: Bool {
        get {
            if showSubzones == nil {
                updateZoneProperties()

                if showSubzones == nil {
                    showSubzones = NSNumber(value: 0)
                }
            }

            return showSubzones?.int64Value == 1
        }

        set {
            if newValue != showChildren {
                showSubzones = NSNumber(integerLiteral: newValue ? 1 : 0)

                recordState.insert(.needsMerge)
            }
        }
    }

    
    var parentZone: Zone? {
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

        set {
            _parentZone  = newValue

            if let parentRecord = newValue?.record {
                parent          = CKReference(record: parentRecord, action: .none)
            }
        }
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(zoneName), #keyPath(parent), #keyPath(zoneOrder), #keyPath(showSubzones)]
    }


    override func updateZoneProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if let cloudValue = record[keyPath] as! NSObject? {
                    let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                    if propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    override func updateCloudProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if let cloudValue = record[keyPath] as! NSObject? {
                    let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                    if propertyValue != nil && propertyValue != cloudValue {
                        record[keyPath] = propertyValue as? CKRecordValue
                    }
                }
            }
        }
    }


    // MARK:- child ordering
    // MARK:-


    func orderAt(_ index: Int) -> Double? {
        if index >= 0 && index < children.count {
            let child = children[index]

            return child.order
        }

        return nil
    }


    func respectOrder() {
        children.sort { (a, b) -> Bool in
            return a.order < b.order
        }
    }


    func normalizeOrdering() {
        let     count = children.count
        let increment = 1.0 / Double(count + 1)
        var     index = 0

        while index < count {
            let   child = children[index]
            index      += 1
            child.order = increment * Double(index)
        }
    }


    func recomputeOrderingUponInsertionAt(_ index: Int) {
        let  orderLarger = orderAt(index + 1) ?? 1.0
        let orderSmaller = orderAt(index - 1) ?? 0.0
        let        child = children[index]
        child.order      = (orderLarger + orderSmaller) / 2.0
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


    // MARK:- file persistence
    // MARK:-


    convenience init(dict: ZStorageDict) {
        self.init(record: nil, storageMode: travelManager.storageMode)

        storageDict = dict
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

            respectOrder()
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
