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
    case eDefaultName
 }


class Zone : ZRecord {


    dynamic var         parent: CKReference?
    dynamic var       zoneName:       String?
    dynamic var       zoneLink:       String?
    dynamic var      zoneColor:       String?
    dynamic var      zoneOwner:  CKReference?
    dynamic var      zoneOrder:     NSNumber?
    dynamic var      zoneCount:     NSNumber?
    dynamic var     zoneAccess:     NSNumber?
    dynamic var     parentLink:       String?
    dynamic var    zoneProgeny:     NSNumber?
    var            _parentZone:         Zone?
    var             _hyperLink:       String?
    var             _crossLink:      ZRecord?
    var                 _color:       ZColor?
    var                 _email:       String?
    var               children =                [Zone] ()
    var                 traits = [ZTraitType : ZTrait] ()
    var                  count:          Int  { return children.count }
    var                 widget:   ZoneWidget? { return gWidgetsManager.widgetForZone(self) }
    var               linkName:       String? { return name(from: zoneLink) }
    var               linkMode: ZStorageMode? { return mode(from: zoneLink) }
    var          unwrappedName:       String  { return zoneName ?? kNoName }
    var          decoratedName:       String  { return decoration + unwrappedName }
    var       fetchedBookmarks:       [Zone]  { return gBookmarksManager.bookmarks(for: self) ?? [] }
    var       grabbedTextColor:       ZColor  { return color.darker(by: 3.0) }
    var directChildrenWritable:         Bool  { return directAccess == .eChildrenWritable || directAccess == .eDefaultName }
    var    hasAccessDecoration:         Bool  { return !isTextEditable || directChildrenWritable }
    var      onlyShowToggleDot:         Bool  { return (isRootOfFavorites && !(widget?.isInMain ?? true)) || (kIsPhone && self == gHere) }
    var      isWritableByUseer:         Bool  { return isTextEditable || userHasAccess }
    var      isCurrentFavorite:         Bool  { return self == gFavoritesManager.currentFavorite }
    var       accessIsChanging:         Bool  { return !isTextEditable && directWritable || (isTextEditable && directReadOnly) || isRootOfFavorites }
    var       isSortableByUser:         Bool  { return ancestorAccess != .eFullReadOnly || userHasAccess }
    var        directRecursive:         Bool  { return directAccess == .eRecurse }
    var         directWritable:         Bool  { return directAccess == .eFullWritable }
    var         directReadOnly:         Bool  { return directAccess == .eFullReadOnly || directChildrenWritable }
    var         isLostAndFound:         Bool  { return recordName == kLostAndFoundName }
    var          hasZonesBelow:         Bool  { return hasAnyZonesAbove(false) }
    var          hasZonesAbove:         Bool  { return hasAnyZonesAbove(true) }
    var            isHyperlink:         Bool  { return hasTrait(for: .eHyperlink) && hyperLink != kNullLink }
    var             isFavorite:         Bool  { return gFavoritesManager.isWorkingFavorite(self) }
    var             isSelected:         Bool  { return gSelectionManager.isSelected(self) }
    var              canTravel:         Bool  { return isBookmark || isHyperlink || isEmail }
    var              isGrabbed:         Bool  { return gSelectionManager .isGrabbed(self) }
    var               hasColor:         Bool  { return zoneColor != nil && zoneColor != "" }
    var                isEmail:         Bool  { return hasTrait(for: .eEmail) && email != "" }
    var                isTrash:         Bool  { return recordName == kTrashName }


    var trashZone: Zone? {
        if  let       mode = storageMode {
            let    manager = gRemoteStoresManager.cloudManagerFor(mode)

            return manager.trashZone
        }

        return nil
    }


    var email: String? {
        get {
            if  _email == nil {
                _email  = getTraitText(for: .eEmail)
            }

            return _email
        }

        set {
            if  _email != newValue {
                _email  = newValue

                setTraitText(newValue, for: .eEmail)
            }
        }
    }


    var hyperLink: String? {
        get {
            if  _hyperLink == nil {
                _hyperLink  = getTraitText(for: .eHyperlink)
            }

            return _hyperLink
        }

        set {
            if  _hyperLink != newValue {
                _hyperLink  = newValue

                setTraitText(newValue, for: .eHyperlink)
            }
        }
    }


    var isInTrash: Bool {
        var result = false

        if !isTrash {
            traverseAllAncestors { iZone in
                if iZone.isTrash {
                    result = true
                }
            }
        }

        return result
    }


    var isInFavorites: Bool {
        var result = false

        traverseAllAncestors { iZone in
            if iZone.isRootOfFavorites {
                result = true
            }
        }

        return result
    }


    convenience init(storageMode: ZStorageMode?, named: String? = nil, identifier: String? = nil) {
        var newRecord : CKRecord?

        if  let rName = identifier {
            newRecord = CKRecord(recordType: kZoneType, recordID: CKRecordID(recordName: rName))
        } else {
            newRecord = CKRecord(recordType: kZoneType)
        }

        self.init(record: newRecord!, storageMode: storageMode)

        zoneName      = named

        updateRecordProperties()
    }


    class func randomZone(in mode: ZStorageMode) -> Zone {
        return Zone(storageMode: mode, named: String(arc4random()))
    }


    // MARK:- properties
    // MARK:-


    class func cloudProperties() -> [String] {
        return [#keyPath(parent),
                #keyPath(zoneName),
                #keyPath(zoneLink),
                #keyPath(zoneColor),
                #keyPath(zoneCount),
                #keyPath(zoneOrder),
                #keyPath(zoneOwner),
                #keyPath(zoneAccess),
                #keyPath(parentLink),
                #keyPath(zoneProgeny)]
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    var fetchedBookmark: Zone? {
        let    bookmarks = fetchedBookmarks

        return bookmarks.count == 0 ? nil : bookmarks[0]
    }


    var decoration: String {
        var d = ""

        if isInTrash {
            d.append("T")
        }

        if isInFavorites {
            d.append("F")
        }

        if isBookmark {
            d.append("B")
        }

        if  indirectFetchableCount != 0 {
            let s  = d == "" ? "" : " "
            let c  = s + "\(indirectFetchableCount)"

            d.append(c)
        }

        if  d != "" {
            d  = "(\(d))  "
        }

        return d
    }


    var bookmarkTarget: Zone? {
        if  let    target = crossLink as? Zone {
            return target
        }

        return nil
    }


    var level: Int {
        get {
            if  !isRoot, !isRootOfFavorites, let p = parentZone, p != self, !p.spawnedBy(self) {
                return p.level + 1
            }

            return 0
        }
    }


    var color: ZColor {
        get {
            if _color == nil {
                if isBookmark {
                    return bookmarkTarget?.color ?? kDefaultZoneColor
                } else if let z = zoneColor, z != "" {
                    _color      = z.color
                } else if let p = parentZone, p != self, hasCompleteAncestorPath(toColor: true) {
                    return p.color
                } else {
                    return kDefaultZoneColor
                }
            }

            return _color!
        }

        set {
            if  _color   != newValue {
                _color    = newValue
                zoneColor = newValue.string

                maybeNeedSave()
            }
        }
    }


    var crossLink: ZRecord? {
        get {
            if _crossLink == nil {
                if  zoneLink == kTrashLink {
                    return gTrash
                }

                if  zoneLink == kLostAndFoundLink {
                    return gLostAndFound
                }

                if  zoneLink?.contains("Optional(") ?? false { // repair consequences of an old, but now fixed, bookmark bug
                    zoneLink = zoneLink?.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
                }

                _crossLink = zoneFrom(zoneLink)
            }

            return _crossLink
        }

        set {
            if newValue == nil {
                zoneLink = kNullLink
            } else {
                let    hasRef = newValue!.record != nil
                let reference = !hasRef ? "" : newValue!.recordName!
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
            if zoneCount == nil {
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


    var indirectFetchableCount: Int {
        if  let    t = bookmarkTarget {
            return t.indirectFetchableCount
        } else {
            return fetchableCount
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


//    @discardableResult func badJonathan() -> Bool {
//        if  let name = zoneName,
//            ["jonathan", "saved"].contains(name) {
//
//            //self.bam("gotcha! " + name)
//
//            if name == "jonathan" && linkName == nil && parent != nil {
//                maybeNeedSave()
//
//                return true
//            }
//        }
//
//        return false
//    }


    var parentZone: Zone? {
        get {
            var deb = 0
            if      _parentZone   == nil {
                deb = 1
                if  let  parentRef = parent, let mode = storageMode {
                    _parentZone    = gRemoteStoresManager.cloudManagerFor(mode).zoneForReference(parentRef) // POTENTIALLY BAD DUMMY
                    deb = 2

                    _parentZone?.requireFetch()
                } else if let zone = zoneFrom(parentLink) {
                    _parentZone    = zone
                    deb = 3
                }
            }

//            if badJonathan() {
//                parent = nil
//                _parentZone = nil
//                parentLink = kNullLink
//            }

            return _parentZone
        }

        set {
            _parentZone                  = newValue

            if _parentZone?.zoneName == "saved" {
                bam("created saved")
            }

            if  newValue == nil {
                if  parentLink != kNullLink || parent != nil {
                    parentLink  = kNullLink
                    parent      = nil

                    maybeNeedSave()
                }
            } else if let      parentRecord  = newValue?.record,
                let                 newMode  = newValue?.storageMode {
                if                  newMode == storageMode {
                    if parent?.recordID.recordName != parentRecord.recordID.recordName {
                        parentLink           = kNullLink
                        parent               = CKReference(record: parentRecord, action: .none)

                        maybeNeedSave()
                    }
                } else {                                                                                // new parent is in different db
                    let newLink = "\(newMode.rawValue)::\(parentRecord.recordID.recordName)"

                    if  newLink != parentLink {
                        parentLink           = newLink  // references don't work across dbs
                        parent               = nil

                        maybeNeedSave()
                    }
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


    var lineThickness: Double {
//        var thickness = gLineThickness
//
//        if  let   root = gRoot, progenyCount > 1 {
//            let  ratio = (Double(progenyCount) / Double(root.progenyCount) * 2.0) + 1.0
//            thickness *= ratio
//        }

        return gLineThickness
    }


    // MARK:- write access
    // MARK:-


    var directAccess: ZoneAccess {
        get {
            if  let    target = bookmarkTarget {
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


    var userHasAccess: Bool {
        if  let    t = bookmarkTarget {
            return t.userHasAccess
        }

        return (!isTrash && !isRootOfFavorites && !isLostAndFound && ownerID == nil)
            || (!gCrippleUserAccess && (ownerID?.recordName == gUserRecordID || gIsSpecialUser))
    }


    var isTextEditable: Bool {
        if let t = bookmarkTarget {
            return    t.isTextEditable
        } else if directWritable {
            return true
        } else if directReadOnly {
            return false
        } else if let p = parentZone, p != self {
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

        return userHasAccess
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
        if  storageMode == .everyoneMode {
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

                    maybeNeedSave()
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


    override func debug(_  iMessage: String) {
        note("\(iMessage) children \(count) parent \(parent != nil) is \(isInTrash ? "" : "not ")deleted  mode \(storageMode!) \(unwrappedName)")
    }


    override func setupLinks() {
        if  record                != nil {
            let           badLinks = ["", "-", "no"]

            if  let link           = zoneLink {
                if  badLinks.contains(link) {
                    zoneLink       = kNullLink
                }
            } else {
                zoneLink           = kNullLink
            }

            if  let pLink          = parentLink {
                if  badLinks.contains(pLink) {
                    parentLink     = kNullLink
                }
            } else {
                parentLink         = kNullLink
            }

            gBookmarksManager.registerBookmark(self)
        }
    }


    func editAndSelect(in range: NSRange) {
        edit()
        FOREGROUND {
            self.widget?.textWidget.selectCharacter(in: range)
        }
    }


    func clearColor() {
        zoneColor = ""
        _color    = nil

        maybeNeedSave()
    }


    static func == ( left: Zone, right: Zone) -> Bool {
        let unequal = left != right // avoid infinite recursion by using negated version of this infix operator

        if  unequal && left.record != nil && right.record != nil {
            return left.recordName == right.recordName
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


    // MARK:- traits
    // MARK:-


    func hasTrait(for iType: ZTraitType) -> Bool {
        return traits[iType] != nil
    }

    
    func getTraitText(for iType: ZTraitType) -> String? {
        return traits[iType]?.text
    }


    func setTraitText(_ iText: String?, for iType: ZTraitType) {
        var trait         = traits[iType]

        if  trait        == nil {
            trait         = ZTrait(storageMode: storageMode)
        } else if  iText == nil {
            traits[iType] = nil

            trait?.needDestroy()

            return
        }

        traits   [iType] = trait
        trait?.traitType = iType
        trait?    .owner = CKReference(record: record, action: .none)
        trait?     .text = iText

        trait?.updateRecordProperties()
        trait?.maybeNeedSave()
    }


    // MARK:- traverse ancestors
    // MARK:-

    func hasCompleteAncestorPath(toColor: Bool = false, toWritable: Bool = false) -> Bool {
        var      isComplete = false
        var ancestor: Zone? = nil

        traverseAllAncestors { iZone in
            let  isReciprocal = ancestor == nil  || iZone.children.contains(ancestor!)

            if  (isReciprocal && iZone.isRoot) || (toColor && iZone.hasColor) || (toWritable && !iZone.directRecursive) {
                isComplete = true
            }

            ancestor = iZone
        }

        return isComplete
    }


    func isABookmark(spawnedBy zone: Zone) -> Bool {
        if  let        link = crossLink, let mode = link.storageMode {
            var     probeID = link.record.recordID as CKRecordID?
            let  identifier = zone.recordName
            var     visited = [String] ()

            while let probe = probeID?.recordName, !visited.contains(probe) {
                visited.append(probe)

                if probe == identifier {
                    return true
                }

                let zone = gRemoteStoresManager.recordsManagerFor(mode)?.maybeZoneForRecordID(probeID)
                probeID  = zone?.parent?.recordID
            }
        }

        return false
    }


    func spawnedByAGrab() -> Bool { return spawnedByAny(of: gSelectionManager.currentGrabs) }
    func spawnedBy(_ iZone: Zone?) -> Bool { return iZone == nil ? false : spawnedByAny(of: [iZone!]) }
    func traverseAncestors(_ block: ZoneToStatusClosure) { safeTraverseAncestors(visited: [], block) }


    func spawnedByAny(of iZones: [Zone]) -> Bool {
        var wasSpawned: Bool = false

        if  iZones.count > 0 {
            traverseAncestors { iAncestor -> ZTraverseStatus in
                if iZones.contains(iAncestor) {
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


    func safeTraverseAncestors(visited: [Zone], _ block: ZoneToStatusClosure) {
        if  block(self) == .eContinue,  //        skip == stop
            !isRoot,                    //      isRoot == stop
            !visited.contains(self),    // graph cycle == stop
            let p = parentZone {        //  nil parent == stop
            p.safeTraverseAncestors(visited: visited + [self], block)
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
                if visited.contains(child) {
                    status = .eSkip

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
            theCopy.addChild(child.deepCopy())
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
                if  !child.showChildren && child.fetchableCount != 0 {
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
            if !hasZoneAbove(iAbove), let p = parentZone {
                return p.safeHasAnyZonesAbove(iAbove, visited + [self])
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


    func maybeNeedBookmarks() {
        if !isBookmark {
            addState(.needsBookmarks)
        }
    }


    override func maybeNeedRoot() {
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
    

    func maybeNeedChildren() {
        if  showChildren && hasMissingChildren() && !needsProgeny {
            needChildren()
        }
    }


    func prepareForArrival() {
        displayChildren()
        maybeNeedWritable()
        maybeNeedColor()
        maybeNeedRoot()
        needChildren()
        grab()
    }


    func extendNeedForChildren(to iLevel: Int) {
        traverseProgeny { iZone -> ZTraverseStatus in
            if iLevel < iZone.level {
                return .eSkip
            } else {
                iZone.needChildren()
                iZone.needCount()
            }

            return .eContinue
        }
    }


    // MARK:- children
    // MARK:-


    override func hasMissingChildren() -> Bool { return count < fetchableCount }


    override func hasMissingProgeny() -> Bool {
        var total = 0

        traverseAllProgeny { iChild in
            total += 1
        }

        return total < progenyCount
    }


    override func unorphan() {
        if  !needsDestroy, let p = parentZone, p != self {

//            if badJonathan() {
//                return
//            }

            p.maybeNeedFetch()
            p.addChildAndRespectOrder(self)
        }
    }


    func orphan() {
        parentZone?.removeChild(self)

        parentZone = nil

        updateRecordProperties()
    }


    func addChildAndRespectOrder(_ child: Zone?) {
        addChild(child)
        respectOrder()
    }


    @discardableResult func addChild(_ child: Zone?) -> Int? {
        return addChild(child, at: 0)
    }


    func addAndReorderChild(_ iChild: Zone?, at iIndex: Int?) {
        if  let child = iChild,
            addChild(child, at: iIndex) != nil {

            children.updateOrder()
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


    @discardableResult func addChild(_ iChild: Zone?, at iIndex: Int?) -> Int? {
        if  let newChild = iChild {
            let insertAt = validIndex(from: iIndex)

            // make sure it's not already been added
            // NOTE: both must have a record for this to be effective

            if  let identifier = newChild.recordName,
                let   oldIndex = children.index(of: newChild) {

                for sibling in children {
                    if  sibling.recordName == identifier {
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

            if  insertAt < count {
                children.insert(newChild, at: insertAt)
            } else {
                children.append(newChild)
            }

            newChild.parentZone = self

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


    func recursivelyApplyMode(_ iMode: ZStorageMode?) {
        if let mode = iMode, mode != storageMode {
            traverseAllProgeny { iZone in
                iZone.unregister()

                let newParentZone = iZone.parentZone                                    // (1) grab new parent zone from previous traverse (2, below)
                let     oldRecord = iZone.record
                let     newRecord = CKRecord(recordType: kZoneType)                     // new record id
                iZone.storageMode = mode                                                // must happen BEFORE record assignment
                iZone     .record = newRecord                                           // side-effect: move registration to the new mode's record manager

                oldRecord?.copy(to: iZone.record, properties: iZone.cloudProperties())  // preserve new record id
                iZone.maybeNeedSave()                                                   // in new mode's record manager

                ///////////////////////////////////////////////////////////////
                // (2) compute parent and parentLink using iZone's new iMode //
                //      this traverse will eventually use it (1, above)      //
                ///////////////////////////////////////////////////////////////

                iZone.parentZone  = newParentZone
            }
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


    func containsCKRecord(_ iCKRecord: CKRecord?) -> Bool {
        if let identifier = iCKRecord?.recordID.recordName {
            for child in children {
                if  let childID = child.recordName, childID == identifier {
                    return true
                }
            }
        }

        return false
    }


    @discardableResult func addChild(for iCKRecord: CKRecord?) -> Zone? {
        var child: Zone?    = nil
        if  let childRecord = iCKRecord, !containsCKRecord(childRecord) {
            child           = gCloudManager.zoneForCKRecord(childRecord)

            addChild(child)
            children.updateOrder()
        }

        return child
    }


    func divideEvenly() {
        let optimumSize     = 40
        if  count           > optimumSize,
            let        mode = storageMode {
            var   divisions = ((count - 1) / optimumSize) + 1
            let        size = count / divisions
            var     holders = [Zone] ()

            while divisions > 0 {
                divisions  -= 1
                var gotten  = 0
                let holder  = Zone.randomZone(in: mode)

                holders.append(holder)

                while gotten < size && count > 0 {
                    if  let child = children.popLast(),
                        child.progenyCount < (optimumSize / 2) {
                        holder.addChild(child, at: nil)
                    }

                    gotten += 1
                }
            }

            for child in holders {
                addChild(child, at: nil)
            }
        }
    }


    // MARK:- progeny counts
    // MARK:-


    func updateProgenyCount() {
        if !hasMissingChildren() {
            fastUpdateProgenyCount()
        } else {
            needChildren()
            gDBOperationsManager.children(.restore) { iSame in
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
        // fastUpdateProgenyCount()
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
        if let     string = dict[kZoneName] as! String? { zoneName = string }

        if let childrenStore: [ZStorageDict] = dict[kChildren] as! [ZStorageDict]? {
            for childStore: ZStorageDict in childrenStore {
                let child = Zone(dict: childStore)

                addChild(child, at: nil)
            }

            respectOrder()
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed to cloud
    }


    override func storageDictionary() -> ZStorageDict? {
        var   childrenStore = [ZStorageDict] ()
        var            dict = super.storageDictionary()!
        dict[kZoneName]     = zoneName as NSObject?
        dict[kShowChildren] = NSNumber(booleanLiteral: showChildren)


        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[kChildren]     = childrenStore as NSObject?

        return dict
    }
}
