 //
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


struct ZoneState: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let ShowsChildren = ZoneState(rawValue: 1 <<  0)
    static let   HasChildren = ZoneState(rawValue: 1 <<  1)
    static let    IsFavorite = ZoneState(rawValue: 1 << 29)
    static let     IsDeleted = ZoneState(rawValue: 1 << 30)
}


class Zone : ZRecord {


    dynamic var  zoneName:      String?
    dynamic var  zoneLink:      String?
    dynamic var    parent: CKReference?
    dynamic var zoneOrder:    NSNumber?
    dynamic var zoneState:    NSNumber?
    dynamic var zoneLevel:    NSNumber?
    var         bookmarks      = [Zone] ()
    var          children      = [Zone] ()
    var       _parentZone:        Zone?
    var        _crossLink:     ZRecord?
    var        isBookmark:         Bool { get { return crossLink != nil } }
    var isRootOfFavorites:         Bool { get { return record != nil && record.recordID.recordName == favoritesRootNameKey } }



    // MARK:- properties
    // MARK:-


    class func cloudProperties() -> [String] {
        return [#keyPath(parent),
                #keyPath(zoneName),
                #keyPath(zoneLink),
                #keyPath(zoneOrder),
                #keyPath(zoneState),
                #keyPath(zoneLevel)]
    }


    var           count: Int  { return children.count }
    var includeChildren: Bool { return showChildren && hasChildren }


    var bookmarkTarget: Zone? {
        get {
            if  let link = crossLink {
                var target: Zone? = nil

                invokeWithMode(link.storageMode) {
                    target = gCloudManager.zoneForRecordID(link.record.recordID)
                }

                return target
            }

            return nil
        }
    }


    var crossLink: ZRecord? {
        get {
            if zoneLink == nil || zoneLink == "" {
                return nil
            } else if _crossLink == nil {
                if (zoneLink?.contains("Optional("))! {
                    zoneLink = zoneLink?.replacingOccurrences(of: "Optional(\"", with: "")
                    zoneLink = zoneLink?.replacingOccurrences(of:         "\")", with: "")
                }

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

                self.needUpdateSave()
            }
        }
    }


    var level: Int {
        get {
            if zoneLevel == nil {
                updateZoneProperties()

                if zoneLevel == nil {
                    zoneLevel = NSNumber(value: gUnlevel)
                }
            }

            return (zoneLevel?.intValue)!
        }

        set {
            if newValue != level {
                zoneLevel = NSNumber(value: newValue)

                self.needJustSave()
            }
        }
    }


    var state: ZoneState {
        get {
            if zoneState == nil {
                updateZoneProperties()

                if zoneState == nil {
                    zoneState = NSNumber(value: 1)
                }
            }

            return ZoneState(rawValue: Int((zoneState?.int64Value)!))
        }

        set {
            if newValue != state {
                zoneState = NSNumber(integerLiteral: newValue.rawValue)

                debug(" state")
                needJustSave()
            }
        }
    }


    override func debug(_  iMessage: String) {
        // report("\(iMessage) children \(count) parent \(parent != nil) isDeleted \(isDeleted) mode \(storageMode!) \(zoneName ?? "unknown")")
    }


    var isDeleted: Bool {
        get {
            return state.contains(.IsDeleted)
        }

        set {
            if newValue != isDeleted {
                if newValue {
                    state.insert(.IsDeleted)
                } else {
                    state.remove(.IsDeleted)
                }
            }
        }
    }


    var isFavorite: Bool {
        get {
            return state.contains(.IsFavorite)
        }

        set {
            if newValue != isFavorite {
                if newValue {
                    state.insert(.IsFavorite)
                } else {
                    state.remove(.IsFavorite)
                }
            }
        }
    }


    var hasChildren: Bool {
        get {
            return state.contains(.HasChildren)
        }

        set {
            if newValue != hasChildren {
                if newValue {
                    state.insert(.HasChildren)
                } else {
                    state.remove(.HasChildren)
                }
            }
        }
    }


    var showChildren: Bool {
        get {
            return state.contains(.ShowsChildren)
        }

        set {
            if newValue != showChildren {
                if newValue {
                    state.insert(.ShowsChildren)
                } else {
                    state.remove(.ShowsChildren)
                }
            }
        }
    }

    
    var parentZone: Zone? {
        get {
            if parent == nil && _parentZone?.record != nil {
                needUpdateSave()

                parent      = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil && _parentZone == nil {
                _parentZone = gCloudManager.zoneForReference(parent!)

                if  _parentZone?.showChildren ?? false {
                    _parentZone?.needChildren()
                }
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


    // MARK:- siblings
    // MARK:-


    private func hasAnyZonesAbove(_ iAbove: Bool) -> Bool {
        let here = gTravelManager.hereZone

        if self != here, let i = siblingIndex {
            let hasZone = i != (iAbove ? 0 : (parentZone!.count - 1))

            return hasZone || parentZone!.hasAnyZonesAbove(iAbove)
        }
        
        return false
    }

    
    // MARK:- convenience
    // MARK:-


    var hasZonesAbove: Bool       { return hasAnyZonesAbove(true) }
    var hasZonesBelow: Bool       { return hasAnyZonesAbove(false) }
    var     isEditing: Bool { get { return gSelectionManager .isEditing(self) } }
    var     isGrabbed: Bool { get { return gSelectionManager .isGrabbed(self) } }
    var    isSelected: Bool { get { return gSelectionManager.isSelected(self) } }
    func        grab()                   { gSelectionManager      .grab(self) }


    static func == ( left: Zone, right: Zone) -> Bool {
        let unequal = left != right // avoid infinite recursion by using negated version of this infix operator

        if  unequal && left.record != nil && right.record != nil {
            return left.record.recordID.recordName == right.record.recordID.recordName
        }

        return !unequal
    }


    subscript(i: Int) -> Zone? {
        if i < count && i >= 0 {
            return children[i]
        } else {
            return nil
        }
    }


    override func deepCopy() -> Zone {
        let zone = super.deepCopy()

        for child in children {
            zone.addChild(child.deepCopy())
        }

        return zone
    }


    override func register() {
        gCloudManager.registerZone(self)
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }

    
    // MARK:- offspring
    // MARK:-


    override func needChildren() {
        if count <= 1 && showChildren {
            super.needChildren()
        }
    }


    func orphan() {
        parentZone?.removeChild(self)

        parentZone = nil

        needUpdateSave()
    }


    @discardableResult func addChild(_ child: Zone?) -> Int? {
        return addChild(child, at: 0)
    }


    @discardableResult func addChild(_ child: Zone?, at index: Int?) -> Int? {
        if child != nil {
            hasChildren = true

            // make sure it's not already been added
            // NOTE: both must have a record for this to be effective

            if children.contains(child!) {
                return children.index(of: child!)
            }

            if child?.record != nil {
                let identifier = child?.record.recordID.recordName

                for sibling in children {
                    if sibling.record != nil && sibling.record.recordID.recordName == identifier {
                        return children.index(of: child!)
                    }
                }
            }

            child!.parentZone = self
            var      insertAt = index ?? count

            if index != nil && index! < count {
                children.insert(child!, at: insertAt)
            } else {
                insertAt = count

                children.append(child!)
            }

            child?.updateLevel()

            return insertAt
        }

        return nil
    }


    func addAndReorderChild(_ child: Zone?, at iIndex: Int?) {
        if let index = addChild(child, at: iIndex) {
            recomputeOrderingUponInsertionAt(index)
        }
    }


    func recomputeOrderingUponInsertionAt(_ index: Int) {
        let  orderLarger = orderAt(index + 1) ?? 1.0
        let orderSmaller = orderAt(index - 1) ?? 0.0
        let        child = children[index]
        child.order      = (orderLarger + orderSmaller) / 2.0

        child.needUpdateSave()
    }


    func removeChild(_ child: Zone?) {
        if child != nil, let index = children.index(of: child!) {
            children.remove(at: index)

            if count == 0 {
                hasChildren = false

                needUpdateSave()
            }
        }
    }


    func moveChild(from: Int, to: Int) {
        if to < count, from < count, let child = self[from] {
            children.remove(       at: from)
            children.insert(child, at: to)
        }
    }


    func orderAt(_ index: Int) -> Double? {
        if index >= 0 && index < count {
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
        let increment = 1.0 / Double(count + 2)

        for (index, child) in children.enumerated() {
            child.order = increment * Double(index + 1)
        }
    }


    var siblingIndex: Int? {
        get {
            if let siblings: [Zone] = parentZone?.children, let index = siblings.index(of: self) {
                return index
            }

            return nil
        }
    }


    @discardableResult func traverseApply(_ block: ZoneToBooleanClosure) -> Bool {
        var stop = block(self)

        if !stop {
            for child in children {
                if self.isProgenyOf(child) || child.traverseApply(block) {
                    stop = true

                    break
                }
            }
        }

        return stop
    }


    func isProgenyOf(_ iZone: Zone) -> Bool {
        if  let p = parentZone, !p.isProgenyOf(self) {
            return p == iZone || p.isProgenyOf(iZone)
        }

        return false
    }
    

    func spawned(_ iChild: Zone) -> Bool {
        traverseApply { iZone -> Bool in
            return iZone == iChild
        }

        return false
    }


    func updateLevel() {
        traverseApply { iZone -> Bool in
            if let parentLevel = iZone.parentZone?.level, parentLevel != gUnlevel {
                iZone.level = parentLevel + 1
            }

            return false
        }
    }


    // MARK:- file persistence
    // MARK:-


    convenience init(dict: ZStorageDict) {
        self.init(record: nil, storageMode: gStorageMode)

        storageDict = dict
    }

    
    override func setStorageDictionary(_ dict: ZStorageDict) {
        if let string = dict[    zoneNameKey] as!   String? { zoneName     = string }
        if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

        if let childrenStore: [ZStorageDict] = dict[childrenKey] as! [ZStorageDict]? {
            for childStore: ZStorageDict in childrenStore {
                let child = Zone(dict: childStore)

                addChild(child, at: nil)
            }

            respectOrder()
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed to cloud
    }


    override func storageDictionary() -> ZStorageDict? {
        var      childrenStore = [ZStorageDict] ()
        var               dict = super.storageDictionary()!
        dict[zoneNameKey]      = zoneName as NSObject?
        dict[showChildrenKey]  = NSNumber(booleanLiteral: showChildren)


        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[childrenKey]      = childrenStore as NSObject?

        return dict
    }
}
