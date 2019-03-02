 //
//  Zone.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


 enum ZoneAccess: Int, CaseIterable {
    case eInherit
    case eReadOnly
    case eProgenyWritable
    case eWritable
    
    static func isDirectlyValid(_ value: Int) -> Bool {
        return ZoneAccess.allCases.filter { iItem -> Bool in
            return iItem != .eInherit && iItem.rawValue == value
        } != []
    }
 }


class Zone : ZRecord {


    @objc dynamic var           parent:  CKRecord.Reference?
    @objc dynamic var         zoneName:       String?
    @objc dynamic var         zoneLink:       String?
    @objc dynamic var        zoneColor:       String?
    @objc dynamic var   zoneAttributes:       String?
    @objc dynamic var       parentLink:       String?
    @objc dynamic var       zoneAuthor:       String?
    @objc dynamic var        zoneOrder:     NSNumber?
    @objc dynamic var        zoneCount:     NSNumber?
    @objc dynamic var       zoneAccess:     NSNumber?
    @objc dynamic var      zoneProgeny:     NSNumber?
    var              _parentZone:         Zone?
    var               _hyperLink:       String?
    var               _crossLink:      ZRecord?
    var                   _color:       ZColor?
    var                   _email:       String?
    var   timeOfLastDragDotClick:         Date?
    var                 children =                [Zone] ()
    var                   traits = [ZTraitType : ZTrait] ()
    var                    count:          Int  { return children.count }
    var            lowestExposed:          Int? { return exposed(upTo: highestExposed) }
    var           bookmarkTarget:         Zone? { return crossLink as? Zone }
    var              destroyZone:         Zone? { return cloud?.destroyZone }
    var                trashZone:         Zone? { return cloud?.trashZone }
    var                   widget:   ZoneWidget? { return gWidgets.widgetForZone(self) }
    var           linkDatabaseID:  ZDatabaseID? { return databaseID(from: zoneLink) }
    var           linkRecordName:       String? { return recordName(from: zoneLink) }
    override var       emptyName:       String  { return "idea" }
    override var   unwrappedName:       String  { return zoneName ?? (isRootOfFavorites ? kFavoritesName : emptyName) }
    var            decoratedName:       String  { return decoration + unwrappedName }
    var         fetchedBookmarks:       [Zone]  { return gBookmarks.bookmarks(for: self) ?? [] }
    var        isCurrentFavorite:         Bool  { return self == gFavorites.currentFavorite }
    var         grabbedTextColor:       ZColor  { return color.darker(by: 3.0) }
    var        onlyShowRevealDot:         Bool  { return (isRootOfFavorites && showingChildren && !(widget?.isInMain ?? true)) || (kIsPhone && self == gHere) }
    var          dragDotIsHidden:         Bool  { return (isRootOfFavorites                    && !(widget?.isInMain ?? true)) || (kIsPhone && self == gHere) }    // always hide drag dot of favorites root
    var            hasZonesBelow:         Bool  { return hasAnyZonesAbove(false) }
    var            hasZonesAbove:         Bool  { return hasAnyZonesAbove(true) }
    var              hasSiblings:         Bool  { return parentZone?.count ?? 0 > 1 }
    var              isHyperlink:         Bool  { return hasTrait(for: .eHyperlink) && hyperLink != kNullLink }
    var               isSelected:         Bool  { return gSelecting.isSelected(self) }
    var                isGrabbed:         Bool  { return gSelecting .isGrabbed(self) }
    var                canTravel:         Bool  { return isBookmark || isHyperlink || isEmail }
    var                 hasColor:         Bool  { return zoneColor != nil && zoneColor != "" }
    var                  isEmail:         Bool  { return hasTrait(for: .eEmail) && email != "" }
    var                  isTrash:         Bool  { return recordName == kTrashName }
    var                isInTrash:         Bool  { return root?.isTrash              ?? false }
    var            isInFavorites:         Bool  { return root?.isRootOfFavorites    ?? false }
    var         isInLostAndFound:         Bool  { return root?.isRootOfLostAndFound ?? false }
    var     isRootOfLostAndFound:         Bool  { return recordName == kLostAndFoundName }
    var           spawnedByAGrab:         Bool  { return spawnedByAny(of: gSelecting.currentGrabs) }
    var               spawnCycle:         Bool  { return spawnedByAGrab || dropCycle }
    var            isDoubleClick:         Bool  { return timeOfLastDragDotClick?.timeIntervalSinceNow ?? 10.0 < 0.5 }


    var deepCopy: Zone {
        let theCopy = Zone(databaseID: databaseID)

        copy(into: theCopy)

        theCopy.parentZone = nil

        for child in children {
            theCopy.addChild(child.deepCopy)
        }

        for (_, trait) in traits {
            theCopy.addTrait(trait.deepCopy)
        }

        return theCopy
    }


    var dropCycle: Bool {
        if  let target = bookmarkTarget, let dragged = gDraggedZone, (target == dragged || target.spawnedBy(dragged) || target.children.contains(dragged)) {
            return true
        }

        return false
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


    var root: Zone? {
        var base: Zone?

        traverseAllAncestors { iZone in
            if iZone.isRoot {
                base = iZone
            }
        }

        return base
    }


    convenience init(databaseID: ZDatabaseID?, named: String? = nil, identifier: String? = nil) {
        var newRecord : CKRecord?

        if  let rName = identifier {
            newRecord = CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: rName))
        } else {
            newRecord = CKRecord(recordType: kZoneType)
        }

        self.init(record: newRecord!, databaseID: databaseID)

        zoneName      = named

        updateCKRecordProperties()
    }


    class func randomZone(in dbID: ZDatabaseID) -> Zone {
        return Zone(databaseID: dbID, named: String(arc4random()))
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
                #keyPath(zoneAuthor),
                #keyPath(zoneAccess),
                #keyPath(parentLink),
                #keyPath(zoneProgeny),
                #keyPath(zoneAttributes)]
    }


    override func cloudProperties() -> [String] {        
        return super.cloudProperties() + Zone.cloudProperties()
    }


    var traitValues: [ZTrait] {
        var values = [ZTrait] ()

        for trait in traits.values {
            values.append(trait)
        }

        return values
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

        if  count != 0 {
            let s  = d == "" ? "" : " "
            let c  = s + "\(count)"

            d.append(c)
        }

        if  d != "" {
            d  = "(\(d))  "
        }

        return d
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
            var computed = _color
            
            if _color == nil {
                if  let b = bookmarkTarget {
                    return b.color
                } else if let c = zoneColor, c != "" {
                    computed    = c.color
                    _color      = computed
                } else if let p = parentZone, p != self, hasCompleteAncestorPath(toColor: true) {
                    return p.color
                } else {
                    computed    = kDefaultZoneColor
                }
            }

            if  gIsDark {
                computed        = computed?.inverted
            }

            return computed!
        }

        set {
            var computed = newValue

            if  gIsDark {
                computed = computed.inverted
            }

            if  isBookmark {
                bookmarkTarget?.color  = newValue
            } else if          _color != computed {
                _color                 = computed
                zoneColor              = computed.string

                maybeNeedSave()
            }
        }
    }


    var colorized: Bool {
        get {
            var        result = false
            let originalColor = color

            if  let  b = bookmarkTarget {
                result = b.colorized
            } else {
                traverseAncestors { iChild -> (ZTraverseStatus) in
                    if iChild.color != originalColor {
                        return .eStop
                    }
                    
                    if  let attributes = iChild.zoneAttributes,
                        attributes.contains(kInvertColorize) {
                        result = !result
                    }
                    
                    return .eContinue
                }
            }

            return result
        }

        set {
            if  let b = bookmarkTarget {
                b.colorized = newValue
            } else {
                var attributes = zoneAttributes ?? ""
                let oldValue   = attributes.contains(kInvertColorize)
                
                if  newValue  != oldValue {
                    if !newValue {
                        attributes = attributes.replacingOccurrences(of: kInvertColorize, with: "")
                    } else if !attributes.contains(kInvertColorize) {
                        attributes.append(kInvertColorize)
                    }
                    
                    if  zoneAttributes != attributes {
                        zoneAttributes  = attributes
                        
                        needSave()
                    }
                }
            }
        }
    }


    func toggleColorized() {
        colorized = !(zoneAttributes?.contains(kInvertColorize) ?? false)
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
                zoneLink      = "\(newValue!.databaseID!.rawValue)::\(reference)"
            }

            _crossLink = nil
        }
    }


    var order: Double {
        get {
            if  zoneOrder == nil {
                updateInstanceProperties()

                if  zoneOrder == nil {
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
            if  zoneCount == nil {
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


    var indirectCount: Int {
        if  let    t = bookmarkTarget {
            return t.indirectCount
        } else {
            return count
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
            if  newValue != progenyCount {
                zoneProgeny = NSNumber(value: newValue)
            }
        }
    }


    var highestExposed: Int {
        var highest = level

        traverseProgeny { iZone -> ZTraverseStatus in
            let traverseLevel = iZone.level

            if  highest < traverseLevel {
                highest = traverseLevel
            }

            return iZone.showingChildren ? .eContinue : .eSkip
        }

        return highest
    }


    func unlinkParentAndMaybeNeedSave() {
        if (recordName(from: parentLink) != nil ||
            parent                 != nil) &&
            canSaveWithoutFetch {
            needSave()
        }

        parent          = nil
        _parentZone     = nil
        parentLink      = kNullLink
    }

    
    var resolveParent: Zone? {
        let     old = _parentZone
        _parentZone = nil
        let     new =  parentZone // recalculate _parentZone

        old?.removeChild(self)
        new?.addChildAndRespectOrder(self)

        return new
    }
    

    var parentZone: Zone? {
        get {
            if  isRoot {
                unlinkParentAndMaybeNeedSave()
            } else if _parentZone == nil {
                if  let  parentRef = parent {
                    _parentZone    = cloud?.zoneForReference(parentRef)
                } else if let zone = zoneFrom(parentLink) {
                    _parentZone    = zone
                }
            }

            return _parentZone
        }

        set {
            if  isRoot {
                unlinkParentAndMaybeNeedSave()
            } else if _parentZone          != newValue {
                _parentZone                 = newValue
                if  _parentZone            == nil {
                    unlinkParentAndMaybeNeedSave()
                } else if let parentRecord  = _parentZone?.record,
                    let      newParentDBID  = _parentZone?.databaseID {
                    if       newParentDBID == databaseID {
                        if  parent?.recordID.recordName != parentRecord.recordID.recordName {
                            parentLink      = kNullLink
                            parent          = CKRecord.Reference(record: parentRecord, action: .none)

                            maybeNeedSave()
                        }
                    } else {                                                                                // new parent is in different db
                        let newParentLink   = "\(newParentDBID.rawValue)::\(parentRecord.recordID.recordName)"

                        if  parentLink     != newParentLink {
                            parentLink      = newParentLink  // references don't work across dbs
                            parent          = nil

                            maybeNeedSave()
                        }
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


    // MARK:- write access
    // MARK:-


    var      inheritedAccess: ZoneAccess { return zoneWithInheritedAccess.directAccess }
    var       directReadOnly:       Bool { return directAccess == .eReadOnly || directAccess == .eProgenyWritable }
    var          userCanMove:       Bool { return userHasDirectOwnership || inheritedAccess == .eWritable || isBookmark } // all bookmarks are movable because they are created by user and live in my databasse
    var         userCanWrite:       Bool { return userHasDirectOwnership || isTextEditable }
    var userCanMutateProgeny:       Bool { return userHasDirectOwnership || inheritedAccess != .eReadOnly }
    
    
    var userHasDirectOwnership: Bool {
        if  let    t = bookmarkTarget {
            return t.userHasDirectOwnership
        }
        
        return !isTrash && !isRootOfFavorites && !isRootOfLostAndFound && !gDebugDenyOwnership && (databaseID == .mineID || zoneAuthor == gAuthorID || gIsMasterAuthor)
    }


    var directAccess: ZoneAccess {
        get {
            if  let    t = bookmarkTarget {
                return t.directAccess
            } else if let value = zoneAccess?.intValue,
                ZoneAccess.isDirectlyValid(value) {
                return ZoneAccess(rawValue: value)!
            }

            return .eInherit // default value
        }

        set {
            if let t = bookmarkTarget {
                t.directAccess = newValue
            } else {
                let    value = newValue.rawValue
                let oldValue = zoneAccess?.intValue ?? ZoneAccess.eInherit.rawValue
                
                if  oldValue != value {
                    zoneAccess = NSNumber(value: value)
                }
            }
        }
    }
    
    
    var hasAccessDecoration: Bool {
        if  let    t = bookmarkTarget {
            return t.hasAccessDecoration
        }

        return isInPublicDatabase && (directReadOnly || inheritedAccess == .eReadOnly)
    }


    var zoneWithInheritedAccess: Zone {
        var     zone = self

        traverseAncestors { iZone -> ZTraverseStatus in
            if  iZone.directAccess != .eInherit {
                zone = iZone
                
                return .eStop
            }

            return .eContinue
        }

        return zone
    }


    var isTextEditable: Bool {
        if  let    t = bookmarkTarget {
            return t.isTextEditable
        } else if directAccess == .eWritable {
            return true
        } else if let p = parentZone, p != self {
            return p.directAccess == .eProgenyWritable || p.isTextEditable
        } else {
            return false
        }
    }


    var nextAccess: ZoneAccess? {
        let  inherited  = parentZone?.inheritedAccess ?? .eProgenyWritable
        var     access  = next(after: directAccess) ?? next(after: inherited)
        
        if  inherited  == .eProgenyWritable {
            if  access == .eWritable {
                access  = .eInherit
            }
        } else if access == inherited {
            access  = .eInherit
        } else if access == nil { // this can happen to the root when the data file *somehow* replaces the root record name and the correction code restores the correct record name
            access  = .eProgenyWritable
        }

        return access
    }
    
    
    func next(after: ZoneAccess?) -> ZoneAccess? {
        if  let    access = after {
            switch access {
            case .eProgenyWritable: return .eReadOnly
            case .eWritable:        return .eProgenyWritable
            case .eReadOnly:        return .eWritable
            default:                break
            }
        }
        
        return nil
    }


    func rotateWritable() {
        if  let t = bookmarkTarget {
            t.rotateWritable()
        } else if userCanWrite,
            databaseID      == .everyoneID {
            let       direct = directAccess
            
            if  let     next = nextAccess,
                direct      != next {
                directAccess = next
                
                if  let identity = gAuthorID,
                    next        != .eInherit,
                    zoneAuthor  != nil {
                    zoneAuthor   = identity
                }
                
                maybeNeedSave()
            }
        }
    }


    // MARK:- convenience
    // MARK:-


    func addToPaste() { gSelecting.pasteableZones[self] = (parentZone, siblingIndex) }
    func  addToGrab() { gSelecting    .addOneGrab(self) }
    func     ungrab() { gSelecting        .ungrab(self) }
    func       edit() { gTextEditor         .edit(self) }

    
    func grab(updateBrowsingLevel: Bool = true) {
        gSelecting.grab(self, updateBrowsingLevel: updateBrowsingLevel)
    }

    
    func makeVisibleAndGrab(updateBrowsingLevel: Bool = true) {
        gSelecting.makeVisibleAndGrab(self, updateBrowsingLevel: updateBrowsingLevel)
    }

    
    func dragDotClicked(isCommand: Bool, isShift: Bool) {
        let doubleClicked = isDoubleClick
        let shouldFocus = isCommand || (doubleClicked && isGrabbed)
        
        timeOfLastDragDotClick = Date()

        if  shouldFocus {
            grab() // narrow selection to just this one zone
            
            if !(doubleClicked && self == gHere) {
                gFocusing.focus(kind: .eSelected) {
                    gGraphEditor.redrawSyncRedraw()
                }
            }
        } else if isGrabbed {
            ungrab()
        } else if isShift {
            addToGrab()
        } else {
            grab()
        }

        gControllers.signalFor(nil, regarding: .eDetails)
    }

    
    override func debug(_  iMessage: String) {
        note("\(iMessage) children \(count) parent \(parent != nil) is \(isInTrash ? "" : "not ") deleted identifier \(databaseID!) \(unwrappedName)")
    }


    override func setupLinks() {
        if  record != nil {

            let isBad: StringToBooleanClosure = { iString -> Bool in
                let badLinks = ["", "-", "not"]

                return iString == nil || badLinks.contains(iString!)
            }

            if  isBad(zoneLink) {
                zoneLink = kNullLink
            }

            if  isBad(parentLink) {
                parentLink = kNullLink
            }

        }
    }
    
    
    func assignAndColorize(_ iText: String) {
        if  userCanWrite {
            zoneName  = iText
            colorized = true
            
            gTextEditor.updateText(inZone: self)
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

    
    func extractTraits(from: Zone) {
        for trait in Array(from.traits.values) {
            addTrait(trait)
        }
    }


    func addTrait(_ trait: ZTrait) {
        if  let       r      = record,
            let    type      = trait.traitType {
            traits[type]     = trait
            trait .owner     = CKRecord.Reference(record: r, action: .none)
            trait._ownerZone = nil

            trait.updateCKRecordProperties()
        }
    }


    func hasTrait(for iType: ZTraitType) -> Bool {
        return traits[iType] != nil
    }

    
    func getTraitText(for iType: ZTraitType) -> String? {
        return traits[iType]?.text
    }


    func setTraitText(_ iText: String?, for iType: ZTraitType?) {
        if  let  type        = iType {
            if  iText       == nil {
                traits[type]?.needDestroy()

                traits[type] = nil
            } else {
                let    trait = self.trait(for: type)
                trait.text   = iText

                trait.updateCKRecordProperties()
                trait.maybeNeedSave()
            }
            
            switch (type) {
            case .eEmail:     _email     = nil
            case .eHyperlink: _hyperLink = nil
            default: break
            }
        }
    }


    func trait(for iType: ZTraitType) -> ZTrait {
        var trait            = traits[iType]
        if  let            r = record,
            trait           == nil {
            trait            = ZTrait(databaseID: databaseID)
            trait?.owner     = CKRecord.Reference(record: r, action: .none)
            trait?.traitType = iType
            traits[iType]    = trait
        }

        return trait!
    }


    // MARK:- traverse ancestors
    // MARK:-

    func hasCompleteAncestorPath(toColor: Bool = false, toWritable: Bool = false) -> Bool {
        var      isComplete = false
        var ancestor: Zone?

        traverseAllAncestors { iZone in
            let  isReciprocal = ancestor == nil  || iZone.children.contains(ancestor!)

            if  (isReciprocal && iZone.isRoot) || (toColor && iZone.hasColor) || (toWritable && iZone.directAccess != .eInherit) {
                isComplete = true
            }

            ancestor = iZone
        }

        return isComplete
    }


    func isABookmark(spawnedBy zone: Zone) -> Bool {
        if  let        link = crossLink, let dbID = link.databaseID {
            var     probeID = link.record?.recordID
            let  identifier = zone.recordName
            var     visited = [String] ()

            while let probe = probeID?.recordName, !visited.contains(probe) {
                visited.append(probe)

                if probe == identifier {
                    return true
                }

                let zone = gRemoteStorage.zRecords(for: dbID)?.maybeZoneForRecordID(probeID)
                probeID  = zone?.parent?.recordID
            }
        }

        return false
    }

    
    var isVisible: Bool {
        var isVisible = true
        
        traverseAncestors { iAncestor -> ZTraverseStatus in
            let showing = iAncestor.showingChildren
            
            if      iAncestor != self {
                if  iAncestor == gHere || !showing {
                    isVisible = showing
                }
                
                return .eStop
            }
            
            return .eContinue
        }
        
        return isVisible
    }

    
    func asssureIsVisible() {
        traverseAncestors { iAncestor -> ZTraverseStatus in
            iAncestor.revealChildren()
            
            if  iAncestor == gHere {
                return .eStop
            }

            return .eContinue
        }
    }
    

    func spawnedBy(_ iZone: Zone?) -> Bool { return iZone == nil ? false : spawnedByAny(of: [iZone!]) }
    func traverseAncestors(_ block: ZoneToStatusClosure) { safeTraverseAncestors(visited: [], block) }


    func spawnedByAny(of iZones: [Zone]) -> Bool {
        var wasSpawned = false

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

            return iZone.showingChildren ? .eContinue : .eSkip
        }

        return visible
    }


    func concealAllProgeny() {
        traverseAllProgeny { iChild in
            iChild.concealChildren()
        }
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

    
    func traverseAllVisibleProgeny(_ block: ZoneClosure) {
        safeTraverseProgeny(visited: []) { iZone -> ZTraverseStatus in
            block(iZone)
            
            return iZone.showingChildren ? .eContinue : .eSkip
        }
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


    func exposedProgeny(at iLevel: Int) -> [Zone] {
        var     progeny = [Zone]()
        var begun: Bool = false

        traverseProgeny { iZone -> ZTraverseStatus in
            if begun {
                if iZone.level > iLevel || iZone == self {
                    return .eSkip
                } else if iZone.level == iLevel && iZone != self && (iZone.parentZone == nil || iZone.parentZone!.showingChildren) {
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
                if  !child.showingChildren && child.fetchableCount != 0 {
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
        if  showingChildren && !needsProgeny {
            needChildren()
        }
    }


    func prepareForArrival() {
        revealChildren()
        maybeNeedWritable()
        maybeNeedColor()
        maybeNeedRoot()
        needChildren()
        grab()
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
        if !needsDestroy, let r = record, !r.isEmpty { // if record is empty, cannot unorphan nor mark needing unorphan
            if  let p = parentZone, p != self {
                p.maybeMarkNotFetched()
                p.addChildAndRespectOrder(self)
                
                if  p.recordName == kFavoritesRootName, let b = bookmarkTarget, !b.isRoot {
                    bam(decoratedName)
                }
            } else if !isRoot {
                needUnorphan()
            }
        }
    }


   override func orphan() {
        parentZone?.removeChild(self)

        parentZone = nil
    }


    func addChildAndRespectOrder(_ child: Zone?) {
        addChild(child)
        respectOrder()
    }


    @discardableResult func addChild(_ child: Zone?) -> Int? {
        return addChild(child, at: 0)
    }


    func addAndReorderChild(_ iChild: Zone?, at iIndex: Int? = nil) {
        if  let child = iChild,
            addChild(child, at: iIndex) != nil {

            children.updateOrder()
            maybeNeedSave()
        }
    }


    func validIndex(from iIndex: Int?) -> Int {
        var insertAt = iIndex

        if  let index = iIndex, index < count {
            if  index < 0 {
                insertAt = 0
            }
        } else {
            insertAt = count
        }

        return insertAt!
    }


    @discardableResult func addChild(_ iChild: Zone?, at iIndex: Int?) -> Int? {
        if  let        child = iChild {
            let     insertAt = validIndex(from: iIndex)
            child.parentZone = self

            // make sure it's not already been added
            // NOTE: both must have a record for this to be effective

            if  let identifier = child.recordName, children.contains(child) {
                for (index, sibling) in children.enumerated() {
                    if  sibling.recordName == identifier {
                        if  index != insertAt {
                            moveChildIndex(from: index, to: insertAt)
                        }

                        return insertAt
                    }
                }
            }

            if  insertAt < count {
                children.insert(child, at: insertAt)
            } else {
                children.append(child)
            }

            maybeNeedSave()
            needCount()

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


    func recursivelyApplyDatabaseID(_ iID: ZDatabaseID?) {
        if  let             appliedID = iID,
            let                  dbID = databaseID,
            appliedID                != dbID {
            traverseAllProgeny { iZone in
                if  let         newID = iZone.databaseID,
                    newID            != appliedID {
                    iZone.unregister()

                    let newParentZone = iZone.parentZone                                    // (1) grab new parent zone asssigned during a previous traverse (2, below)
                    let     oldRecord = iZone.record
                    let     newRecord = CKRecord(recordType: kZoneType)                     // new record id
                    iZone .databaseID = appliedID                                           // must happen BEFORE record assignment
                    iZone     .record = newRecord                                           // side-effect: move registration to the new id's record manager

                    oldRecord?.copy(to: iZone.record, properties: iZone.cloudProperties())  // preserve new record id
                    iZone.needSave()                                                        // in new id's record manager

                    ////////////////////////////////////////////////////////////////////
                    // (2) compute parent and parentLink using iZone's new databaseID //
                    //     a subsequent traverse will eventually use it (1, above)    //
                    ////////////////////////////////////////////////////////////////////

                    iZone.parentZone  = newParentZone
                }
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
            child           = gCloud?.zone(for: childRecord)

            if  child != nil {
                addChild(child)
                children.updateOrder()
            }
        }

        return child
    }


    func divideEvenly() {
        let optimumSize     = 40
        if  count           > optimumSize,
            let        dbID = databaseID {
            var   divisions = ((count - 1) / optimumSize) + 1
            let        size = count / divisions
            var     holders = [Zone] ()

            while divisions > 0 {
                divisions  -= 1
                var gotten  = 0
                let holder  = Zone.randomZone(in: dbID)

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


    func outlineString(for iInset: Int = 0, at iIndex: Int = 0) -> String {
        let   marks = ".)>"
        let indices = "A1ai"
        let modulus = indices.count
        let  margin = " " * (modulus * iInset)
        let    type = ZOutlineLevelType(rawValue: indices.character(at: iInset % modulus))
        let  letter = String.character(at: iIndex, for: type!)
        var  string = margin + letter + marks.character(at: iInset / modulus) + " " + unwrappedName + kReturn

        for (index, child) in children.enumerated() {
            string += child.outlineString(for: iInset + 1, at: index)
        }

        return string
    }


    // MARK:- lines and titles
    // MARK:-

    
    
    func convertToTitledLine() {
        zoneName  = kHalfLineOfDashes + " " + unwrappedName + " " + kHalfLineOfDashes
        colorized = true
        
        needSave()
    }
    
    
    func convertToLine() -> Bool {
        if  let childName = widget?.textWidget.extractSelectedText(requiresAllOrTitleSelected: true) {
            
            if  zoneName != childName {
                zoneName  = childName
                colorized = false
                
                editAndSelect(in: NSMakeRange(0,  childName.length))
            } else {
                zoneName  = kHalfLineOfDashes + " " + childName + " " + kHalfLineOfDashes
                colorized = true
                
                editAndSelect(in: NSMakeRange(12, childName.length))
            }
            
            return true
        }
        
        return false
    }
    
    
    func convertFromLineWithTitle() {
        if  let childName = widget?.textWidget.extractTitleText() {
            zoneName  = childName
            colorized = false
        }
    }
    

    // MARK:- progeny counts
    // MARK:-
    

    func updateCounts(_ iVisited: [Zone] = []) {
        if !iVisited.contains(self) {
            let visited = iVisited + [self]
            var counter = 0

            for child in children {
                if  child.isBookmark {
                    counter += 1
                } else {
                    child.updateCounts(visited)

                    counter += child.count + child.progenyCount
                }
            }

            if  progenyCount != counter {
                progenyCount  = counter

                needSave()
            }
        }
    }

    
    // MARK:- receive from cloud
    // MARK:-
    

    func resolve(_ onCompletion: ZoneMaybeClosure? = nil) {
        FOREGROUND(canBeDirect: true) {
            self._color = nil               // recompute color
            let parent  = self.resolveParent
            let done: Closure = {
                parent?.respectOrder()      // assume newly fetched zone knows its order

                self.columnarReport("   ->", self.unwrappedName)
                onCompletion?(parent)
            }
            
            if  let p = parent,
                !p.children.contains(self) {
                p.addChild(self)
            }
            
            if  parent == nil || !parent!.showingChildren {
                done()
            } else {
                parent?.needChildren()
                
                gBatches.children(.restore) { iSame in
                    FOREGROUND(canBeDirect: true) {
                        done()
                    }
                }
            }
        }
    }
    

    // MARK:- file persistence
    // MARK:-


    convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) {
        self.init(record: nil, databaseID: dbID)

        temporarilyIgnoreNeeds {
            setStorageDictionary(dict, of: kZoneType, into: dbID)
        }
    }

    
    func rootName(for type: ZStorageType) -> String? {
        switch type {
        case .favorites: return kFavoritesRootName
        case .lost:      return kLostAndFoundName
        case .trash:     return kTrashName
        case .graph:     return kRootName
        default:         return nil
        }
    }
    
    
    func updateRecordName(for type: ZStorageType) {
        if  let name = rootName(for: type),
            recordName != name {
            record = CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: name)) // change record name by relacing record
            
            updateCKRecordProperties() // transfer instance variables into record
            needSave()
            
            for child in children {
                child.parentZone = self // because record name is different, children must be pointed through a ck reference to new record created above
                
                child.needSave()
            }
        }
    }
    

    override func setStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) {
        if let       name = dict[.name] as? String { zoneName = name }

        super.setStorageDictionary(dict, of: iRecordType, into: iDatabaseID) // do this step last so the assignment above is NOT pushed to cloud

        if let childrenDicts: [ZStorageDictionary] = dict[.children] as! [ZStorageDictionary]? {
            for childDict: ZStorageDictionary in childrenDicts {
                let child = Zone(dict: childDict, in: iDatabaseID)

                child.temporarilyIgnoreNeeds {       // prevent needsSave caused by child's parent (intentionally) not being in childDict
                    addChild(child, at: nil)
                }
            }

            respectOrder()
        }

        if let traitsStore: [ZStorageDictionary] = dict[.traits] as! [ZStorageDictionary]? {
            for traitStore: ZStorageDictionary in traitsStore {
                let trait = ZTrait(dict: traitStore, in: iDatabaseID)

                trait.temporarilyIgnoreNeeds {       // prevent needsSave caused by child's parent (intentionally) not being in childDict
                    addTrait(trait)
                }
            }
        }
    }


    override func storageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true) -> ZStorageDictionary? {
        var dict            = super.storageDictionary(for: iDatabaseID, includeRecordName: includeRecordName) ?? ZStorageDictionary ()

        if  let   childDict = Zone.storageArray(for: children, from: iDatabaseID, includeRecordName: includeRecordName) {
            dict[.children] = childDict as NSObject?
        }

        if  let  traitsDict = Zone.storageArray(for: traitValues, from: iDatabaseID, includeRecordName: includeRecordName) {
            dict  [.traits] = traitsDict as NSObject?
        }

        return dict
    }


}
