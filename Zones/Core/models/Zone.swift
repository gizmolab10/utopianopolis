 //
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


struct ZoneState: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let ShowsChildren = ZoneState(rawValue: 1 <<  0)
    static let    IsFavorite = ZoneState(rawValue: 1 << 29)
    static let     IsDeleted = ZoneState(rawValue: 1 << 30)
}


class Zone : ZRecord {


    dynamic var    zoneName:      String?
    dynamic var    zoneLink:      String?
    dynamic var      parent: CKReference?
    dynamic var   zoneOrder:    NSNumber?
    dynamic var   zoneState:    NSNumber?
    dynamic var   zoneLevel:    NSNumber?
    dynamic var zoneProgeny:    NSNumber?
    var         _parentZone:        Zone?
    var          _crossLink:     ZRecord?
    var           bookmarks      = [Zone] ()
    var            children      = [Zone] ()
    var              widget:  ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var          isBookmark:         Bool { return crossLink != nil }
    var   isRootOfFavorites:         Bool { return record != nil && record.recordID.recordName == favoritesRootNameKey }
    var         hasProgeny:         Bool { return progenyCount != 0 }



    // MARK:- properties
    // MARK:-


    class func cloudProperties() -> [String] {
        return [#keyPath(parent),
                #keyPath(zoneName),
                #keyPath(zoneLink),
                #keyPath(zoneOrder),
                #keyPath(zoneState),
                #keyPath(zoneLevel),
                #keyPath(zoneProgeny)]
    }


    var           count: Int  { return children.count }
    var includeChildren: Bool { return showChildren && hasProgeny }


    var bookmarkTarget: Zone? {
        if  let link = crossLink {
            var target: Zone? = nil

            invokeWithMode(link.storageMode) {
                target = gCloudManager.zoneForRecordID(link.record.recordID)
            }

            return target
        }

        return nil
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


    var progenyCount: Int {
        get {
            if zoneProgeny == nil {
                updateZoneProperties()

                if zoneProgeny == nil {
                    zoneProgeny = NSNumber(value: currentProgenyCount)
                }
            }

            return zoneProgeny!.intValue
        }

        set {
            if newValue != progenyCount {
                zoneProgeny = NSNumber(value: newValue)

                self.needJustSave()
            }
        }
    }


    var currentProgenyCount: Int {
        var currentCount = count

        for child in children {
            currentCount += child.progenyCount
        }

        return currentCount
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


    var lowestExposed: Int? { return exposed(upTo: highestExposed) }


    var highestExposed: Int {
        var highest = level

        traverseApply { iZone -> ZTraverseStatus in
            let traverseLevel = iZone.level

            if  highest < traverseLevel {
                highest = traverseLevel
            }

            return iZone.includeChildren ? .eDescend : .eAscend
        }

        return highest
    }


    // MARK:- properties
    // MARK:-


    override func debug(_  iMessage: String) {
        // report("\(iMessage) children \(count) parent \(parent != nil) isDeleted \(isDeleted) mode \(storageMode!) \(zoneName ?? "unknown")")
    }


    var    isDeleted: Bool { get { return getState(for:     .IsDeleted) } set { setState(newValue, for: .IsDeleted) } }
    var   isFavorite: Bool { get { return getState(for:    .IsFavorite) } set { setState(newValue, for: .IsFavorite) } }
    var showChildren: Bool { get { return getState(for: .ShowsChildren) } set { setState(newValue, for: .ShowsChildren) } }

    
    var parentZone: Zone? {
        get {
            if parent == nil && _parentZone?.record != nil {
                needUpdateSave()

                parent      = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil && _parentZone == nil {
                _parentZone = gCloudManager.zoneForReference(parent!)

                if  _parentZone?.showChildren ?? false {
                    _parentZone?.maybeNeedChildren()
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


    var siblingIndex: Int? {
        if let siblings = parentZone?.children, let index = siblings.index(of: self) {
            return index
        }

        return nil
    }


    func getState(for iState: ZoneState) -> Bool {
        return state.contains(iState)

    }


    func setState(_ iValue: Bool, for iState: ZoneState) {
        if iValue != getState(for: iState) {
            if iValue {
                state.insert(iState)
            } else {
                state.remove(iState)
            }
        }
    }

    
    // MARK:- convenience
    // MARK:-


    var hasZonesAbove: Bool { return hasAnyZonesAbove(true) }
    var hasZonesBelow: Bool { return hasAnyZonesAbove(false) }
    var     isEditing: Bool { return gSelectionManager .isEditing(self) }
    var     isGrabbed: Bool { return gSelectionManager .isGrabbed(self) }
    var    isSelected: Bool { return gSelectionManager.isSelected(self) }
    func      ungrab()             { gSelectionManager    .ungrab(self) }
    func        grab()             { gSelectionManager      .grab(self) }


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


    override func register() {
        gCloudManager.registerZone(self)
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    // MARK:- parents
    // MARK:-


    func orphan() {
        parentZone?.removeChild(self)

        parentZone = nil

        needUpdateSave()
    }


    func updateProgenyCounts() {
        let currentCount = currentProgenyCount

        if  progenyCount != currentCount {
            progenyCount  = currentCount

            needUpdateSave()

            if !isRoot {
                if parentZone != nil {
                    parentZone?.updateProgenyCounts()
                } else {
                    markForStates([.needsParent])

                    gOperationsManager.parent {
                        self.updateZoneProperties()
                        self.parentZone?.updateProgenyCounts()
                    }
                }
            }
        }
    }


    // MARK:- siblings
    // MARK:-


    private func hasAnyZonesAbove(_ iAbove: Bool) -> Bool {
        if self != gHere {
            if !hasZoneAbove(iAbove), let parent = parentZone {
                return parent.hasAnyZonesAbove(iAbove)
            }

            return true
        }

        return false
    }


    func isSibling(of iSibling: Zone?) -> Bool {
        return iSibling != nil && parentZone == iSibling!.parentZone
    }

    
    // MARK:- offspring
    // MARK:-


    func maybeNeedChildren() {
        if count <= 1 && includeChildren {
            needChildren()
        }
    }


    @discardableResult func addChild(_ child: Zone?) -> Int? {
        return addChild(child, at: 0)
    }


    @discardableResult func addChild(_ child: Zone?, at index: Int?) -> Int? {
        if child != nil {

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

            if index != nil && index! >= 0 && index! < count {
                children.insert(child!, at: insertAt)
            } else {
                insertAt = count

                children.append(child!)
            }

            child?.needUpdateSave()
            child?.updateLevel()
            updateProgenyCounts()

            return insertAt
        }

        return nil
    }


    func addAndReorderChild(_ child: Zone?, at iIndex: Int?) {
        if addChild(child, at: iIndex) != nil {
            updateOrdering()
        }
    }


    func removeChild(_ child: Zone?) {
        if child != nil, let index = children.index(of: child!) {
            children.remove(at: index)
            updateProgenyCounts()
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


    func isChild(of iParent: Zone?) -> Bool {
        return iParent != nil && iParent == parentZone
    }


    enum ZCycleType: Int {
        case cycle
        case found
        case none
    }


    // MARK:- recursion
    // MARK:-


    override func deepCopy() -> Zone {
        let zone = super.deepCopy()

        for child in children {
            zone.addChild(child.deepCopy())
        }

        return zone
    }
    

    func updateOrdering() {
        let increment = 1.0 / Double(count + 2)

        for (index, child) in children.enumerated() {
            child.order = increment * Double(index + 1)
        }
    }


    func recursivelyMarkAsDeleted(_ iDeleted: Bool) {
        isDeleted = iDeleted

        for child in children {
            child.recursivelyMarkAsDeleted(iDeleted)
        }
    }


    // FUBAR occasional infinite loop
    // when child of child == self

    @discardableResult func traverseApply(_ block: ZoneToStatusClosure) -> ZTraverseStatus {
        var status = block(self)

        if status == .eDescend {
            for child in children {
                if self.isDescendantOf(child) != .none {
                    status = .eStop

                    break
                }

                status = child.traverseApply(block)

                if status == .eStop {
                    break
                }
            }
        }

        return status
    }


    // FUBAR occasional infinite loop
    // when parent of parent == self

    var cycleDetectorArray = [Zone] ()


    func isDescendantOf(_ iZone: Zone) -> ZCycleType {
        let         detector = iZone.cycleDetectorArray
        var flag: ZCycleType = .none

        if iZone == self {
            if detector.count > 0 {
                flag = .found
            }
        } else if detector.contains(self) {
            flag = .cycle
        } else if let parent = parentZone {
            iZone.cycleDetectorArray.append(self)

            return parent.isDescendantOf(iZone)
        }

        iZone.cycleDetectorArray.removeAll()

        return flag
    }


    func spawned(_ iChild: Zone) -> Bool {
        var isSpawn = false

        traverseApply { iZone -> ZTraverseStatus in
            if iZone == iChild {
                isSpawn = true

                return .eStop
            }

            return .eDescend
        }

        return isSpawn
    }


    func updateLevel() {
        traverseApply { iZone -> ZTraverseStatus in
            if let parentLevel = iZone.parentZone?.level, parentLevel != gUnlevel {
                iZone.level = parentLevel + 1
            }

            return .eDescend
        }
    }


    func exposedProgeny(at iLevel: Int) -> [Zone] {
        var     progeny = [Zone]()
        var begun: Bool = false

        traverseApply { iZone -> ZTraverseStatus in
            if begun {
                if iZone.level > iLevel || iZone == self {
                    return .eAscend
                } else if iZone.level == iLevel && iZone != self && (iZone.parentZone == nil || iZone.parentZone!.showChildren) {
                    progeny.append(iZone)
                }
            }

            begun = true

            return .eDescend
        }

        return progeny
    }


    func exposed(upTo highestLevel: Int) -> Int? {
        if !hasProgeny {
            return nil
        }

        var   exposedLevel = level

        while exposedLevel <= highestLevel {
            let progeny = exposedProgeny(at: exposedLevel + 1)

            if  progeny.count == 0 {
                return exposedLevel
            }

            exposedLevel += 1

            for child: Zone in progeny {
                if !child.showChildren && (child.hasProgeny || child.count != 0) {
                    return exposedLevel
                }
            }
        }

        return level
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
