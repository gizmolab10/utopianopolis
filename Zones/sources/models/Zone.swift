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
    case eRecurse
    case eFullReadOnly
    case eChildrenWritable
    case eFullWritable
 }


class Zone : ZRecord {


    dynamic var         parent: CKReference?
    dynamic var       zoneName:      String?
    dynamic var       zoneLink:      String?
    dynamic var      zoneColor:      String?
    dynamic var      zoneOwner: CKReference?
    dynamic var      zoneOrder:    NSNumber?
    dynamic var      zoneCount:    NSNumber?
    dynamic var     zoneAccess:    NSNumber?
    dynamic var    zoneProgeny:    NSNumber?
    dynamic var zoneParentLink:      String?
    var            _parentZone:        Zone?
    var             _crossLink:     ZRecord?
    var               children =      [Zone] ()
    var                 _color:      ZColor?
    var                  count:         Int  { return children.count }
    var                 widget:  ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var               linkName:      String? { return name(from: zoneLink) }
    var          unwrappedName:      String  { return zoneName ?? "empty" }
    var          decoratedName:      String  { return "\(unwrappedName)\(decoration)" }
    var       grabbedTextColor:      ZColor  { return color.darker(by: 3.0) }
    var      isCurrentFavorite:        Bool  { return self == gFavoritesManager.currentFavorite }
    var      isRootOfFavorites:        Bool  { return record != nil && record.recordID.recordName == gFavoriteRootNameKey }
    var      onlyShowToggleDot:        Bool  { return isRootOfFavorites || (!isOSX && self == gHere) }
    var     hasMissingChildren:        Bool  { return count < fetchableCount }
    var directChildrenWritable:        Bool  { return   directAccess == .eChildrenWritable }
    var    hasAccessDecoration:        Bool  { return !isTextEditable || directChildrenWritable }
    var      isWritableByUseer:        Bool  { return  isTextEditable || gOnboardingManager.userHasAccess(self) }
    var       accessIsChanging:        Bool  { return !isTextEditable && directWritable || (isTextEditable && directReadOnly) || isRootOfFavorites }
    var       isSortableByUser:        Bool  { return ancestorAccess != .eFullReadOnly || gOnboardingManager.userHasAccess(self) }
    var        directRecursive:        Bool  { return directAccess == .eRecurse }
    var         directWritable:        Bool  { return directAccess == .eFullWritable }
    var         directReadOnly:        Bool  { return directAccess == .eFullReadOnly || directChildrenWritable }
    var          hasZonesBelow:        Bool  { return hasAnyZonesAbove(false) }
    var          hasZonesAbove:        Bool  { return hasAnyZonesAbove(true) }
    var             isBookmark:        Bool  { return crossLink != nil }
    var             isSelected:        Bool  { return gSelectionManager.isSelected(self) }
    var              isGrabbed:        Bool  { return gSelectionManager .isGrabbed(self) }
    var               hasColor:        Bool  { return zoneColor != nil && zoneColor != "" }
    var                isTrash:        Bool  { return zoneName == gTrashNameKey }


    var manifest: ZManifest? {
        if let mode = storageMode {
            return gRemoteStoresManager.manifest(for: mode)
        }

        return nil
    }


    var showChildren: Bool  {
        var show = false

        if isRootOfFavorites {
            show = true
        } else if let m = manifest {
            show    = m.showsChildren(self)
        }

        return show
    }


    var isInFavorites: Bool {
        if isRootOfFavorites { return true }

        if let p = parentZone {
            return !p.spawnedBy(self) && p.isInFavorites
        }

        return false
    }


    convenience init(storageMode: ZStorageMode?) {
        self.init(record: CKRecord(recordType: gZoneTypeKey), storageMode: storageMode)
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
                #keyPath(zoneAccess),
                #keyPath(zoneProgeny),
                #keyPath(zoneParentLink)]
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    var hasFetchedBookmark: Bool {
        if  let identifier = record?.recordID.recordName {
            for     zone in gAllZones {
                if  zone.alreadyExists, let linkName = zone.linkName {
                    if linkName == identifier {
                        return true
                    }
                }
            }
        }

        return false
    }


    var isDeleted: Bool {
        var result = false

        if !isRoot {
            traverseAllAncestors{ iParent in
                if iParent.isRoot && iParent.isTrash {
                    result = true
                }
            }
        }

        return result

    }


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


    var bookmarkTarget: Zone? {
        if  let    link = crossLink {
            return link.target as? Zone
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

                needSave()
            }
        }
    }


    var crossLink: ZRecord? {
        get {
            if _crossLink == nil {
                if  zoneLink == gTrashLink {
                    return gTrash
                }

                if  zoneLink?.contains("Optional(") ?? false { // repair consequences of an old, but now fixed, bookmark bug
                    zoneLink = zoneLink?.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
                }

                _crossLink = zone(from: zoneLink)
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
            if  let    t = bookmarkTarget {
                return t.progenyCount
            } else if  zoneProgeny == nil {
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
                } else if let zone = zone(from: zoneParentLink) {
                    _parentZone    = zone
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
        if let siblings = parentZone?.children {
            if let index = siblings.index(of: self) {
                return index
            } else {
                for (index, sibling) in siblings.enumerated() {
                    if sibling.order > order {
                        return index == 0 ? 0 : index - 1
                    }
                }
            }
        }

        return nil
    }


    // MARK:- write access
    // MARK:-


    var directAccess: ZoneAccess {
        get {
            if  isTrash || isRootOfFavorites {
                return .eChildrenWritable
            } else if  let    target = bookmarkTarget {
                return target.directAccess
            } else if let value = zoneAccess?.intValue,
                value          <= ZoneAccess.eFullWritable.rawValue,
                value          >= 0 {
                return ZoneAccess(rawValue: value)!
            }

            return .eRecurse // default value
        }

        set {
            let                 value = newValue.rawValue

            if  zoneAccess?.intValue != value {
                zoneAccess            = NSNumber(value: value)
            }
        }
    }


    var ancestorAccess: ZoneAccess {
        var      access = directAccess

        traverseAncestors { iZone -> ZTraverseStatus in
            if   iZone != self {
                access  = iZone.directAccess
            }

            return access == .eRecurse ? .eContinue : .eStop
        }

        return access
    }


    var isTextEditable: Bool {
        if let t = bookmarkTarget {
            return    t.isTextEditable
        } else if isTrash {
            return false
        } else if directWritable {
            return true
        } else if directReadOnly {
            return false
        } else if let p = parentZone {
            return p.directChildrenWritable ? true : p.isTextEditable
        }

        return true
    }


    var isMovableByUser: Bool {
        if  let p = parentZone,
            p.ancestorAccess != .eFullReadOnly,
            !directChildrenWritable,
            !directReadOnly {
            return true
        }

        return gOnboardingManager.userHasAccess(self)
    }


    var nextAccess: ZoneAccess {
        var      access = directAccess

        if isWritableByUseer {
            let ancestor = ancestorAccess
            let readOnly = ancestor == .eFullReadOnly

            if directChildrenWritable {
                access  = .eFullWritable
            } else if directWritable {
                access  = .eFullReadOnly
            } else if directReadOnly || readOnly {
                access  = .eChildrenWritable
            } else if !readOnly {
                access  = .eFullReadOnly
            }

            if  access == ancestor {
                access  = .eRecurse
            }
        }

        return access
    }


    func toggleWritable() {
        if  storageMode == .everyoneMode && !isTrash && !isRootOfFavorites {
            if  let t = bookmarkTarget {
                t.toggleWritable()
            } else if isWritableByUseer {
                if  let     name = gUserRecordID {
                    ownerID      = CKRecordID(recordName: name)
                }

                let         next = nextAccess
                let       direct = directAccess

                if  direct      != next {
                    directAccess = next

                    needSave()
                }
            }
        }
    }


    // MARK:- convenience
    // MARK:-


    func addToPaste() { gSelectionManager.pasteableZones[self] = (parentZone, siblingIndex) }
    func  addToGrab() { gSelectionManager.addToGrab(self) }
    func     ungrab() { gSelectionManager   .ungrab(self) }
    func       grab() { gSelectionManager     .grab(self) }
    func       edit() { gSelectionManager     .edit(self) }


    override func register() { cloudManager?  .registerZone(self) }
    func        unregister() { cloudManager?.unregisterZone(self) }


    override func debug(_  iMessage: String) {
        note("\(iMessage) children \(count) parent \(parent != nil) isDeleted \(isDeleted) mode \(storageMode!) \(unwrappedName)")
    }


    override func setupLinks() {
        if  record                != nil {
            let           badLinks = ["", "-", "no"]

            if  let link           = zoneLink {
                if  badLinks.contains(link) {
                    zoneLink       = gNullLink
                }
            } else {
                zoneLink           = gNullLink
            }

            if  let pLink          = zoneParentLink {
                if  badLinks.contains(pLink) {
                    zoneParentLink = gNullLink
                }
            } else {
                zoneParentLink     = gNullLink
            }
        }
    }


    func editAndSelect(in range: NSRange) {
        edit()
        FOREGROUND {
            self.widget?.textWidget.selectCharacter(in: range)
        }
    }


    override func unorphan() {
        if let p = parentZone, !p.isBookmark, !spawnedBy(p) {
            p.add(self, at: siblingIndex)
        }
    }


    func orphan() {
        parentZone?.removeChild(self)

        parentZone = nil

        needSave()
        updateRecordProperties()
    }


    func clearColor() {
        zoneColor = ""
        _color    = nil

        needSave()
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


    func spawnedByAGrab() -> Bool {
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
    
    
    func spawnedBy(_ iZone: Zone?) -> Bool {
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
        if  block(self) == .eContinue,  //        skip == stop
            !isRoot,                    //      isRoot == stop
            !visited.contains(self),    // graph cycle == stop
            let parent = parentZone {   //  nil parent == stop
            parent.safeTraverseAncestors(visited: visited + [self], block)
        }
    }


    // MARK:- traverse progeny
    // MARK:-


    var visibleWidgets: [ZoneWidget] {
        var visible = [ZoneWidget] ()

        traverseProgeny { iZone -> ZTraverseStatus in
            if let w = iZone.widget {
                visible.append(w)
            }

            return iZone.showChildren ? .eContinue : .eSkip
        }

        return visible
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
        if  showChildren && hasMissingChildren {
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
            } else {
                iZone.needChildren()
            }

            return .eContinue
        }
    }


    // MARK:- children
    // MARK:-


    func displayChildren() { manifest?.displayChildren(in: self) }
    func    hideChildren() { manifest?   .hideChildren(in: self) }


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

            child.needSave()
            needSave()
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

            iChild.needSave() // so will be noted in new mode's record manager
            iChild.updateRecordProperties() // in case new ckrecord is created, above
        }
    }


    @discardableResult func moveChildIndex(from: Int, to: Int) -> Bool {
        if  to < count, from < count, let child = self[from] {
            children.remove(       at: from)
            children.insert(child, at: to)

            return true
        }

        return false
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
