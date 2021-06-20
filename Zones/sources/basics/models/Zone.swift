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

@objc(Zone)
class Zone : ZRecord, ZIdentifiable, ZToolable {

	@NSManaged    var         zoneOrder :           NSNumber?
	@NSManaged    var         zoneCount :           NSNumber?
	@NSManaged    var        zoneAccess :           NSNumber?
	@NSManaged    var       zoneProgeny :           NSNumber?
	@NSManaged    var         parentRID :             String?
	@NSManaged    var          zoneName :             String?
	@NSManaged    var          zoneLink :             String?
	@NSManaged    var         zoneColor :             String?
	@NSManaged    var        parentLink :             String?
	@NSManaged    var        zoneAuthor :             String?
	@NSManaged    var    zoneAttributes :             String?
	var              videoFileNameMaybe :             String?
	var                  hyperLinkMaybe :             String?
	var                      emailMaybe :             String?
	var                      assetMaybe :            CKAsset?
	var                      colorMaybe :             ZColor?
	var                       noteMaybe :              ZNote?
	var                  crossLinkMaybe :            ZRecord?
	var                 parentZoneMaybe :               Zone?
	var                      groupOwner :               Zone? { if let (_, r) = groupOwner([]) { return r } else { return nil } }
	var                  bookmarkTarget :               Zone? { return crossLink as? Zone }
	var                     destroyZone :               Zone? { return cloud?.destroyZone }
	var                       trashZone :               Zone? { return cloud?.trashZone }
	var                        manifest :          ZManifest? { return cloud?.manifest }
	var                          widget :         ZoneWidget? { return gWidgets.widgetForZone(self) }
	var                    widgetObject :      ZWidgetObject? { return widget?.widgetObject }
	var                  linkDatabaseID :        ZDatabaseID? { return zoneLink?.maybeDatabaseID }
	var                   lowestExposed :                Int? { return exposed(upTo: highestExposed) }
	var                       textColor :             ZColor? { return (gColorfulMode && colorized) ? color?.darker(by: 3.0) : gDefaultTextColor }
	var                       emailLink :             String? { return email == nil ? nil : "mailTo:\(email!)" }
	var                  linkRecordName :             String? { return zoneLink?.maybeRecordName }
	override var        cloudProperties :       StringsArray  { return Zone.cloudProperties }
	override var optionalCloudProperties :      StringsArray  { return Zone.optionalCloudProperties }
	override var              emptyName :             String  { return kEmptyIdea }
	override var            description :             String  { return decoratedName }
	override var          unwrappedName :             String  { return zoneName ?? smallMapRootName }
	override var          decoratedName :             String  { return decoration + unwrappedName }
	override var   matchesFilterOptions :               Bool  { return isBookmark && gFilterOption.contains(.fBookmarks) || !isBookmark && gFilterOption.contains(.fIdeas) }
	override var                isAZone :               Bool  { return true }
	var                smallMapRootName :             String  { return isFavoritesRoot ? kFavoritesRootName : isRecentsRoot ? kRecentsRootName : emptyName }
	var                     clippedName :             String  { return !gShowToolTips ? kEmpty : unwrappedName }
	var                           level :                Int  { return (parentZone?.level ?? 0) + 1 }
	var                           count :                Int  { return children.count }
	var                      isBookmark :               Bool  { return bookmarkTarget != nil }
	var       isCurrentSmallMapBookmark :               Bool  { return isCurrentFavorite || isCurrentRecent }
	var                 isCurrentRecent :               Bool  { return self ==   gRecents.currentBookmark }
	var               isCurrentFavorite :               Bool  { return self == gFavorites.currentBookmark }
	var               onlyShowRevealDot :               Bool  { return expanded && ((isSmallMapHere && !(widget?.type.isBigMap ??  true)) || (kIsPhone && self == gHereMaybe)) }
	var                 dragDotIsHidden :               Bool  { return (isSmallMapHere && !(widget?.type.isBigMap ?? false)) || (kIsPhone && self == gHereMaybe && expanded) } // hide favorites root drag dot
	var                hasBadRecordName :               Bool  { return recordName == nil }
	var                   hasZonesBelow :               Bool  { return hasAnyZonesAbove(false) }
	var                   hasZonesAbove :               Bool  { return hasAnyZonesAbove(true) }
	var                    hasHyperlink :               Bool  { return hasTrait(for: .tHyperlink) && hyperLink != kNullLink && !(hyperLink?.isEmpty ?? true) }
	var                     hasSiblings :               Bool  { return parentZone?.count ?? 0 > 1 }
	var                      linkIsRoot :               Bool  { return linkRecordName == kRootName }
	var                      isSelected :               Bool  { return gSelecting.isSelected(self) }
	var                       isGrabbed :               Bool  { return gSelecting .isGrabbed(self) }
	var                        hasColor :               Bool  { return zoneColor != nil && !zoneColor!.isEmpty }
	var                        hasEmail :               Bool  { return hasTrait(for: .tEmail) && !(email?.isEmpty ?? true) }
	var                        hasAsset :               Bool  { return hasTrait(for: .tAssets) }
	var                         hasNote :               Bool  { return hasTrait(for: .tNote) }
	var                     isTraveller :               Bool  { return isBookmark || hasHyperlink || hasEmail || hasNote }
	var                       isInTrash :               Bool  { return root?.isTrashRoot        ?? false }
	var                     isInDestroy :               Bool  { return root?.isDestroyRoot      ?? false }
	var                     isInRecents :               Bool  { return root?.isRecentsRoot      ?? false }
	var                    isInSmallMap :               Bool  { return root?.isSmallMapRoot     ?? false }
	var                   isInFavorites :               Bool  { return root?.isFavoritesRoot    ?? false }
	var                   isInEitherMap :               Bool  { return root?.isEitherMapRoot    ?? false }
	var                isInLostAndFound :               Bool  { return root?.isLostAndFoundRoot ?? false }
	var            isNonRootInEitherMap :               Bool  { return !isARoot && isInEitherMap }
	var                  isReadOnlyRoot :               Bool  { return isLostAndFoundRoot || isFavoritesRoot || isTrashRoot || widgetType.isExemplar }
	var                  spawnedByAGrab :               Bool  { return spawnedByAny(of: gSelecting.currentMapGrabs) }
	var                      spawnCycle :               Bool  { return spawnedByAGrab  || dropCycle }
	var                       isInGroup :               Bool  { return groupOwner?.bookmarkTargets.contains(self) ?? false }
	var                    isGroupOwner :               Bool  { return zoneAttributes?.contains(ZoneAttributeType.groupOwner.rawValue) ?? false }
	var                     userCanMove :               Bool  { return userCanMutateProgeny   || isBookmark } // all bookmarks are movable because they are created by user and live in my databasse
	var                    userCanWrite :               Bool  { return userHasDirectOwnership || isIdeaEditable }
	var            userCanMutateProgeny :               Bool  { return userHasDirectOwnership || inheritedAccess != .eReadOnly }
	var                 inheritedAccess :         ZoneAccess  { return zoneWithInheritedAccess.directAccess }
	var  smallMapBookmarksTargetingSelf :          ZoneArray  { return bookmarksTargetingSelf.filter { $0.isInSmallMap } }
	var          bookmarkTargets        :          ZoneArray  { return bookmarks.map { return $0.bookmarkTarget! } }
	var          bookmarks              :          ZoneArray  { return zones(of:  .wBookmarks) }
	var          notemarks              :          ZoneArray  { return zones(of:  .wNotemarks) }
	var               allProgeny        :          ZoneArray  { return zones(of:               .wProgeny)  }
	var       allNotemarkProgeny        :          ZoneArray  { return zones(of: [.wNotemarks, .wProgeny]) }
	var       allBookmarkProgeny        :          ZoneArray  { return zones(of: [.wBookmarks, .wProgeny]) }
	var       all                       :          ZoneArray  { return zones(of:  .wAll) }
	var                  duplicateZones =          ZoneArray  ()
	var                        children =          ZoneArray  ()
	var                          traits =   ZTraitDictionary  ()
	func                copyWithZone() ->           NSObject  { return self }
	func                  identifier() ->             String? { return isARoot ? databaseID.rawValue : recordName }
	func                    toolName() ->             String? { return clippedName }
	func                   toolColor() ->             ZColor? { return color?.lighter(by: 3.0) }
	func                     recount()                        { updateAllProgenyCounts() }
	class  func randomZone(in dbID: ZDatabaseID) ->     Zone  { return Zone.uniqueZoneRenamed(String(arc4random()), databaseID: dbID) }
	static func object(for id: String, isExpanded: Bool) -> NSObject? { return gRemoteStorage.maybeZoneForRecordName(id) }

	var zonesWithNotes : ZoneArray {
		var zones = ZoneArray()

		traverseAllProgeny { zone in
			if  zone.hasNote {
				zones.append(zone)
			}
		}

		return zones
	}

	struct ZWorkingListType: OptionSet {
		let rawValue: Int

		init(rawValue: Int) {
			self.rawValue = rawValue
		}

		static let wBookmarks = ZWorkingListType(rawValue: 0x0001)
		static let wNotemarks = ZWorkingListType(rawValue: 0x0002)
		static let   wProgeny = ZWorkingListType(rawValue: 0x0004)  //
		static let       wAll = ZWorkingListType(rawValue: 0x0008)  // everything
	}

	func zones(of type: ZWorkingListType) -> ZoneArray {
		var result = ZoneArray()
		if  type.contains(.wAll) {
			traverseAllProgeny { iZone in
				result.append(iZone)
			}
		} else if type.contains(.wProgeny) {
			traverseAllProgeny { iZone in
				if  iZone.isBookmark(of: type) {
					result.append(iZone)
				}
			}
		} else {
			result = children.filter { $0.isBookmark(of: type) }
		}
		return result
	}

	var unwrappedNameWithEllipses : String {
		var   name = unwrappedName
		let length = name.length

		if (isInFavorites || isInRecents),
		    length > 25 {
			let first = name.substring(toExclusive: 12)
			let  last = name.substring(fromInclusive: length - 12)
			name      = first + kEllipsis + last
		}

		return name
	}

	var traitsArray: ZRecordsArray {
		var values = ZRecordsArray ()

		for trait in traits.values {
			values.append(trait)
		}

		return values
	}

	var traitKeys   : StringsArray {
		var results = StringsArray()

		for key in traits.keys {
			results.append(key.rawValue)
		}

		return results
	}

	var zoneType : ZoneType {
		var type = ZoneType()

		if  count == 0 {
			type.insert(.zChildless)
		}

		if  hasNote {
			type.insert(.zNote)
		}

		if  traits.count > 0 {
			type.insert(.zTrait)
		}

		if  isBookmark {
			type.insert(.zBookmark)
		}

		if  duplicateZones.count > 0 {
			type.insert(.zDuplicate)
		}

		return type
	}

	var widgetType : ZWidgetType {
		if  let    name = root?.recordName {
			switch name {
				case   kRecentsRootName: return .tRecent
				case  kExemplarRootName: return .tExemplar
				case kFavoritesRootName: return .tFavorite
				default:                 break
			}
		}

		return .tBigMap
	}

	// MARK:- bookmarks
	// MARK:-

	var bookmarksTargetingSelf: ZoneArray {
		if  let  name = recordName,
			let  dict = gBookmarks.reverseLookup[databaseID],
			let array = dict[name] {

			return array
		}

		return []
	}

	var firstBookmarkTargetingSelf: Zone? {
		let    bookmarks = bookmarksTargetingSelf

		return bookmarks.count == 0 ? nil : bookmarks[0]
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
					zoneLink = zoneLink?.replacingOccurrences(of: "Optional(\"", with: kEmpty).replacingOccurrences(of: "\")", with: kEmpty)
				}

				crossLinkMaybe = zoneLink?.maybeZone
			}

			return crossLinkMaybe
		}

		set {
			crossLinkMaybe = nil
			zoneLink       = kNullLink
			if  let  value = newValue,
				let   name = value.recordName {
				let   dbid = value.databaseID.rawValue
				zoneLink   = "\(dbid)::\(name)"
			}
		}
	}

	@discardableResult func isBookmark(of type: ZWorkingListType) -> Bool {
		return bookmarkTarget != nil && (type.contains(.wBookmarks) || (type.contains(.wNotemarks) && bookmarkTarget!.hasNote))
	}

	func addBookmark() {
		if  !isARoot {
			if  gHere == self {
				gHere  = self.parentZone ?? gHere
				
				revealParentAndSiblings()
			}

			gNewOrExistingBookmark(targeting: self, addTo: parentZone).grab()
			gRelayoutMaps()
		}
	}

	// MARK:- setup
	// MARK:-

	func updateInstanceProperties() {
		if  gUseCoreData {
			if  let    id = parentZoneMaybe?.recordName {
				parentRID = id
			}
		}
	}

	// MARK:- properties
	// MARK:-

	override class var cloudProperties: StringsArray {
		return optionalCloudProperties +
			super.cloudProperties
	}

	override class var optionalCloudProperties: StringsArray {
		return [#keyPath(zoneName),
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

	func deepCopy(dbID: ZDatabaseID?) -> Zone {
		let      id = dbID ?? databaseID
		let theCopy = Zone.uniqueZoneRenamed("noname", databaseID: id)

		copyInto(theCopy)
		gBookmarks.addToReverseLookup(theCopy)   // only works for bookmarks

		theCopy.parentZone = nil

		let zones = gListsGrowDown ? children : children.reversed()

		for child in zones {
			theCopy.addChildNoDuplicate(child.deepCopy(dbID: id))
		}

		for trait in traits.values {
			theCopy.addTrait(trait.deepCopy(dbID: id))
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

	var ancestralString: String {
		let names = ancestralPath.map { $0.unwrappedName.capitalized }             // convert ancestors into capitalized strings

		return names.joined(separator: kColonSeparator)
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

	var crumbTipZone: Zone? {
		if  isBookmark {
			return bookmarkTarget?.crumbTipZone
		}

		return self
	}

	var root: Zone? {
		var base: Zone?

		traverseAllAncestors { zone in
			if  zone.isARoot {
				base = zone
			}
		}

		return base
	}

	var decoration: String {
		var d = kEmpty

		if  isInTrash {
			d.append("T")
		}

		if  isInFavorites {
			d.append("F")
		}

		if  isInRecents {
			d.append("R")
		}

		if  isBookmark {
			d.append("B")
		}

		if  count != 0 {
			let s  = d == kEmpty ? kEmpty : kSpace
			let c  = s + "\(count)"

			d.append(c)
		}

		if  d != kEmpty {
			d  = "(\(d))  "
		}

		return d
	}

	var color: ZColor? {
		get {
			if !gColorfulMode { return gDefaultTextColor }

			var     computed    = colorMaybe

			if  zoneName == "jonathan" {
				noop()
			}

			if  colorMaybe     == nil {
				if  let       b = bookmarkTarget {
					return    b.color
				} else if let c = zoneColor, c != kEmpty {
					computed    = c.color
					colorMaybe  = computed
				} else if let p = parentZone, p != self {
					return p.color
				} else {
					computed    = kDefaultIdeaColor
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
				zoneColor              = computed?.string ?? kEmpty
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
						attributes.contains(ZoneAttributeType.invertColorize.rawValue) {
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
				let attributes = zoneAttributes ?? kEmpty
				let       type = ZoneAttributeType.invertColorize
				let oldValue   = attributes.contains(type.rawValue)

				if  newValue  != oldValue {
					alterAttribute(type, remove: !newValue)
				}
			}
		}
	}

	func alterAttribute(_ type: ZoneAttributeType, remove: Bool = false) {
		var attributes = zoneAttributes ?? kEmpty

		if  remove {
			attributes = attributes.replacingOccurrences(of: type.rawValue, with: kEmpty)
		} else if !attributes.contains(type.rawValue) {
			attributes.append(type.rawValue)
		}

		if  zoneAttributes != attributes {
			zoneAttributes  = attributes
		}
	}

	func toggleColorized() {
		colorized = !(zoneAttributes?.contains(ZoneAttributeType.invertColorize.rawValue) ?? false)
	}

	var order: Double {
		get {
			if  zoneOrder == nil {
				updateInstanceProperties()

				if  zoneOrder == nil {
					zoneOrder = NSNumber(value: 0.0)
				}
			}

			return zoneOrder!.doubleValue
		}

		set {
			if  newValue != order {
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

			return iZone.expanded ? .eContinue : .eSkip
		}

		return highest
	}

	func unlinkParentAndMaybeNeedSave() {
		if  parentZoneMaybe != nil ||
				parentLink  != kNullLink {
			parentZoneMaybe  = nil
			parentLink       = kNullLink
		}
	}

	var resolveParent: Zone? {
		let     old = parentZoneMaybe
		parentZoneMaybe = nil
		let     new = parentZone // recalculate _parentZone

		old?.removeChild(self)
		new?.addChildAndRespectOrder(self)

		return new
	}

	var parentZone: Zone? {
		get {
			if  isARoot {
				unlinkParentAndMaybeNeedSave()
			} else  if  parentZoneMaybe == nil {
				if  let      parentName  = parentRID {
					parentZoneMaybe      = cloud?.maybeZoneForRecordName(parentName)
				} else if let      zone  = parentLink?.maybeZone {
					parentZoneMaybe      = zone
				}
			}

			return parentZoneMaybe
		}

		set {
			if  isARoot {
				unlinkParentAndMaybeNeedSave()
			} else if parentZoneMaybe    != newValue {
				parentZoneMaybe           = newValue
				if  parentZoneMaybe      == nil {
					unlinkParentAndMaybeNeedSave()
				} else if let parentName  = parentZoneMaybe?.recordName,
						  let parentDBID  = parentZoneMaybe?.databaseID {
					if        parentDBID == databaseID {
						if  parentRID    != parentName {
							parentRID     = parentName
							parentLink    = kNullLink
						}
					} else {                                                                                // new parent is in different db
						let newParentLink = parentDBID.rawValue + kColonSeparator + kColonSeparator + parentName

						if  parentLink   != newParentLink {
							parentLink    = newParentLink  // references don't work across dbs
							parentRID     = nil
						}
					}
				}
			}
		}
	}

	var siblingIndex: Int? {
		if  let  siblings = parentZone?.children {
			if  let index = siblings.firstIndex(of: self) {
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
		return [kTab, kSpace, kReturn, "-", "d", "e", "h", "v"].contains(gCurrentKeyPressed)
			|| gCurrentKeyPressed?.arrow != nil
			|| gCurrentMouseDownZone     == self
	}

	// MARK:- core data
	// MARK:-

	@discardableResult override func convertFromCoreData(visited: StringsArray?) -> StringsArray {
		alterAttribute(ZoneAttributeType.validCoreData)
		updateFromCoreDataTraitRelationships()
		return super.convertFromCoreData(visited: visited) // call super, too
	}

	override func updateFromCoreDataHierarchyRelationships(visited: StringsArray?) -> StringsArray {
		var      converted = StringsArray()
		var              v = visited ?? StringsArray()

		if  let       name = recordName {
			v.appendUnique(item: name)
		}

		if  let        set = mutableSetValue(forKeyPath: kChildArray) as? Set<Zone>, set.count > 0 {
			let childArray = ZoneArray(set: set)

			for child in childArray {
				let c = child.convertFromCoreData(visited: v)

				if  child.dbid != dbid {
					noop()
				}

				if  let name = child.recordName,
					(visited == nil || !visited!.contains(name)) {
					converted.append(contentsOf: c)
					FOREGROUND(canBeDirect: true) {
						self.addChildNoDuplicate(child, updateCoreData: false) // not update core data, it already exists
						child.register() // need to wait until after child has a parent so bookmarks will be registered properly
					}
				}
			}

			FOREGROUND(canBeDirect: true) {
				self.respectOrder()
			}
		}

		return converted
	}

	func updateFromCoreDataTraitRelationships() {
		if  let        set = mutableSetValue(forKeyPath: kTraitArray) as? Set<ZTrait>, set.count > 0 {
			let traitArray = ZTraitArray(set: set)

			for trait in traitArray {
				trait.convertFromCoreData(visited: [])

				if  trait.dbid != dbid {
					noop()
				}

				if  let type = trait.traitType,
					!hasTrait(for: type) {
					addTrait(trait, updateCoreData: false) // we got here because this is not a first-time launch and thus core data already exists
				}

				trait.register()
			}
		}
	}

	func updateCoreDataRelationships() {
		if  gUseCoreData,
			let        zID = dbid {
			var childArray = Set<Zone>()
			var traitArray = Set<ZTrait>()

			for child in children {
				if  let cID = child.dbid,
					zID    == cID {                // avoid cross-store relationships
					childArray.insert(child)
				}
			}

			for trait in traits.values {
				if  let tID = trait.dbid,
					zID    == tID {                // avoid cross-store relationships
					traitArray.insert(trait)
				}
			}

			if  childArray.count > 0 {
				setValue(childArray as NSObject, forKeyPath: kChildArray)
			} else {
				setValue(nil,                    forKeyPath: kChildArray)
			}

			if  traitArray.count > 0 {
				setValue(traitArray as NSObject, forKeyPath: kTraitArray)
			} else {
				setValue(nil,                    forKeyPath: kTraitArray)
			}
		}
	}

	// MARK:- write access
	// MARK:-

	var userHasDirectOwnership: Bool {
		if  let    t = bookmarkTarget {
			return t.userHasDirectOwnership
		}

		return !isTrashRoot && !isFavoritesRoot && !isLostAndFoundRoot && !gPrintModes.contains(.dAccess) && (databaseID == .mineID || zoneAuthor == gAuthorID || gHasFullAccess)
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
			if  let t = bookmarkTarget {
				t.directAccess = newValue
			} else {
				let    value   = newValue.rawValue
				let oldValue   = zoneAccess?.intValue ?? ZoneAccess.eInherit.rawValue

				if  oldValue  != value {
					zoneAccess = NSNumber(value: value)
				}
			}
		}
	}

	var hasAccessDecoration: Bool {
		if  let    t = bookmarkTarget {
			return t.hasAccessDecoration
		}

		return isInPublicDatabase && ([directAccess, inheritedAccess].contains(.eReadOnly) || directAccess == .eProgenyWritable)
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
			}
		}
	}

	// MARK:- edit map
	// MARK:-

	func duplicate() {
		var array = [self]

		array.duplicate()
	}

	func revealParentAndSiblings() {
		if  let parent = parentZone {
			parent.expand()
		}
	}

	func addIdea() {
		if  !isBookmark,
		    userCanMutateProgeny {
			expand()
			addIdea(at: gListsGrowDown ? nil : 0) { iChild in
				gControllers.signalFor(self, multiple: [.sRelayout]) {
					gTemporarilySetMouseZone(iChild)
					iChild?.edit()
				}
			}
		}
	}

	func addNext(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
		if  let parent = parentZone, parent.userCanMutateProgeny {
			var  zones = gSelecting.currentMapGrabs

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

				parent.expand()
			}

			var index   = siblingIndex

			if  index  != nil {
				index! += gListsGrowDown ? 1 : 0
			}

			parent.addIdea(at: index, with: name) { iChild in
				if  let child = iChild {
					if !containing {
						gRelayoutMaps(for: parent) {
							completion(child)
						}
					} else {
						child.acquireZones(zones)
						gRelayoutMaps(for: parent) {
							completion(child)
						}
					}
				}
			}
		}
	}

	func swapWithParent(onCompletion: Closure? = nil) {
		// swap places with parent

		if  let grabbedI = siblingIndex,
			let   parent = parentZone,
			let  parentI = parent.siblingIndex,
			let   grandP = parent.parentZone {

			gScratchZone.children = []

			gScratchZone.acquireZones(children)
			self.moveZone(into: grandP, at: parentI, orphan: true) {
				self.acquireZones(parent.children)
				parent.moveZone(into: self, at: grabbedI, orphan: true) {
					parent.acquireZones(gScratchZone.children)
					parent.needCount()
					parent.grab()

					if  gHere == parent {
						gHere  = self
					}

					onCompletion?()
				}
			}
		}
	}

	func acquireZones(_ zones: ZoneArray, at iIndex: Int? = nil) {
		expand()

		for     zone in zones {
			if  zone != self {
				zone.orphan()
				addChildNoDuplicate(zone, at: iIndex)
			}
		}

		children.updateOrder()
	}

	func addIdea(at iIndex: Int?, with name: String? = nil, onCompletion: ZoneMaybeClosure?) {
		if  databaseID != .favoritesID {
			let newIdea = Zone.uniqueZoneRenamed(name, databaseID: databaseID)

			parentZoneMaybe?.expand()
			gTextEditor.stopCurrentEdit()

			if !gHasFullAccess,
			    databaseID        == .everyoneID,
			    let       identity = gAuthorID {
			    newIdea.zoneAuthor = identity
			}

			UNDO(self) { iUndoSelf in
				newIdea.deleteSelf {
					onCompletion?(nil)
				}
			}

			ungrab()
			addChildAndReorder(newIdea, at: iIndex, { onCompletion?(newIdea) } )
		}
	}

	func deleteSelf(permanently: Bool = false, onCompletion: Closure?) {
		if  isARoot {
			onCompletion?() // deleting root would be a disaster
		} else {
			maybeRestoreParent()

			let parent = parentZone
			if  self  == gHere {                         // this can only happen ONCE during recursion (multiple places, below)
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

					self.bookmarksTargetingSelf.deleteZones(permanently: permanently) {
						onCompletion?()
					}
				}

				addToPaste()

				if  isInTrash {
					moveZone(to: destroyZone) {
						deleteBookmarksClosure()
					}
				} else if !permanently, !isInDestroy {
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

				gRelayoutMaps(for: self) {
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
						gRelayoutMaps()

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

		into.expand()

		if  orphan {
			self.orphan() // remove from current parent
			maybeRestoreParent()
			self.orphan() // in case parent was restored
		}

		into.addChildAndReorder(self, at: iIndex)

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
		let clouds: [ZRecords?] = [gFavorites, gRecents, zRecords]

		for cloud in clouds {
			restoreParentFrom(cloud?.rootZone)   // look through all records for a match with which to set parent
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
		} else if !there.isABookmark(spawnedBy: self),
				  let targetLink = there.crossLink {

			// ///////////////////////////////
			// MOVE ZONE THROUGH A BOOKMARK //
			// ///////////////////////////////

			var     movedZone = self
			let    targetDBID = targetLink.databaseID
			let       sameMap = databaseID == targetDBID
			let grabAndTravel = {
				there.focusOnBookmarkTarget() { object, kind in
					let there = object as! Zone

					movedZone.moveZone(into: there, at: gListsGrowDown ? nil : 0) {
						movedZone.recursivelyApplyDatabaseID(targetDBID)
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

				movedZone = movedZone.deepCopy(dbID: targetDBID)

				gRelayoutMaps {
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
				let   json = try JSONSerialization.jsonObject(with: data) as? ZStringObjectDictionary {
				let   dict = self.dictFromJSON(json)
				temporarilyOverrideIgnore { // allow needs save
					let zone = Zone.uniqueZone(from: dict, in: databaseID)
					addChildNoDuplicate(zone, at: 0)
				}

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
	func       focusRecent() { focusOn() { gRelayoutMaps() } }
	func editTrait(for iType: ZTraitType) { gTextEditor.edit(traitFor(iType)) }

	@discardableResult func edit() -> ZTextEditor? {
		gTemporarilySetMouseZone(self) // so become first responder will work

		return gTextEditor.edit(self)
	}

	// ckrecords lookup:
	// initialized with one entry for each word in each zone's name
	// grows with each unique search

	func addToLocalSearchIndex() {
		if  let  name = zoneName,
			let array = zRecords {
			array.appendZRecordsLookup(with: name) { iRecords -> ZRecordsArray in
				guard var r = iRecords else { return [] }

				r.appendUnique(item: self)

				return r
			}
		}
	}

	func resolveAsHere() {
		gHere = self

		grab()
		expand()
		gControllers.swapMapAndEssay(force: .wMapMode)
	}

	func grab(updateBrowsingLevel: Bool = true) {
		gTextEditor.stopCurrentEdit(andRedraw: false)
		printDebug(.dEdit, " GRAB    \(unwrappedName)")
		gSelecting.grab([self], updateBrowsingLevel: updateBrowsingLevel)
	}

	func asssureIsVisibleAndGrab(updateBrowsingLevel: Bool = true) {
		gShowSmallMapForIOS = kIsPhone && isInSmallMap

		asssureIsVisible()
		grab(updateBrowsingLevel: updateBrowsingLevel)
	}

	func dragDotClicked(_ COMMAND: Bool, _ SHIFT: Bool, _ CLICKTWICE: Bool) {
		if  COMMAND || (CLICKTWICE && isGrabbed) {
			grab() // narrow selection to just this one zone

			if !(CLICKTWICE && self == gHere) {
				gRecents.focusOnGrab(.eSelected) {
					gRelayoutMaps()
				}
			}
		} else if isGrabbed && gCurrentlyEditingWidget == nil {
			ungrabAssuringOne()
		} else if SHIFT {
			addToGrabs()
		} else {
			grab()
		}

		gRelayoutMaps(for: self)
	}

	override func setupLinks() {
		if  recordName != nil {

			let isBadLink: StringToBooleanClosure = { iString -> Bool in
				let badLinks = [kEmpty, "-", "not"]

				return iString == nil || badLinks.contains(iString!)
			}

			if  isBadLink(zoneLink) {
				zoneLink = kNullLink
			}

			if  isBadLink(parentLink) {
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
		zoneColor  = kEmpty
		colorMaybe = nil
	}

	static func !== ( left: Zone, right: Zone) -> Bool {
		return left != right
	}

	static func == ( left: Zone, right: Zone) -> Bool {
		let unequal = left != right                        // avoid infinite recursion by using negated version of this infix operator

		if  unequal,
			let lName =  left.recordName,
			let rName = right.recordName {
			return lName == rName
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

	func addTrait(_ trait: ZTrait, updateCoreData: Bool = true) {
		if  let                  type  = trait.traitType {
			traits              [type] = trait
			let             ownerName  = trait.ownerRID
			if  let          selfName  = recordName,
				selfName != ownerName {
				trait     ._ownerZone  = nil
				trait      .ownerRID   = selfName
			}

			if  updateCoreData {
				updateCoreDataRelationships()
			}
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
		if  isBookmark {
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

				trait.updateSearchables()
			} else {
				traits[type]?.needDestroy()

				traits[type] = nil
			}

			updateCoreDataRelationships()  // need to record changes in core data traits array

			switch (type) {
				case .tEmail:     emailMaybe         = iText
				case .tHyperlink: hyperLinkMaybe     = iText
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
			} else {
				traits[.tAssets]?.needDestroy()

				traits[.tAssets] = nil
			}
		}
	}

	func traitFor(_ iType: ZTraitType) -> ZTrait {
		var trait            = traits[iType]
		if  trait           == nil,
			let         name = recordName {
			trait            = ZTrait.uniqueTrait(recordName: nil, in: databaseID)
			trait?.ownerRID  = name
			trait?.traitType = iType
			traits[iType]    = trait
		}

		return trait!
	}

	func removeTrait(for iType: ZTraitType) {
		let     trait = traits[iType]
		traits[iType] = nil

		updateCoreDataRelationships()
		trait?.needDestroy()

		if  let t = trait {
			gCoreDataStack.managedContext.delete(t)
		}
	}

	// MARK:- notes / essays
	// MARK:-

	var countOfNotes: Int {
		return zonesWithNotes.count
	}

	var currentNote: ZNote? {
		if  isBookmark {
			return bookmarkTarget!.currentNote
		}

		let zones = zonesWithNotes

		if  zones.count > 0 {
			return ZNote(zones[0])
		}

		return nil
	}

	var note: ZNote? {
		if  isBookmark {
			return bookmarkTarget!.note
		} else if noteMaybe == nil || !hasTrait(matching: [.tNote, .tEssay]), let emptyNote = createNote() {
			return emptyNote
		}

		return noteMaybe
	}

	@discardableResult func createNote() -> ZNote? {
		let zones = zonesWithNotes
		let count = zones.count
		var note : ZNote?

		if  count > 1, gCreateCombinedEssay, zones.contains(self) {
			note      = ZEssay(self)
			noteMaybe = note

			note?.setupChildren()
		} else if count == 0 || !gCreateCombinedEssay {
			note      = ZNote(self)
			noteMaybe = note
		} else {
			let  zone = zones[0]
			note      = ZNote(zone)
			zone.noteMaybe = note
		}

		return note
	}

	func clearAllNotes() {     // discard current essay text and all child note's text
		for zone in zonesWithNotes {
			zone.noteMaybe = nil
		}

	}

	func deleteNote() {
		removeTrait(for: .tNote)
		gRecents.removeBookmark(for: self)

		noteMaybe     = nil
		gNeedsRecount = true // trigger recount on next timer fire
	}

	func showNote() {
		gCreateCombinedEssay = false
		gCurrentEssay        = note

		gControllers.swapMapAndEssay(force: .wEssayMode)
	}

	// MARK:- groupOwner
	// MARK:-

	var parentOwnsAGroup : Zone? {
		if  isInEitherMap,
			let    p = parentZone, p.isGroupOwner, p.isInEitherMap {
			return p
		}

		return nil
	}

	private func groupOwner(_ iVisited: StringsArray) -> (StringsArray, Zone)? {
		guard let name = recordName, !iVisited.contains(name), gHasFinishedStartup else {
			return nil                                          // avoid looking more than once per zone for a group owner
		}

		var visited = iVisited

		visited.appendUnique(item: name)

		if  isGroupOwner, isInEitherMap {
			return (visited, self)
		} else if let p = parentOwnsAGroup {
			visited.appendUnique(item: p.recordName)
			return (visited, p)
		} else if let t = bookmarkTarget {
			return t.groupOwner(visited)
		} else {
			for bookmark in bookmarksTargetingSelf {
				visited.appendUnique(item: bookmark.recordName)
				visited.appendUnique(item: bookmark.parentZone?.recordName)

				if  let r = bookmark.parentOwnsAGroup {
					return (visited, r)
				}
			}

			for target in bookmarkTargets {
				if  let (v, r) = target.groupOwner(visited) {
					visited.appendUnique(contentsOf: v)

					return (visited, r)
				}
			}
		}

		return nil
	}

	func ownedGroup(_ iVisited: StringsArray) -> ZoneArray? {
		guard let name = recordName, !iVisited.contains(name) else { return nil }
		var      zones = ZoneArray()
		var    visited = iVisited

		func append(_ zone: Zone?) {
			if  isInEitherMap {    // disallow rootless, trash, etc.
				zones  .appendUnique(item: zone)
				visited.appendUnique(item: zone?.recordName)
			}
		}

		visited.appendUnique(item: name)

		for bookmark in bookmarks {
			if  let target = bookmark.bookmarkTarget,
				!visited.contains(target.recordName) {
				append(target)
			}
		}

		return zones
	}

	func indexIn(_ zones: ZoneArray) -> Int? {
		if  let   target = bookmarkTarget,
		    let    index = zones.firstIndex(of: target) {
			return index
		} else if let index = zones.firstIndex(of: self) {
			return    index
		}

		return nil
	}

	func cycleToNextInGroup(_ forward: Bool) {
		guard   let   rr = groupOwner else {
			if  self    != gHere {
				gHere.cycleToNextInGroup(forward)
			}

			return
		}

		if  let     r = rr.ownedGroup([]), r.count > 0,
			let index = indexIn(r),
			let  zone = r.next(from: index, forward: forward) {
			gHere     = zone

//			print("\(rr) : \(r) -> \(zone)") // very helpful in final debugging

			gFavorites.show(zone)
			zone.grab()
			gRelayoutMaps()
		}
	}

	// MARK:- travel / focus / move / bookmarks
	// MARK:-

	@discardableResult func focusThrough(_ atArrival: @escaping Closure) -> Bool {
		if  isBookmark {
			if  isInSmallMap {
				let targetParent = bookmarkTarget?.parentZone

				targetParent?.expand()
				focusOnBookmarkTarget { (iObject: Any?, kind: ZSignalKind) in
					gRecents.updateCurrentForMode()
					atArrival()
				}

				return true
			} else if let dbID = crossLink?.databaseID {
				gDatabaseID = dbID

				gRecents.focusOnGrab {
					gHere.grab()
					atArrival()
				}

				return true
			}

			performance("bookmark with bad db crosslink")
		}

		return false
	}

	func focusOnBookmarkTarget(atArrival: @escaping SignalClosure) {
		if  let    targetZRecord = crossLink,
			let targetRecordName = targetZRecord.recordName {
			let       targetDBID = targetZRecord.databaseID
			let           target = bookmarkTarget

			let complete : SignalClosure = { (iObject, kind) in
				self.showTopLevelFunctions()
				atArrival(iObject, kind)
			}

			var there: Zone?

			if  isInFavorites {
				gFavorites.currentBookmark = self
			} else if isInRecents {
				gRecents.currentBookmark   = self
			}

			if  let t = target, t.spawnedBy(gHereMaybe) {
				if !t.isGrabbed {
					t.asssureIsVisible()
					t.grab()
				} else {
					gHere = t

					gRecents.push()
				}

				gShowSmallMapForIOS = targetDBID.isSmallMapDB

				complete(target, .sRelayout)
			} else {
				gShowSmallMapForIOS = targetDBID.isSmallMapDB

				if  gDatabaseID != targetDBID {
					gDatabaseID  = targetDBID

					// ///////////////////////// //
					// TRAVEL TO A DIFFERENT MAP //
					// ///////////////////////// //

					if  let here = target { // e.g., default root favorite
						gRecents.focusOnGrab(.eSelected) {
							gHere = here

							gHere.prepareForArrival()
							complete(gHere, .sRelayout)
						}
					} else if let here = gCloud?.maybeZoneForRecordName(targetRecordName) {
						gHere          = here

						gHere.prepareForArrival()
						gRecents.focusOnGrab {
							complete(gHere, .sRelayout)
						}
					} else {
						complete(gHere, .sRelayout)
					}
				} else {

					// /////////////// //
					// STAY WITHIN MAP //
					// /////////////// //

					there = gRecords?.maybeZoneForRecordName(targetRecordName)
					let grabbed = gSelecting.firstSortedGrab
					let    here = gHere

					UNDO(self) { iUndoSelf in
						self.UNDO(self) { iRedoSelf in
							self.focusOnBookmarkTarget(atArrival: complete)
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
					} else if gRecords?.databaseID != .favoritesID, // favorites does not have a cloud database
							  let here = gCloud?.maybeZoneForRecordName(targetRecordName) {
						gHere = here

						grabHere()
					} // else ignore: favorites id with an unresolvable bookmark target
				}
			}
		}
	}

	func focusOn(_ atArrival: @escaping Closure) {
		gHere = self // side-effect does push

		grab() // so the following will work correctly
		gRecents.focusOnGrab(.eSelected) {
			atArrival()
		}
	}

	func invokeTravel(_ COMMAND: Bool = false, onCompletion: BoolClosure? = nil) {
		if !invokeBookmark(COMMAND, onCompletion: onCompletion),
		   !invokeEssay(),
		   !invokeURL(for: .tHyperlink) {
			invokeURL(for: .tEmail)
		}
	}

	@discardableResult func invokeBookmark(_ COMMAND: Bool = false, onCompletion: BoolClosure?) -> Bool { // false means not traveled
		if  let target = bookmarkTarget {
			if  COMMAND, target.invokeEssay() { // first, check if target has an essay
				onCompletion?(false)
			} else {
				if  gIsEssayMode {
					gControllers.swapMapAndEssay(force: .wMapMode)
				}

				focusOnBookmarkTarget() { object, kind in
					#if os(iOS)
					gActionsController.alignView()
					#endif
					onCompletion?(true)
				}
			}

			return true
		}

		if  gIsEssayMode {
			gControllers.swapMapAndEssay(force: .wMapMode)
		}

		return false
	}

	func invokeEssay() -> Bool { // false means not handled
		if  hasNote {
			grab()

			gCurrentEssay = note

			if  gIsEssayMode {
				gEssayView?.updateText()
			} else {
				gControllers.swapMapAndEssay()
			}

			return true
		}

		return false
	}

	func link(for traitType: ZTraitType) -> String? {
		switch traitType {
			case .tHyperlink: return hyperLink
			case .tEmail:     return emailLink
			default:          return nil
		}
	}

	@discardableResult func invokeURL(for type: ZTraitType?) -> Bool { // false means not traveled
		if  let    t = type,
			let link = link(for: t),
			link    != kNullLink {
			link.openAsURL()

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

				gSignal([.spSmallMap, .sRelayout])
			}
		}
	}

	func moveSelectionOut(extreme: Bool = false, onCompletion: BoolClosure?) {
		if  extreme {
			if  gHere.isARoot {
				gHere = self // reverse what the last move out extreme did
			} else {
				let here = gHere // revealZonesToRoot (below) changes gHere, so nab it first

				grab()
				revealZonesToRoot() {
					here.revealSiblings(untilReaching: gRoot!)
					onCompletion?(true)
				}

				return
			}
		} else if let p = parentZone {
			if  self == gHere {
				revealParentAndSiblings()
				revealSiblings(untilReaching: p)
			} else {
				if !isInSmallMap {
					p.expand()
				} else if let g = p.parentZone { // narrow: hide children and set here zone to parent
					p.collapse()
					g.expand()
					g.setAsSmallMapHereZone()
					// FUBAR: parent sometimes disappears!!!!!!!!!
				} else if p.isARoot {
					onCompletion?(true)
					return // do nothing if p is root of either small map
				}

				p.grab()
				gSignal([.spCrumbs, .spData, .spSmallMap])
			}
		} else if let bookmark = firstBookmarkTargetingSelf {		 // self is an orphan
			gHere              = bookmark			                 // change focus to bookmark of self
		}

		onCompletion?(true)
	}

	func revealZonesToRoot(_ onCompletion: Closure?) {
		if  isARoot {
			onCompletion?()
		} else {
			var here = gHere

			traverseAllAncestors { zone in
				zone.expand()
				here = zone
			}

			gHere    = here

			onCompletion?()
		}
	}

	func addAGrab(extreme: Bool = false, onCompletion: BoolClosure?) {
		var   needReveal = false
		var         zone = self
		var addRecursive = {}

		addRecursive = {
			let expand = !zone.expanded
			needReveal = needReveal || expand

			if  expand {
				zone.expand()
			}

			if  zone.count > 0,
				let child = gListsGrowDown ? zone.children.last : zone.children.first {

				child.grab()

				if  zone.isInSmallMap { // narrow, so hide former here and ignore extreme
					zone.setAsSmallMapHereZone()
				} else if extreme {
					zone = child

					addRecursive()
				}
			}
		}

		addRecursive()
		onCompletion?(needReveal)

		if !needReveal {
			gSignal([.spCrumbs, .spData, .spSmallMap])
		}
	}

	func addGrabbedZones(at iIndex: Int?, undoManager iUndoManager: UndoManager?, _ flags: ZEventFlags, onCompletion: Closure?) {

		// ////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// 1. move a normal zone into another normal zone                                                            //
		// 2. move a normal zone through a bookmark                                                                  //
		// 3. move a normal zone into small map -- create a bookmark pointing at normal zone, then add it to the map //
		// 4. move from small map into a normal zone -- convert to a bookmark, then move the bookmark                //
		//                                                                                                           //
		// OPTION  = copy                                                                                            //
		// SPECIAL = don't create bookmark              (case 3)                                                     //
		// CONTROL = don't change here or expand into                                                                //
		// ////////////////////////////////////////////////////////////////////////////////////////////////////////////

		guard let undoManager = iUndoManager else {
			onCompletion?()

			return
		}

		let   toBookmark = isBookmark                    // type 2
		let   toSmallMap = isInSmallMap && !toBookmark   // type 3
		let         into = bookmarkTarget ?? self        // grab bookmark AFTER travel
		var        grabs = gSelecting.currentMapGrabs
		var      restore = [Zone: (Zone, Int?)] ()
		let     STAYHERE = flags.exactlySpecial
		let   NOBOOKMARK = flags.isControl
		let         COPY = flags.isOption
		var    cyclicals = IndexSet()

		// separate zones that are connected back to themselves

		for (index, zone) in grabs.enumerated() {
			if  spawnedBy(zone) {
				cyclicals.insert(index)
			} else if let parent = zone.parentZone {
				let siblingIndex = zone.siblingIndex
				restore[zone]    = (parent, siblingIndex)
			}
		}

		while let index = cyclicals.last {
			cyclicals.remove(index)
			grabs.remove(at: index)
		}

		// case 4

		grabs.sort { (a, b) -> Bool in
			return a.order < b.order
		}

		// ///////////////////
		// prepare for UNDO //
		// ///////////////////

		if  toBookmark {
			undoManager.beginUndoGrouping()
		}

		// todo: relocate this in caller, hope?
		UNDO(self) { iUndoSelf in
			for (child, (parent, index)) in restore {
				child.orphan()
				parent.addChildAndReorder(child, at: index)
			}

			iUndoSelf.UNDO(self) { iUndoUndoSelf in
				let zoneSelf = iUndoUndoSelf as Zone
				zoneSelf.addGrabbedZones(at: iIndex, undoManager: undoManager, flags, onCompletion: onCompletion)
			}

			onCompletion?()
		}

		// /////////////
		// move logic //
		// /////////////

		let finish = {
			var onlyTime = true

			if !NOBOOKMARK {
				into.expand()
			}

			if  onlyTime {
				onlyTime          = false
				if  let firstGrab = grabs.first,
					let fromIndex = firstGrab.siblingIndex,
					(firstGrab.parentZone != into || fromIndex > (iIndex ?? 1000)) {
					grabs = grabs.reversed()
				}

				gSelecting.ungrabAll()

				for grab in grabs {
					var bookmark = grab

					if  toSmallMap && !bookmark.isInSmallMap && !bookmark.isBookmark && !bookmark.isInTrash && !STAYHERE {
						if  let    b = gCurrentSmallMapRecords?.matchOrCreateBookmark(for: bookmark, autoAdd: false) {	// case 3
							bookmark = b
						}
					} else if bookmark.databaseID != into.databaseID {    // being moved to the other db
						if  bookmark.parentZone == nil || !bookmark.parentZone!.children.contains(bookmark) || !COPY {
							bookmark.needDestroy()                        // is not a child within its parent and should be tossed
							bookmark.orphan()
						}

						bookmark = bookmark.deepCopy(dbID: into.databaseID)
					}

					if !STAYHERE, !NOBOOKMARK {
						bookmark.addToGrabs()

						if  toSmallMap {
							into.updateVisibilityInSmallMap(true)
						}
					}

					bookmark.orphan()
					into.addChildAndReorder(bookmark, at: iIndex)
					bookmark.recursivelyApplyDatabaseID(into.databaseID)
					gBookmarks.addToReverseLookup(bookmark)
				}

				if  toBookmark && undoManager.groupingLevel > 0 {
					undoManager.endUndoGrouping()
				}

				onCompletion?()
			}
		}

		// ////////////////////////////////////
		// deal with target being a bookmark //
		// ////////////////////////////////////

		if !toBookmark || STAYHERE || NOBOOKMARK || COPY {
			finish()
		} else {
			focusOnBookmarkTarget() { (iAny, iSignalKind) in
				finish()
			}
		}
	}

	// MARK:- traverse ancestors
	// MARK:-

	func isABookmark(spawnedBy: Zone) -> Bool {
		if  let          link = crossLink {
			let      linkDBID = link.databaseID
			var      linkName = link.recordName
			let spawnedByName = spawnedBy.recordName
			var       visited = StringsArray ()

			while let    name = linkName, !visited.contains(name) {
				visited.append(name)

				if  name     == spawnedByName {
					return true
				}

				let newLink   = gRemoteStorage.zRecords(for: linkDBID)?.maybeZoneForRecordName(name)
				linkName      = newLink?.recordName
			}
		}

		return false
	}

	var isVisible: Bool {
		var isVisible = true

		traverseAncestors { iAncestor -> ZTraverseStatus in
			let showing = iAncestor.expanded

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
		if  let goal = gRemoteStorage.cloud(for: databaseID)?.currentHere {

			traverseAncestors { iAncestor -> ZTraverseStatus in
				if  iAncestor != self {
					iAncestor.expand()
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
			ancestor.adopt()
		}
	}

	func spawnedBy(_ iZone: Zone?) -> Bool { return iZone == nil ? false : spawnedByAny(of: [iZone!]) }
	func traverseAncestors(_ block: ZoneToStatusClosure) { safeTraverseAncestors(visited: [], block) }

	func spawnedByAny(of iZones: ZoneArray) -> Bool {
		var wasSpawned = false

		if  iZones.count > 0 {
			traverseAncestors { iAncestor -> ZTraverseStatus in
				if  iAncestor != self,
					iZones.contains(iAncestor) {
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

			return iZone.expanded ? .eContinue : .eSkip
		}

		return visible
	}

	func concealAllProgeny() {
		traverseAllProgeny { iChild in
			iChild.collapse()
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

			return iZone.expanded ? .eContinue : .eSkip
		}
	}

	// first call block on self, then recurse on each child

	@discardableResult func safeTraverseProgeny(visited: ZoneArray, _ block: ZoneToStatusClosure) -> ZTraverseStatus {
		var status  = block(self)

		if  status == .eContinue {
			for child in children {
				if  visited.contains(child) {
					break						// do not revisit or traverse further inward
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
				} else if iZone.level == iLevel && iZone != self && (iZone.parentZone == nil || iZone.parentZone!.expanded) {
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
				if  !child.expanded && child.fetchableCount != 0 {
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

	// MARK:- children visibility
	// MARK:-

	var expanded: Bool {
		if  let name = recordName,
			gExpandedZones.contains(name) {
			return true
		}

		return false
	}

	func expand() {
		var expansionSet = gExpandedZones

		if  let name = recordName, !isBookmark, !expansionSet.contains(name) {
			expansionSet.append(name)

			gExpandedZones = expansionSet
		}
	}

	func collapse() {
		var expansionSet = gExpandedZones

		if  let name = recordName {
			while let index = expansionSet.firstIndex(of: name) {
				expansionSet.remove(at: index)
			}
		}

		if  gExpandedZones.count != expansionSet.count {
			gExpandedZones        = expansionSet
		}
	}

	func toggleChildrenVisibility() {
		if  expanded {
			collapse()
		} else {
			expand()
		}
	}

	// MARK:- state
	// MARK:-

	func prepareForArrival() {
		expand()
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

	override var isAdoptable: Bool { return parentRID != nil || parentLink != nil }

	// adopt recursively

	override func adopt(recursively: Bool = false) {
		if  !isARoot, !needsDestroy {
			if  let p = parentZone, p != self {        // first compute parentZone
				if !p.children.contains(self) {        // see if already adopted
					p.addChildAndRespectOrder(self)
					updateMaxLevel()
				}

				if  recursively {
					p.adopt(recursively: true)         // recurse on parent
				}
			}
		}

		removeState(.needsAdoption)
	}

	override func orphan() {
		parentZone?.removeChild(self)
	}

	func addChildAndRespectOrder(_ child: Zone?) {
		addChildNoDuplicate(child)
		respectOrder()
	}

	func addChildAndReorder(_ iChild: Zone?, at iIndex: Int? = nil, _ afterAdd: Closure? = nil) {
		if  let child = iChild,
			addChildNoDuplicate(child, at: iIndex, afterAdd) != nil {
			children.updateOrder() // also marks children need save
		}
	}

	func validIndex(from iIndex: Int?) -> Int {
		var index = iIndex ?? (gListsGrowDown ? count : 0)

		if  index < 0 {
			index = 0
		} else if index > count {
			index = count
		}

		return index   // count is bottom, 0 is top
	}

	func deleteDuplicates() {
		for d in duplicateZones {
			if  d != self {
				d.deleteDuplicates()
				d.moveZone(to: gDestroy)
			}
		}

		duplicateZones.removeAll()
	}

	func cycleToNextDuplicate() {
		var     d = duplicateZones
		if  let p = parentZone, d.count > 0,
			let i = siblingIndex,
			let n = d.popLast() {     // pop next from duplicates

			orphan()
			p.addChildAndReorder(n, at: i)  // swap it into this zones sibling index
		}
	}

	func isSameAs(_ other: Zone) {
		// identify discrepancies and do what with them?
	}

	@discardableResult func addChildNoDuplicate(_ iChild: Zone? = nil, at iIndex: Int? = nil, updateCoreData: Bool = true, _ onCompletion: Closure? = nil) -> Int? {
		if  let        child = iChild {
			let      toIndex = validIndex(from: iIndex)
			child.parentZone = self

			func finish() -> Int {
				updateMaxLevel()
				onCompletion?()

				return toIndex
			}

			func rearange(from index: Int) -> Int {
				if  index != toIndex {
					moveChildIndex(from: index, to: toIndex)
				}

				return finish()
			}

			if  let childTarget = child.bookmarkTarget {           // detect if its bookmark is already added
				for (index, sibling) in children.enumerated() {
					if  childTarget == sibling.bookmarkTarget {
						return rearange(from: index)
					}
				}
			}

			for (index, sibling) in children.enumerated() {        // detect if it's already added
				if  child == sibling { // same record name
					return rearange(from: index)
				}
			}

			return addChild(iChild, at: iIndex, updateCoreData: updateCoreData, onCompletion)
		}

		return nil
	}

	@discardableResult func addChild(_ iChild: Zone? = nil, at iIndex: Int? = nil, updateCoreData: Bool = true, _ onCompletion: Closure? = nil) -> Int? {
		if  let        child = iChild {
			let      toIndex = validIndex(from: iIndex)
			child.parentZone = self

			if  toIndex < count {
				children.insert(child, at: toIndex)
			} else {
				children.append(child)
			}

			if  updateCoreData {
				updateCoreDataRelationships()
			}

			needCount()
			updateMaxLevel()
			onCompletion?()

			return toIndex
		}

		return nil
	}

	@discardableResult func removeChild(_ iChild: Zone?) -> Bool {
		if  let child = iChild {
			if  let index = children.firstIndex(of: child) {
				children.remove(at: index)
			}

			child.parentZone = nil

			child.setValue(nil, forKeyPath: kParentRef)
			updateCoreDataRelationships()
			updateMaxLevel()
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
								self.expand()
								gRelayoutMaps(for: self) {
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
			let   childName = zoneName ?? kEmpty
			let childLength = childName.length
			let    combined = original.stringBySmartly(appending: childName)
			let       range = NSMakeRange(combined.length - childLength, childLength)
			parent.zoneName = combined
			parent.extractTraits  (from: self)
			parent.extractChildren(from: self)

			gDeferRedraw {
				self.moveZone(to: gTrash)

				gDeferringRedraw = false

				gRelayoutMaps(for: parent) {
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
			gRelayoutMaps(for: self)
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
		if !show && isGrabbed && (count == 0 || !expanded) {

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
			let grabs = gSelecting.currentGrabs
			let apply = {
				var grabHere = false
				self.traverseAllProgeny { iChild in
					if           !iChild.isBookmark {
						if        iChild.level  < goal &&  show {
							iChild.expand()
						} else if iChild.level >= goal && !show {
							iChild.collapse()

							if  iChild.children.intersects(grabs) {
								grabHere = true
							}
						}
					}
				}

				if  show {
					gCurrentSmallMapRecords?.swapBetweenBookmarkAndTarget()
				} else if grabHere {
					gHere.grab()
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
			addChildNoDuplicate(child)
		}
	}

	func recursivelyApplyDatabaseID(_ iID: ZDatabaseID) {
		let                 appliedID = iID.identifier
		if  appliedID                != dbid {
			traverseAllProgeny { iZone in
				if  appliedID        != iZone.dbid {
					iZone.unregister()

					let newParentZone = iZone.parentZone        // (1) grab new parent zone asssigned during a previous traverse (2, below)
					iZone       .dbid = appliedID               // must happen BEFORE record assignment

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
		if  from < count, to <= count, from != to,
			let child = self[from] {

			func add() {
				if  to < count {
					self.children.insert(child, at: to)
				} else {
					self.children.append(child)
				}
			}

			if  from > to {
				children.remove(at: from)
				add()
			} else if from < to {
				add()
				children.remove(at: from)
			}

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
		gRelayoutMaps()
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

	func divideEvenly() {
		let optimumSize     = 40
		if  count           > optimumSize {
			var   divisions = ((count - 1) / optimumSize) + 1
			let        size = count / divisions
			var     holders = ZoneArray ()

			while divisions > 0 {
				divisions  -= 1
				var gotten  = 0
				let holder  = Zone.randomZone(in: databaseID)

				holders.append(holder)

				while gotten < size && count > 0 {
					if  let child = children.popLast(),
						child.progenyCount < (optimumSize / 2) {
						holder.addChildNoDuplicate(child, at: nil)
					}

					gotten += 1
				}
			}

			for child in holders {
				addChildNoDuplicate(child, at: nil)
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
		var  string = margin + letter + marks.character(at: (iInset / modulus) % marks.count) + kSpace + unwrappedName + kReturn

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

			if  expanded {
				gSelecting.ungrabAll(retaining: children)
			} else {
				return // selection does not show its children
			}
		}

		gRelayoutMaps(for: self)
	}

	func updateMaxLevel() {
		gRemoteStorage.zRecords(for: databaseID)?.updateMaxLevel(with: level)
	}

	// MARK:- dots
	// MARK:-

	func ungrabProgeny() {
		for     grabbed in gSelecting.currentMapGrabs {
			if  grabbed != self && grabbed.spawnedBy(self) {
				grabbed.ungrab()
			}
		}
	}

	func revealDotClicked(_ flags: ZEventFlags) {
		gTextEditor.stopCurrentEdit()
		ungrabProgeny()

		let COMMAND = flags.isCommand
		let  OPTION = flags.isOption

		if  count > 0, !OPTION, !isBookmark {
			let show = !expanded

			if  isInSmallMap {
				updateVisibilityInSmallMap(show)
				gRelayoutMaps()
			} else {
				let goal = (COMMAND && show) ? Int.max : nil
				generationalUpdate(show: show, to: goal) {
					gRelayoutMaps(for: self)
				}
			}
		} else if isTraveller {
			invokeTravel(COMMAND) { reveal in // note, email, video, bookmark, hyperlink
				gRelayoutMaps()
			}
		}
	}

	func updateVisibilityInSmallMap(_ show: Bool) {

		// //////////////////////////////////////////////////////////
		// avoid annoying user: treat small map non-generationally //
		// //////////////////////////////////////////////////////////

		// show -> collapse parent, expand self, here = parent
		// hide -> collapse self, expand parent, here = self

		if  !isARoot || show {
			let hidden = show ? parentZone : self

			hidden?.collapse()

			if  let shown = show ? self : parentZone {
				shown.expand()

				if  isInFavorites {
					gFavoritesHereMaybe = shown
				} else if isInRecents {
					gRecentsHereMaybe   = shown
				}
			}
		}
	}

	func dotParameters(_ isFilled: Bool, _ isReveal: Bool) -> ZDotParameters {
		let            c = widgetType.isExemplar ? gHelpHyperlinkColor : gColorfulMode ? (color ?? gDefaultTextColor) : gDefaultTextColor
		var            p = ZDotParameters()
		let            t = bookmarkTarget
		let            k = traitKeys
		let            g = groupOwner
		p.color          = c
		p.isGrouped      = g != nil
		p.showList       = expanded
		p.isReveal       = isReveal
		p.filled         = isFilled
		p.hasTarget      = isBookmark
		p.showAccess     = hasAccessDecoration
		p.hasTargetNote  = t?.hasNote ?? false
		p.isGroupOwner   = g == self || g == t
		p.isDrop         = self == gDropZone
		p.showSideDot    = isCurrentSmallMapBookmark
		p.traitType      = (k.count < 1) ? kEmpty : k[0]
		p.fill           = isFilled ? c.lighter(by: 2.5) : gBackgroundColor
		p.accessType     = directAccess == .eProgenyWritable ? .sideDot : .vertical
		p.childCount     = (gCountsMode == .progeny) ? progenyCount : indirectCount

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
		zoneName  = kHalfLineOfDashes + kSpace + unwrappedName + kSpace + kHalfLineOfDashes
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
			if  isBookmark {
				return
			}

			let visited = iVisited + [self]
			var counter = 0

			for     child in children {
				if !child.isBookmark {
					child.updateAllProgenyCounts(visited) // recurse (hitting every progeny)

					counter += child.progenyCount
				}

				counter += 1
			}

			if  progenyCount != counter {
				progenyCount  = counter
			}
		}

		return
	}

	// MARK:- receive from cloud
	// MARK:-

	// add to map

	func addToParent(_ onCompletion: ZoneMaybeClosure? = nil) {
		FOREGROUND(canBeDirect: true) {
			self.colorMaybe   = nil               // recompute color
			let parent        = self.resolveParent
			let done: Closure = {
				parent?.respectOrder()          // assume newly fetched zone knows its order

				self.columnarReport("   ->", self.unwrappedName)
				onCompletion?(parent)
			}

			if  let p = parent,
				!p.children.contains(self) {
				p.addChildNoDuplicate(self)
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
				case "a":      children.alphabetize()
				case "b":      addBookmark()
				case "d":      duplicate()
				case "e":      editTrait(for: .tEmail)
				case "h":      editTrait(for: .tHyperlink)
				case "i":      children.sortByCount()
				case "m":      children.sortByLength()
				case "n":      showNote()
				case "o":      importFromFile(.eSeriously) { gRelayoutMaps(for: self) }
				case "r":      reverseChildren()
				case "s":      gFiles.export(self, toFileAs: .eSeriously)
				case "t":      swapWithParent { gRelayoutMaps(for: self) }
				case "/":      focusRecent()
				case kSpace:   addIdea()
				case "\u{08}", kDelete: deleteSelf { gRelayoutMaps() }
				default:       break
			}
		}
	}

	// MARK:- initialization
	// MARK:-

	// /////////////////////////////
	// exemplar and scratch ideas //
	//  N.B. not to be persisted  //
	// /////////////////////////////

	static func recordNameFor(_ rootName: String, at index: Int) -> String {
		var name = rootName

		if  index > 0 { // index of 0 means use just the root name parameter
			name.append(index.description)
		}

		return name
	}

	// never use closure
	static func create(within rootName: String, for index: Int = 0, databaseID: ZDatabaseID) -> Zone {
		let           name = recordNameFor(rootName, at: index)
		let        created = Zone.uniqueZone(recordName: name, in: databaseID)
		created.parentLink = kNullLink

		return created
	}

	static func uniqueZoneRenamed(_ named: String?, recordName: String? = nil, databaseID: ZDatabaseID) -> Zone {
		let created           = uniqueZone(recordName: recordName, in: databaseID)
		if  created.zoneName == nil || created.zoneName!.isEmpty {
			created.zoneName  = named
		}

		return created
	}

	static func uniqueZone(recordName: String?, in dbID: ZDatabaseID) -> Zone {
		return uniqueZRecord(entityName: kZoneType, recordName: recordName, in: dbID) as! Zone
	}

	static func uniqueZone(from dict: ZStorageDictionary, in dbID: ZDatabaseID) -> Zone {
		let result = uniqueZone(recordName: dict.recordName, in: dbID)

		result.temporarilyIgnoreNeeds {
			do {
				try result.extractFromStorageDictionary(dict, of: kZoneType, into: dbID)
			} catch {
				printDebug(.dError, "\(error)")    // de-serialization
			}
		}

		return result
	}

	func rootName(for type: ZStorageType) -> String? {
		switch type {
			case .favorites: return kFavoritesRootName
			case .lost:      return kLostAndFoundName
			case .recent:    return kRecentsRootName
			case .trash:     return kTrashName
			case .graph:     return kRootName
			default:         return nil
		}
	}

	func updateRecordName(for type: ZStorageType) {
		if  let    name = rootName(for: type),
			recordName != name {

			for child in children {
				child.parentZone = self // because record name is different, children must be pointed through a ck reference to new record created above
			}
		}
	}

	override func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) throws {
		if  let name = dict[.name] as? String,
			responds(to: #selector(setter: self.zoneName)) {
			zoneName = name
		}

		try super.extractFromStorageDictionary(dict, of: iRecordType, into: iDatabaseID) // do this step last so the assignment above is NOT pushed to cloud

		if  let childrenDicts: [ZStorageDictionary] = dict[.children] as! [ZStorageDictionary]? {
			for childDict: ZStorageDictionary in childrenDicts {
				let child = Zone.uniqueZone(from: childDict, in: iDatabaseID)
				cloud?.temporarilyIgnoreAllNeeds() {        // prevent needsSave caused by child's parent intentionally not being in childDict
					addChildNoDuplicate(child, at: nil)
				}
			}

			respectOrder()
		}

		if  let traitsStore: [ZStorageDictionary] = dict[.traits] as! [ZStorageDictionary]? {
			for  traitStore:  ZStorageDictionary in traitsStore {
				let trait = ZTrait.uniqueTrait(from: traitStore, in: iDatabaseID)

				cloud?.temporarilyIgnoreAllNeeds {       // prevent needsSave caused by trait intentionally not being in traits
					addTrait(trait)
				}

				if  gPrintModes.contains(.dNotes),
					let   tt = trait.type,
					let type = ZTraitType(rawValue: tt),
					type    == .tNote {
					printDebug(.dNotes, "trait (in " + (zoneName ?? kUnknown) + ") --> " + (trait.format ?? "empty"))
				}
			}
		}
	}

	override func createStorageDictionary(for iDatabaseID: ZDatabaseID, includeRecordName: Bool = true, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> ZStorageDictionary? {

		var dict             = try super.createStorageDictionary(for: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) ?? ZStorageDictionary ()

		if  (includeInvisibles || expanded),
			let childrenDict = try (children as ZRecordsArray).createStorageArray(from: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
			dict [.children] = childrenDict as NSObject?
		}

		if  let   traitsDict = try traitsArray.createStorageArray(from: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
			dict   [.traits] = traitsDict as NSObject?
		}

		return dict
	}

}