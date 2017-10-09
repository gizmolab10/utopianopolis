 //
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class Zone : ZRecord {


    dynamic var           parent: CKReference?
    dynamic var         zoneName:      String?
    dynamic var         zoneLink:      String?
    dynamic var        zoneColor:      String?
    dynamic var        zoneOrder:    NSNumber?
    dynamic var        zoneCount:    NSNumber?
    dynamic var      zoneProgeny:    NSNumber?
    dynamic var zoneShowChildren:    NSNumber?
    var              _parentZone:        Zone?
    var                   _color:      ZColor?
    var               _crossLink:     ZRecord?
    var                 children      = [Zone] ()
    var                    count:          Int { return children.count }
    var                   widget:  ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var            unwrappedName:       String { return zoneName ?? "empty" }
    var            decoratedName:       String { return "\(unwrappedName)\(decoration)" }
    var         grabbedTextColor:       ZColor { return color.darker(by: 1.8) }
    var        isRootOfFavorites:         Bool { return record != nil && record.recordID.recordName == favoritesRootNameKey }
    var       hasMissingChildren:         Bool { return count < fetchableCount }
    var            isInFavorites:         Bool { return isRootOfFavorites || parentZone?.isRootOfFavorites ?? false }
    var            hasZonesBelow:         Bool { return hasAnyZonesAbove(false) }
    var            hasZonesAbove:         Bool { return hasAnyZonesAbove(true) }
    var             showChildren:         Bool { return isRootOfFavorites || gManifest.showsChildren(self) }
    var              isTrashRoot:         Bool { return zoneName == trashNameKey }
    var               isBookmark:         Bool { return crossLink != nil }
    var               isSelected:         Bool { return gSelectionManager.isSelected(self) }
    var                isGrabbed:         Bool { return gSelectionManager .isGrabbed(self) }
    var                isDeleted:         Bool { return gTrash != self && gTrash?.spawned(self) ?? false }
    var                 hasColor:         Bool { return zoneColor != nil }


    var decoration: String {
        var d = ""

        if isDeleted {
            d.append("D")
        }

        if isInFavorites {
            d.append("F")
        }

        if isBookmark {
            d.append("B")
        }

        if  fetchableCount != 0 {
            let s  = d == "" ? "" : " "
            let c  = s + "\(fetchableCount)"

            d.append(c)
        }

        if  d != "" {
            d  = "  (\(d))"
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
                #keyPath(zoneProgeny),
                #keyPath(zoneShowChildren)]
    }


    convenience init(favorite named: String) {
        self.init(record: nil, storageMode: .favoritesMode)

        self .zoneName = named

        FOREGROUND(after: 0.5) {
            self.crossLink = gFavoritesManager.rootZone
        }
    }
    

    var bookmarkTarget: Zone? {
        if  let link = crossLink, let mode = link.storageMode {
            return gRemoteStoresManager.cloudManagerFor(mode).zoneForRecordID(link.record.recordID)
        }

        return nil
    }


    var level: Int {
        get {
            if  !isRoot, !isRootOfFavorites, let p = parentZone, p != self {
                return p.level + 1
            }

            return 0
        }
    }


    var color: ZColor {
        get {
            if _color == nil {
                if isBookmark {
                    return bookmarkTarget?.color ?? gDefaultZoneColor
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
                if  zoneLink == trashLink {
                    return gTrash
                }

                if  link.contains("Optional(") { // repair consequences of an old, but now fixed, bookmark bug
                    zoneLink = link.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
                }

                link                       = zoneLink!
                var components:   [String] = link.components(separatedBy: ":")
                let name:          String  = components[2] == "" ? "root" : components[2]
                let identifier: CKRecordID = CKRecordID(recordName: name)
                let record:       CKRecord = CKRecord(recordType: zoneTypeKey, recordID: identifier)
                let               rawValue = components[0]
                let mode:    ZStorageMode? = rawValue == "" ? gStorageMode : ZStorageMode(rawValue: rawValue)

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


    var fetchableCount: Int {
        get {
            if isBookmark || isInFavorites {
                return bookmarkTarget?.fetchableCount ?? 0
            } else if zoneCount == nil {
                updateClassProperties()

                if zoneCount == nil {
                    zoneCount = NSNumber(value: 0)
                }
            }

            return zoneCount!.intValue
        }

        set {
            if  newValue != fetchableCount && !isBookmark && !isInFavorites {
                zoneCount = NSNumber(value: newValue)
            }
        }
    }
    

    var progenyCount: Int {
        get {
            if  zoneProgeny == nil {
                updateClassProperties()

                if  zoneProgeny == nil {
                    zoneProgeny = NSNumber(value: 0)
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


    var lowestExposed: Int? { return exposed(upTo: highestExposed) }


    var highestExposed: Int {
        var highest = level

        traverseProgeny { iZone -> ZTraverseStatus in
            let traverseLevel = iZone.level

            if  highest < traverseLevel {
                highest = traverseLevel
            }

            return iZone.showChildren ? .eContinue : .eSkip
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


    // MARK:- convenience
    // MARK:-


    func addToPaste() { gSelectionManager.pasteableZones[self] = (parentZone, siblingIndex) }
    func  addToGrab() { gSelectionManager.addToGrab(self) }
    func     ungrab() { gSelectionManager   .ungrab(self) }
    func       grab() { gSelectionManager     .grab(self) }
    func       edit() { gSelectionManager     .edit(self) }
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
        var    isComplete = false
        var parent: Zone? = nil

        traverseAllAncestors { iZone in
            let  isReciprocal = parent == nil  || iZone.children.contains(parent!)

            if  (isReciprocal && iZone.isRoot) || (toColor && iZone.hasColor) {
                isComplete = true
            }

            parent = iZone
        }

        return isComplete
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
        if showChildren && hasMissingChildren {
            needProgeny()
        }
    }
    

    func maybeNeedChildren() {
        if  showChildren && hasMissingChildren && !isMarkedForAnyOfStates([.needsProgeny]) {
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


    func displayChildren() { gManifest.displayChildren(in: self) }
    func    hideChildren() { gManifest   .hideChildren(in: self) }


    @discardableResult func add(_ child: Zone?) -> Int? {
        return add(child, at: 0)
    }


    func addAndReorderChild(_ iChild: Zone?, at iIndex: Int?) {
        if  let child = iChild,
            add(child, at: iIndex) != nil {

            children.updateOrdering()
        }
    }


    func validIndex(from iIndex: Int?) -> Int {
        var insertAt = iIndex

        if  let index = iIndex, index < count {
            if index < 0 {
                insertAt = 0
            }
        } else {
            insertAt = count
        }

        return insertAt!
    }


    @discardableResult func add(_ iChild: Zone?, at iIndex: Int?) -> Int? {
        if let child = iChild {
            let insertAt = validIndex(from: iIndex)

            // make sure it's not already been added
            // NOTE: both must have a record for this to be effective

            if  let     record = child.record {
                let identifier = record.recordID.recordName

                for sibling in children {
                    if sibling.record != nil && sibling.record.recordID.recordName == identifier {
                        if  let oldIndex = children.index(of: child) {
                            if  oldIndex == iIndex {
                                return oldIndex
                            } else {
                                let newIndex = insertAt < count ? insertAt : count - 1
                                moveChildIndex(from: oldIndex, to: newIndex)

                                return newIndex
                            }
                        }
                    }
                }
            }

            if  insertAt < count {
                children.insert(child, at: insertAt)
            } else {
                children.append(child)
            }

            child.parentZone   = self

            needCount()

            // self.columnarReport(" ADDED", child.decoratedName)

            return insertAt
        }

        return nil
    }


    @discardableResult func removeChild(_ iChild: Zone?) -> Bool {
        if  let child = iChild, let index = children.index(of: child) {
            children.remove(at: index)

            needCount()

            return true
        }

        return false
    }


    @discardableResult func moveChildIndex(from: Int, to: Int) -> Bool {
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


    func containsCKRecord(_ iCKRecord: CKRecord) -> Bool {
        let      identifier = iCKRecord.recordID
        var           found = false

        for child in children {
            if  let childID = child.record?.recordID, childID == identifier {
                found       = true
            }
        }

        return found
    }


    @discardableResult func addCKRecord(_ iCKRecord: CKRecord) -> Zone? {
        if containsCKRecord(iCKRecord) {
            return nil
        }

        let child = gCloudManager.zoneForRecord(iCKRecord)

        add(child)
        children.updateOrdering()

        return child
    }


    func hasChildMatchingRecordName(of iChild: Zone) -> Bool {
        let    name  = iChild.record.recordID.recordName

        for child in children {
            if name ==  child.record.recordID.recordName {
                return true
            }
        }

        return false
    }

    // MARK:- progeny counts
    // MARK:-


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


    func fullUpdateProgenyCount() {
        safeUpdateProgenyCount([])
        fastUpdateProgenyCount()
    }


    func safeUpdateProgenyCount(_ iMissing: [Zone]) {
        if !iMissing.contains(self) && count != 0 {
            let missing = iMissing + [self]
            var counter = 0

            for child in children {
                if !child.isBookmark {
                    child.safeUpdateProgenyCount(missing)

                    counter += child.fetchableCount + child.progenyCount
                }
            }

            progenyCount = counter
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
        if  count == 0 {
            return nil
        }

        var   exposedLevel  = level

        while exposedLevel <= highestLevel {
            let progeny = exposedProgeny(at: exposedLevel + 1)

            if  progeny.count == 0 {
                return exposedLevel
            }

            exposedLevel += 1

            for child: Zone in progeny {
                if  !child.showChildren && child.fetchableCount > 0 {
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
        // if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

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
