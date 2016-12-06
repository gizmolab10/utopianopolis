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


    dynamic var     zoneName:      String?
    dynamic var     zoneLink:      String?
    dynamic var       parent: CKReference?
    dynamic var    zoneOrder:    NSNumber?
    dynamic var showSubzones:    NSNumber?
    var             children:       [Zone] = []
    var          _parentZone:        Zone?
    var           isBookmark:         Bool { get { return crossLink != nil } }
    var               isRoot:         Bool { get { return record != nil && record.recordID.recordName == rootNameKey } }


    // MARK:- properties
    // MARK:-


    class func cloudProperties() -> [String] {
        return [#keyPath(parent),
                #keyPath(zoneName),
                #keyPath(zoneLink),
                #keyPath(zoneOrder),
                #keyPath(showSubzones)]
    }


    var crossLink: ZRecord? {
        get {
            if zoneLink == nil {
                return nil
            } else {
                let components: [String] = (zoneLink?.components(separatedBy: ":"))!
                let refString:   String  = components[2]
                let refID:   CKRecordID? = refString == "" ? nil : CKRecordID(recordName: refString)
                let reference: CKRecord? = refID == nil ? nil : CKRecord(recordType: zoneTypeKey, recordID: refID!)
                let mode:  ZStorageMode? = ZStorageMode(rawValue: components[0])

                return ZRecord(record: reference, storageMode: mode)
            }
        }

        set {
            if newValue == nil {
                zoneLink = nil
            } else {
                let    hasRef = newValue != nil && newValue!.record != nil
                let reference = !hasRef ? "" : newValue!.record.recordID.recordName
                zoneLink      = "\(newValue!.storageMode!.rawValue)::\(reference)"
            }
        }
    }


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

                cloudManager.addRecord(self, forState: .needsMerge)
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

                cloudManager.addRecord(self, forState: .needsMerge)
            }
        }
    }

    
    var parentZone: Zone? {
        get {
            if parent == nil && _parentZone?.record != nil {
                needSave()

                parent      = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil && _parentZone == nil {
                _parentZone = cloudManager.zoneForRecordID((parent?.recordID)!) // sometimes yields nil ... WHY?
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


    func copyAsOrphanBookmark() -> Zone {
        let          zone = Zone(record: record, storageMode: storageMode)
        zone.showChildren = showChildren
        zone.crossLink    = crossLink
        zone.zoneName     = zoneName
        zone.order        = order

        return zone
    }


    override func register() {
        cloudManager.registerZone(self)
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    // MARK:- offspring
    // MARK:-


    func orphan() {
        parentZone?.removeChild(self)
    }


    func removeChild(_ child: Zone?) {
        if child != nil, let index = children.index(of: child!) {
            children.remove(at: index)
        }

    }


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
        if let siblings: [Zone] = parentZone?.children {
            if let index = siblings.index(of: self) {
                return index
            }
        }

        return -1
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
