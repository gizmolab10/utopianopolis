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
    static let   HasChildren = ZoneState(rawValue: 1 <<  1)
    static let    IsUpToDate = ZoneState(rawValue: 1 << 10)
    static let    IsFavorite = ZoneState(rawValue: 1 << 29)
    static let     IsDeleted = ZoneState(rawValue: 1 << 30)
}


class Zone : ZRecord {


    dynamic var    zoneName:      String?
    dynamic var    zoneLink:      String?
    dynamic var      parent: CKReference?
    dynamic var   zoneOrder:    NSNumber?
    dynamic var   zoneCount:    NSNumber?
    dynamic var   zoneState:    NSNumber?
    dynamic var   zoneLevel:    NSNumber?
    dynamic var zoneProgeny:    NSNumber?
    var         _parentZone:        Zone?
    var          _crossLink:     ZRecord?
    var           bookmarks      = [Zone] ()
    var            children      = [Zone] ()
    var               count:          Int { return children.count }
    var              widget:  ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var          isBookmark:         Bool { return crossLink != nil }
    var   isRootOfFavorites:         Bool { return record != nil && record.recordID.recordName == favoritesRootNameKey }
    var          hasProgeny:         Bool { return hasChildren || count > 0 || progenyCount > 1 }
    var      exposeChildren:         Bool { return hasProgeny &&  showChildren }
    var    indicateChildren:         Bool { return hasProgeny && !showChildren }
    var       hasZonesAbove:         Bool { return hasAnyZonesAbove(true) }
    var       hasZonesBelow:         Bool { return hasAnyZonesAbove(false) }
    var           isEditing:         Bool { return gSelectionManager .isEditing(self) }
    var           isGrabbed:         Bool { return gSelectionManager .isGrabbed(self) }
    var          isSelected:         Bool { return gSelectionManager.isSelected(self) }
    var           isDeleted:         Bool { get { return getState(for:     .IsDeleted) } set { setState(newValue, for: .IsDeleted) } }
    var          isUpToDate:         Bool { get { return getState(for:    .IsUpToDate) } set { setState(newValue, for: .IsUpToDate) } }
    var          isFavorite:         Bool { get { return getState(for:    .IsFavorite) } set { setState(newValue, for: .IsFavorite) } }
    var         hasChildren:         Bool { get { return getState(for:   .HasChildren) } set { setState(newValue, for: .HasChildren) } }
    var        showChildren:         Bool { get { return getState(for: .ShowsChildren) } set { setState(newValue, for: .ShowsChildren) } }


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


    var bookmarkTarget: Zone? {
        if  let link = crossLink, let mode = link.storageMode {
            return gRemoteStoresManager.cloudManagerFor(mode).zoneForRecordID(link.record.recordID)
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
                updateClassProperties()

                if zoneOrder == nil {
                    zoneOrder = NSNumber(value: 0.0)
                }
            }

            return Double(zoneOrder!.doubleValue)
        }

        set {
            if newValue != order {
                zoneOrder = NSNumber(value: newValue)
            }
        }
    }


    var level: Int {
        get {
            if zoneLevel == nil {
                updateClassProperties()

                if zoneLevel == nil {
                    zoneLevel = NSNumber(value: gUnlevel)
                }
            }

            return zoneLevel!.intValue
        }

        set {
            if newValue != level {
                zoneLevel = NSNumber(value: newValue)
            }
        }
    }


    var fetchableChildren: Int {
        get {
            if zoneCount == nil {
                updateClassProperties()

                if zoneCount == nil {
                    zoneCount = NSNumber(value: 0)
                }
            }

            return zoneCount!.intValue
        }

        set {
            if newValue != fetchableChildren {
                zoneCount = NSNumber(value: newValue)
            }
        }
    }
    

    var progenyCount: Int {
        get {
            if zoneProgeny == nil {
                updateClassProperties()

                if zoneProgeny == nil {
                    zoneProgeny = NSNumber(value: currentProgenyCount)
                }
            }

            return zoneProgeny!.intValue
        }

        set {
            if newValue != progenyCount {
                zoneProgeny = NSNumber(value: newValue)
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
                updateClassProperties()

                if zoneState == nil {
                    zoneState = NSNumber(value: 1)
                }
            }

            return ZoneState(rawValue: Int((zoneState?.int64Value)!))
        }

        set {
            if newValue != state {
                zoneState = NSNumber(integerLiteral: newValue.rawValue)
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

            return iZone.exposeChildren ? .eDescend : .eAscend
        }

        return highest
    }


    // MARK:- properties
    // MARK:-


    override func debug(_  iMessage: String) {
        // performance("\(iMessage) children \(count) parent \(parent != nil) isDeleted \(isDeleted) mode \(storageMode!) \(zoneName ?? "unknown")")
    }

    
    var parentZone: Zone? {
        get {
            if  parent == nil && _parentZone?.record != nil {
                parent  = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil && _parentZone == nil && storageMode != nil {
                _parentZone = gRemoteStoresManager.cloudManagerFor(storageMode!).zoneForReference(parent!)

                // _parentZone?.maybeNeedChildren()
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
        cloudManager?.registerZone(self)
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    // MARK:- parents
    // MARK:-


    func orphan() {
        if let zone = parentZone, zone.removeChild(self) {
            zone.incrementProgenyCount(by: -progenyCount)
        }

        parentZone = nil

        needSave()
        updateCloudProperties()
    }


    func progenyCountUpdate( _ visited: [Zone]) {
        if !visited.contains(self) {
            progenyCount = 1

            for child in self.children {
                child.progenyCountUpdate(visited + [self])

                progenyCount += child.progenyCount
            }
        }
    }


    func extendNeedForChildrenToInfinity( _ visited: [Zone]) {
        if !visited.contains(self) {
            if count == 0 {
                markForAllOfStates([.needsChildren])
            } else {
                for child in children {
                    child.extendNeedForChildrenToInfinity(visited + [self])
                }
            }
        }
    }


    func fullProgenyCountUpdate() {
        extendNeedForChildrenToInfinity([])
        gOperationsManager.children(recursiveGoal: -1) {
            self.progenyCountUpdate([])
            self.signalFor(nil, regarding: .redraw)
        }
    }


    func incrementProgenyCount(by delta: Int) {
        safeIncrementProgenyCount(by: delta, [])
    }


    func safeIncrementProgenyCount(by delta: Int, _ visited: [Zone]) {
        if !visited.contains(self) {
            var increment = delta

            if  increment >= 0 && (zoneProgeny == nil || progenyCount + increment < count + 1) {
                increment += 1
            }

            if  increment != 0 {
                progenyCount += increment
                // report("\(increment) \(zoneName ?? "---")")

                if !isRoot && !isRootOfFavorites {
                    if parentZone != nil {
                        parentZone?.safeIncrementProgenyCount(by: increment, visited + [self])
                    } else if record != nil && !isDeleted {
                        needParent()

                        gOperationsManager.parent {
                            self.parentZone?.safeIncrementProgenyCount(by: increment, visited + [self])
                        }
                    }
                }
            }
        }
    }


    // MARK:- siblings
    // MARK:-


    private func hasAnyZonesAbove(_ iAbove: Bool) -> Bool {
        return safeHasAnyZonesAbove(iAbove, [])
    }


    private func safeHasAnyZonesAbove(_ iAbove: Bool, _ visited: [Zone]) -> Bool {
        if self != gHere && !visited.contains(self) {
            if !hasZoneAbove(iAbove), let parent = parentZone {
                return parent.safeHasAnyZonesAbove(iAbove, visited + [self])
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
        if count == 0 && exposeChildren && !isMarkedForAnyOfStates([.needsProgeny]) {
            needChildren()
        }
    }


    func displayChildren() { showChildren = true  }
    func    hideChildren() { showChildren = false }


    @discardableResult func addChild(_ child: Zone?) -> Int? {
        return addChild(child, at: 0)
    }


    @discardableResult func addChild(_ iChild: Zone?, at iIndex: Int?) -> Int? {
        if  let child = iChild {

            // make sure it's not already been added
            // NOTE: both must have a record for this to be effective

            if  let     record = child.record {
                let identifier = record.recordID.recordName

                for sibling in children {
                    if sibling.record != nil && sibling.record.recordID.recordName == identifier {
                        return children.index(of: child)
                    }
                }
            }

            var insertAt = iIndex

            if  let index = iIndex, index >= 0, index < count {
                children.insert(child, at: index)
            } else {
                insertAt = count

                children.append(child)
            }

            child.parentZone  = self
            hasChildren       = true
            fetchableChildren = count

            child.updateLevel()

            return insertAt
        }

        return nil
    }


    var progenyCountIncrement: Int {
        var  increment = 0

        for child in children {
            increment += child.progenyCountIncrement
        }

        return increment
    }


    func addAndReorderChild(_ iChild: Zone?, at iIndex: Int?) {
        if  let child = iChild, addChild(child, at: iIndex) != nil {
            if  child.zoneProgeny == nil {
                child.incrementProgenyCount(by: 0)
            } else {
                incrementProgenyCount(by: child.progenyCount)
            }

            updateOrdering()
        }
    }


    @discardableResult func removeChild(_ child: Zone?) -> Bool {
        if child != nil, let index = children.index(of: child!) {
            children.remove(at: index)

            hasChildren       = count > 0
            fetchableChildren = count

            return true
        }

        return false
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
        let        zone = super.deepCopy()
        zone.parentZone = nil

        if progenyCount == 0 {
            zone.progenyCount = 1
        }

        for child in children {
            let newChild = child.deepCopy()
            zone.addChild(newChild)
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


    @discardableResult func traverseApply(_ block: ZoneToStatusClosure) -> ZTraverseStatus {
        return safeTraverseApply(block, visited: [])
    }


    @discardableResult func safeTraverseApply(_ block: ZoneToStatusClosure, visited: [Zone]) -> ZTraverseStatus {
        var status = block(self)

        if status == .eDescend {
            for child in children {
                if visited.contains(self) {
                    status = .eStop

                    break
                }

                status = child.safeTraverseApply(block, visited: visited + [self])

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


    func isDescendantOf(_ iZone: Zone?) -> ZCycleType {
        var flag: ZCycleType = .none

        if  let babyZone = iZone {
            let detector = babyZone.cycleDetectorArray

            if babyZone == self {
                if detector.count > 0 {
                    flag = .found
                }
            } else if detector.contains(self) {
                flag = .cycle
            } else if let parent = parentZone {
                babyZone.cycleDetectorArray.append(self)

                return parent.isDescendantOf(babyZone) // continue with parent
            }
            
            babyZone.cycleDetectorArray.removeAll()
        }

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
