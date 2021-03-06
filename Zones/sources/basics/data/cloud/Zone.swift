//
//  Zone.swift
//  Seriously
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

class Zone : ZRecord, ZIdentifiable, ZToolable {

	@objc dynamic var         parent : CKRecord.Reference?
	@objc dynamic var      zoneOrder :           NSNumber?
	@objc dynamic var      zoneCount :           NSNumber?
	@objc dynamic var     zoneAccess :           NSNumber?
	@objc dynamic var    zoneProgeny :           NSNumber?
	@objc dynamic var       zoneName :             String?
	@objc dynamic var       zoneLink :             String?
	@objc dynamic var      zoneColor :             String?
	@objc dynamic var     parentLink :             String?
	@objc dynamic var     zoneAuthor :             String?
	@objc dynamic var zoneAttributes :             String?
	var               hyperLinkMaybe :             String?
	var                   emailMaybe :             String?
	var                   assetMaybe :            CKAsset?
	var                   colorMaybe :             ZColor?
	var       		       noteMaybe :              ZNote?
	var               crossLinkMaybe :            ZRecord?
	var              parentZoneMaybe :               Zone?
	var               bookmarkTarget :               Zone? { return crossLink as? Zone }
	var                  destroyZone :               Zone? { return cloud?.destroyZone }
	var                    trashZone :               Zone? { return cloud?.trashZone }
	var                     manifest :          ZManifest? { return cloud?.manifest }
	var                       widget :         ZoneWidget? { return gWidgets.widgetForZone(self) }
	var                 widgetObject :      ZWidgetObject? { return widget?.widgetObject }
	var               linkDatabaseID :        ZDatabaseID? { return databaseID(from: zoneLink) }
	var                lowestExposed :                Int? { return exposed(upTo: highestExposed) }
	var               linkRecordName :             String? { return recordName(from: zoneLink) }
	override var           emptyName :             String  { return kEmptyIdea }
	override var         description :             String  { return unwrappedName }
	override var       unwrappedName :             String  { return zoneName ?? (isFavoritesRoot ? kFavoritesName : emptyName) }
	var                decoratedName :             String  { return decoration + unwrappedName }
	var                  clippedName :             String  { return !gShowToolTips ? "" : unwrappedName }
	var                        count :                Int  { return children.count }
	var     isACurrentDetailBookmark :               Bool  { return isCurrentFavorite || isCurrentRecent }
	var              isCurrentRecent :               Bool  { return self ==   gRecents.currentBookmark }
	var            isCurrentFavorite :               Bool  { return self == gFavorites.currentBookmark }
	var            onlyShowRevealDot :               Bool  { return showingChildren && ((isSmallMapHere && !(widget?.type.isMap ??  true)) || (kIsPhone && self == gHereMaybe)) }
	var              dragDotIsHidden :               Bool  { return                     (isSmallMapHere && !(widget?.type.isMap ?? false)) || (kIsPhone && self == gHereMaybe && showingChildren) } // hide favorites root drag dot
	var                hasZonesBelow :               Bool  { return hasAnyZonesAbove(false) }
	var                hasZonesAbove :               Bool  { return hasAnyZonesAbove(true) }
	var                 hasHyperlink :               Bool  { return hasTrait(for: .tHyperlink) && hyperLink != kNullLink }
	var                  hasSiblings :               Bool  { return parentZone?.count ?? 0 > 1 }
	var                   isSelected :               Bool  { return gSelecting.isSelected(self) }
	var                    isGrabbed :               Bool  { return gSelecting .isGrabbed(self) }
	var                    canTravel :               Bool  { return isBookmark || hasHyperlink || hasEmail || hasNote }
	var                     hasColor :               Bool  { return zoneColor != nil && zoneColor != "" }
	var                     hasEmail :               Bool  { return hasTrait(for: .tEmail) && email != "" }
	var                     hasAsset :               Bool  { return hasTrait(for: .tAssets) }
	var                      hasNote :               Bool  { return hasTrait(for: .tNote) }
	var                    isInTrash :               Bool  { return root?.isTrashRoot        ?? false }
	var                   isInBigMap :               Bool  { return root?.isBigMapRoot       ?? false }
	var                  isInRecents :               Bool  { return root?.isRecentsRoot      ?? false }
	var                isInFavorites :               Bool  { return root?.isFavoritesRoot    ?? false }
	var             isInLostAndFound :               Bool  { return root?.isLostAndFoundRoot ?? false }
	var                 isInSmallMap :               Bool  { return isInRecents || isInFavorites }
	var               isReadOnlyRoot :               Bool  { return isLostAndFoundRoot || isFavoritesRoot || isTrashRoot || type.isExemplar }
	var               spawnedByAGrab :               Bool  { return spawnedByAny(of: gSelecting.currentGrabs) }
	var                   spawnCycle :               Bool  { return spawnedByAGrab  || dropCycle }
	var             fetchedBookmarks :          ZoneArray  { return gBookmarks.bookmarks(for: self) ?? [] }
	var                     children =          ZoneArray  ()
	var                       traits =   ZTraitDictionary  ()

	var bookmarks : ZoneArray {
		return children.filter { (iZone) -> Bool in
			return iZone.isBookmark
		}
	}

	var allBookmarkProgeny : ZoneArray {
		var result = ZoneArray()

		traverseAllProgeny { iProgeny in
			if iProgeny.isBookmark {
				result.append(iProgeny)
			}
		}

		return result
	}

	var unwrappedNameWithEllipses : String {
		var   name = unwrappedName
		let length = name.length

		if (isInFavorites || isInRecents),
		   length > 15 {
			let first = name.substring(toExclusive: 7)
			let  last = name.substring(fromInclusive: length - 7)
			name      = first + kEllipsis + last
		}

		return name
	}

	var traitKeys   : [String] {
		var results = [String]()

		for key in traits.keys {
			results.append(key.rawValue)
		}

		return results
	}

	var type : ZWidgetType {
		if  let name = root?.recordName() {
			switch name {
				case kRecentsName:       return .tRecent
				case kExemplarName:      return .tExemplar
				case kFavoritesRootName: return .tFavorite
				default:                 break
			}
		}

		return .tMap
	}

	// MARK:- setup
	// MARK:-

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

	func recordName() -> String? { return recordName }
	func identifier() -> String? { return isARoot ? databaseID?.rawValue : recordName }
	func   toolName() -> String? { return clippedName }
	static func object(for id: String, isExpanded: Bool) -> NSObject? { return gRemoteStorage.maybeZoneForRecordName(id) }

	// MARK:- properties
	// MARK:-

	override var cloudProperties: [String] { return Zone.cloudProperties }
	override var optionalCloudProperties: [String] { return Zone.optionalCloudProperties }

	override class var cloudProperties: [String] {
		return optionalCloudProperties +
			super.cloudProperties
	}

	override class var optionalCloudProperties: [String] {
		return [#keyPath(parent),
				#keyPath(zoneName),
				#keyPath(zoneLink),
				#keyPath(zoneOrder),
				#keyPath(zoneCount),
				#keyPath(zoneColor),
				#keyPath(zoneAuthor),
				#keyPath(parentLink),
				#keyPath(zoneAccess),
				#keyPath(zoneProgeny),
				#keyPath(zoneAttributes)] +
			super.optionalCloudProperties
	}

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

	var ancestralPath: ZoneArray {
		var  results = ZoneArray()

		traverseAllAncestors { ancestor in
			results.append(ancestor)
		}

		return results.reversed()
	}

	var email: String? {
		get {
			if  emailMaybe == nil {
				emailMaybe  = getTraitText(for: .tEmail)
			}

			return emailMaybe
		}

		set {
			if  emailMaybe != newValue {
				emailMaybe  = newValue

				setTraitText (newValue, for: .tEmail)
			}
		}
	}

	var zonesWithNotes: ZoneArray {
		var    result = ZoneArray()

		traverseAllProgeny { zone in
			if  zone.hasTrait(for: .tNote) {
				result.append(zone)
			}
		}

		return result
	}

	var countOfNotes: Int {
		return zonesWithNotes.count
	}

	var currentNote: ZNote? {
		let zones = zonesWithNotes

		if  zones.count > 0 {
			return ZNote(zones[0])
		}

		return nil
	}

	var note: ZNote {
		if  isBookmark {
			return bookmarkTarget!.note
		} else if noteMaybe == nil || !hasTrait(matching: [.tNote, .tEssay]) {
			createNote()
		}

		return noteMaybe!
	}

	func destroyNote() {
		removeTrait(for: .tNote)

		noteMaybe = nil
	}

	func createNote() {
		let zones = zonesWithNotes
		let count = zones.count

		if  count > 1 && gCreateCombinedEssay {
			let  essay = ZEssay(self)
			noteMaybe = essay

			essay.setupChildren()
		} else if count == 0 || !gCreateCombinedEssay {
			noteMaybe = ZNote(self)
		} else {
			noteMaybe = ZNote(zones[0])
		}
	}

	var hyperLink: String? {
		get {
			if  hyperLinkMaybe == nil {
				hyperLinkMaybe  = getTraitText(for: .tHyperlink)
			}

			return hyperLinkMaybe
		}

		set {
			if  hyperLinkMaybe != newValue {
				hyperLinkMaybe  = newValue

				setTraitText(newValue, for: .tHyperlink)
			}
		}
	}

	var crumbRoot: Zone? {
		if  isBookmark {
			return bookmarkTarget?.crumbRoot
		}

		return self
	}

	var root: Zone? {
		var base: Zone?

		traverseAllAncestors { iZone in
			if  iZone.isARoot {
				base = iZone
			}
		}

		return base
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

		if isInRecents {
			d.append("R")
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
			if  !isARoot, !isFavoritesRoot, let p = parentZone, p != self, !p.spawnedBy(self) {
				return p.level + 1
			}

			return 0
		}
	}

	func toolColor() -> ZColor? { return color?.lighter(by: 3.0) }

	var textColor: ZColor? { return (gColorfulMode && colorized) ? color?.darker(by: 3.0) : gDefaultTextColor }

	var color: ZColor? {
		get {
			if !gColorfulMode { return gDefaultTextColor }

			var computed = colorMaybe

			if  colorMaybe == nil {
				if  let b = bookmarkTarget {
					return b.color
				} else if let c = zoneColor, c != "" {
					computed    = c.color
					colorMaybe  = computed
				} else if let p = parentZone, p != self, hasCompleteAncestorPath(toColor: true) {
					return p.color
				} else {
					computed    = kBlueColor
				}
			}

			if  gIsDark {
				computed        = computed?.inverted.lighter(by: 3.0)
			}

			return computed!
		}

		set {
			var computed = newValue

			if  gIsDark {
				computed = computed?.inverted
			}

			if  isBookmark {
				bookmarkTarget?.color  = newValue
			} else if      colorMaybe != computed {
				colorMaybe             = computed
				zoneColor              = computed?.string ?? ""

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
			if  let          b = bookmarkTarget {   // changing a bookmark changes its target
				b.colorized    = newValue           // when drawn, a bookmark gets its color from its target
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
			if  crossLinkMaybe == nil {
				if  zoneLink == kTrashLink {
					return gTrash
				}

				if  zoneLink == kLostAndFoundLink {
					return gLostAndFound
				}

				if  zoneLink?.contains("Optional(") ?? false { // repair consequences of an old, but now fixed, bookmark bug
					zoneLink = zoneLink?.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
				}

				crossLinkMaybe = zoneFrom(zoneLink)
			}

			return crossLinkMaybe
		}

		set {
			if newValue == nil {
				zoneLink = kNullLink
			} else {
				let    hasRef = newValue!.record != nil
				let reference = !hasRef ? "" : newValue!.recordName!
				zoneLink      = "\(newValue!.databaseID!.rawValue)::\(reference)"
			}

			crossLinkMaybe = nil
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
				parent                       != nil) &&
			canSaveWithoutFetch {
			needSave()
		}

		parent          = nil
		parentZoneMaybe = nil
		parentLink      = kNullLink
	}

	var resolveParent: Zone? {
		let     old = parentZoneMaybe
		parentZoneMaybe = nil
		let     new =  parentZone // recalculate _parentZone

		old?.removeChild(self)
		new?.addChildAndRespectOrder(self)

		return new
	}

	var parentZone: Zone? {
		get {
			if  isARoot {
				unlinkParentAndMaybeNeedSave()
			} else if parentZoneMaybe == nil {
				if  let     parentRef  = parent {
					parentZoneMaybe    = cloud?.maybeZoneForReference(parentRef)
				} else if let    zone  = zoneFrom(parentLink) {
					parentZoneMaybe    = zone
				}
			}

			return parentZoneMaybe
		}

		set {
			if  isARoot {
				unlinkParentAndMaybeNeedSave()
			} else if parentZoneMaybe      != newValue {
				parentZoneMaybe             = newValue
				if  parentZoneMaybe        == nil {
					unlinkParentAndMaybeNeedSave()
				} else if let parentRecord  = parentZoneMaybe?.record,
						  let      newParentDBID  = parentZoneMaybe?.databaseID {
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
			if let index = siblings.firstIndex(of: self) {
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

	var insertionIndex: Int? {
		if let index = siblingIndex {
			return index + (gListsGrowDown ? 1 : 0)
		}

		return nil
	}

	var canEditNow: Bool {   // workaround recently introduced change in become first responder invocation logic [aka: fucked it up]
		return !gRefusesFirstResponder
			&&  userWantsToEdit
			&&  userCanWrite
	}

	var userWantsToEdit: Bool {
		return [kTab, kSpace, kReturn, "-", "d", "e", "h"].contains(gCurrentKeyPressed)
			|| gCurrentKeyPressed?.arrow != nil
			|| gCurrentMouseDownZone     == self
	}

	// MARK:- write access
	// MARK:-

	var      inheritedAccess: ZoneAccess { return zoneWithInheritedAccess.directAccess }
	var       directReadOnly:       Bool { return directAccess == .eReadOnly || directAccess == .eProgenyWritable }
	var          userCanMove:       Bool { return userCanMutateProgeny   || isBookmark } // all bookmarks are movable because they are created by user and live in my databasse
	var         userCanWrite:       Bool { return userHasDirectOwnership || isIdeaEditable }
	var userCanMutateProgeny:       Bool { return userHasDirectOwnership || inheritedAccess != .eReadOnly }

	var userHasDirectOwnership: Bool {
		if  let    t = bookmarkTarget {
			return t.userHasDirectOwnership
		}

		return !isTrashRoot && !isFavoritesRoot && !isLostAndFoundRoot && !gPrintMode.contains(.dAccess) && (databaseID == .mineID || zoneAuthor == gAuthorID || gIsMasterAuthor)
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

	private var isIdeaEditable: Bool {    // this is a primitive, only called from userCanWrite
		if  let    t = bookmarkTarget {
			return t.isIdeaEditable
		} else if isReadOnlyRoot {
			return false
		} else if directAccess == .eWritable || databaseID != .everyoneID {
			return true
		} else if let p = parentZone, p != self, p.parentZone != self {
			return p.directAccess == .eProgenyWritable || p.isIdeaEditable
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

	// MARK:- edit map
	// MARK:-

	func duplicate() {
		var array = [self]

		array.duplicate()
	}

	func addBookmark() {
		if  databaseID != .favoritesID, !isARoot {
			var bookmark: Zone?

			if  gHere == self {
				revealParentAndSiblings()

				gHere = self.parentZone ?? gHere
			}

			self.invokeUsingDatabaseID(.mineID) {
				bookmark = gFavorites.createFavorite(for: self, action: .aBookmark)
			}

			bookmark?.grab()
			bookmark?.markNotFetched()
			gRedrawMaps()
		}
	}

	func revealParentAndSiblings() {
		if  let parent = parentZone {
			parent.revealChildren()
			parent.needChildren()
		} else {
			needParent()
		}
	}

	func addIdea() {
		if !isBookmark,
		   userCanMutateProgeny {
			revealChildren()
			addIdea(at: gListsGrowDown ? nil : 0) { iChild in
				gControllers.signalFor(self, regarding: .sRelayout) {
					gTemporarilySetMouseZone(iChild)
					iChild?.edit()
				}
			}
		}
	}

	func addNext(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
		if  let parent = parentZone, parent.userCanMutateProgeny {
			var  zones = gSelecting.currentGrabs

			let completion: ZoneClosure = { iZone in
				onCompletion?(iZone)

				if  onCompletion == nil {
					iZone.edit()
				}
			}

			if  containing {
				zones.sort { (a, b) -> Bool in
					return a.order < b.order
				}
			}

			if  self  == gHere {
				gHere  = parent

				parent.revealChildren()
			}

			var index   = siblingIndex

			if  index  != nil {
				index! += gListsGrowDown ? 1 : 0
			}

			parent.addIdea(at: index, with: name) { iChild in
				if  let child = iChild {
					if !containing {
						gRedrawMaps(for: parent) {
							completion(child)
						}
					} else {
						child.acquireZones(zones) {
							gRedrawMaps(for: parent) {
								completion(child)
							}
						}
					}
				}
			}
		}
	}

	func swapWithParent() {
		let scratchZone = Zone()

		// swap places with parent

		if  let grabbedI = siblingIndex,
			let   parent = parentZone,
			let  parentI = parent.siblingIndex,
			let   grandP = parent.parentZone {

			scratchZone.acquireZones(children) {
				self.moveZone(into: grandP, at: parentI, orphan: true) {
					self.acquireZones(parent.children) {
						parent.moveZone(into: self, at: grabbedI, orphan: true) {
							parent.acquireZones(scratchZone.children) {
								parent.needCount()
								parent.grab()

								if  gHere == parent {
									gHere  = self
								}

								gRedrawMaps(for: self)
							}
						}
					}
				}
			}
		}
	}

	func acquireZones(_ zones: ZoneArray, at iIndex: Int? = nil, orphan: Bool = true, onCompletion: Closure?) {
		revealChildren()
		needChildren()

		for     zone in zones {
			if  zone != self {
				if  orphan {
					zone.orphan()
				}

				addChild(zone, at: iIndex)
			}
		}

		children.updateOrder()
		maybeNeedSave()
		onCompletion?()
	}

	func addIdea(at iIndex: Int?, with name: String? = nil, onCompletion: ZoneMaybeClosure?) {
		if  let    dbID = databaseID,
			dbID       != .favoritesID {
			let newIdea = Zone(databaseID: dbID)

			parentZoneMaybe?.revealChildren()
			gTextEditor.stopCurrentEdit()

			if  name != nil {
				newIdea.zoneName   = name
			}

			if !gIsMasterAuthor,
			   dbID              == .everyoneID,
			   let       identity = gAuthorID {
				newIdea.zoneAuthor = identity
			}

			newIdea.markNotFetched()

			UNDO(self) { iUndoSelf in
				newIdea.deleteSelf() {
					onCompletion?(nil)
				}
			}

			ungrab()
			addAndReorderChild(newIdea, at: iIndex, { onCompletion?(newIdea) } )
		}
	}

	func deleteSelf(permanently: Bool = false, onCompletion: Closure?) {
		if  isARoot {
			onCompletion?() // deleting root would be a disaster
		} else {
			let parent = parentZone
			if  self == gHere {                         // this can only happen ONCE during recursion (multiple places, below)
				let recurse: Closure = {

					// //////////
					// RECURSE //
					// //////////

					self.deleteSelf(permanently: permanently, onCompletion: onCompletion)
				}

				if  let p = parent, p != self {
					gHere = p

					revealParentAndSiblings()
					recurse()
				} else {

					// ////////////////////////////////////////////////////////////////////////////////////////////
					// SPECIAL CASE: delete here but here has no parent ... so, go somewhere useful and familiar //
					// ////////////////////////////////////////////////////////////////////////////////////////////

					gRecents.refocus {                 // travel through current favorite, then ...
						if  gHere != self {
							recurse()
						}
					}
				}
			} else {
				let deleteBookmarksClosure: Closure = {
					if  let            p = parent, p != self {
						p.fetchableCount = p.count       // delete alters the count
					}

					// //////////
					// RECURSE //
					// //////////

					self.fetchedBookmarks.deleteZones(permanently: permanently) {
						onCompletion?()
					}
				}

				addToPaste()
				maybeRestoreParent()

				if  isInTrash {
					moveZone(to: destroyZone) {
						onCompletion?()
						deleteBookmarksClosure()
					}
				} else if !permanently {
					moveZone(to: trashZone) {
						deleteBookmarksClosure()
					}
				} else {
					concealAllProgeny()           // strip cloggers from gExpandedZones list
					traverseAllProgeny { iZone in
						if !iZone.isInTrash {
							iZone.needDestroy()   // gets written in file
							iZone.orphan()
							gManifest?.smartAppend(iZone)
							gRecents.pop(iZone)	  // avoid getting stuck on a zombie
						}
					}

					if  cloud?.cloudUnavailable ?? true {
						moveZone(to: destroyZone) {
							onCompletion?()
							deleteBookmarksClosure()
						}
					} else {
						deleteBookmarksClosure()
					}
				}
			}
		}
	}

	func addNextAndRedraw(containing: Bool = false, onCompletion: ZoneClosure? = nil) {
		gDeferRedraw {
			addNext(containing: containing) { iChild in
				gDeferringRedraw = false

				gRedrawMaps(for: self) {
					onCompletion?(iChild)
					iChild.edit()
				}
			}
		}
	}

	func tearApartCombine(_ intoParent: Bool, _ reversed: Bool) {
		if  intoParent {
			insertSelectedText()
		} else {
			createIdeaFromSelectedText(reversed)
		}
	}

	func insertSelectedText() {
		if  let     index = siblingIndex,
			let    parent = parentZone,
			let childName = widget?.textWidget.extractTitleOrSelectedText() {

			gTextEditor.stopCurrentEdit()

			gDeferRedraw {
				parent.addIdea(at: index, with: childName) { iChild in
					self.moveZone(to: iChild) {
						gRedrawMaps()

						gDeferringRedraw = false

						iChild?.edit()
					}
				}
			}
		}
	}

	func moveZone(into: Zone, at iIndex: Int?, orphan: Bool = false, onCompletion: Closure? = nil) {
		if  let parent = parentZone {
			let  index = siblingIndex

			UNDO(self) { iUndoSelf in
				self.moveZone(into: parent, at: index, orphan: orphan) { onCompletion?() }
			}
		}

		into.revealChildren()

		if  orphan {
			maybeRestoreParent()
			self.orphan() // remove from current parent
		}

		into.addAndReorderChild(self, at: iIndex)
		into.maybeNeedSave()
		maybeNeedSave()

		if !into.isInTrash { // so grab won't disappear
			grab()
		}

		onCompletion?()
	}

	func restoreParentFrom(_ root: Zone?) {
		root?.traverseProgeny { (iCandidate) -> (ZTraverseStatus) in
			if  iCandidate.children.contains(self) {
				self.parentZone = iCandidate

				return .eStop
			}

			return .eContinue
		}
	}

	func maybeRestoreParent() {
		if  root == nil || !isInBigMap {
			// look through all records for match to set parent
			if  !isInSmallMap {
				restoreParentFrom(  gRecents.rootZone)
				restoreParentFrom(gFavorites.rootZone)
			} else {
				restoreParentFrom(gRoot)
			}
		}
	}

	func moveZone(to iThere: Zone?, onCompletion: Closure? = nil) {
		guard let there = iThere else {
			onCompletion?()

			return
		}

		if !there.isBookmark {
			moveZone(into: there, at: gListsGrowDown ? nil : 0, orphan: true) {
				onCompletion?()
			}
		} else if !there.isABookmark(spawnedBy: self) {

			// ///////////////////////////////
			// MOVE ZONE THROUGH A BOOKMARK //
			// ///////////////////////////////

			var     movedZone = self
			let    targetLink = there.crossLink
			let       sameMap = databaseID == targetLink?.databaseID
			let grabAndTravel = {
				there.travelThrough() { object, kind in
					let there = object as! Zone

					movedZone.moveZone(into: there, at: gListsGrowDown ? nil : 0) {
						movedZone.recursivelyApplyDatabaseID(targetLink?.databaseID)
						movedZone.grab()
						onCompletion?()
					}
				}
			}

			movedZone.orphan()

			if  sameMap {
				grabAndTravel()
			} else {
				movedZone.needDestroy()

				movedZone = movedZone.deepCopy

				gRedrawMaps {
					grabAndTravel()
				}
			}
		}
	}

	func importFromFile(_ type: ZExportType, onCompletion: Closure?) {
		if  type == .eSeriously {
			ZFiles.presentOpenPanel() { (iAny) in
				if  let url = iAny as? URL {
					self.importFile(from: url.path, onCompletion: onCompletion)
				} else if let panel = iAny as? NSPanel {
					let  suffix = type.rawValue
					panel.title = "Import as \(suffix)"
					panel.setAllowedFileType(suffix)
				}
			}
		}
	}

	func importFile(from path: String, onCompletion: Closure?) {
		do {
			if  let   data = FileManager.default.contents(atPath: path),
				data.count > 0,
				let   dbID = databaseID,
				let   json = try JSONSerialization.jsonObject(with: data) as? ZStringObjectDictionary {
				let   dict = self.dictFromJSON(json)
				let   zone = Zone(dict: dict, in: dbID)

				addChild(zone, at: 0)
				onCompletion?()
			}
		} catch {
			printDebug(.dError, "\(error)")    // de-serialization
		}
	}

	// MARK:- convenience
	// MARK:-

	func        addToPaste() { gSelecting   .pasteableZones[self] = (parentZone, siblingIndex) }
	func        addToGrabs() { gSelecting.addMultipleGrabs([self]) }
	func ungrabAssuringOne() { gSelecting.ungrabAssuringOne(self) }
	func            ungrab() { gSelecting           .ungrab(self) }
	func       focusRecent() { focusOn() { gRedrawMaps() } }
	func editTrait(for iType: ZTraitType) { gTextEditor.edit(traitFor(iType)) }

	@discardableResult func edit() -> ZTextEditor? {
		gTemporarilySetMouseZone(self) // so become first responder will work

		return gTextEditor.edit(self)
	}

	func resolveAndSelect(_ searchText: String?) {
		gHere = self

		revealChildren()
		gControllers.swapMapAndEssay(force: .mapMode)
		gRedrawMaps()

		let e = edit()

		FOREGROUND(after: 0.2) {
			e?.selectText(searchText)
		}
	}

	func grab(updateBrowsingLevel: Bool = true) {
		gTextEditor.stopCurrentEdit(andRedraw: false)
		printDebug(.dEdit, " GRAB    \(unwrappedName)")
		gSelecting.grab([self], updateBrowsingLevel: updateBrowsingLevel)
	}

	func asssureIsVisibleAndGrab(updateBrowsingLevel: Bool = true) {
		gShowSmallMap = kIsPhone && isInSmallMap

		asssureIsVisible()
		grab(updateBrowsingLevel: updateBrowsingLevel)
	}

	func dragDotClicked(_ COMMAND: Bool, _ SHIFT: Bool, _ CLICKTWICE: Bool) {
		if  COMMAND || (CLICKTWICE && isGrabbed) {
			grab() // narrow selection to just this one zone

			if !(CLICKTWICE && self == gHere) {
				gRecents.maybeRefocus(.eSelected) {
					gRedrawMaps()
				}
			}
		} else if isGrabbed && gCurrentlyEditingWidget == nil {
			ungrabAssuringOne()
		} else if SHIFT {
			addToGrabs()
		} else {
			grab()
		}

		gRedrawMaps(for: self)
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

	func editAndSelect(range: NSRange? = nil) {
		edit()
		FOREGROUND(canBeDirect: true) {
			let newRange = range ?? NSRange(location: 0, length: self.zoneName?.length ?? 0)

			self.widget?.textWidget.selectCharacter(in: newRange)
		}
	}

	func clearColor() {
		zoneColor = ""
		colorMaybe    = nil

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

	func hasTrait(matching iTypes: [ZTraitType]) -> Bool {
		for type in iTypes {
			if  hasTrait(for: type) {
				return true
			}
		}

		return false
	}

	func hasTrait(for iType: ZTraitType) -> Bool {
		if isBookmark {
			return bookmarkTarget?.hasTrait(for: iType) ?? false
		} else {
			return traits[iType] != nil
		}
	}

	func getTraitText(for iType: ZTraitType) -> String? {
		return traits[iType]?.text
	}

	func setTraitText(_ iText: String?, for iType: ZTraitType?) {
		if  let       type = iType {
			if  let   text = iText {
				let  trait = traitFor(type)
				trait.text = text

				trait.maybeNeedSave()
			} else {
				traits[type]?.needDestroy()

				traits[type] = nil
			}

			switch (type) {
				case .tEmail:     emailMaybe     = nil
				case .tHyperlink: hyperLinkMaybe = nil
				default: break
			}
		}
	}

	var assets: [CKAsset]? {
		get {
			return traits[.tAssets]?.assets
		}

		set {
			if  let        a = newValue {
				let    trait = traitFor(.tAssets)
				trait.assets = a

				trait.maybeNeedSave()
			} else {
				traits[.tAssets]?.needDestroy()

				traits[.tAssets] = nil
			}
		}
	}

	func traitFor(_ iType: ZTraitType) -> ZTrait {
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

	func removeTrait(for iType: ZTraitType) {
		let     trait = traits[iType]
		traits[iType] = nil

		trait?.needDestroy()
		needSave()
	}

	func showNote() {
		gCreateCombinedEssay = false
		gCurrentEssay        = note

		gControllers.swapMapAndEssay(force: .noteMode)
	}

	// MARK:- travel / focus / move
	// MARK:-

	@discardableResult func focusThrough(_ atArrival: @escaping Closure) -> Bool {
		if  isBookmark {
			if  isInSmallMap {
				let targetParent = bookmarkTarget?.parentZone

				targetParent?.revealChildren()
				targetParent?.needChildren()
				travelThrough { (iObject: Any?, iKind: ZSignalKind) in
					gRecents.updateCurrentRecent()
					gFavorites.updateAllFavorites(iObject as? Zone)
					atArrival()
				}

				return true
			} else if let dbID = crossLink?.databaseID {
				gDatabaseID = dbID

				gRecents.maybeRefocus {
					gHere.grab()
					atArrival()
				}

				return true
			}

			performance("bookmark with bad db crosslink")
		}

		return false
	}

	func travelThrough(atArrival: @escaping SignalClosure) {
		if  let  targetZRecord = crossLink,
			let     targetDBID = targetZRecord.databaseID,
			let   targetRecord = targetZRecord.record {
			let targetRecordID = targetRecord.recordID
			let        iTarget = bookmarkTarget

			let complete : SignalClosure = { (iObject, iKind) in
				self.showTopLevelFunctions()
				atArrival(iObject, iKind)
			}

			var there: Zone?

			if  isInFavorites {
				gFavorites.currentBookmark = self
			} else if isInRecents {
				gRecents.currentBookmark   = self
			}

			if  let target = iTarget, target.spawnedBy(gHereMaybe) {
				if !target.isGrabbed {
					target.asssureIsVisible()
					target.grab()
				} else {
					gHere = target

					gRecents.push()
				}

				gShowSmallMap = targetDBID.isSmallMapDB

				complete(target, .sRelayout)
			} else {
				gShowSmallMap = targetDBID.isSmallMapDB

				if  gDatabaseID != targetDBID {
					gDatabaseID  = targetDBID

					// ///////////////////////// //
					// TRAVEL TO A DIFFERENT MAP //
					// ///////////////////////// //

					if  let target = iTarget, target.isFetched { // e.g., default root favorite
						gRecents.maybeRefocus(.eSelected) {
							gHere  = target

							gHere.prepareForArrival()
							complete(gHere, .sRelayout)
						}
					} else {
						gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
							if  let hereRecord = iRecord,
								let    newHere = gCloud?.zoneForRecord(hereRecord) {
								gHere          = newHere

								newHere.prepareForArrival()
								gRecents.maybeRefocus {
									complete(newHere, .sRelayout)
								}
							} else {
								complete(gHere, .sRelayout)
							}
						}
					}
				} else {

					// /////////////// //
					// STAY WITHIN MAP //
					// /////////////// //

					there = gCloud?.maybeZoneForRecordID(targetRecordID)
					let grabbed = gSelecting.firstSortedGrab
					let    here = gHere

					UNDO(self) { iUndoSelf in
						self.UNDO(self) { iRedoSelf in
							self.travelThrough(atArrival: complete)
						}

						gHere = here

						grabbed?.grab()
						complete(here, .sRelayout)
					}

					let grabHere = {
						gHereMaybe?.prepareForArrival()
						complete(gHereMaybe, .sRelayout)
					}

					if  there != nil {
						gHere = there!

						grabHere()
					} else if gCloud?.databaseID != .favoritesID { // favorites does not have a cloud database
						gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
							if  let hereRecord = iRecord,
								let    newHere = gCloud?.zoneForRecord(hereRecord) {
								gHere          = newHere

								grabHere()
							}
						}
					} // else ... favorites id with an unresolvable bookmark target
				}
			}
		}
	}

	func focusOn(_ atArrival: @escaping Closure) {
		gHere = self // side-effect does recents push

		gRecents.maybeRefocus(.eSelected) {
			self.grab()
			gSmallMapController?.update()
			atArrival()
		}
	}

	func invokeTravel(onCompletion: Closure? = nil) {
		if !invokeBookmark(onCompletion: onCompletion),
		   !invokeHyperlink(),
		   !invokeEssay() {
			invokeEmail()
		}
	}

	@discardableResult func invokeBookmark(onCompletion: Closure?) -> Bool { // false means not traveled
		if  isBookmark {
			travelThrough() { object, kind in
				#if os(iOS)
				gActionsController.alignView()
				#endif
				onCompletion?()
			}

			return true
		}

		return false
	}

	@discardableResult func invokeHyperlink() -> Bool { // false means not traveled
		if  let link = hyperLink,
			link    != kNullLink {
			link.openAsURL()

			return true
		}

		return false
	}

	@discardableResult func invokeEssay() -> Bool { // false means not handled
		if  hasNote {
			grab()

			gCurrentEssay = note

			gControllers.swapMapAndEssay()

			return true
		}

		return false
	}

	@discardableResult func invokeEmail() -> Bool { // false means not traveled
		if  let  link = email {
			let email = "mailTo:" + link
			email.openAsURL()

			return true
		}

		return false
	}

	func setAsSmallMapHereZone() {
		if  let r = root {
			if  r.isFavoritesRoot {
				gFavorites.hereZoneMaybe = self
			} else {
				gRecents  .hereZoneMaybe = self
			}
		}
	}

	func revealSiblings(untilReaching iAncestor: Zone) {
		[self].recursivelyRevealSiblings(untilReaching: iAncestor) { iZone in
			if     iZone != self {
				if iZone == iAncestor {
					gHere = iAncestor // side-effect does recents push

					gHere.grab()
				}

				gSmallMapController?.update()
				gRedrawMaps()
			}
		}
	}

	func moveSelectionOut(extreme: Bool = false, onCompletion: Closure?) {

		if extreme {
			if  gHere.isARoot {
				gHere = self // reverse what the last move out extreme did
			} else {
				let here = gHere // revealZonesToRoot (below) changes gHere, so nab it first

				grab()
				revealZonesToRoot() {
					here.revealSiblings(untilReaching: gRoot!)
					onCompletion?()
				}
			}
		} else if let p = parentZone {
			if  self == gHere {
				revealParentAndSiblings()
				revealSiblings(untilReaching: p)
			} else {
				if  isInBigMap {
					p.revealChildren()
					p.needChildren()
				} else if let g = p.parentZone { // narrow: hide children and set here zone to parent
					p.concealChildren()
					g.revealChildren()
					g.setAsSmallMapHereZone()
					// FUBAR: parent sometimes disappears!!!!!!!!!
				}

				p.grab()
				gSignal([.sCrumbs])
			}
		} else {
			// self is an orphan
			// change focus to bookmark of self

			if  let bookmark = self.fetchedBookmark {
				gHere        = bookmark
			}
		}
	}

	func revealZonesToRoot(_ onCompletion: Closure?) {
		if  isARoot {
			onCompletion?()
		} else {
			var needOp = false

			traverseAncestors { iZone -> ZTraverseStatus in
				if  let parentZone = iZone.parentZone, !parentZone.isFetched {
					iZone.needRoot()

					needOp = true

					return .eStop
				}

				return .eContinue
			}

			if let root = gRoot, !needOp {
				gHere = root

				onCompletion?()
			} else {
				gBatches.root { iSame in
					onCompletion?()
				}
			}
		}
	}

	func moveSelectionInto(extreme: Bool = false, onCompletion: Closure?) {
		var needReveal = false
		var      child = self
		var     invoke = {}

		invoke = {
			needReveal = needReveal || !child.showingChildren

			child.revealChildren()

			if  child.count > 0,
				let grandchild = gListsGrowDown ? child.children.last : child.children.first {
				grandchild.grab()

				if  child.isInSmallMap { // narrow, so hide parent
					child.setAsSmallMapHereZone()
				} else if extreme {
					child = grandchild

					invoke()
				}
			}
		}

		invoke()
		onCompletion?()

		if !needReveal {
			gSignal([.sCrumbs])
		}
	}

	// MARK:- traverse ancestors
	// MARK:-

	func hasCompleteAncestorPath(toColor: Bool = false, toWritable: Bool = false) -> Bool {
		var      isComplete = false
		var ancestor: Zone?

		traverseAllAncestors { iZone in
			let  isReciprocal = ancestor == nil  || iZone.children.contains(ancestor!)

			if  (isReciprocal && iZone.isARoot) || (toColor && iZone.hasColor) || (toWritable && iZone.directAccess != .eInherit) {
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
		if  let dbID = databaseID,
			let goal = gRemoteStorage.cloud(for: dbID)?.currentHere {

			traverseAncestors { iAncestor -> ZTraverseStatus in
				if  iAncestor != self {
					iAncestor.revealChildren()
				}

				if  iAncestor == goal {
					return .eStop
				}

				return .eContinue
			}
		}
	}

	func assureAdoption() {
		traverseAllAncestors { ancestor in
			ancestor.needAdoption()
		}

		gRemoteStorage.assureNoOrphanIdeas()
	}

	func spawnedBy(_ iZone: Zone?) -> Bool { return iZone == nil ? false : spawnedByAny(of: [iZone!]) }
	func traverseAncestors(_ block: ZoneToStatusClosure) { safeTraverseAncestors(visited: [], block) }

	func spawnedByAny(of iZones: ZoneArray) -> Bool {
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

	func safeTraverseAncestors(visited: ZoneArray, _ block: ZoneToStatusClosure) {
		if  block(self) == .eContinue,  //       skip == stop
			!isARoot,                   //    isARoot == stop
			!visited.contains(self),    //  map cycle == stop
			let p = parentZone {        // nil parent == stop
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

	@discardableResult func safeTraverseProgeny(visited: ZoneArray, _ block: ZoneToStatusClosure) -> ZTraverseStatus {
		var status  = block(self)

		if  status == .eContinue {
			for child in children {
				if  visited.contains(child) {
					break						// do not traverse further inward
				}

				status = child.safeTraverseProgeny(visited: visited + [self], block)

				if  status == .eStop {
					break						// halt traversal
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

	func exposedProgeny(at iLevel: Int) -> ZoneArray {
		var     progeny = ZoneArray()
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

	private func safeHasAnyZonesAbove(_ iAbove: Bool, _ visited: ZoneArray) -> Bool {
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

	func closestCommonParent(of other: Zone) -> Zone? {
		var ancestors = [self]
		var common: Zone?

		if  databaseID == other.databaseID {
			traverseAllAncestors { zone in
				if  zone != self {
					ancestors.append(zone)
				}
			}

			if  ancestors.contains(other) {
				common = other
			} else {
				other.traverseAllAncestors { zone in
					if  ancestors.contains(zone),
						common == nil {
						common  = zone
					}
				}
			}
		}

		return common
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

	override var isAdoptable: Bool { return parent != nil || parentLink != nil }

	// adopt recursively

	override func adopt(moveOrphansToLost: Bool = false) {
		if  isARoot {
			removeState(.needsAdoption)
		} else if !needsDestroy, needsAdoption {
			if let p = parentZone, p != self {
				p.maybeMarkNotFetched()
				p.addChildAndRespectOrder(self)
				removeState(.needsAdoption)

				if  p.parentZone == nil, !p.isARoot {
					p.needAdoption()
					p.adopt() // recurse on ancestor
				}
			} else if moveOrphansToLost, let r = record, r.isOrphaned {
				gLostAndFound?.addChild(self)
				removeState(.needsAdoption)
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

	func addAndReorderChild(_ iChild: Zone?, at iIndex: Int? = nil, _ afterAdd: Closure? = nil) {
		if  let child = iChild,
			addChild(child, at: iIndex, afterAdd) != nil {
			children.updateOrder()
			maybeNeedSave()
		}
	}

	func validIndex(from iIndex: Int?) -> Int {
		var index = iIndex ?? (gListsGrowDown ? count : 0)

		if  index < 0 {
			index = 0
		}

		return index   // count is bottom, 0 is top
	}

	@discardableResult func addChild(_ iChild: Zone? = nil, at iIndex: Int? = nil, _ afterAdd: Closure? = nil) -> Int? {
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

						afterAdd?()

						return insertAt
					}
				}
			}

			if  insertAt < count {
				children.insert(child, at: insertAt)
			} else {
				children.append(child)
			}

			afterAdd?()
			maybeNeedSave()
			needCount()

			return insertAt
		}

		return nil
	}

	@discardableResult func removeChild(_ iChild: Zone?) -> Bool {
		if  let child = iChild, let index = children.firstIndex(of: child) {
			children.remove(at: index)

			needCount()

			return true
		}

		return false
	}

	func createIdeaFromSelectedText(_ asNewParent: Bool) {
		if  let newName  = widget?.textWidget.extractTitleOrSelectedText() {

			gTextEditor.stopCurrentEdit()

			if  newName == zoneName {
				combineIntoParent()
			} else {
				gDeferRedraw {
					if  asNewParent {
						parentZone?.addNextAndRedraw(containing: true) { iChild in
							iChild.zoneName = newName
						}
					} else {
						addIdea(at: gListsGrowDown ? nil : 0, with: newName) { iChild in
							gDeferringRedraw = false

							if  let child = iChild {
								self.revealChildren()
								gRedrawMaps(for: self) {
									child.editAndSelect()
								}
							}
						}
					}
				}
			}
		}
	}

	func combineIntoParent() {
		if  let      parent = parentZone,
			let    original = parent.zoneName {
			let   childName = zoneName ?? ""
			let childLength = childName.length
			let    combined = original.stringBySmartly(appending: childName)
			let       range = NSMakeRange(combined.length - childLength, childLength)
			parent.zoneName = combined
			parent.extractTraits  (from: self)
			parent.extractChildren(from: self)

			gDeferRedraw {
				self.moveZone(to: gTrash)

				gDeferringRedraw = false

				gRedrawMaps(for: parent) {
					parent.editAndSelect(range: range)
				}
			}
		}
	}

	func applyGenerationally(_ show: Bool, extreme: Bool = false) {
		var goal: Int?

		if !show {
			goal = extreme ? level - 1 : highestExposed - 1
		} else if  extreme {
			goal = Int.max
		} else if let lowest = lowestExposed {
			goal = lowest + 1
		}

		generationalUpdate(show: show, to: goal) {
			gRedrawMaps(for: self)
		}
	}

	func expand(_ show: Bool) {
		generationalUpdate(show: show) {
			gRedrawMaps(for: self)
		}
	}

	func generationalUpdate(show: Bool, to iLevel: Int? = nil, onCompletion: Closure?) {
		recursiveUpdate(show, to: iLevel) {

			// ////////////////////////////////////////////////////////
			// delay executing this until the last time it is called //
			// ////////////////////////////////////////////////////////

			onCompletion?()
		}
	}

	func recursiveUpdate(_ show: Bool, to iLevel: Int?, onCompletion: Closure?) {
		if !show && isGrabbed && (count == 0 || !showingChildren) {

			// ///////////////////////////////
			// COLLAPSE OUTWARD INTO PARENT //
			// ///////////////////////////////

			concealAllProgeny()

			revealParentAndSiblings()

			if  let parent = parentZone, parent != self {
				if  gHere == self {
					gHere  = parent
				}

				parent.recursiveUpdate(show, to: iLevel) {
					parent.grab()
					onCompletion?()
				}
			} else {
				onCompletion?()
			}
		} else {

			// /////////////////
			// ALTER CHILDREN //
			// /////////////////

			let  goal = iLevel ?? level + (show ? 1 : -1)
			let apply = {
				self.traverseAllProgeny { iChild in
					if           !iChild.isBookmark {
						if        iChild.level >= goal && !show {
							iChild.concealChildren()
						} else if iChild.level  < goal &&  show {
							iChild.revealChildren()
						}
					}
				}

				if  show {
					if  self.isInFavorites {
						gFavorites.updateAllFavorites()
					}

					if  self.isInRecents {
						gRecents.swapBetweenBookmarkAndTarget()
					}
				}

				onCompletion?()
			}

			if !show {
				gSelecting.deselectGrabsWithin(self);
			}

			apply()
		}
	}

	func extractChildren(from: Zone) {
		for child in from.children.reversed() {
			child.orphan()
			addChild(child)
		}
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

					oldRecord?.copy(to: iZone.record, properties: iZone.cloudProperties)  // preserve new record id
					iZone.needSave()                                                        // in new id's record manager

					// /////////////////////////////////////////////////////////////////
					// (2) compute parent and parentLink using iZone's new databaseID //
					//     a subsequent traverse will eventually use it (1, above)    //
					// /////////////////////////////////////////////////////////////////

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

	func reverseChildren() {
		children.reverse()
		respectOrder()
		gRedrawMaps()
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
			child           = gCloud?.zoneForRecord(childRecord)

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
			var     holders = ZoneArray ()

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
		let  margin = kSpace * (4 * iInset)
		let    type = ZOutlineLevelType(rawValue: indices.character(at: iInset % modulus))
		let  letter = String.character(at: iIndex, for: type!)
		var  string = margin + letter + marks.character(at: (iInset / modulus) % marks.count) + " " + unwrappedName + kReturn

		for (index, child) in children.enumerated() {
			string += child.outlineString(for: iInset + 1, at: index)
		}

		return string
	}

	func selectAll(progeny: Bool = false) {
		if progeny {
			gSelecting.ungrabAll()

			traverseAllProgeny { iChild in
				iChild.addToGrabs()
			}
		} else {
			if  count == 0 {
				if  let parent = parentZone {
					parent.selectAll(progeny: progeny)
				}

				return // selection has not changed
			}

			if  showingChildren {
				gSelecting.ungrabAll(retaining: children)
			} else {
				return // selection does not show its children
			}
		}

		gRedrawMaps(for: self)
	}

	// MARK:- dots
	// MARK:-

	func revealDotClicked(COMMAND: Bool, OPTION: Bool) {
		gTextEditor.stopCurrentEdit()

		// ungrab progeny
		for     grabbed in gSelecting.currentGrabs {
			if  grabbed != self && grabbed.spawnedBy(self) {
				grabbed.ungrab()
			}
		}

		if  canTravel && (COMMAND || (fetchableCount == 0 && count == 0)) {
			invokeTravel() { // email, hyperlink, bookmark, essay
				gRedrawMaps()
			}
		} else {
			let show = !showingChildren

			if  isInBigMap {

				// //////////////////////////
				// generational visibility //
				// //////////////////////////

				generationalUpdate(show: show) {
					gRedrawMaps(for: self)
				}
			} else if !isSmallMapRoot {

				// //////////////////////////////////////////////////////////
				// avoid annoying user: treat small map non-generationally //
				// //////////////////////////////////////////////////////////

				toggleChildrenVisibility()

				let newHere = showingChildren ? self : parentZone

				newHere?.revealChildren()

				if  isInFavorites {
					gFavoritesHereMaybe = newHere
				} else {
					gRecentsHereMaybe   = newHere
				}

				gRedrawMaps()
			}
		}
	}

	func dotParameters(_ isFilled: Bool, _ isReveal: Bool) -> ZDotParameters {
		let traits    = traitKeys
		var p         = ZDotParameters()
		p.isDrop      = self == gDragDropZone
		p.accessType  = directAccess == .eProgenyWritable ? .sideDot : .vertical
		p.showSideDot = isACurrentDetailBookmark
		p.isBookmark  = isBookmark
		p.showAccess  = hasAccessDecoration
		p.showList    = showingChildren
		p.color       = type.isExemplar ? gHelpHyperlinkColor : gColorfulMode ? (color ?? gDefaultTextColor) : gDefaultTextColor
		p.childCount  = (gCountsMode == .progeny) ? progenyCount : indirectCount
		p.traitType   = (traits.count < 1) ? "" : traits[0]
		p.filled      = isFilled
		p.fill        = isFilled ? p.color.lighter(by: 2.5) : gBackgroundColor
		p.isReveal    = isReveal

		return p
	}

	func dropDotParameters() -> ZDotParameters {
		var      p = dotParameters(true, true)
		p.fill     = gActiveColor
		p.isReveal = true

		return p
	}

	// MARK:- lines and titles
	// MARK:-

	func convertToTitledLine() {
		zoneName  = kHalfLineOfDashes + " " + unwrappedName + " " + kHalfLineOfDashes
		colorized = true
	}

	func surround(by: String) -> Bool {
		let     range = gTextEditor.selectedRange
		let      text = gTextEditor.string

		if  range.length > 0 {
			var     t = text.substring(with: range)
			var     a = text.substring(  toExclusive: range.lowerBound)
			var     b = text.substring(fromInclusive: range.upperBound)
			var     o = 1                               // 1 means add it
			let    aa = by.isOpposite ? by.opposite : by
			let    bb = by.isOpposite ? by          : by.opposite
			let  aHas = a.hasSuffix(aa) || a.hasSuffix(bb)
			let  bHas = b.hasPrefix(aa) || b.hasPrefix(bb)

			if !aHas {    								// if it is NOT already there
				a     = a + aa                          // add it
				b     = bb + b
			} else {
				a     = a.substring(  toExclusive: a.length - 1)
				o     = -1                              // -1 means remove it

				if  bHas {
					b = b.substring(fromInclusive: 1)
				}
			}

			t         = a + t + b
			let     r = NSRange(location: range.location + o, length: range.length)
			zoneName  = t

			gTextEditor.updateText(inZone: self, isEditing: true)
			widget?.textWidget.updateGUI()
			editAndSelect(range: r)

			return true
		}

		return false
	}

	func convertToFromLine() -> Bool {
		if  let childName = widget?.textWidget.extractTitleOrSelectedText(requiresAllOrTitleSelected: true) {
			var location = 12

			if  zoneName != childName {
				zoneName  = childName
				colorized = false
				location  = 0
			} else {
				convertToTitledLine()
			}

			gTextEditor.stopCurrentEdit()
			editAndSelect(range: NSMakeRange(location,  childName.length))

			return true
		}

		return false
	}

	func convertFromLineWithTitle() {
		if  let childName = widget?.textWidget.extractedTitle {
			zoneName  = childName
			colorized = false
		}
	}

	// MARK:- progeny counts
	// MARK:-

	func updateAllProgenyCounts(_ iVisited: ZoneArray = []) {
		if !iVisited.contains(self) {
			let visited = iVisited + [self]
			var counter = 0

			for child in children {
				if  child.isBookmark {
					counter += 1
				} else {
					child.updateAllProgenyCounts(visited) // recurse (hitting every progeny)

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

	// add to map

	func addToParent(_ onCompletion: ZoneMaybeClosure? = nil) {
		FOREGROUND(canBeDirect: true) {
			self.colorMaybe = nil               // recompute color
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

			done()
		}
	}

	// MARK:- contextual menu
	// MARK:-

	func handleContextualMenuKey(_ key: String){
		gTemporarilySetMouseZone(self)

		if  let arrow = key.arrow {
			switch arrow {
				case .left:  applyGenerationally(false)
				case .right: applyGenerationally(true)
				default:     break
			}
		} else {
			switch key {
				case "a":     children.alphabetize()
				case "b":     addBookmark()
				case "c":     break
				case "d":     duplicate()
				case "e":     editTrait(for: .tEmail)
				case "h":     editTrait(for: .tHyperlink)
				case "k":     break
				case "m":     children.sortByLength()
				case "n":     showNote()
				case "o":     importFromFile(.eSeriously) { gRedrawMaps(for: self) }
				case "p":     break
				case "r":     reverseChildren()
				case "s":     exportToFile(.eSeriously)
				case "t":     swapWithParent()
				case "/":     focusRecent()
				case "_":     break
				case kEquals: break
				case kSpace:  addIdea()
				case "\u{08}",                                      // control-delete?
					 kDelete:      deleteSelf { gRedrawMaps() }
				default:      break
			}
		}
	}

	// MARK:- file persistence
	// MARK:-

	convenience init(dict: ZStorageDictionary, in dbID: ZDatabaseID) {
		self.init(record: nil, databaseID: dbID)

		temporarilyIgnoreNeeds {
			do {
				try extractFromStorageDictionary(dict, of: kZoneType, into: dbID)
			} catch {
				printDebug(.dError, "\(error)")    // de-serialization
			}
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

			needSave()

			for child in children {
				child.parentZone = self // because record name is different, children must be pointed through a ck reference to new record created above

				child.needSave()
			}
		}
	}

	override func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) throws {
		if  let name = dict[.name] as? String { zoneName = name }

		try super.extractFromStorageDictionary(dict, of: iRecordType, into: iDatabaseID) // do this step last so the assignment above is NOT pushed to cloud

		if  let childrenDicts: [ZStorageDictionary] = dict[.children] as! [ZStorageDictionary]? {
			for childDict: ZStorageDictionary in childrenDicts {
				let child = Zone(dict: childDict, in: iDatabaseID)

				cloud?.temporarilyIgnoreAllNeeds() { // prevent needsSave caused by child's parent (intentionally) not being in childDict
					addChild(child, at: nil)
				}
			}

			respectOrder()
		}

		if  let traitsStore: [ZStorageDictionary] = dict[.traits] as! [ZStorageDictionary]? {
			for  traitStore:  ZStorageDictionary in traitsStore {
				let    trait = try ZTrait(dict: traitStore, in: iDatabaseID)

				if  gPrintMode.contains(.dNotes),
					let   tt = trait.type,
					let type = ZTraitType(rawValue: tt),
					type    == .tNote {
					printDebug(.dNotes, "trait (in " + (zoneName ?? kUnknown) + ") --> " + (trait.format ?? "empty"))
				}

				cloud?.temporarilyIgnoreAllNeeds {       // prevent needsSave caused by trait (intentionally) not being in traits
					addTrait(trait)
				}
			}
		}
	}

	override func createStorageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> ZStorageDictionary? {
		guard record != nil else {
			printDebug(.dFile, "\(self) has no record")

			return nil
		}

		var dict             = try super.createStorageDictionary(for: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) ?? ZStorageDictionary ()

		if  (includeInvisibles || showingChildren),
			let childrenDict = try (children as [ZRecord]).createStorageArray(from: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
			dict [.children] = childrenDict as NSObject?
		}

		if  let   traitsDict = try (traitValues as [ZRecord]).createStorageArray(from: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
			dict   [.traits] = traitsDict as NSObject?
		}

		return dict
	}

}
