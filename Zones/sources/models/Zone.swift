 //
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


 enum ZIntegerState: Int {
    case showChildren = 0
    case   isUpToDate = 10
    case   isFavorite = 29
    case    isDeleted = 30
 }
 

struct ZoneState: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let ShowsChildren = ZoneState(rawValue: 1 << ZIntegerState.showChildren.rawValue)
    static let    IsUpToDate = ZoneState(rawValue: 1 << ZIntegerState.isUpToDate  .rawValue)
    static let    IsFavorite = ZoneState(rawValue: 1 << ZIntegerState.isFavorite  .rawValue)
    static let     IsDeleted = ZoneState(rawValue: 1 << ZIntegerState.isDeleted   .rawValue)

    var decoration: String {
        if  let    raw = ZIntegerState(rawValue: Int(log2(Double(rawValue as Int) + 0.5))) {
            switch raw {
            case .isFavorite: return "  (F)"
            case .isDeleted:  return "  (D)"
            default:          break
            }
        }

        return ""
    }
}


class Zone : ZRecord {


    dynamic var      parent: CKReference?
    dynamic var    zoneName:      String?
    dynamic var    zoneLink:      String?
    dynamic var   zoneColor:      String?
    dynamic var   zoneOrder:    NSNumber?
    dynamic var   zoneCount:    NSNumber?
    dynamic var   zoneState:    NSNumber?
    dynamic var   zoneLevel:    NSNumber?
    dynamic var zoneProgeny:    NSNumber?
    var         _parentZone:        Zone?
    var              _color:      ZColor?
    var          _crossLink:     ZRecord?
    var            children      = [Zone] ()
    var               count:          Int { return children.count }
    var              widget:  ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var       unwrappedName:       String { return zoneName ?? "empty" }
    var       decoratedName:       String { return "\(unwrappedName)\(decoration)" }
    var    grabbedTextColor:       ZColor { return color.darker(by: 1.8) }
    var   isRootOfFavorites:         Bool { return record != nil && record.recordID.recordName == favoritesRootNameKey }
    var  hasMissingChildren:         Bool { return count < fetchableCount }
    var   canRevealChildren:         Bool { return hasChildren &&   showChildren }
    var    indicateChildren:         Bool { return hasChildren && (!showChildren || count == 0) }
    var       hasZonesBelow:         Bool { return hasAnyZonesAbove(false) }
    var       hasZonesAbove:         Bool { return hasAnyZonesAbove(true) }
    var         hasChildren:         Bool { return fetchableCount > 0 }
    var          isBookmark:         Bool { return crossLink != nil }
    var          isSelected:         Bool { return gSelectionManager.isSelected(self) }
    var           isEditing:         Bool { return gSelectionManager .isEditing(self) }
    var           isGrabbed:         Bool { return gSelectionManager .isGrabbed(self) }
    var            hasColor:         Bool { return _color != nil }
    var           isDeleted:         Bool { get { return getValue(for:     .IsDeleted) } set { setValue(newValue, for: .IsDeleted) } }
    var          isUpToDate:         Bool { get { return getValue(for:    .IsUpToDate) } set { setValue(newValue, for: .IsUpToDate) } }
    var          isFavorite:         Bool { get { return getValue(for:    .IsFavorite) } set { setValue(newValue, for: .IsFavorite) } }
    var        showChildren:         Bool { get { return getValue(for: .ShowsChildren) } set { setValue(newValue, for: .ShowsChildren) } }


    var decoration: String {
        var d = state.decoration

        if  d == "" {
            if isBookmark {
                d = "  (B)"
            } else if fetchableCount != 0 {
                d = "  (\(fetchableCount))"
            }
        }

        return d
    }


    // MARK:- properties
    // MARK:-


    class func cloudProperties() -> [String] {
        return [#keyPath(parent),
                #keyPath(zoneName),
                #keyPath(zoneLink),
                #keyPath(zoneColor),
                #keyPath(zoneOrder),
                #keyPath(zoneCount),
                #keyPath(zoneState),
                #keyPath(zoneLevel),
                #keyPath(zoneProgeny)]
    }


    convenience init(favoriteNamed: String) {
        self.init(record: nil, storageMode: .favorites)

        self .zoneName = favoriteNamed
        self.crossLink = gFavoritesManager.rootZone
    }
    

    var bookmarkTarget: Zone? {
        if  let link = crossLink, let mode = link.storageMode {
            return gRemoteStoresManager.cloudManagerFor(mode).zoneForRecordID(link.record.recordID)
        }

        return nil
    }


    var color: ZColor {
        get {
            if _color == nil {
                if isRootOfFavorites || isBookmark {
                    return gBookmarkColor
                } else if let z = zoneColor, z != "" {
                    _color      = z.color
                } else if let p = parentZone, hasCompleteAncestorPath(toColor: true) {
                    return p.color
                } else {
                    return gDefaultZoneColor
                }
            }

            return _color!
        }

        set {
            if  _color   != newValue {
                _color    = newValue
                zoneColor = newValue.string

                needFlush()
            }
        }
    }


    var crossLink: ZRecord? {
        get {
            if _crossLink == nil, var link = zoneLink, link != "" {
                if  link.contains("Optional(") { // repair consequences of an old, but now fixed, bookmark bug
                    zoneLink = link.replacingOccurrences(of: "Optional(\"", with: "")
                    zoneLink = link.replacingOccurrences(of:         "\")", with: "")
                    link     = zoneLink!
                }

                let components:   [String] = link.components(separatedBy: ":")
                let name:          String  = components[2] == "" ? "root" : components[2]
                let identifier: CKRecordID = CKRecordID(recordName: name)
                let record:       CKRecord = CKRecord(recordType: zoneTypeKey, recordID: identifier)
                let mode:    ZStorageMode? = ZStorageMode(rawValue: components[0])

                _crossLink = ZRecord(record: record, storageMode: mode)
            }

            return _crossLink
        }

        set {
            if newValue == nil {
                zoneLink = nil
            } else {
                let    hasRef = newValue!.record != nil
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


    var fetchableCount: Int {
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
            if  newValue != fetchableCount && !isBookmark {
                zoneCount = NSNumber(value: newValue)
            }

            for bookmark in gRemoteStoresManager.bookmarksFor(self) {
                bookmark.zoneCount = NSNumber(value: newValue)
            }
        }
    }
    

    var progenyCount: Int {
        get {
            if  zoneProgeny == nil {
                updateClassProperties()

                if  zoneProgeny == nil {
                    zoneProgeny = NSNumber(value: count + 1)
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

        traverseProgeny { iZone -> ZTraverseStatus in
            let traverseLevel = iZone.level

            if  highest < traverseLevel {
                highest = traverseLevel
            }

            return iZone.canRevealChildren ? .eContinue : .eSkip
        }

        return highest
    }


    var parentZone: Zone? {
        get {
            if  parent == nil && _parentZone?.record != nil {
                parent  = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if  parent != nil && _parentZone == nil && storageMode != nil {
                _parentZone = gRemoteStoresManager.cloudManagerFor(storageMode!).zoneForReference(parent!)
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


    func getValue(for iState: ZoneState) -> Bool {
        return state.contains(iState)

    }


    func setValue(_ iValue: Bool, for iState: ZoneState) {
        if     iValue != getValue(for: iState) {
            if iValue {
                state.insert(iState)
            } else {
                state.remove(iState)
            }
        }
    }

    
    // MARK:- convenience
    // MARK:-


    func addToGrab() { gSelectionManager.addToGrab(self) }
    func    ungrab() { gSelectionManager   .ungrab(self) }
    func      grab() { gSelectionManager     .grab(self) }
    func      edit() { gSelectionManager     .edit(self) }
    override func register() { cloudManager?.registerZone(self) }


    override func debug(_  iMessage: String) {
        note("\(iMessage) children \(count) parent \(parent != nil) isDeleted \(isDeleted) mode \(storageMode!) \(unwrappedName)")
    }


    func editAndSelect(in range: NSRange) {
        edit()
        FOREGROUND {
            self.widget?.textWidget.selectCharacter(in: range)
        }
    }


    func orphan() {
        parentZone?.removeChild(self)

        parentZone = nil

        needFlush()
        updateCloudProperties()
    }


    func clearColor() {
        zoneColor = ""
        _color    = nil

        needFlush()
    }


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


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    // MARK:- traverse ancestors
    // MARK:-


    func hasCompleteAncestorPath(toColor: Bool = false) -> Bool {
        var isSafe = false

        traverseAllAncestors { iZone in
            if  iZone.isRoot || (toColor && iZone.hasColor) {
                isSafe = true
            }
        }

        return isSafe
    }


    func isABookmark(spawnedBy zone: Zone) -> Bool {
        if  let        link = crossLink, let mode = link.storageMode {
            var     probeID = link.record.recordID as CKRecordID?
            let  identifier = zone.record.recordID.recordName
            var     visited = [String] ()

            while let probe = probeID?.recordName, !visited.contains(probe) {
                visited.append(probe)

                if probe == identifier {
                    return true
                }

                let zone = gRemoteStoresManager.recordsManagerFor(mode).zoneForRecordID(probeID)
                probeID  = zone?.parent?.recordID
            }
        }

        return false
    }


    func wasSpawnedByAGrab() -> Bool {
        let               grabbed = gSelectionManager.currentGrabs
        var wasSpawned:      Bool = grabbed.contains(self)
        if !wasSpawned, let pZone = parentZone {
            pZone.traverseAncestors { iAncestor -> ZTraverseStatus in
                if grabbed.contains(iAncestor) {
                    wasSpawned = true

                    return .eStop
                }

                return .eContinue
            }
        }
        
        return wasSpawned
    }
    
    
    func wasSpawnedBy(_ iZone: Zone?) -> Bool {
        var wasSpawned: Bool = false

        if let zone = iZone, let pZone = parentZone {
            pZone.traverseAncestors { iAncestor -> ZTraverseStatus in
                if iAncestor == zone {
                    wasSpawned = true

                    return .eStop
                }

                return .eContinue
            }
        }

        return wasSpawned
    }


    func traverseAllAncestors(_ block: @escaping ZoneClosure) {
        safeTraverseAncestors(visited: []) { iZone -> ZTraverseStatus in
            block(iZone)

            return .eContinue
        }
    }


    func traverseAncestors(_ block: ZoneToStatusClosure) {
        safeTraverseAncestors(visited: [], block)
    }


    func safeTraverseAncestors(visited: [Zone], _ block: ZoneToStatusClosure) {
        let status  = block(self)

        if  let parent  = parentZone, !visited.contains(self), !isRoot, status == .eContinue {
            parent.safeTraverseAncestors(visited: visited + [self], block)
        }
    }


    // MARK:- traverse progeny
    // MARK:-


    func spawned(_ iChild: Zone) -> Bool {
        var isSpawn = false

        traverseProgeny { iZone -> ZTraverseStatus in
            if iZone == iChild {
                isSpawn = true

                return .eStop
            }
            
            return .eContinue
        }
        
        return isSpawn
    }


    func traverseAllProgeny(_ block: ZoneClosure) {
        safeTraverseProgeny(visited: []) { iZone -> ZTraverseStatus in
            block(iZone)

            return .eContinue
        }
    }


    @discardableResult func traverseProgeny(_ block: ZoneToStatusClosure) -> ZTraverseStatus {
        return safeTraverseProgeny(visited: [], block)
    }


    // first call block on self

    @discardableResult func safeTraverseProgeny(visited: [Zone], _ block: ZoneToStatusClosure) -> ZTraverseStatus {
        var status = block(self)

        if status == .eContinue {
            for child in children {
                if visited.contains(self) {
                    status = .eStop

                    break
                }

                status = child.safeTraverseProgeny(visited: visited + [self], block)

                if status == .eStop {
                    break
                }
            }
        }
        
        return status
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

    
    // MARK:- state
    // MARK:-


    override func maybeNeedMerge() {
        if !gFavoritesManager.defaultFavorites.children.contains(self) {
            super.maybeNeedMerge()
        }
    }


    func maybeNeedRoot() {
        if !hasCompleteAncestorPath() {
            markForAllOfStates([.needsRoot])
        }
    }



    func maybeNeedProgeny() {
        if canRevealChildren && hasMissingChildren {
            needProgeny()
        }
    }
    

    func maybeNeedChildren() {
        if  canRevealChildren && hasMissingChildren && !isMarkedForAnyOfStates([.needsProgeny]) {
            needChildren()
        }
    }


    func extendNeedForChildren(to iLevel: Int) {
        traverseProgeny { iZone -> ZTraverseStatus in
            if iLevel < iZone.level {
                return .eSkip
            } else if iZone.hasMissingChildren {
                iZone.needChildren()
            }

            return .eContinue
        }
    }


    // MARK:- children
    // MARK:-


    func displayChildren() { showChildren = true  }
    func    hideChildren() { showChildren = false }


    @discardableResult func add(_ child: Zone?) -> Int? {
        return add(child, at: 0)
    }


    func addAndReorderChild(_ iChild: Zone?, at iIndex: Int?) {
        if  let child = iChild,
            add(child, at: iIndex) != nil {

            updateOrdering()
        }
    }


    @discardableResult func add(_ iChild: Zone?, at iIndex: Int?) -> Int? {
        if  let       child = iChild {
            child.isDeleted = false

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

            child.parentZone   = self

            if  fetchableCount < count {
                fetchableCount = count
            }

            updateProgenyCount()
            child.updateLevel()

            return insertAt
        }

        return nil
    }


    @discardableResult func removeChild(_ iChild: Zone?) -> Bool {
        if  let child = iChild, let index = children.index(of: child) {
            children.remove(at: index)
            updateProgenyCount()

            fetchableCount = count

            return true
        }

        return false
    }


    @discardableResult func move(child from: Int, to: Int) -> Bool {
        var succeeded = false

        if  to < count, from < count, let child = self[from], !gFavoritesManager.defaultFavorites.children.contains(child) {
            children.remove(       at: from)
            children.insert(child, at: to)

            succeeded = true
        }

        return succeeded
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


    // MARK:- progeny counts
    // MARK:-


    func fullUpdateProgenyCount() {
        traverseAllProgeny { iZone in
            if iZone.fetchableCount == 0 {
                iZone.fastUpdateProgenyCount()
            }
        }
    }


    func fastUpdateProgenyCount() {
        self.traverseAncestors { iAncestor -> ZTraverseStatus in
            var      counter = 0

            for child in iAncestor.children {
                if !child.isBookmark {
                    counter += child.fetchableCount + child.progenyCount
                }
            }

            if counter != 0 && counter == iAncestor.progenyCount {
                return .eStop
            }

            iAncestor.progenyCount = counter

            return .eContinue
        }
    }


    func updateProgenyCount() {
        if !hasMissingChildren {
            fastUpdateProgenyCount()
        } else {
            needChildren()
            gOperationsManager.children(.restore) {
                self.fastUpdateProgenyCount()
            }
        }
    }


    // MARK:- recursion
    // MARK:-


    enum ZCycleType: Int {
        case cycle
        case found
        case none
    }


    func deepCopy() -> Zone {
        let theCopy = Zone(record: CKRecord(recordType: zoneTypeKey), storageMode: storageMode)

        copy(into: theCopy)

        theCopy.parentZone = nil

        for child in children {
            theCopy.add(child.deepCopy())
        }

        return theCopy
    }


    func deleteIntoPaste() {
        traverseAllProgeny { iZone in
            iZone.isDeleted = true

            iZone.needFlush()
        }

        gSelectionManager.pasteableZones[self] = (parentZone, siblingIndex)

        orphan()
    }


    func updateOrdering() {
        let increment = 1.0 / Double(count + 2)

        for (index, child) in children.enumerated() {
            child.order = increment * Double(index + 1)
        }
    }


    func updateLevel() {
        traverseAllProgeny { iZone in
            if let parentLevel = iZone.parentZone?.level, parentLevel != gUnlevel {
                iZone.level = parentLevel + 1
            }
        }
    }


    func exposedProgeny(at iLevel: Int) -> [Zone] {
        var     progeny = [Zone]()
        var begun: Bool = false

        traverseProgeny { iZone -> ZTraverseStatus in
            if begun {
                if iZone.level > iLevel || iZone == self {
                    return .eSkip
                } else if iZone.level == iLevel && iZone != self && (iZone.parentZone == nil || iZone.parentZone!.showChildren) {
                    progeny.append(iZone)
                }
            }

            begun = true

            return .eContinue
        }

        return progeny
    }


    func exposed(upTo highestLevel: Int) -> Int? {
        if !hasChildren {
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
                if  child.indicateChildren {
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

                add(child, at: nil)
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
