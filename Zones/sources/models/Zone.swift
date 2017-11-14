 //
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


 enum ZoneAccess: Int {
    case eProgenyReadOnly
    case eProgenyWritable
    case eRecurse
 }


class Zone : ZRecord {


    dynamic var                 parent: CKReference?
    dynamic var               zoneName:      String?
    dynamic var               zoneLink:      String?
    dynamic var              zoneColor:      String?
    dynamic var              zoneOwner: CKReference?
    dynamic var              zoneOrder:    NSNumber?
    dynamic var              zoneCount:    NSNumber?
    dynamic var            zoneProgeny:    NSNumber?
    dynamic var      zoneProgenyAccess:    NSNumber?
    dynamic var         zoneParentLink:      String?
    var                    _parentZone:        Zone?
    var                         _color:      ZColor?
    var                     _crossLink:     ZRecord?
    var                       children  =     [Zone] ()
    var                          count:          Int { return children.count }
    var                         widget:  ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var                  unwrappedName:       String { return zoneName ?? "empty" }
    var                  decoratedName:       String { return "\(unwrappedName)\(decoration)" }
    var               grabbedTextColor:       ZColor { return color.darker(by: 3.0) }
    var              isCurrentFavorite:         Bool { return self == gFavoritesManager.currentFavorite }
    var              isRootOfFavorites:         Bool { return record != nil && record.recordID.recordName == gFavoriteRootNameKey }
    var             hasMissingChildren:         Bool { return count < fetchableCount }
    var            hasAccessDecoration:         Bool { return  !isWritable || directReadOnly }
    var             showAccessChanging:         Bool { return !isWritable && directWritable }
    var              isWritableByUseer:         Bool { return isWritable || gOnboardingManager.userHasAccess(self) }
    var               accessIsChanging:         Bool { return (!isWritable && directWritable) || (isWritable && directReadOnly) || isRootOfFavorites }
    var                directRecursive:         Bool { return directAccess == nil ? true  : directAccess! == .eRecurse }
    var                 directWritable:         Bool { return directAccess == nil ? false : directAccess! == .eProgenyWritable }
    var                 directReadOnly:         Bool { return directAccess == nil ? false : directAccess! == .eProgenyReadOnly }
    var                  isInFavorites:         Bool { return isRootOfFavorites || (self != parentZone && parentZone?.isInFavorites ?? false) }
    var                  hasZonesBelow:         Bool { return hasAnyZonesAbove(false) }
    var                  hasZonesAbove:         Bool { return hasAnyZonesAbove(true) }
    var                   showChildren:         Bool { return isRootOfFavorites || gManifest.showsChildren(self) }
    var                    isTrashRoot:         Bool { return zoneName == gTrashNameKey }
    var                     isBookmark:         Bool { return crossLink != nil }
    var                     isSelected:         Bool { return gSelectionManager.isSelected(self) }
    var                      isInTrash:         Bool { return parentZone?.isTrashRoot ?? false }
    var                      isGrabbed:         Bool { return gSelectionManager .isGrabbed(self) }
    var                      isVisible:         Bool { return !isRootOfFavorites && (isOSX || self != gHere) }
    var                      isDeleted:         Bool { return gTrash != self && gTrash?.spawned(self) ?? false }
    var                       hasColor:         Bool { return zoneColor != nil && zoneColor != "" }


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

        if let link  = zoneLink {
            if link != gNullLink {
                d.append("L")
            } else {
                d.append("-")
            }
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
                #keyPath(zoneLink),
                #keyPath(zoneName),
                #keyPath(zoneColor),
                #keyPath(zoneCount),
                #keyPath(zoneOrder),
                #keyPath(zoneOwner),
                #keyPath(zoneProgeny),
                #keyPath(zoneParentLink),
                #keyPath(zoneProgenyAccess)]
    }


    convenience init(storageMode: ZStorageMode?) {
        self.init(record: CKRecord(recordType: gZoneTypeKey), storageMode: storageMode)
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
                } else if let p = parentZone, p != self, hasCompleteAncestorPath(toColor: true) {
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


    func zone(from link: String) -> Zone? {
        if link == gNullLink { return nil }

        var components:   [String] = link.components(separatedBy: ":")
        let name:          String  = components[2] == "" ? "root" : components[2]
        let identifier: CKRecordID = CKRecordID(recordName: name)
        let record:       CKRecord = CKRecord(recordType: gZoneTypeKey, recordID: identifier)
        let                rawMode = components[0]
        let mode:    ZStorageMode? = rawMode == "" ? gStorageMode : ZStorageMode(rawValue: rawMode)
        let                manager = mode == nil ? nil : gRemoteStoresManager.recordsManagerFor(mode!)
        let                   zone = manager?.zoneForRecordID(identifier)

        return zone != nil ? zone! : Zone(record: record, storageMode: mode)
    }


    var crossLink: ZRecord? {
        get {
            if _crossLink == nil, let link = zoneLink, link != "" {
                if  zoneLink == gTrashLink {
                    return gTrash
                }

                if  link.contains("Optional(") { // repair consequences of an old, but now fixed, bookmark bug
                    zoneLink = link.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
                }

                _crossLink = zone(from: link)
            }

            return _crossLink
        }

        set {
            if newValue == nil {
                zoneLink = gNullLink
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
                updateInstanceProperties()

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


    var ownerID: CKRecordID? {
        get {
            if let owner = zoneOwner {
                return owner.recordID
            } else if let t = bookmarkTarget {
                return t.ownerID
            } else if let p = parentZone {
                return p.ownerID
            } else {
                return nil
            }
        }

        set {
            zoneOwner = (newValue == nil) ? nil : CKReference(recordID: newValue!, action: .none)
        }
    }


    var fetchableCount: Int {
        get {
            if  let    t = bookmarkTarget {
                return t.fetchableCount
            } else if zoneCount == nil {
                updateInstanceProperties()

                if  zoneCount == nil {
                    zoneCount = NSNumber(value: count)
                }
            }

            return zoneCount!.intValue
        }

        set {
            if  newValue != fetchableCount && !isBookmark {
                zoneCount = NSNumber(value: newValue)
            }
        }
    }
    

    var progenyCount: Int {
        get {
            if  zoneProgeny == nil {
                updateInstanceProperties()

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
            if  let p = _parentZone {
                if  parent == nil, p.storageMode == storageMode, let record = p.record {
                    parent  = CKReference(record: record, action: .none)
                }
            } else {
                if  let  reference = parent, let mode = storageMode {
                    _parentZone    = gRemoteStoresManager.cloudManagerFor(mode).zoneForReference(reference)
                } else if let link = zoneParentLink {
                    _parentZone    = zone(from: link)
                }
            }

            return _parentZone
        }

        set {
            zoneParentLink = gNullLink
            _parentZone    = newValue
            parent         = nil

            if  let  parentRecord  = newValue?.record,
                let       newMode  = newValue?.storageMode {
                if        newMode == storageMode {
                    parent         = CKReference(record: parentRecord, action: .none)
                } else {
                    zoneParentLink = "\(newMode.rawValue)::\(parentRecord.recordID.recordName)"
                }
            }
        }
    }


    var siblingIndex: Int? {
        if let siblings = parentZone?.children, let index = siblings.index(of: self) {
            return index
        }

        return nil
    }


    // MARK:- write access
    // MARK:-


    var directAccess: ZoneAccess? {
        if  isBookmark {
            return bookmarkTarget?.directAccess
        } else if let value = zoneProgenyAccess?.intValue,
            value          <= ZoneAccess.eRecurse.rawValue,
            value          >= 0 {
            return ZoneAccess(rawValue: value)
        }

        return nil
    }


    var ancestralProgenyAccess: ZoneAccess {
        get {
            if  isTrashRoot {
                return .eProgenyWritable
            } else if let t = bookmarkTarget {
                return t.ancestralProgenyAccess // go up bookmark target's (NOT bookmark's) ancestor path
            } else if  directAccess != .eRecurse {
                return directWritable ? .eProgenyWritable : .eProgenyReadOnly
            } else if let p = parentZone, p != self, p.hasCompleteAncestorPath(toWritable: true) {
                return p.ancestralProgenyAccess // go further up ancestor path
            }

            return .eProgenyReadOnly
        }

        set {
            if  zoneProgenyAccess?.intValue != newValue.rawValue {
                zoneProgenyAccess            = NSNumber(value: newValue.rawValue)

                needFlush()
            }
        }
    }


    var isWritable: Bool {
        if  isTrashRoot {
            return true
        } else if let t  = bookmarkTarget {
            return    t.isWritable
        } else if let p  = parentZone, p != self {
            return    p.ancestralProgenyAccess == .eProgenyWritable  // go up ancestor path
        } else if let a  = zoneProgenyAccess?.intValue {    // root or orphan
            return    a == ZoneAccess.eProgenyWritable.rawValue
        }

        return false
    }


    func toggleWritable() {
        if  let t = bookmarkTarget {
            t.toggleWritable()
        } else if isTrashRoot {
            ancestralProgenyAccess     = .eProgenyWritable
        } else if isWritableByUseer {
            ownerID                    = nil

            if  !directRecursive, accessIsChanging, let p = parentZone, (p.accessIsChanging || (!p.directReadOnly && p.isWritable == isWritable)) {
                ancestralProgenyAccess = .eRecurse
            } else if !isWritable {
                ancestralProgenyAccess = .eProgenyWritable
            } else {
                ancestralProgenyAccess = .eProgenyReadOnly
                if let name = gUserRecordID {
                    ownerID            = CKRecordID(recordName: name)
                }
            }

            needFlush()
        }
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


    override func setupLinks() {
        if  record != nil {
            var dirty = false

            if  let    link  = zoneLink {
                if     link == "" {
                    zoneLink = gNullLink
                    dirty    = true
                }
            } else {
                zoneLink = gNullLink
                dirty    = true
            }

            if  zoneParentLink == nil {
                zoneParentLink  = gNullLink
                dirty           = true
            }

            if  dirty {
                needFlush()
            }
        }
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
        updateRecordProperties()
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


    func hasCompleteAncestorPath(toColor: Bool = false, toWritable: Bool = false) -> Bool {
        var    isComplete = false
        var parent: Zone? = nil

        traverseAllAncestors { iZone in
            let  isReciprocal = parent == nil  || iZone.children.contains(parent!)

            if  (isReciprocal && iZone.isRoot) || (toColor && iZone.hasColor) || (toWritable && !iZone.directRecursive) {
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
            needRoot()
        }
    }


    func maybeNeedColor() {
        if !hasCompleteAncestorPath(toColor: true) {
            needColor()
        }
    }


    func maybeNeedWritable() {
        if !hasCompleteAncestorPath(toWritable: true) {
            needWritable()
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


    func prepareForArrival() {
        grab()
        needChildren()
        maybeNeedRoot()
        maybeNeedColor()
        displayChildren()
        maybeNeedWritable()
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
        if  let    child = iChild, child != child.parentZone {
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

            child.parentZone = self

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


    func recursivelyApplyMode() {
        let copy = parentZone?.storageMode != storageMode

        traverseAllProgeny { iChild in
            if  copy {
                iChild .record = CKRecord(recordType: gZoneTypeKey)
            }

            if  let              p = iChild.parentZone {
                iChild.storageMode = p.storageMode

                if  iChild .parent?.recordID.recordName != p.record.recordID.recordName {
                    iChild .parent = CKReference(record: p.record, action: .none)
                }
            }

            iChild.needFlush() // so will be noted in new mode's record manager
            iChild.updateRecordProperties() // in case new ckrecord is created, above
        }
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
            gDBOperationsManager.children(.restore) {
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
        let theCopy = Zone(storageMode: storageMode)

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
        if let string = dict[    gZoneNameKey] as!   String? { zoneName     = string }
        // if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

        if let childrenStore: [ZStorageDict] = dict[gChildrenKey] as! [ZStorageDict]? {
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
        dict[gZoneNameKey]     = zoneName as NSObject?
        dict[gShowChildrenKey]  = NSNumber(booleanLiteral: showChildren)


        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[gChildrenKey]      = childrenStore as NSObject?

        return dict
    }
}
