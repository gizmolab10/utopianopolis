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
    var           _crossLink:     ZRecord?
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
            } else if _crossLink == nil {
                let components: [String] = (zoneLink?.components(separatedBy: ":"))!
                let refString:   String  = components[2] == "" ? "root" : components[2]
                let refID:    CKRecordID = CKRecordID(recordName: refString)
                let refRecord:  CKRecord = CKRecord(recordType: zoneTypeKey, recordID: refID)
                let mode:  ZStorageMode? = ZStorageMode(rawValue: components[0])

                _crossLink = ZRecord(record: refRecord, storageMode: mode)
            }

            return _crossLink
        }

        set {
            if newValue == nil {
                zoneLink = nil
            } else {
                let    hasRef = newValue != nil && newValue!.record != nil
                let reference = !hasRef ? "" : newValue!.record.recordID.recordName
                zoneLink      = "\(newValue!.storageMode!.rawValue)::\(reference)"
            }

            _crossLink = nil
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

                self.maybeNeedMerge()
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

                self.maybeNeedMerge()
            }
        }
    }

    
    var parentZone: Zone? {
        get {
            if parent == nil && _parentZone?.record != nil {
                needSave()

                parent          = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil && _parentZone == nil {
                _parentZone     = cloudManager.zoneForRecordID((parent?.recordID)!) // sometimes yields nil ... WHY?
            }

            return _parentZone
        }

        set {
            _parentZone  = newValue

            if let parentRecord = newValue?.record {
                parent          = CKReference(record: parentRecord, action: .none)
            } else {
                parent          = nil
            }
        }
    }


    subscript(i: Int) -> Zone? {
        if i < children.count && i >= 0 {
            return children[i]
        } else {
            return nil
        }
    }


    func deepCopy() -> Zone {
        let          zone = Zone(record: nil, storageMode: storageMode)
        zone.showChildren = showChildren
        zone.crossLink    = crossLink
        zone.zoneName     = zoneName
        zone.order        = order

        for child in children {
            zone.children.append(child.deepCopy())
        }

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


    override func needChildren() {
        if children.count == 0 {
            super.needChildren()
        }
    }


    func orphan() {
        parentZone?.removeChild(self)
        parentZone = nil
        parent     = nil
    }


    func addChild(_ child: Zone?, at index: Int) {
        if child != nil {
            if children.contains(child!) {
                return
            }

            if child?.record != nil {
                let identifier = child?.record.recordID.recordName

                for sibling in children {
                    if sibling.record != nil && sibling.record.recordID.recordName == identifier {
                        return
                    }
                }
            }

            children.insert(child!, at: index)
        }
    }


    func addChild(_ child: Zone?) {
        addChild(child, at: 0)
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
        let increment = 1.0 / Double(children.count + 2)

        for (index, child) in children.enumerated() {
            child.order = increment * Double(index + 1)
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
