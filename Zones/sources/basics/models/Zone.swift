//
//  Zone.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

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

struct ZWorkingListType: OptionSet {
	let rawValue : Int
	
	init(rawValue: Int) { self.rawValue = rawValue }

	static let wBookmarks = ZWorkingListType(rawValue: 1 << 0)
	static let wNotemarks = ZWorkingListType(rawValue: 1 << 1)
	static let   wProgeny = ZWorkingListType(rawValue: 1 << 2)
	static let       wAll = ZWorkingListType(rawValue: 1 << 3)
}

@objc (Zone)
class Zone : ZRecord, ZIdentifiable, ZToolable {

	@NSManaged    var          zoneOrder :           NSNumber?
	@NSManaged    var          zoneCount :           NSNumber?
	@NSManaged    var         zoneAccess :           NSNumber?
	@NSManaged    var        zoneProgeny :           NSNumber?
	@NSManaged    var          parentRID :             String?
	@NSManaged    var           zoneName :             String?
	@NSManaged    var           zoneLink :             String?
	@NSManaged    var          zoneColor :             String?
	@NSManaged    var         parentLink :             String?
	@NSManaged    var         zoneAuthor :             String?
	@NSManaged    var     zoneAttributes :             String?
	var                   hyperLinkMaybe :             String?
	var                       emailMaybe :             String?
	var                       assetMaybe :            CKAsset?
	var                       colorMaybe :             ZColor?
	var                        noteMaybe :              ZNote?
	var                   crossLinkMaybe :            ZRecord?
	var                  parentZoneMaybe :               Zone?
	var                             root :               Zone?
	var                       groupOwner :               Zone? { if let (_, r) = groupOwner([]) { return r } else { return nil } }
	var                   bookmarkTarget :               Zone? { return crossLink as? Zone }
	var                      destroyZone :               Zone? { return cloud?.destroyZone }
	var                        trashZone :               Zone? { return cloud?.trashZone }
	var                         manifest :          ZManifest? { return cloud?.manifest }
	var                           widget :         ZoneWidget? { return gWidgets.widgetForZone(self) }
	var                     widgetObject :      ZWidgetObject? { return widget?.widgetObject }
	var                   linkDatabaseID :        ZDatabaseID? { return zoneLink?.maybeDatabaseID }
	var                        textColor :             ZColor? { return (gColorfulMode && colorized) ? color?.darker(by: 3.0) : kDefaultIdeaColor }
	var                        emailLink :             String? { return email == nil ? nil : "mailTo:\(email!)" }
	var                   linkRecordName :             String? { return zoneLink?.maybeRecordName }
	var                    lowestExposed :                Int? { return exposed(upTo: highestExposed) }
	var                            count :                Int  { return children.count }
	var                         dotColor :             ZColor  { return widgetType.isExemplar ? gHelpHyperlinkColor : gColorfulMode ? (color ?? kDefaultIdeaColor) : kDefaultIdeaColor }
	var                 smallMapRootName :             String  { return isFavoritesRoot ? kFavoritesRootName : isRecentsRoot ? kRecentsRootName : emptyName }
	var                      clippedName :             String  { return !gShowToolTips ? kEmpty : unwrappedName }
	override var               emptyName :             String  { return kEmptyIdea }
	override var             description :             String  { return decoratedName }
	override var           unwrappedName :             String  { return zoneName ?? smallMapRootName }
	override var           decoratedName :             String  { return decoration + unwrappedName }
	override var         cloudProperties :       StringsArray  { return Zone.cloudProperties }
	override var optionalCloudProperties :       StringsArray  { return Zone.optionalCloudProperties }
	override var              isBrandNew :               Bool  { return zoneName == nil || zoneName == kEmpty }
	override var             isAdoptable :               Bool  { return parentRID != nil || parentLink != nil }
	override var                 isAZone :               Bool  { return true }
	override var                 isARoot :               Bool  { return !gHasFinishedStartup ? super.isARoot : parentZoneMaybe == nil }
	var                       isBookmark :               Bool  { return bookmarkTarget != nil }
	var        isCurrentSmallMapBookmark :               Bool  { return isCurrentFavorite || isCurrentRecent }
	var                  isCurrentRecent :               Bool  { return self ==   gRecents.currentBookmark }
	var                isCurrentFavorite :               Bool  { return self == gFavorites.currentBookmark }
	var               hasVisibleChildren :               Bool  { return isExpanded && count > 0 }
	var                  dragDotIsHidden :               Bool  { return (isSmallMapHere && !(widget?.type.isBigMap ?? false)) || (kIsPhone && self == gHereMaybe && isExpanded) } // hide favorites root drag dot
	var               canRelocateInOrOut :               Bool  { return parentZoneMaybe?.widget != nil }
	var                      hasSiblings :               Bool  { return parentZoneMaybe?.count ?? 0 > 1 }
	var                 hasBadRecordName :               Bool  { return recordName == nil }
	var                    showRevealDot :               Bool  { return count > 0 || isTraveller }
	var                    hasZonesBelow :               Bool  { return hasAnyZonesAbove(false) }
	var                    hasZonesAbove :               Bool  { return hasAnyZonesAbove(true) }
	var                     hasHyperlink :               Bool  { return hasTrait(for: .tHyperlink) && hyperLink != kNullLink && !(hyperLink?.isEmpty ?? true) }
	var                      isTraveller :               Bool  { return isBookmark || hasHyperlink || hasEmail || hasNote }
	var                       linkIsRoot :               Bool  { return linkRecordName == kRootName }
	var                       isSelected :               Bool  { return gSelecting.isSelected(self) }
	var                        isGrabbed :               Bool  { return gSelecting .isGrabbed(self) }
	var                         hasColor :               Bool  { return zoneColor != nil && !zoneColor!.isEmpty }
	var                         hasEmail :               Bool  { return hasTrait(for: .tEmail) && !(email?.isEmpty ?? true) }
	var                         hasAsset :               Bool  { return hasTrait(for: .tAssets) }
	var                          hasNote :               Bool  { return hasTrait(for: .tNote) }
	var                        isInTrash :               Bool  { return root?.isTrashRoot        ?? false }
	var                       isInBigMap :               Bool  { return root?.isBigMapRoot       ?? false }
	var                       isInAnyMap :               Bool  { return root?.isAnyMapRoot       ?? false }
	var                      isInDestroy :               Bool  { return root?.isDestroyRoot      ?? false }
	var                      isInRecents :               Bool  { return root?.isRecentsRoot      ?? false }
	var                     isInSmallMap :               Bool  { return root?.isSmallMapRoot     ?? false }
	var                    isInFavorites :               Bool  { return root?.isFavoritesRoot    ?? false }
	var                 isInLostAndFound :               Bool  { return root?.isLostAndFoundRoot ?? false }
	var                   isReadOnlyRoot :               Bool  { return isLostAndFoundRoot || isFavoritesRoot || isTrashRoot || widgetType.isExemplar }
	var                   spawnedByAGrab :               Bool  { return spawnedByAny(of: gSelecting.currentMapGrabs) }
	var                       spawnCycle :               Bool  { return spawnedByAGrab || dropCycle }
	var                        dropCycle :               Bool  { return gDragging.draggedZones.contains(self) || spawnedByAny(of: gDragging.draggedZones) || (bookmarkTarget?.dropCycle ?? false) }
	var                       isInAGroup :               Bool  { return groupOwner?.bookmarkTargets.contains(self) ?? false }
	var                    isAGroupOwner :               Bool  { return zoneAttributes?.contains(ZoneAttributeType.groupOwner.rawValue) ?? false }
	var                      userCanMove :               Bool  { return userCanMutateProgeny   || isBookmark } // all bookmarks are movable because they are created by user and live in my databasse
	var                     userCanWrite :               Bool  { return userHasDirectOwnership || isIdeaEditable }
	var             userCanMutateProgeny :               Bool  { return userHasDirectOwnership || inheritedAccess != .eReadOnly }
	var                      hideDragDot :               Bool  { return isExpanded && (isSmallMapHere || (kIsPhone && (self == gHereMaybe))) }
	var                  inheritedAccess :         ZoneAccess  { return zoneWithInheritedAccess.directAccess }
	var   smallMapBookmarksTargetingSelf :          ZoneArray  { return bookmarksTargetingSelf.filter { $0.isInSmallMap } }
	var           bookmarkTargets        :          ZoneArray  { return bookmarks.map { return $0.bookmarkTarget! } }
	var           bookmarks              :          ZoneArray  { return zones(of:  .wBookmarks) }
	var           notemarks              :          ZoneArray  { return zones(of:  .wNotemarks) }
	var                allProgeny        :          ZoneArray  { return zones(of:               .wProgeny)  }
	var        allNotemarkProgeny        :          ZoneArray  { return zones(of: [.wNotemarks, .wProgeny]) }
	var        allBookmarkProgeny        :          ZoneArray  { return zones(of: [.wBookmarks, .wProgeny]) }
	var        all                       :          ZoneArray  { return zones(of:               .wAll) }
	var                  visibleChildren :          ZoneArray  { return hasVisibleChildren ? children : [] }
	var                   duplicateZones =          ZoneArray  ()
	var                         children =          ZoneArray  ()
	var                           traits =   ZTraitDictionary  ()
	func                   identifier() ->             String? { return isARoot ? databaseID.rawValue : recordName }
	func                     toolName() ->             String? { return clippedName }
	func                    toolColor() ->             ZColor? { return color?.lighter(by: 3.0) }
	func                toggleShowing()                        { isShowing ? hide() : show() }
	func                      recount()                        { updateAllProgenyCounts() }
	class  func randomZone(in dbID: ZDatabaseID)         ->     Zone  { return Zone.uniqueZoneNamed(String(arc4random()), databaseID: dbID) }
	static func object(for id: String, isExpanded: Bool) -> NSObject? { return gRemoteStorage.maybeZoneForRecordName(id) }
	override func hasMissingChildren()                   ->     Bool  { return count < fetchableCount }
	override func orphan()                                            { parentZone?.removeChild(self) }
	func maybeTraitFor(_ iType: ZTraitType)              -> ZTrait?   { return traits[iType] }
	func updateRootFromParent()                                       { setRoot(parentZone?.root ?? self) }
	func setRoot(_ iRoot: Zone?)                                      { if let r = iRoot { root = r } }

	override var passesFilter: Bool {
		return isBookmark && gFilterOption.contains(.fBookmarks) || !isBookmark && gFilterOption.contains(.fIdeas)
	}

	override var isInScope: Bool {
		if  let name = root?.recordName {
			switch databaseID {
				case .favoritesID: if gSearchScopeOption.contains(.fFavorites), name == kFavoritesRootName { return true }
				case .recentsID:   if gSearchScopeOption.contains(.fRecent),    name == kRecentsRootName   { return true }
				case .everyoneID:  if gSearchScopeOption.contains(.fPublic),    name == kRootName          { return true }
				case .mineID:      if gSearchScopeOption.contains(.fMine),      name == kRootName          { return true }
			}

			if  gSearchScopeOption.contains(.fTrash) {
				return name == kTrashName || name == kDestroyName
			}
		} else {
			return gSearchScopeOption.contains(.fOrphan)
		}

		return false
	}

	var visibleDoneZone: Zone? {
		var done: Zone?

		gHere.traverseAllProgeny { child in
			if  child.zoneName == kDone,
				child != self,
				child.isVisible,
				(done == nil || done!.level > child.level) {
				done = child
			}
		}

		return done
	}

	var zonesWithNotes : ZoneArray {
		var zones = ZoneArray()

		traverseAllProgeny { zone in
			if  zone.hasNote {
				zones.append(zone)
			}
		}

		return zones
	}

	var level: Int {
		var level = 0

		parentZone?.traverseAllAncestors { ancestor in
			level += 1
		}

		return level
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

	struct ZoneType: OptionSet {
		let rawValue : Int

		init(rawValue: Int) { self.rawValue = rawValue }

		static let zChildless = ZoneType(rawValue: 0x0001)
		static let zTrait     = ZoneType(rawValue: 0x0002)
		static let zNote      = ZoneType(rawValue: 0x0004)
		static let zDuplicate = ZoneType(rawValue: 0x0008)
		static let zBookmark  = ZoneType(rawValue: 0x0010)
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

	// MARK: - bookmarks
	// MARK: -

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
		return (bookmarkTarget != nil && (type.contains(.wBookmarks) || (type.contains(.wNotemarks) && bookmarkTarget!.hasNote)))
	}

	func addBookmark() {
		if  !isARoot {
			if  gHere == self {
				gHere  = parentZone ?? gHere
				
				revealParentAndSiblings()
			}

			gNewOrExistingBookmark(targeting: self, addTo: parentZone).grab()
			gRelayoutMaps()
		}
	}

	// MARK: - setup
	// MARK: -

	func updateInstanceProperties() {
		if  gIsUsingCoreData {
			if  let    id = parentZoneMaybe?.recordName {
				parentRID = id
			}
		}
	}

	// MARK: - properties
	// MARK: -

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
		let theCopy = Zone.uniqueZoneNamed("noname", databaseID: id)

		copyInto(theCopy)
		gBookmarks.addToReverseLookup(theCopy)   // only works for bookmarks

		theCopy.parentZone = nil

		let zones = gListsGrowDown ? children : children.reversed()

		for child in zones {
			theCopy.addChildNoDuplicate(child.deepCopy(dbID: id))
		}

		for trait in traits.values {
			let  traitCopy = trait.deepCopy(dbID: id)
			traitCopy.dbid = id.identifier

			theCopy.addTrait(traitCopy)
		}

		return theCopy
	}

	var ancestralPath: ZoneArray {
		var  results = ZoneArray()

		traverseAllAncestors { ancestor in
			results = [ancestor] + results
		}

		return results
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

	override var color: ZColor? {
		get {
			var computed: ZColor? = kDefaultIdeaColor

			if  gColorfulMode {
				if  let       b = bookmarkTarget {
					return b.color
				} else if let m = colorMaybe ?? zoneColor?.color {
					computed    = m
				} else if let c = parentZone?.color {
					return c
				}
			}

			if  gIsDark {
				computed = computed?.inverted.lighter(by: 3.0)
			}

			return computed
		}

		set {
			var computed = newValue

			if  gIsDark {
				computed = computed?.inverted
			}

			if  let             b = bookmarkTarget {
				b.color           = newValue
			} else if colorMaybe != computed {
				colorMaybe        = computed
				zoneColor         = computed?.string ?? kEmpty
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

	var crumbFillColor: ZColor { // not used
		let visible = ancestralPath.contains(gHere)

		if  gColorfulMode {
			return visible ? gActiveColor .lighter(by: 4.0) : gAccentColor
		} else if  gIsDark {
			return visible ? kDarkGrayColor.darker(by: 6.0) : kDarkGrayColor.darker(by: 4.0)
		} else {
			return visible ? kDarkGrayColor.darker(by: 3.0) : kLighterGrayColor
		}
	}

	var crumbBorderColor: ZColor { // not used
		let visible = ancestralPath.contains(gHere)

		if  gColorfulMode {
			return visible ? gActiveColor .lighter(by: 4.0) : gAccentColor
		} else if  gIsDark {
			return visible ? kDarkGrayColor.darker(by: 6.0) : kDarkGrayColor.darker(by: 4.0)
		} else {
			return visible ? kDarkGrayColor.darker(by: 3.0) : kLighterGrayColor
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

			return iZone.isExpanded ? .eContinue : .eSkip
		}

		return highest
	}

	func unlinkParentAndMaybeNeedSave() {
		if  parentZoneMaybe != nil ||
				(parentLink  != nil &&
				 parentLink  != kNullLink) {
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
			if  root == self {
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
			if  root == self {
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
					if  sibling.order > order {
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

	var offsetFromMiddle : Double {
		var index = ((Double(parentZone?.count ?? 0) / 2.0) - Double(siblingIndex ?? 0)) * 0.8
		let limit = 6.0
		if  index < .zero {
			index = max(index, -limit)
		} else {
			index = min(index,  limit)
		}

		return index
	}

	var canEditNow: Bool {   // workaround recently introduced change in become first responder invocation logic [aka: fucked it up]
		return !gRefusesFirstResponder
			&&  userWantsToEdit
			&&  userCanWrite
	}

	var userWantsToEdit: Bool {
		let key = gCurrentKeyPressed ?? kEmpty
		return "-deh \t\r".contains(key)
		|| gCurrentKeyPressed?.arrow != nil
		|| gCurrentMouseDownZone     == self
	}

	// MARK: - core data
	// MARK: -

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
					FOREGROUND { [self] in
						addChildNoDuplicate(child, updateCoreData: false) // not update core data, it already exists
						child.register() // need to wait until after child has a parent so bookmarks will be registered properly
					}
				}
			}

			FOREGROUND { [self] in
				respectOrder()
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
		if  gIsUsingCoreData,
			let      zID = dbid {
			var childSet = Set<Zone>()
			var traitSet = Set<ZTrait>()

			for child in children {
				if  let cID = child.dbid,
					zID    == cID,
					let   c = child.selfInCurrentBackgroundCDContext as? Zone {                  // avoid cross-store relationships
					childSet.insert(c)
				}
			}

			for trait in traits.values {
				if  let tID = trait.dbid,
					zID    == tID,
					let   t = trait.selfInCurrentBackgroundCDContext as? ZTrait {                // avoid cross-store relationships
					traitSet.insert(t)
				}
			}

			if  childSet.count > 0 {
				setValue(childSet as NSObject, forKeyPath: kChildArray)
			} else {
				setValue(nil,                  forKeyPath: kChildArray)
			}

			if  traitSet.count > 0 {
				setValue(traitSet as NSObject, forKeyPath: kTraitArray)
			} else {
				setValue(nil,                  forKeyPath: kTraitArray)
			}
		}
	}

	// MARK: - write access
	// MARK: -

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

	// MARK: - edit map
	// MARK: -

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
				gControllers.signalFor(self, multiple: [.spRelayout]) {
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
					if  containing {
						child.acquireZones(zones)
					}

					gRelayoutMaps(for: parent) {
						completion(child)
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

			kScratchZone.children = []

			kScratchZone.acquireZones(children)
			moveZone(into: grandP, at: parentI, orphan: true) { [self] in
				acquireZones(parent.children)
				parent.moveZone(into: self, at: grabbedI, orphan: true) {
					parent.acquireZones(kScratchZone.children)
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
			let newIdea = Zone.uniqueZoneNamed(name, databaseID: databaseID)

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
			addChildAndReorder(newIdea, at: iIndex, { addedChild in onCompletion?(newIdea) } )
		}
	}

	func deleteSelf(permanently: Bool = false, onCompletion: Closure?) {
		if  isARoot {
			onCompletion?() // deleting root would be a disaster
		} else {
			maybeRestoreParent()

			let parent = parentZone
			if  self  == gHere {                         // this can only happen ONCE during recursion (multiple places, below)
				let recurse: Closure = { [self] in

					// //////////
					// RECURSE //
					// //////////

					deleteSelf(permanently: permanently, onCompletion: onCompletion)
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
				let finishDeletion: Closure = { [self] in
					if  let            p = parent, p != self {
						p.fetchableCount = p.count       // delete alters the count

						if  p.count == 0, p.isInSmallMap,
							let g = p.parentZone {
							gCurrentSmallMapRecords?.hereZoneMaybe = g

							g.expand()
							p.grab()
						}
					}

					// //////////
					// RECURSE //
					// //////////

					bookmarksTargetingSelf.deleteZones(permanently: permanently) {
						onCompletion?()
					}
				}

				addToPaste()

				if  isInTrash {
					moveZone(to: destroyZone) {
						finishDeletion()
					}
				} else if !permanently, !isInDestroy {
					moveZone(to: trashZone) {
						finishDeletion()
					}
				} else {
					concealAllProgeny()           // shrink gExpandedZones list
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
							finishDeletion()
						}
					} else {
						finishDeletion()
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
			let childName = widget?.textWidget?.extractTitleOrSelectedText() {

			gTextEditor.stopCurrentEdit()

			gDeferRedraw {
				parent.addIdea(at: index, with: childName) { [self] iChild in
					moveZone(to: iChild) {
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
				iUndoSelf.moveZone(into: parent, at: index, orphan: orphan) { onCompletion?() }
			}
		}

		into.expand()

		if  orphan {
			self.orphan() // remove from current parent
			maybeRestoreParent()
			self.orphan() // in case parent was restored
		}

		into.addChildAndReorder(self, at: iIndex) { addedChild in

			if !addedChild.isInTrash { // so grab won't disappear
				addedChild.grab()
			}

			onCompletion?()
		}
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

	func browseRight(extreme: Bool = false, onCompletion: BoolClosure?) {
		if  isBookmark {
			invokeBookmark(onCompletion: onCompletion)
		} else if isTraveller && fetchableCount == 0 && count == 0 {
			invokeTravel(onCompletion: onCompletion)
		} else if isInBigMap {
			addAGrab(extreme: extreme, onCompletion: onCompletion)
		} else if let next = gListsGrowDown ? children.last : children.first {
			parentZone?.collapse()
			setAsSmallMapHereZone()
			expand()
			next.grab()
			gSignal([.spCrumbs, .spDataDetails, .spSmallMap, .sDetails])
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
					g.concealAllProgeny()
					g.expand()
					g.setAsSmallMapHereZone()
					// FUBAR: parent sometimes disappears!!!!!!!!!
				} else if p.isARoot {
					onCompletion?(true)
					return // do nothing if p is root of either small map
				}

				p.grab()
				gSignal([.spCrumbs, .spDataDetails, .spSmallMap, .sDetails])
			}
		} else if let bookmark = firstBookmarkTargetingSelf {		 // self is an orphan
			gHere              = bookmark			                 // change focus to bookmark of self
		}

		onCompletion?(true)
	}

	// MARK: - import
	// MARK: -

	func importFromFile(_ type: ZExportType, onCompletion: Closure?) {
		ZFiles.presentOpenPanel() { [self] (iAny) in
			if  let url = iAny as? URL {
				importFile(from: url.path, type: type, onCompletion: onCompletion)
			} else if let panel = iAny as? NSOpenPanel {
				let  suffix = type.rawValue
				panel.title = "Import as \(suffix)"
				panel.allowedFileTypes = [suffix]
			}
		}
	}

	func importSeriously(from data: Data) -> Zone? {
		var zone: Zone?
		if  let json = data.extractJSONDict() {
			let dict = dictFromJSON(json)
			temporarilyOverrideIgnore { // allow needs save
				zone = Zone.uniqueZone(from: dict, in: databaseID)
			}
		}

		return zone
	}

	func importCSV(from data: Data, kumuFlavor: Bool = false) -> Zone {
		let   rows = data.extractCSV()
		var titles = [String : Int]()
		let first = rows[0]
		for (index, title) in first.enumerated() {
			titles[title] = index
		}

		let top = childWithName("Press Conference")

		for (index, row) in rows.enumerated() {
			if  index     != 0,
				let nIndex = titles["Name"],
				let tIndex = titles["Type"],
				row.count  > tIndex {
				let   name = row[nIndex]
				let   type = row[tIndex]
				let  child = top  .childWithName(type)
				let   zone = child.childWithName(name)

				if  let dIndex = titles["Description"] {
					let   text = row[dIndex]
					let  trait = ZTrait.uniqueTrait(recordName: nil, in: databaseID)
					trait.traitType = .tNote
					trait.text = text
					zone.addTrait(trait)
				}
			}
		}

		return top
	}

	func importFile(from path: String, type: ZExportType = .eSeriously, onCompletion: Closure?) {
			if  let     data = FileManager.default.contents(atPath: path),
				data.count > 0 {
				var zone: Zone?

				switch type {
					case .eSeriously: zone = importSeriously(from: data)
					default:          zone = importCSV      (from: data, kumuFlavor: true)
				}

				if  let z = zone {
					addChildNoDuplicate(z, at: 0)
				}

				onCompletion?()
			}
	}

	// MARK: - convenience
	// MARK: -

	func        addToPaste() { gSelecting   .pasteableZones[self] = (parentZone, siblingIndex) }
	func        addToGrabs() { gSelecting.addMultipleGrabs([self]) }
	func ungrabAssuringOne() { gSelecting.ungrabAssuringOne(self) }
	func            ungrab() { gSelecting           .ungrab(self) }
	func editTraitForType(_ type: ZTraitType) { gTextEditor.edit(traitFor(type)) }

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
		FOREGROUND { [self] in
			let newRange = range ?? NSRange(location: 0, length: zoneName?.length ?? 0)

			widget?.textWidget?.selectCharacter(in: newRange)
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

	// MARK: - traits
	// MARK: -

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

	func hasTrait(matchingAny iTypes: [ZTraitType]) -> Bool {
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
				case .tEmail:     emailMaybe     = iText
				case .tHyperlink: hyperLinkMaybe = iText
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
			t.unregister()
			gCDCurrentBackgroundContext.delete(t)
		}
	}

	// MARK: - notes / essays
	// MARK: -

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

	@discardableResult func createNoteMaybe() -> ZNote? {
		if (noteMaybe == nil || !hasTrait(matchingAny: [.tNote, .tEssay])), let emptyNote = createNote() {
			return emptyNote // might be note from "child"
		}

		return noteMaybe
	}

	var note: ZNote? {
		if  isBookmark {
			return bookmarkTarget!.note
		}

		return createNoteMaybe()
	}

	@discardableResult func createNote() -> ZNote? {
		let zones = zonesWithNotes
		let count = zones.count
		var  note : ZNote?

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

	func deleteEssay() {
		if  let c = note?.children {
			for child in c {
				if  let z = child.zone, z != self {
					z.deleteEssay()
				}
			}
		}

		deleteNote()
	}

	func showNote() {
		gCreateCombinedEssay = false
		gCurrentEssay        = note

		gControllers.swapMapAndEssay(force: .wEssayMode)
	}

	// MARK: - groupOwner
	// MARK: -

	var parentOwnsAGroup : Zone? {
		if  isInAnyMap,
			let    p = parentZone, p.isAGroupOwner, p.isInAnyMap, p.count > 1 {
			return p
		}

		return nil
	}

	private func groupOwner(_ iVisited: StringsArray) -> (StringsArray, Zone)? {
		guard let name = recordName, gHasFinishedStartup, !iVisited.contains(name) else {
			return nil      // avoid looking more than once per zone for a group owner
		}

		var visited = iVisited

		visited.appendUnique(item: name)

		if  isAGroupOwner, isInAnyMap, count > 1 {
			return (visited, self)
		}

		if  let t = bookmarkTarget {
			return t.groupOwner(visited)
		}

		if  let p = parentOwnsAGroup {
			visited.appendUnique(item: p.recordName)

			return (visited, p)
		}

		for b in bookmarksTargetingSelf {
			visited.appendUnique(item: b.recordName)
			visited.appendUnique(item: b.parentZone?.recordName)

			if  let g = b.parentOwnsAGroup {
				return (visited, g)
			}
		}

		for target in bookmarkTargets {
			if  let (v, r) = target.groupOwner(visited) {
				visited.appendUnique(contentsOf: v)

				return (visited, r)
			}
		}

		return nil
	}

	func ownedGroup(_ iVisited: StringsArray) -> ZoneArray? {
		guard let name = recordName, !iVisited.contains(name) else { return nil }
		var      zones = ZoneArray()
		var    visited = iVisited

		func append(_ zone: Zone?) {
			if  isInAnyMap {    // disallow rootless, trash, etc.
				zones  .appendUnique(item: zone)
				visited.appendUnique(item: zone?.recordName)
			}
		}

		visited.appendUnique(item: name)

		for bookmark in bookmarks {
			if  let target = bookmark.bookmarkTarget,
				!visited.containsAnyOf(target.recordName) {
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

	@discardableResult func cycleToNextInGroup(_ forward: Bool) -> Bool {
		guard   let   rr = groupOwner else {
			if  self    != gHere {
				gHere.cycleToNextInGroup(forward)
			}

			return true
		}

		if  let     r = rr.ownedGroup([]), r.count > 1,
			let index = indexIn(r),
			let  zone = r.next(from: index, forward: forward) {
			gHere     = zone

//			print("\(rr) : \(r) -> \(zone)") // very helpful in final debugging

			gFavorites.show(zone)
			zone.grab()
			gRelayoutMaps()

			return true
		}

		return false
	}

	// MARK: - travel / focus / move / bookmarks
	// MARK: -

	@discardableResult func focusThrough(_ atArrival: @escaping Closure) -> Bool {
		if  isBookmark {
			if  isInSmallMap {
				let targetParent = bookmarkTarget?.parentZone

				targetParent?.expand()
				focusOnBookmarkTarget { (iObject: Any?, kind: ZSignalKind) in
					gCurrentSmallMapRecords?.updateCurrentBookmark()
					atArrival()
				}

				return true
			} else if let dbID = crossLink?.databaseID {
				gDatabaseID = dbID

				gFocusing.focusOnGrab {
					gHere.grab()
					atArrival()
				}

				return true
			}

			performance("bookmark with bad db crosslink")
		}

		return false
	}

	func expandGrabAndFocusOn() {
		gHere = self

		expand()
		grab()
	}

	func focusOnBookmarkTarget(atArrival: @escaping SignalClosure) {
		if  let    targetZRecord = crossLink,
			let targetRecordName = targetZRecord.recordName {
			let       targetDBID = targetZRecord.databaseID
			let           target = bookmarkTarget

			let complete : SignalClosure = { [self] (iObject, kind) in
				showTopLevelFunctions()
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

				complete(target, .spRelayout)
			} else {
				gShowSmallMapForIOS = targetDBID.isSmallMapDB

				if  gDatabaseID != targetDBID {
					gDatabaseID  = targetDBID

					// ///////////////////////// //
					// TRAVEL TO A DIFFERENT MAP //
					// ///////////////////////// //

					if  let here = target { // e.g., default root favorite
						gFocusing.focusOnGrab(.eSelected) {
							here.expandGrabAndFocusOn()
							complete(gHere, .spRelayout)
						}
					} else if let here = gCloud?.maybeZoneForRecordName(targetRecordName) {
						here.expandGrabAndFocusOn()
						gFocusing.focusOnGrab {
							complete(gHere, .spRelayout)
						}
					} else {
						complete(gHere, .spRelayout)
					}
				} else {

					// /////////////// //
					// STAY WITHIN MAP //
					// /////////////// //

					there = gRecords?.maybeZoneForRecordName(targetRecordName)
					let grabbed = gSelecting.firstSortedGrab
					let    here = gHere

					UNDO(self) { iUndoSelf in
						iUndoSelf.UNDO(self) { iRedoSelf in
							iRedoSelf.focusOnBookmarkTarget(atArrival: complete)
						}

						gHere = here

						grabbed?.grab()
						complete(here, .spRelayout)
					}

					if  there != nil {
						there?.expandGrabAndFocusOn()
					} else if let    r = gRecords, !r.databaseID.isSmallMapDB, // small maps have no lookup???
							  let here = r.maybeZoneForRecordName(targetRecordName) {
						here.expandGrabAndFocusOn()
					} // else ignore: favorites id with an unresolvable bookmark target

					complete(gHereMaybe, .spRelayout)
				}
			}
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
			gCreateCombinedEssay = true
			gCurrentEssay        = note

			if  gIsEssayMode {
				gEssayView?.updateTextStorage()
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

				gSignal([.spSmallMap, .spRelayout])
			}
		}
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
			let expand = !zone.isExpanded
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
			gSignal([.spCrumbs, .spDataDetails, .spSmallMap, .spBigMap])
		}
	}

	func addZones(_ iZones: ZoneArray, at iIndex: Int?, undoManager iUndoManager: UndoManager?, _ flags: ZEventFlags, onCompletion: Closure?) {

		if  iZones.count == 0 {
			return
		}

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
		var        zones = iZones
		var      restore = [Zone: (Zone, Int?)] ()
		let     STAYHERE = flags.exactlySpecial
		let   NOBOOKMARK = flags.isControl
		let         COPY = flags.isOption
		var    cyclicals = IndexSet()

		// separate zones that are connected back to themselves

		for (index, zone) in zones.enumerated() {
			if  spawnedBy(zone) {
				cyclicals.insert(index)
			} else if let parent = zone.parentZone {
				let siblingIndex = zone.siblingIndex
				restore[zone]    = (parent, siblingIndex)
			}
		}

		while let index = cyclicals.last {
			cyclicals.remove(index)
			zones.remove(at: index)
		}

		// case 4

		zones.sort { (a, b) -> Bool in
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
				zoneSelf.addZones(zones, at: iIndex, undoManager: undoManager, flags, onCompletion: onCompletion)
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
				if  let firstGrab = zones.first,
					let fromIndex = firstGrab.siblingIndex,
					(firstGrab.parentZone != into || fromIndex > (iIndex ?? 1000)) {
					zones = zones.reversed()
				}

				gSelecting.ungrabAll()

				for grab in zones {
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

	// MARK: - traverse ancestors
	// MARK: -

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
			if  iAncestor != self, !iAncestor.isExpanded {
				isVisible  = false

				return .eStop
			}

			if  let  here  = widget?.controller?.hereZone,     // so this will also be correct for small map
				iAncestor == here {
				return .eStop
			}

			return .eContinue
		}

		return isVisible
	}

	func asssureIsVisible() {
		if  let goal = gRemoteStorage.zRecords(for: databaseID)?.currentHere {

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

	// MARK: - traverse progeny
	// MARK: -

	var visibleWidgets: ZoneWidgetArray {
		var visible = ZoneWidgetArray()

		traverseProgeny { iZone -> ZTraverseStatus in
			if  let w = iZone.widget {
				visible.append(w)
			}

			return iZone.isExpanded ? .eContinue : .eSkip
		}

		return visible
	}

	func concealAllProgeny() {
		traverseAllProgeny(inReverse: true) { iChild in
			iChild.collapse()
		}
	}

	func traverseAllProgeny(inReverse: Bool = false, _ block: ZoneClosure) {
		safeTraverseProgeny(visited: [], inReverse: inReverse) { iZone -> ZTraverseStatus in
			block(iZone)

			return .eContinue
		}
	}

	@discardableResult func traverseProgeny(inReverse: Bool = false, _ block: ZoneToStatusClosure) -> ZTraverseStatus {
		return safeTraverseProgeny(visited: [], inReverse: inReverse, block)
	}

	func traverseAllVisibleProgeny(inReverse: Bool = false, _ block: ZoneClosure) {
		safeTraverseProgeny(visited: [], inReverse: inReverse) { iZone -> ZTraverseStatus in
			block(iZone)

			return iZone.isExpanded ? .eContinue : .eSkip
		}
	}

	@discardableResult func safeTraverseProgeny(visited: ZoneArray, inReverse: Bool = false, _ block: ZoneToStatusClosure) -> ZTraverseStatus {
		var status  = ZTraverseStatus.eContinue

		if !inReverse {
			status  = block(self)               // first call block on self, then recurse on each child
		}

		if  status == .eContinue {
			for child in children {
				if  visited.contains(child) {
					break						// do not revisit or traverse further inward
				}

				status = child.safeTraverseProgeny(visited: visited + [self], inReverse: inReverse, block)

				if  status == .eStop {
					break						// halt traversal
				}
			}
		}

		if  inReverse {
			status  = block(self)
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
				if  iZone.level > iLevel || iZone == self {
					return .eSkip
				} else if iZone.level == iLevel && iZone != self && (iZone.parentZone == nil || iZone.parentZone!.isExpanded) {
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
				if  !child.isExpanded && child.fetchableCount != 0 {
					return exposedLevel
				}
			}
		}

		return level
	}

	// MARK: - siblings
	// MARK: -

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

	// MARK: - children visibility
	// MARK: -

	func     hide() {    add(  to: .hide) }
	func   expand() {    add(  to: .expand) }
	func collapse() { remove(from: .expand) }
	func     show() { remove(from: .hide) }

	func toggleChildrenVisibility() {
		if  isExpanded {
			collapse()
		} else {
			expand()
		}
	}

	var isExpanded: Bool {
		if  let name = recordName,
			gExpandedZones.contains(name) {
			return true
		}

		return false
	}

	var isShowing: Bool {
		if  let w = widget, w.isLinearMode {
			return true
		}

		if  self == gHere {
			return true
		}

		if  let name = recordName {
			return !gHiddenZones.contains(name)
		}

		return true
	}
	
	func add(to type: ZVisibilityType) {
		var a = type.array

		add(to: &a)
		
		if  type == .expand {
			for child in children {
				child.remove(from: .hide)
			}
		}
		
		type.setArray(a)
	}
	
	func remove(from type: ZVisibilityType) {
		var a = type.array

		remove(from: &a)
		
		type.setArray(a)
	}
	
	func add(to array: inout StringsArray) {
		if  let name = recordName, !array.contains(name), !isBookmark {
			array.append(name)
		}
	}

	func remove(from array: inout StringsArray) {
		if  let name = recordName {
			while let index = array.firstIndex(of: name) {
				array.remove(at: index)
			}
		}
	}

	// MARK: - children
	// MARK: -

	override func hasMissingProgeny() -> Bool {
		var total = 0

		traverseAllProgeny { iChild in
			total += 1
		}

		return total < progenyCount
	}

	var isFirstSibling: Bool {
		if  let parent     = parentZone {
			let siblings   = parent.children
			if  siblings.count > 0 {
				let first  = siblings[0]
				let isHere = parent.widget?.isHere ?? false

				return first == self && (isHere || parent.isFirstSibling)
			}
		}

		return false
	}

	var isLastSibling: Bool {
		if  let parent   = parentZone {
			let siblings = parent.children
			let pIsHere  = parent.widget?.isHere ?? false
			if  pIsHere || parent.isLastSibling {
				return (siblings.count < 2) || (self == siblings[siblings.count - 1])
			}
		}

		return false
	}

	// adopt recursively

	func assureRoot() {
		if  root == nil {
			var foundRoot = self

			while let p = foundRoot.parentZone {
				foundRoot = p
			}

			if  foundRoot != self {
				root = foundRoot
			}
		}
	}

	override func adopt(recursively: Bool = false) {
		if  !needsDestroy {
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

	func addChildAndRespectOrder(_ child: Zone?) {
		addChildNoDuplicate(child)
		respectOrder()
	}

	func addChildAndReorder(_ iChild: Zone?, at iIndex: Int? = nil, _ afterAdd: ZoneClosure? = nil) {
		if  isBookmark {
			bookmarkTarget?.addChildAndReorder(iChild, at: iIndex, afterAdd)
		} else if let child = iChild,
			addChildNoDuplicate(child, at: iIndex, afterAdd) != nil {
			children.updateOrder() // also marks children need save
		}
	}

	func indexInRelation(_ relation: ZRelation) -> Int {
		if  relation == .upon {
			return validIndex(from: gListsGrowDown ? nil : 0)
		} else {
			return siblingIndex! + relation.rawValue
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

	@discardableResult func addChildNoDuplicate(_ iChild: Zone? = nil, at iIndex: Int? = nil, updateCoreData: Bool = true, _ onCompletion: ZoneClosure? = nil) -> Int? {
		if  let        child = iChild {
			let      toIndex = validIndex(from: iIndex)
			child.parentZone = self

			func finish() -> Int {
				updateMaxLevel()
				onCompletion?(child)

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

	@discardableResult func addChild(_ iChild: Zone? = nil, at iIndex: Int? = nil, updateCoreData: Bool = true, _ onCompletion: ZoneClosure? = nil) -> Int? {
		if  var        child = iChild {
			let      toIndex = validIndex(from: iIndex)

			// prevent cross-db family relation

			if  databaseID  != child.databaseID {
				let        c = child
				child        = child.deepCopy(dbID: databaseID)

				c.deleteSelf(onCompletion: nil)
			}

			child.root       = root
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
			onCompletion?(child)

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
		if  let newName  = widget?.textWidget?.extractTitleOrSelectedText() {

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
						addIdea(at: gListsGrowDown ? nil : 0, with: newName) { [self] iChild in
							gDeferringRedraw = false

							if  let child = iChild {
								expand()
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
				moveZone(to: gTrash)

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
		if !show && isGrabbed && (count == 0 || !isExpanded) {

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
			let grabs = gSelecting.currentMapGrabs
			let apply = { [self] in
				var grabHere = false
				traverseAllProgeny { iChild in
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
					children.insert(child, at: to)
				} else {
					children.append(child)
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

			if  isExpanded {
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

	// MARK: - dots
	// MARK: -

	func ungrabProgeny() {
		for     grabbed in gSelecting.currentMapGrabs {
			if  grabbed != self && grabbed.spawnedBy(self) {
				grabbed.ungrab()
			}
		}
	}

	func dragDotClicked(_ flags: ZEventFlags) {
		let COMMAND = flags.isCommand
		let   SHIFT = flags.isShift

		if  COMMAND {
			grab()            // narrow selection to just this one zone

			if  self != gHere {
				gFocusing.focusOnGrab(.eSelected) {
					gRelayoutMaps()
				}
			}
		} else if SHIFT {
			addToGrabs()
		} else {
			grab()
		}

		gRelayoutMaps(for: self)
	}

	func revealDotClicked(_ flags: ZEventFlags, isCircularMode: Bool = false) {
		ungrabProgeny()

		let COMMAND = flags.isCommand
		let  OPTION = flags.isOption

		if  isCircularMode {
			toggleShowing()
			
			if  isShowing {
				parentZone?.expand()
			}
			
			gRelayoutMaps()
		} else if isBookmark || (isTraveller && (COMMAND || count == 0)) {
			invokeTravel(COMMAND) { reveal in      // note, email, bookmark, hyperlink
				gRelayoutMaps()
			}
		} else if count > 0, !OPTION {
			let show = !isExpanded

			if  isInSmallMap {
				updateVisibilityInSmallMap(show)
				gRelayoutMaps()
			} else {
				let goal = (COMMAND && show) ? Int.max : nil
				generationalUpdate(show: show, to: goal) {
					gRelayoutMaps(for: self)
				}
			}
		}
	}
	
	func dotClicked(_ flags: ZEventFlags, isReveal: Bool, isCircularMode: Bool = false) {
		if  isReveal {
			revealDotClicked(flags, isCircularMode: isCircularMode)
		} else {
			dragDotClicked  (flags)
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

	func plainDotParameters(_ isFilled: Bool, _ isReveal: Bool, _ isDragDrop: Bool = false) -> ZDotParameters {
		let            d = gDragging.dragLine?.parentWidget?.widgetZone
		var            p = ZDotParameters()
		let            t = bookmarkTarget
		let            k = traitKeys
		let            g = groupOwner
		p.color          = dotColor
		p.isGrouped      = g != nil
		p.showList       = isExpanded
		p.hasTarget      = isBookmark
		p.typeOfTrait    = k.first ?? kEmpty
		p.showAccess     = hasAccessDecoration
		p.hasTargetNote  = t?.hasNote ?? false
		p.isGroupOwner   = g == self || g == t
		p.showSideDot    = isCurrentSmallMapBookmark
		p.isDragged      = gDragging.draggedZones.contains(self) && gDragging.dragLine != nil
		p.verticleOffset = offsetFromMiddle / (Double(gHorizontalGap) - 27.0) * 4.0
		p.childCount     = (gCountsMode == .progeny) ? progenyCount : indirectCount
		p.accessType     = (directAccess == .eProgenyWritable) ? .sideDot : .vertical
		p.isReveal       = isReveal
		p.isDrop         = isDragDrop && d != nil && d == self
		p.filled         = isFilled
		p.fill           = isFilled ? dotColor.lighter(by: 2.5) : gBackgroundColor

		return p
	}

	func dropDotParameters() -> ZDotParameters {
		var      p = plainDotParameters(true, true)
		p.fill     = gActiveColor
		p.isReveal = true

		return p
	}

	// MARK: - lines and titles
	// MARK: -

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
			widget?.textWidget?.updateGUI()
			editAndSelect(range: r)

			return true
		}

		return false
	}

	func convertToFromLine() -> Bool {
		if  let childName = widget?.textWidget?.extractTitleOrSelectedText(requiresAllOrTitleSelected: true) {
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
		if  let childName = widget?.textWidget?.extractedTitle {
			zoneName  = childName
			colorized = false
		}
	}

	// MARK: - progeny counts
	// MARK: -

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

	// MARK: - receive from cloud
	// MARK: -

	// add to map

	func addToParent(_ onCompletion: ZoneMaybeClosure? = nil) {
		FOREGROUND { [self] in
			colorMaybe        = nil               // recompute color
			let parent        = resolveParent
			let done: Closure = { [self] in
				parent?.respectOrder()          // assume newly fetched zone knows its order

				columnarReport("   ->", unwrappedName)
				onCompletion?(parent)
			}

			if  let p = parent,
				!p.children.contains(self) {
				p.addChildNoDuplicate(self)
			}

			done()
		}
	}

	// MARK: - contextual menu
	// MARK: -

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
				case "i":      children.sortByCount()
				case "m":      children.sortByLength()
				case "e":      editTraitForType(.tEmail)
				case "w":      editTraitForType(.tHyperlink)
				case "b":      addBookmark()
				case "d":      duplicate()
				case "n":      showNote()
				case "r":      reverseChildren()
				case "s":      gFiles.export(self, toFileAs: .eSeriously)
				case "o":      importFromFile(.eSeriously)    { gRelayoutMaps(for: self) }
				case "t":      swapWithParent                 { gRelayoutMaps(for: self) }
				case "/":      gFocusing.grabAndFocusOn(self) { gRelayoutMaps() }
				case "\u{08}", kDelete: deleteSelf            { gRelayoutMaps() }
				case kSpace:   addIdea()
				default:       break
			}
		}
	}

	// MARK: - initialization
	// MARK: -

	func childWithName(_ name: String) -> Zone {
		for child in children {
			if  child.zoneName == name {
				return child
			}
		}

		let zone = Zone.uniqueZoneNamed(name, recordName: nil, databaseID: databaseID)

		addChildAndReorder(zone)

		return zone
	}

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

	static func uniqueZoneNamed(_ named: String?, recordName: String? = nil, databaseID: ZDatabaseID) -> Zone {
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

	func updateRecordName(for type: ZStorageType) {
		if  let    name = type.rootName,
			recordName != name {

			for child in children {
				child.parentZone = self // because record name is different, children must be pointed through a ck reference to new record created above
			}
		}
	}

	override func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID) throws {
		if  let name = dict[.name] as? String,
			responds(to: #selector(setter: zoneName)) {
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

		if  (includeInvisibles || isExpanded),
			let childrenDict = try (children as ZRecordsArray).createStorageArray(from: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
			dict [.children] = childrenDict as NSObject?
		}

		if  let   traitsDict = try traitsArray.createStorageArray(from: iDatabaseID, includeRecordName: includeRecordName, includeInvisibles: includeInvisibles, includeAncestors: includeAncestors) {
			dict   [.traits] = traitsDict as NSObject?
		}

		return dict
	}

}
