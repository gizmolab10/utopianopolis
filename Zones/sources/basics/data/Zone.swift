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

@objc (Zone)
class Zone : ZRecord, ZIdentifiable, ZToolable {

	@NSManaged var                                zoneOrder :           NSNumber?
	@NSManaged var                                zoneCount :           NSNumber?
	@NSManaged var                               zoneAccess :           NSNumber?
	@NSManaged var                              zoneProgeny :           NSNumber?
	@NSManaged var                                parentRID :             String?
	@NSManaged var                                 zoneName :             String?
	@NSManaged var                                 zoneLink :             String?
	@NSManaged var                                zoneColor :             String?
	@NSManaged var                               parentLink :             String?
	@NSManaged var                               zoneAuthor :             String?
	@NSManaged var                           zoneAttributes :             String?
	var                                      hyperLinkMaybe :             String?
	var                                          emailMaybe :             String?
	var                                          assetMaybe :            CKAsset?
	var                                          colorMaybe :             ZColor?
	var                                           noteMaybe :              ZNote?
	var                                      crossLinkMaybe :            ZRecord?
	var                                     parentZoneMaybe :               Zone?
	var                                                root :               Zone? { return mapType.root ?? gRemoteStorage.zRecords(for: maybeDatabaseID)?.rootZone }
	var                                          groupOwner :               Zone? { if let (_, r) = groupOwner([]) { return r } else { return nil } }
	var                                         destroyZone :               Zone? { return zRecords?.destroyZone }
	var                                           trashZone :               Zone? { return zRecords?.trashZone }
	var                                             getRoot :               Zone  { return isARoot ? self : parentZone?.getRoot ?? self }
	var                                            siblings :          ZoneArray? { return parentZone?.children }
	var                                            manifest :          ZManifest? { return zRecords?.manifest }
	var                                              widget :         ZoneWidget? { return gWidgets.widgetForZone(self) }
	var                                          textWidget :     ZoneTextWidget? { return widget?.textWidget }
	var                                      linkDatabaseID :        ZDatabaseID? { return zoneLink?.maybeDatabaseID }
	var                               maybeNoteOrEssayTrait :             ZTrait? { return maybeTraitFor(.tNote) ?? maybeTraitFor(.tEssay) }
	var                                         widgetColor :             ZColor? { return (gColorfulMode && colorized) ? color : kBlackColor }
	var                                           textColor :             ZColor? { return isDragged ? gActiveColor : widgetColor }
	var                                        lighterColor :             ZColor? { return gIsDark ? color : color?.withAlphaComponent(0.3) }
	var                                      highlightColor :             ZColor? { return isDragged ? gActiveColor : (widget?.isCircularMode ?? true) ? color : lighterColor }
	var                                            dotColor :             ZColor  { return mapType.isExemplar ? gHelpHyperlinkColor : gColorfulMode ? (color ?? kDefaultIdeaColor) : kDefaultIdeaColor }
	var                                       lowestExposed :                Int? { return exposed(upTo: highestExposed) }
	var                                           halfCount :                Int  { return Int((Double(count) + 0.5) / 2.0) }
	var                                               count :                Int  { return children.count }
	var                                           emailLink :             String? { return email == nil ? nil : kMailTo + email! }
	var                                      linkRecordName :             String? { return zoneLink?.maybeRecordName }
	var                                         clippedName :             String  { return !gShowToolTips ? kEmpty : unwrappedName }
	override var                                  emptyName :             String  { return kEmptyIdea }
	override var                                  debugName :             String  { return zoneName ?? kUnknown }
	override var                                description :             String  { return decoratedName }
	override var                              unwrappedName :             String  { return zoneName ?? (isFavoritesRoot ? kFavoritesRootName : emptyName) }
	override var                              decoratedName :             String  { return decoration + unwrappedName }
	override var                            cloudProperties :       StringsArray  { return Zone.cloudProperties }
	override var                    optionalCloudProperties :       StringsArray  { return Zone.optionalCloudProperties }
	override var                              isActualChild :               Bool  { return siblingIndex != nil }
	override var                                 isBrandNew :               Bool  { return zoneName == nil || zoneName == kEmpty }
	override var                                isAdoptable :               Bool  { return parentRID != nil || parentLink != nil }
	override var                                    isAZone :               Bool  { return true }
	override var                               passesFilter :               Bool  { return isBookmark && gSearchFilter.contains(.fBookmarks) || !isBookmark && gSearchFilter.contains(.fIdeas) }
	var                                           isDragged :               Bool  { return gDragging.isDragged(self) }
	var                                          isAnOrphan :               Bool  { return parentRID == nil && parentLink == nil }
	var                                          isBookmark :               Bool  { return zoneLink != nil }
	var                                  hasVisibleChildren :               Bool  { return isExpanded && count > 0 }
	var                                     dragDotIsHidden :               Bool  { return (isFavoritesHere && !(widget?.mapType.isMainMap ?? false)) || (kIsPhone && self == gHereMaybe && isExpanded) } // hide favorites root drag dot
	var                                  canRelocateInOrOut :               Bool  { return parentZoneMaybe?.widget != nil }
	var                                  hasNarrowRevealDot :               Bool  { return isExpanded || [0, 1, 3].contains(count) || (gCountsMode != .dots) }
	var                                    hasBadRecordName :               Bool  { return recordName == nil }
	var                                       showRevealDot :               Bool  { return count > 0 || isTraveller }
	var                                       hasZonesBelow :               Bool  { return hasAnyZonesAbove(false) }
	var                                       hasZonesAbove :               Bool  { return hasAnyZonesAbove(true) }
	var                                       hasChildNotes :               Bool  { return zonesWithNotes.count > 1 }
	var                                        hasHyperlink :               Bool  { return hasTrait(for: .tHyperlink) && hyperLink != kNullLink && !(hyperLink?.isEmpty ?? true) }
	var                                         hasSiblings :               Bool  { return parentZoneMaybe?.count ?? 0 > 1 }
	var                                         isTraveller :               Bool  { return isBookmark || hasHyperlink || hasEmail || hasNote }
	var                                          linkIsRoot :               Bool  { return linkRecordName == kRootName }
	var                                          isSelected :               Bool  { return gSelecting.isSelected(self) }
	var                                           isGrabbed :               Bool  { return gSelecting .isGrabbed(self) }
	var                                            hasColor :               Bool  { return isBookmark ? (bookmarkTarget?.hasColor ?? false) : (zoneColor != nil && !zoneColor!.isEmpty) }
	var                                            hasEmail :               Bool  { return hasTrait(for: .tEmail) && !(email?.isEmpty ?? true) }
	var                                            hasAsset :               Bool  { return hasTrait(for: .tAssets) }
	var                                             hasNote :               Bool  { return hasTrait(for: .tNote) }
	var                                      hasNoteOrEssay :               Bool  { return hasTrait(matchingAny: [.tNote, .tEssay]) }
	var                                           isInTrash :               Bool  { return root?.isTrashRoot        ?? false }
	var                                          isInAnyMap :               Bool  { return root?.isAnyMapRoot       ?? false }
	var                                         isInMainMap :               Bool  { return root?.isMainMapRoot      ?? false }
	var                                         isInDestroy :               Bool  { return root?.isDestroyRoot      ?? false }
	var                                       isInFavorites :               Bool  { return root?.isFavoritesRoot    ?? false }
	var                                    isInLostAndFound :               Bool  { return root?.isLostAndFoundRoot ?? false }
	var                                   isInFavoritesHere :               Bool  { return isProgenyOfOrEqualTo(gFavorites.currentHere) }
	var                                    isInRecentsGroup :               Bool  { return isProgenyOfOrEqualTo(gFavorites.getRecentsGroup()) }
	var                                      isReadOnlyRoot :               Bool  { return isLostAndFoundRoot || isFavoritesRoot || isTrashRoot || mapType.isExemplar }
	var                                    isProgenyOfAGrab :               Bool  { return isProgenyOfAny(of: gSelecting.currentMapGrabs) }
	var                                          spawnCycle :               Bool  { return isProgenyOfAGrab || dropCycle }
	var                                           dropCycle :               Bool  { return gDragging.draggedZones.contains(self) || isProgenyOfAny(of: gDragging.draggedZones) || (bookmarkTarget?.dropCycle ?? false) }
	var                                          isInAGroup :               Bool  { return groupOwner?.bookmarkTargets.contains(self) ?? false }
	var                                       isAGroupOwner :               Bool  { return zoneAttributes?.contains(ZoneAttributeType.groupOwner.rawValue) ?? false }
	var                                         userCanMove :               Bool  { return userCanMutateProgeny   || isBookmark } // all bookmarks are movable because they are created by user and live in my databasse
	var                                        userCanWrite :               Bool  { return userHasDirectOwnership || isIdeaEditable }
	var                                userCanMutateProgeny :               Bool  { return userHasDirectOwnership || inheritedAccess != .eReadOnly }
	var                                         hideDragDot :               Bool  { return isExpanded && (isFavoritesHere || (kIsPhone && (self == gHereMaybe))) }
	var                                             mapType :           ZMapType  = .tMainMap
	var                                     inheritedAccess :         ZoneAccess  { return zoneWithInheritedAccess.directAccess }
	var                                              traits =   ZTraitDictionary  ()
	var                                      duplicateZones =          ZoneArray  ()
	var                                            children =          ZoneArray  ()
	var                                     bookmarkTargets :          ZoneArray  { return bookmarks.filter { $0.bookmarkTarget != nil }.map { $0.bookmarkTarget! } }
	var                                           notemarks :          ZoneArray  { return zonesMatching(.wNotemarks) }
	var                                           bookmarks :          ZoneArray  { return zonesMatching(.wBookmarks) }
	var                                          allProgeny :          ZoneArray  { return zonesMatching(.wProgeny  ) }
	var                                           allGroups :          ZoneArray  { return zonesMatching(.wGroups   ) }
	var                                                 all :          ZoneArray  { return zonesMatching(.wAll      ) }
	var                                     visibleChildren :          ZoneArray  { return hasVisibleChildren ? children : [] }
	func          identifier()                             ->             String? { return isARoot ? databaseID.rawValue : recordName }
	func          toolName()                               ->             String? { return clippedName }
	func          toolColor()                              ->             ZColor? { return color?.lighter(by: 3.0) }
	func          maybeTraitFor(_ iType: ZTraitType)       ->             ZTrait? { return traits[iType] }
	static   func object(for id: String, isExpanded: Bool) ->           NSObject? { return gMaybeZoneForRecordName(id) }
	static   func randomZone(in dbID: ZDatabaseID)         ->               Zone  { return Zone.uniqueZoneNamed(String(arc4random()), databaseID: dbID) }
	override func hasMissingChildren()                     ->               Bool  { return count < fetchableCount }
	override func orphan()                                                        { parentZone?.removeChild(self) }
	func          toggleShowing()                                                 { isShowing ? hide() : show() }
	func          recount()                                                       { updateAllProgenyCounts() }

	var parentZone : Zone? {
		get { return getParentZone() }
		set { setParentZone(newValue) }
	}

	override var isInScope: Bool {
		if  parentZone        == nil {
			return gSearchScope.contains(.sOrphan)
		} else if let rootName = root?.recordName {
			if  rootName      == kRootName {
				switch databaseID {
					case .everyoneID: if gSearchScope.contains(.sPublic) { return true }
					case .mineID:     if gSearchScope.contains(.sMine)   { return true }
					default: break
				}
			}

			if  gSearchScope.contains(.sFavorites),
				isInFavorites {
				return true
			}

			if  gSearchScope.contains(.sTrash),
				[kTrashName, kDestroyName].contains(rootName) {
				return true
			}
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

	var level: Int {
		var value  = 0

		parentZone?.traverseAllAncestors { ancestor in
			value += 1
		}

		return value
	}

	func unwrappedNameWithEllipses(_ forceTruncation: Bool = true, noLongerThan threshold: Int = 25) -> String {
		var      name = unwrappedName
		let    length = name.length
		let   breakAt = threshold / 2

		if  threshold < length, forceTruncation {
			let first = name.substring(toExclusive: breakAt)
			let  last = name.substring(fromInclusive: length - breakAt)
			name      = first + kEllipsis + last
		}

		return name
	}

	struct ZoneType: OptionSet {
		let rawValue : Int

		init(rawValue: Int) { self.rawValue = rawValue }

		static let zChildless = ZoneType(rawValue: 1 << 0)
		static let zTrait     = ZoneType(rawValue: 1 << 1)
		static let zNote      = ZoneType(rawValue: 1 << 2)
		static let zDuplicate = ZoneType(rawValue: 1 << 3)
		static let zBookmark  = ZoneType(rawValue: 1 << 4)
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

	// MARK: - bookmarks
	// MARK: -

	var bookmarksTargetingSelf: ZoneArray {
		if  gCDUseRelationships {
			return gRelationships.relationshipsFor(self)?.bookmarks ?? []
		} else if  let  name = recordName,
				   let  dict = gBookmarks.reverseLookup[databaseID],
				   let array = dict[name] {

			return array
		}

		return []
	}

	func applyToAllBookmarksTargetingSelf(_ closure: ZoneClosure) {
		for bookmark in bookmarksTargetingSelf {
			closure(bookmark)
		}
	}

	func setNameForSelfAndBookmarks(to name: String) {
		zoneName = name

		applyToAllBookmarksTargetingSelf { b in
			b.zoneName = name
		}
	}

	var firstBookmarkTargetingSelf: Zone? {
		let    bookmarks = bookmarksTargetingSelf

		return bookmarks.count == 0 ? nil : bookmarks[0]
	}

	var bookmarkTarget : Zone? {
		if  !gCDUseRelationships {
			return crossLink?.maybeZone
		}

		if  let relationships = gRelationships.relationshipsFor(self),
			let       targets = relationships.targets {
			for target in targets {
				if  self != target {
					return  target
				}
			}
		}

		return nil
	}

	var asZoneLink: String? {
		guard let name = recordName else { return nil }

		return databaseID.rawValue + kDoubleColonSeparator + name
	}

	func updateCrossLinkMaybe(force: Bool = false) {
		if (force || (crossLinkMaybe == nil) || (crossLinkMaybe!.recordName == nil)),
		    var l                = zoneLink {
			if  l.contains(kOptional) {    // repair consequences of an old, but now fixed, bookmark bug
				l                = l.replacingOccurrences(of: kOptional + kDoubleQuote, with: kEmpty).replacingOccurrences(of: kDoubleQuote + ")", with: kEmpty)
				zoneLink         = l
			}

			crossLinkMaybe       = l.maybeZone
		}
	}

	var crossLink: ZRecord? {
		get {
			if  gIsReadyToShowUI {       // zrecords registry not ready until ui can be shown
				updateCrossLinkMaybe()
			}

			return crossLinkMaybe
		}

		set {
			crossLinkMaybe = nil   // force update (get)
			zoneLink       = newValue?.asString
		}
	}

	func addBookmark() {
		if  gHere == self {
			gHere  = parentZone ?? gHere

			revealParentAndSiblings()
		}

		ZBookmarks.newOrExistingBookmark(targeting: self, addTo: parentZone).grab()
		gRelayoutMaps()
	}

	// MARK: - setup
	// MARK: -

	func updateInstanceProperties() {
		if  gIsUsingCD {
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

	func deepCopy(into dbID: ZDatabaseID?) -> Zone {
		let      id = dbID ?? databaseID
		let theCopy = Zone.uniqueZoneNamed("noname", databaseID: id)

		copyInto(theCopy)
		if  gBookmarks.addToReverseLookup(theCopy) {  // only works for bookmarks
			gRelationships.addBookmarkRelationship(theCopy, target: self, in: id)
		}

		theCopy.parentZone = nil

		let zones = gListsGrowDown ? children : children.reversed()

		for child in zones {
			theCopy.addChildNoDuplicate(child.deepCopy(into: id))
		}

		for trait in traits.values {
			let  traitCopy = trait.deepCopy(into: id)
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

	var ancestralStrings: StringsArray {
		return ancestralPath.map { $0.unwrappedName.capitalized }            // convert ancestors into capitalized strings
	}

	var ancestralString: String {
		return ancestralStrings.joined(separator: kColonSeparator)
	}

	var favoritesTitle: String {
		var names = ancestralStrings

		if  names.count > 1 {
			names.removeFirst(1)
		}

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

		if  isBookmark {
			d.append("B")

			if  bookmarkTarget?.hasNote ?? false {
				d.append("N")
			}
		}

		if  hasNote {
			d.append("N")
		}

		if  (isBookmark ? bookmarkTarget?.count ?? 0 : count) != 0 {
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
			var computed        = kDefaultIdeaColor

			if  zoneName == "features", !isBookmark {
				noop()
			}

			if  gColorfulMode {
				if  let       t = bookmarkTarget {
					return t.color
				} else if let m = colorMaybe ?? zoneColor?.color {
					computed    = m
				} else if let c = parentZone?.color {
					return c
				}
			}

			if  gIsDark {
				computed        = computed.invertedColor
			}

			return computed
		}

		set {
			if  let           b = bookmarkTarget {
				b.color         = newValue
			} else {
				var computed    = newValue

				if  gIsDark {
					computed    = computed?.invertedColor
				}

				if  colorMaybe != computed {
					colorMaybe  = computed
					zoneColor   = computed?.string ?? kEmpty
				}
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
					if  iChild.color != originalColor {
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
					zoneOrder = NSNumber(value: Double.zero)
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

	var nextSiblingIndex : Int? {
		if  let    index = siblingIndex {
			return index + (gListsGrowDown ? 1 : 0)
		}

		return nil
	}

	var siblingIndex: Int? {
		if  let siblingZones = siblings {
			if  let    index = siblingZones.firstIndex(of: self) {
				return index
			} else {
				for (index, sibling) in siblingZones.enumerated() {
					if  sibling.recordName == recordName {
						return index
					}
				}
			}
		}

		return nil
	}

	var canEditNow: Bool {   // workaround recently introduced change in become first responder invocation logic [aka: fucked it up]
		return !gRefusesFirstResponder
			&&  userWantsToEdit
			&&  userCanWrite
	}

	var userWantsToEdit: Bool {
		let key = gCurrentKeyPressed ?? kEmpty
		return "-deh, \t\r".contains(key)
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
			var childArray = ZoneArray(set: set)
			let     needed = fetchableCount - childArray.count

			// workaround a new  (@#$$!@@)  apple bug with core data relationships
			//
			// the childArray is sometimes incomplete
			// never seen this before
			// nothing useful turned up in net grovelling
			// hence this
			//
			// which kinda works, but has a problem
			// fetches extra ideas, deleted long ago or something ???

			if  needed > 0, maybeDatabaseID == .mineID,
				let       name = recordName,
			    let      zones = gCoreDataStack.fetchChildrenOf(name, in: .mineID) {
				fetchableCount = zones.count
				childArray     = zones
			}

			for child in childArray {
				let strings = child.convertFromCoreData(visited: v)

				if  let name = child.recordName,
					(visited == nil || !visited!.contains(name)) {
					converted.append(contentsOf: strings)
					let cid = child.objectID
					FOREGROUND { [self] in
						if  let zone = gCDCurrentBackgroundContext?.object(with: cid) as? Zone {
							addChildNoDuplicate(zone, updateCoreData: false) // not update core data, it already exists
							zone.register() // need to wait until after child has a parent so bookmarks will be registered properly
						}
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

				if  let type = trait.traitType,
					!hasTrait(for: type) {
					addTrait(trait, updateCoreData: false) // we got here because this is not a first-time launch and thus core data already exists
				}

				trait.register()
			}
		}
	}

	func updateCoreDataRelationships() {
		if  gIsUsingCD,
			let      zID = dbid {
			var childSet = Set<Zone>()
			var traitSet = Set<ZTrait>()

			for child in children {
				if  let cID = child.dbid,
					zID    == cID,
					let   c = child.selfInContext?.maybeZone {                  // avoid cross-store relationships
					childSet.insert(c)
				}
			}

			for trait in traits.values {
				if  let tID = trait.dbid,
					zID    == tID,
					let   t = trait.selfInContext?.maybeTrait {                 // avoid cross-store relationships
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
		if  let    t = bookmarkTarget, t != self {
			return t.userHasDirectOwnership
		}

		return !isTrashRoot && !isFavoritesRoot && !isLostAndFoundRoot && (maybeDatabaseID == .mineID || zoneAuthor == gAuthorID || gHasFullAccess)
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
		var     access  = nextAccess(after: directAccess) ?? nextAccess(after: inherited)

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

	func nextAccess(after: ZoneAccess?) -> ZoneAccess? {
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
				  maybeDatabaseID == .everyoneID {
			let             direct = directAccess
			if  let           next = nextAccess,
				direct            != next {
				directAccess       = next

				if  let identity   = gAuthorID,
					next          != .eInherit,
					zoneAuthor    != nil {
					zoneAuthor     = identity
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
				gControllers.signalFor(multiple: [.spRelayout]) {
					gTemporarilySetMouseZone(iChild)
					iChild?.edit()
				}
			}
		}
	}

	func addNextAndRelayout(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
		if  let parent  = parentZone, parent.userCanMutateProgeny {
			var zones   = gSelecting.currentMapGrabs
			var index   = siblingIndex
			if  index  != nil && gListsGrowDown {
				index! += 1
			}

			if  self   == gHere {
				gHere   = parent

				parent.expand()
			}

			if  containing {
				zones.reorderAccordingToValue()
			}

			parent.addIdea(at: index, with: name) { iChild in
				if  let child = iChild {
					if  containing {
						child.acquireZones(zones)
					}

					if  let closure = onCompletion {
						closure(child)
					} else {
						gRelayoutMaps() {
							child.edit()
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

		for     zone in zones.reversed() {
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
				newIdea.deleteSelf { flag in
					onCompletion?(nil)
				}
			}

			ungrab()
			addChildAndUpdateOrder(newIdea, at: iIndex, { addedChild in onCompletion?(newIdea) } )
		}
	}

	func deleteSelf(permanently: Bool = false, force: Bool = false, onCompletion: BooleanClosure?) {
		if  isARoot, !force {
			onCompletion?(false) // deleting root would be a disaster
		} else {
			maybeRestoreParent()

			let parent = parentZone
			if  self  == gHere {                         // this can only happen ONCE during recursion (multiple places, below)
				let recurse: Closure = { [self] in

					// /////// //
					// RECURSE //
					// /////// //

					deleteSelf(permanently: permanently, force: force, onCompletion: onCompletion)
				}

				if  let p = parent, p != self {
					gHere = p

					revealParentAndSiblings()
					recurse()
				} else {

					// ///////////////////////////////////////////////////////////////////////////////////////// //
					// SPECIAL CASE: delete here but here has no parent ... so, go somewhere useful and familiar //
					// ///////////////////////////////////////////////////////////////////////////////////////// //

					gFavorites.refocus { [self] in               // travel through current favorite, then ...
						if  gHere != self {
							recurse()
						} else {
							bookmarksTargetingSelf.deleteZones(permanently: permanently) {
								onCompletion?(true)
							}
						}
					}
				}
			} else {
				let finishDeletion: BooleanClosure = { [self] flag in
					if  let            p = parent, p != self {
						p.fetchableCount = p.count       // delete alters the count

						if  p.count == 0, p.isInFavorites,
							let g = p.parentZone {
							gFavorites.hereZoneMaybe = g

							g.expand()
							p.grab()
						}
					}

					// /////// //
					// RECURSE //
					// /////// //

					bookmarksTargetingSelf.deleteZones(permanently: permanently) {
						onCompletion?(flag)
					}
				}

				addToPaste()
				concealAllProgeny()            // shrink gExpandedZones list

				if !permanently, !isInDestroy, !isInTrash {
					moveZone(to: trashZone) {
						finishDeletion(true)
					}
				} else {
					traverseAllProgeny { iZone in
						if !iZone.isInTrash {
							iZone.needDestroy()    // gets written in file
							iZone.unregister()
							iZone.orphan()
							gManifest?.smartAppend(iZone)
							gFavorites.pop(iZone)  // avoid getting stuck on a zombie
							iZone.deleteSelf()
						}
					}

					finishDeletion(false)
				}
			}
		}
	}

	func addNextAndRedraw(containing: Bool = false, onCompletion: ZoneClosure? = nil) {
		gDeferRedraw {
			addNextAndRelayout(containing: containing) { iChild in
				gDeferringRedraw = false

				gRelayoutMaps() {
					onCompletion?(iChild)
					iChild.edit()
				}
			}
		}
	}

	func tearApartCombine(_ flags: ZEventFlags) {
		if  flags.exactlyAll {
			createChildWithTitleOrSelectedText()
		} else {
			createIdeaFromSelectedText()
		}
	}

	func createChildWithTitleOrSelectedText() {
		if  let     index = siblingIndex,
			let    parent = parentZone,
			let childName = textWidget?.extractTitleOrSelectedText() {

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

		into.addChildAndUpdateOrder(self, at: iIndex) { addedChild in

			if !addedChild.isInTrash { // so grab won't disappear
				addedChild.grab()
			}

			onCompletion?()
		}
	}

	func restoreParentFrom(_ root: Zone?) {
		root?.traverseAllProgeny { iCandidate in
			if  iCandidate.children.contains(self) {
				self.parentZone = iCandidate
			}
		}
	}

	func maybeRestoreParent() {
		let clouds: [ZRecords?] = [gFavorites, zRecords]

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
		} else if let bookmark = there.bookmarkTarget {

			// //////////////////////////// //
			// MOVE ZONE THROUGH A BOOKMARK //
			// //////////////////////////// //

			var     movedZone = self
			let    targetDBID = bookmark.databaseID
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

				movedZone = movedZone.deepCopy(into: targetDBID)

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
		} else if isInMainMap {
			addAGrab(extreme: extreme, onCompletion: onCompletion)
		} else if let next = gListsGrowDown ? children.last : children.first {
			next.grab()
			gFavorites.setHere(to: self)
			gFavorites.updateFavoritesAndRedraw {
				gSignal([.spCrumbs, .spDataDetails, .spFavoritesMap, .sDetails])
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
				if !isInFavorites {
					p.expand()
				} else if let g = p.parentZone { // narrow: hide children and set here zone to parent
					g.concealAllProgeny()
					gFavorites.setHere(to: g)
					// FUBAR: parent sometimes disappears!!!!!!!!!
				} else if p.isARoot {
					onCompletion?(true)
					return // do nothing if p is root of either favorites map
				}

				p.grab()
				gSignal([.spCrumbs, .spDataDetails, .spFavoritesMap, .sDetails])
			}
		} else if let bookmark = firstBookmarkTargetingSelf {		 // self is an orphan
			gHere              = bookmark			                 // change focus to bookmark of self
		}

		onCompletion?(true)
	}

	// MARK: - convenience
	// MARK: -

	func        addToPaste() { gSelecting   .pasteableZones[self] = (parentZone, siblingIndex) }
	func        addToGrabs() { gSelecting.addMultipleGrabs([self]) }
	func ungrabAssuringOne() { gSelecting.ungrabAssuringOne(self) }
	func            ungrab() { gSelecting           .ungrab(self) }

	func editTraitForType(_ type: ZTraitType) {
		switch type {
			case .tNote: showNote()
			default:     gTextEditor.edit(traitFor(type))
		}
	}

	@discardableResult func edit() -> ZTextEditor? {
		gTemporarilySetMouseZone(self) // so become first responder will work

		return gTextEditor.edit(self)
	}

	// ckrecords lookup:
	// initialized with one entry for each word in each zone's name
	// grows with each unique search

	func addToLocalSearchIndex() {
		if  let    name = zoneName,
			let records = zRecords {
			records.appendZRecords(containing: name) { iRecords -> ZRecordsArray in
				guard var r = iRecords else { return [] }

				r.appendUnique(item: self)

				return r
			}
		}
	}

	func resolveAsHere() {
		let here = bookmarkTarget ?? self
		gHere    = here

		here.grab()
		here.expand()
		gControllers.swapMapAndEssay(force: .wMapMode)
	}

	func grab(updateBrowsingLevel: Bool = true) {
		gTextEditor.stopCurrentEdit(andRedraw: false)
		printDebug(.dEdit, " GRAB    \(unwrappedName)")
		gSelecting.grab([self], updateBrowsingLevel: updateBrowsingLevel)
	}

	func asssureIsVisibleAndGrab(updateBrowsingLevel: Bool = true) {
		gShowFavoritesMapForIOS = kIsPhone && isInFavorites

		asssureIsVisible()
		grab(updateBrowsingLevel: updateBrowsingLevel)
	}

	override func setupLinks() {
		if  recordName != nil {

			let isBadLink: StringToBooleanClosure = { iString -> Bool in
				let badLinks = [kEmpty, kHyphen, "not"]

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
			colorized = !colorized // WTF?

			gTextEditor.updateText(inZone: self)
		}
	}

	func editAndSelect(range: NSRange? = nil) {
		edit()
		FOREGROUND { [self] in
			let newRange = range ?? NSRange(location: 0, length: zoneName?.length ?? 0)

			textWidget?.selectCharacter(in: newRange)
		}
	}

	func clearColor() {
		zoneColor  = kEmpty
		colorMaybe = nil
	}

	static func == ( left: Zone, right: Zone) -> Bool {
		let equal = (left === right)                        // avoid infinite recursion by using address-of-object equals operator

		if  !equal,
			let    lName  =  left.recordName,
			let    rName  = right.recordName {
			return lName == rName
		}

		return equal
	}

	subscript(i: Int) -> Zone? {
		if i < count && i >= 0 {
			return children[i]
		} else {
			return nil
		}
	}


	func applyMutator(_ type: ZMutateTextMenuType) {
		switch type {
			case .eCapitalize: zoneName = zoneName?.capitalized
			case .eLower:      zoneName = zoneName?.lowercased()
			case .eUpper:      zoneName = zoneName?.uppercased()
			case .eCancel:     break
		}
	}

	func reverseWordsInZoneName() -> Bool {
		if  let words = zoneName?.components(separatedBy: kSpace), words.count > 1 {
			zoneName = words.reversed().joined(separator: kSpace)

			return true
		}

		return false
	}

	func isInMap(of type: ZRelayoutMapType = .both) -> Bool {
		guard let isFavorites = root?.isInFavorites else { return false }
		switch type {
			case .favorites: return  isFavorites
			case      .main: return !isFavorites
			default:         return  true
		}
	}

	func hasSameZoneLink(as other: Zone) -> Bool {
		if  let     aLink  =       zoneLink,
			let     bLink  = other.zoneLink {
			return (aLink == bLink)
		}

		return false
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
			return maybeTraitFor(iType) != nil
		}
	}

	func getTraitText(for iType: ZTraitType) -> String? {
		return traits[iType]?.text
	}

	func setTraitText(_ iText: String?, for iType: ZTraitType?, addDefaultAttributes: Bool = false) {
		if  let       type = iType {
			if  let   text = iText {
				let  trait = traitFor(type)
				trait.text = text

				if  addDefaultAttributes { // for creating new child notes with non-default text
					let attributed = NSMutableAttributedString(string: text)

					attributed.addAttribute(.font, value: kDefaultEssayFont, range: NSRange(location: 0, length: text.length))

					trait.format   = attributed.attributesAsString
				}

				trait.updateSearchables()
			} else {
				traits[type]?.needDestroy()

				traits[type] = nil
			}

			updateCoreDataRelationships()  // need to record changes in core data traits array

			switch (type) {
				case .tEmail:     emailMaybe     = iText
				case .tHyperlink: hyperLinkMaybe = iText
				default:          break
			}
		}
	}

	var noteText : NSMutableAttributedString? { return maybeTraitFor(.tNote)?.noteText }

	var assets: CKAssetsArray? {
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
			gCDCurrentBackgroundContext?.delete(t)
		}
	}

	// MARK: - notes / essays
	// MARK: -

	var currentNote: ZNote? {
		if  isBookmark {
			return bookmarkTarget!.currentNote
		}

		let zones = zonesWithVisibleNotes

		if  zones.count > 0 {
			return ZNote(zones[0])
		}

		return nil
	}

	@discardableResult func createNoteMaybe() -> ZNote? {
		if (noteMaybe == nil || !hasNoteOrEssay), let emptyNote = createNote() {
			noteMaybe = emptyNote     // might be note from "child"
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
		let zones = zonesWithVisibleNotes
		let count = zones.count
		var  note : ZNote?

		if  count > 1, gCreateCombinedEssay, zones.contains(self) {
			note      = gCreateEssay(self)
			noteMaybe = note

			note?.updateChildren()
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

	func clearAllNoteMaybes() {       // discard current essay text and all child note's text
		for zone in zonesWithNotes {
			zone.noteMaybe = nil
		}
	}

	func deleteNote() {
		removeTrait(for: .tNote)
		gFavorites.pop(self)

		noteMaybe     = nil
		gNeedsRecount = true          // trigger recount on next timer fire
	}

	func deleteEssay() {
		if  let c = note?.children {
			for child in c {
				if  let z = child.zone, z != self {
					z.deleteEssay()   // recurse
				}
			}
		}

		deleteNote()
	}

	func editNote(flags: ZEventFlags?, useGrabbed: Bool = true) {
		if !gIsEssayMode {
			let               ALL  = flags?.exactlyAll     ?? false
			let            OPTION  = flags?.hasOption      ?? true
			let           SPECIAL  = flags?.exactlySpecial ?? false
			gCreateCombinedEssay   = !OPTION || SPECIAL                // default is multiple         (OPTION -> single)

			if  ALL {
				convertChildrenToNote()
			} else {
				if  gCurrentEssay == nil || OPTION || useGrabbed {     // restore prior or create new (OPTION -> create)
					gCurrentEssay  = note

					gFavorites.push(note?.zone)
				}

				if  SPECIAL {
					traverseAllProgeny { child in
						if  child != self, !child.isBookmark, !child.hasNoteOrEssay {
							child.setTraitText(kDefaultNoteText, for: .tNote)
						}
					}
				}
			}
		}

		gControllers.swapMapAndEssay(force: .wEssayMode) {
			gEssayView?.selectFirstNote()
		}
	}

	func showNote() {
		gCreateCombinedEssay = false
		gCurrentEssay        = note

		gControllers.swapMapAndEssay(force: .wEssayMode)
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

	var zonesWithVisibleNotes : ZoneArray {
		if  gHideNoteVisibility {
			return zonesWithNotes
		}

		var zones = [self]

		if  let essayTrait = maybeNoteOrEssayTrait {
			let showHidden = essayTrait.showsHidden

			for  child in children {
				if  let trait = child.maybeNoteOrEssayTrait, (trait.showsSelf || showHidden) {
					zones.append(child)

					if  trait.showsChildren {
						zones.append(contentsOf: child.zonesWithVisibleNotes)
					}
				}

			}
		}

		return zones
	}

	func convertChildrenToNote() {
		let empty = NSMutableAttributedString(string: kEmpty)
		let  text = noteText ?? empty
		let     n = createNote()

		traverseAllProgeny { child in
			if  child != self {
				let t = child.extractAsNoteText()

				if  text.string != kEmpty {
					text.append(kDoubleBlankLine)
				}

				text.append(t)
				child.deleteSelf { flag in }
			}
		}

		n?.saveAsNote(text, force: true)
	}

	func extractAsNoteText() -> NSAttributedString {
		let text  = NSMutableAttributedString(string: zoneName ?? kEmptyIdea, attributes: [.font : kDefaultEssayFont])
		if  let t = noteText {
			text.append(kDoubleBlankLine)
			text.append(t)
		}

		return text
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

	@discardableResult func cycleToNextInGroup(_ increasing: Bool) -> Bool {
		guard   let   rr = groupOwner else {
			if  self    != gHere {
				gHere.cycleToNextInGroup(increasing)
			}

			return true
		}

		if  let     r = rr.ownedGroup([]), r.count > 1,
			let index = indexIn(r),
			let  zone = r.next(increasing: increasing, from: index) {
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
			if  isInFavorites {
				let targetParent = bookmarkTarget?.parentZone

				targetParent?.expand()
				focusOnBookmarkTarget { (iObject: Any?, kind: ZSignalKindArray) in
					gFavorites.updateCurrentWithBookmarksTargetingHere()
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

	func expandAndGrab(focus: Bool = true) {
		if  focus {
			gHere = self
		}

		expand()
		grab()
	}

	func focusOnBookmarkTarget(atArrival: @escaping SignalClosure) {
		if  let              target = bookmarkTarget,
			let    targetRecordName = target.recordName {
			let          targetDBID = target.databaseID
			gShowFavoritesMapForIOS = targetDBID.isFavoritesDB
			var               there : Zone?

			let complete : SignalClosure = { [self] (iObject, kind) in
				gFavorites.setCurrentFavoriteBoomkarks(to: self)
				showTopLevelFunctions()
				atArrival(iObject, kind)
			}

			if      target.isProgenyOfOrEqualTo(gHereMaybe) {
				if !target.isGrabbed,
				    target.isVisible {
					target.grab()
				} else {
					gHere = target
				}

				complete(target, [.spRelayout, .spCrumbs])
			} else {
				if  gDatabaseID != targetDBID {
					gDatabaseID  = targetDBID

					// ///////////////////////// //
					// TRAVEL TO A DIFFERENT MAP //
					// ///////////////////////// //

					target.expandAndGrab()
					gFocusing.focusOnGrab(.eSelected) {
						complete(gHere, [.spRelayout])
					}
				} else {

					// /////////////// //
					// STAY WITHIN MAP //
					// /////////////// //

					there       = gRecords.maybeZoneForRecordName(targetRecordName)
					let grabbed = gSelecting.firstSortedGrab
					let    here = gHere

					UNDO(self) { iUndoSelf in
						iUndoSelf.UNDO(self) { iRedoSelf in
							iRedoSelf.focusOnBookmarkTarget(atArrival: complete)
						}

						gHere = here

						grabbed?.grab()
						complete(here, [.spRelayout])
					}

					if  there != nil {
						there?.expandAndGrab()
					} else if !gRecords.databaseID.isFavoritesDB, // favorites map has no lookup???
							  let here = gRecords.maybeZoneForRecordName(targetRecordName) {
						here.expandAndGrab()
					} // else ignore: favorites id with an unresolvable bookmark target

					complete(gHereMaybe, [.spRelayout])
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
			} else if target.isInFavorites {
				gFavorites.setHere(to: target)
				gFavorites.updateFavoritesAndRedraw {
					onCompletion?(false)
				}
			} else {
				if  gIsEssayMode {
					gControllers.swapMapAndEssay(force: .wMapMode)
				}

				focusOnBookmarkTarget() { (object, kind) in
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
		if  hasNoteOrEssay {
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

	func revealSiblings(untilReaching iAncestor: Zone) {
		[self].recursivelyRevealSiblings(untilReaching: iAncestor) { iZone in
			if     iZone != self {
				if iZone == iAncestor {
					gHere = iAncestor // side-effect does recents push

					gHere.grab()
				}

				gSignal([.spFavoritesMap, .spRelayout])
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

				if  zone.isInFavorites { // narrow, so hide former here and ignore extreme
					gFavorites.setHere(to: zone)
				} else if extreme {
					zone = child

					addRecursive()
				}
			}
		}

		addRecursive()
		onCompletion?(needReveal)

		if !needReveal {
			gSignal([.spCrumbs, .spDataDetails])
		}
	}

	func addZones(_ iZones: ZoneArray, at iIndex: Int?, undoManager iUndoManager: UndoManager?, _ flags: ZEventFlags, onCompletion: Closure?) {

		if  iZones.count == 0 {
			return
		}

		// ///////////////////////////////////////////////////////////////////////////////////////////////////////////// //
		// 1. move a normal zone into another normal zone                                                                //
		// 2. move a normal zone through a bookmark                                                                      //
		// 3. move a normal zone into favorites map -- create a bookmark pointing at normal zone, then add it to the map //
		// 4. move from favorites map into a normal zone -- convert to a bookmark, then move the bookmark                //
		//                                                                                                               //
		// OPTION  = copy                                                                                                //
		// SPECIAL = don't create bookmark              (case 3)                                                         //
		// CONTROL = don't change here or expand into                                                                    //
		// ///////////////////////////////////////////////////////////////////////////////////////////////////////////// //

		guard let undoManager = iUndoManager else {
			onCompletion?()

			return
		}

		let   toBookmark = isBookmark                    // type 2
		let  toFavorites = isInFavorites && !toBookmark   // type 3
		let         into = bookmarkTarget ?? self        // grab bookmark AFTER travel
		var        zones = iZones
		var      restore = [Zone: (Zone, Int?)] ()
		let     STAYHERE = flags.exactlySpecial
		let   NOBOOKMARK = flags.hasControl
		let         COPY = flags.hasOption
		var    cyclicals = IndexSet()

		// separate zones that are connected back to themselves

		for (index, zone) in zones.enumerated() {
			if  isProgenyOf(zone) {
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

		zones.reorderAccordingToValue()

		// //////////////// //
		// prepare for UNDO //
		// //////////////// //

		if  toBookmark {
			undoManager.beginUndoGrouping()
		}

		// todo: relocate this in caller, hope?
		UNDO(self) { iUndoSelf in
			for (child, (parent, index)) in restore {
				child.orphan()
				parent.addChildAndUpdateOrder(child, at: index)
			}

			iUndoSelf.UNDO(self) { iUndoUndoSelf in
				let zoneSelf = iUndoUndoSelf as Zone
				zoneSelf.addZones(zones, at: iIndex, undoManager: undoManager, flags, onCompletion: onCompletion)
			}

			onCompletion?()
		}

		// ////////// //
		// move logic //
		// ////////// //

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

				for zone in zones {
					var bookmark = zone

					if  toFavorites && !bookmark.isInFavorites && !bookmark.isBookmark && !bookmark.isInTrash && !STAYHERE {
						bookmark = gFavorites.matchOrCreateBookmark(for: bookmark, addToRecents: false)
					} else if bookmark.databaseID != into.databaseID {    // being moved to the other db
						if  bookmark.parentZone == nil || !bookmark.parentZone!.children.contains(bookmark) || !COPY {
							bookmark.needDestroy()                        // in wrong DB ... is not a child within its parent
							bookmark.orphan()
						}

						bookmark = bookmark.deepCopy(into: into.databaseID)
					}

					if !STAYHERE, !NOBOOKMARK {
						bookmark.addToGrabs()

						if  toFavorites {
							into.updateVisibilityInFavoritesMap(true)
						}
					}

					bookmark.orphan()
					into.addChildAndUpdateOrder(bookmark, at: iIndex)
					bookmark.recursivelyApplyDatabaseID(into.databaseID)
					if  gBookmarks.addToReverseLookup(bookmark) {
						gRelationships.addBookmarkRelationship(bookmark, target: zone, in: zone.databaseID)
					}
				}

				if  toBookmark && undoManager.groupingLevel > 0 {
					undoManager.endUndoGrouping()
				}

				onCompletion?()
			}
		}

		// ///////////////////////////////// //
		// deal with target being a bookmark //
		// ///////////////////////////////// //

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

	var isVisible: Bool {
		var isVisible = true

		traverseAncestors { iAncestor -> ZTraverseStatus in
			if  iAncestor != self, !iAncestor.isExpanded {
				isVisible  = false

				return .eStop
			}

			if  let  here  = widget?.controller?.hereZone,     // so this will also be correct for favorites map
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

	func assureZoneAdoption() {
		traverseAllAncestors { ancestor in
			ancestor.adopt()
		}
	}

	func isProgenyOfOrEqualTo(_ iZone: Zone?) -> Bool { return self == iZone || isProgenyOf(iZone) }
	func isProgenyOf(_ iZone: Zone?) -> Bool { return iZone == nil ? false : isProgenyOfAny(of: [iZone!]) }

	func isProgenyOfAny(of zones: ZoneArray) -> Bool {
		var isProgeny         = false
		if  zones.count       > 0 {
			traverseAncestors { ancestor -> ZTraverseStatus in
				if  ancestor != self,
					zones.contains(ancestor) {
					isProgeny = true

					return .eStop
				}

				return .eContinue
			}
		}

		return isProgeny
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

	func     hide() {    add(  to: .mCollapsed) }
	func   expand() {    add(  to: .mExpanded) }
	func collapse() { remove(from: .mExpanded) }
	func     show() { remove(from: .mCollapsed) }

	func toggleChildrenVisibility() {
		if  isExpanded {
			collapse()
		} else {
			expand()
		}
	}

	var isExpanded: Bool {
		if  let name = recordName,
			gExpandedIdeas.contains(name) {
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
			return !gCollapsedIdeas.contains(name)
		}

		return true
	}

	func add(to type: ZIdeaVisibilityMode) {
		var a = type.array

		add(to: &a)
		
		if  type == .mExpanded {
			for child in children {
				child.remove(from: .mCollapsed)
			}
		}
		
		type.setArray(a)
	}
	
	func remove(from type: ZIdeaVisibilityMode) {
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

	func addChildAndUpdateOrder(_ iChild: Zone?, at iIndex: Int? = nil, _ afterAdd: ZoneClosure? = nil) {
		if  isBookmark {
			bookmarkTarget?.addChildAndUpdateOrder(iChild, at: iIndex, afterAdd)
		} else if let child = iChild,
			addChildNoDuplicate(child, at: iIndex, afterAdd) != nil {
			children.updateOrder() // also marks children need save
		}
	}

	func indexInRelation(_ relation: ZRelation) -> Int {
		if  relation == .upon {
			return validIndex(from: gListsGrowDown ? nil : 0)
		} else {
			return (siblingIndex ?? 0) + relation.rawValue
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
			p.addChildAndUpdateOrder(n, at: i)  // swap it into this zones sibling index
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
					moveChild(from: index, to: toIndex)
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

			return addChild(child, at: toIndex, updateCoreData: updateCoreData, onCompletion)
		}

		return nil
	}

	@discardableResult func addChild(_ iChild: Zone? = nil, at iIndex: Int? = nil, updateCoreData: Bool = true, _ onCompletion: ZoneClosure? = nil) -> Int? {
		if  var        child = iChild {
			let      toIndex = validIndex(from: iIndex)

			// prevent cross-db family relation

			if  let maybe = maybeDatabaseID,
				maybe    != child.maybeDatabaseID {
				let c     = child
				child     = child.deepCopy(into: databaseID)

				c.deleteSelf(permanently: true, force: true, onCompletion: nil)
			}

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

			child.parentRID = nil

			child.setParentZone(nil)
			child.setValue(nil, forKeyPath: kParentRef)
			updateCoreDataRelationships()
			updateMaxLevel()
			needCount()

			return true
		}

		return false
	}

	func createIdeaFromSelectedText() {
		if  let newName  = textWidget?.extractTitleOrSelectedText() {

			gTextEditor.stopCurrentEdit()

			if  newName == zoneName {
				combineIntoParent()
			} else {
				gDeferRedraw {
					addIdea(at: gListsGrowDown ? nil : 0, with: newName) { [self] iChild in
						gDeferringRedraw = false

						if  let child = iChild {
							expand()
							gRelayoutMaps() {
								child.editAndSelect()
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
			}

			gRelayoutMaps() {
				parent.editAndSelect(range: range)
			}
		}
	}

	func generationalGoal(_ show: Bool, extreme: Bool = false) -> Int? {
		var goal: Int?

		if !show {
			goal = extreme ? level - 1 : highestExposed - 1
		} else if  extreme {
			goal = Int.max
		} else if let lowest = lowestExposed {
			goal = lowest + 1
		}

		return goal
	}

	func applyGenerationally(_ show: Bool, extreme: Bool = false) {
		let goal = generationalGoal(show, extreme: extreme)

		generationalUpdate(show: show, to: goal) {
			gRelayoutMaps()
		}
	}

	func generationalUpdate(show: Bool, to iLevel: Int? = nil, onCompletion: Closure? = nil) {
		recursiveUpdate(show, to: iLevel) {

			// ///////////////////////////////////////////////////// //
			// delay executing this until the last time it is called //
			// ///////////////////////////////////////////////////// //

			onCompletion?()
		}
	}

	func recursiveUpdate(_ show: Bool, to iLevel: Int?, onCompletion: Closure?) {
		if !show && isGrabbed && (count == 0 || !isExpanded) {

			// ///////////////////////// //
			// COLLAPSE LEFT INTO PARENT //
			// ///////////////////////// //

//			if  let l = iLevel, level > l {
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

			// ////////////// //
			// ALTER CHILDREN //
			// ////////////// //

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
					gFavorites.swapBetweenBookmarkAndTarget()
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
					let newParentZone = iZone.parentZone        // (1) grab new parent zone asssigned during a previous traverse (2, below)
					iZone       .dbid = appliedID               // must happen BEFORE record assignment

					// ////////////////////////////////////////////////////////////// //
					// (2) compute parent and parentLink using iZone's new databaseID //
					//     a subsequent traverse will eventually use it (1, above)    //
					// ////////////////////////////////////////////////////////////// //

					iZone.parentZone  = newParentZone
				}
			}
		}
	}

	@discardableResult func moveChild(from: Int, to: Int) -> Bool {
		if  from < count, to <= count, from != to,
			let child = self[from] { // nothing is created or destroyed

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
			} else if from < (to - 1) {
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
		children.reorderAccordingToValue()
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
			if  count == 0 || !isExpanded {
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

		gRelayoutMaps()
	}

	func updateMaxLevel() {
		if  gIsReadyToShowUI {
			gRemoteStorage.zRecords(for: maybeDatabaseID)?.updateMaxLevel(with: level)
		}
	}

	func zonesMatching(_ type: ZWorkingListType) -> ZoneArray {
		let progeny = type.contains(.wProgeny)
		let  groups = type.contains(.wGroups)
		let     all = type.contains(.wAll)
		var  result = ZoneArray()

		traverseAllProgeny { zone in
			let   notSelf = zone != self                 // ignore root of traversal
			let markMatch = zone.bookmarksMatching(type)
			let qualifies = all ||
				(!groups && (!progeny ||  notSelf) && markMatch) ||
			(notSelf && ( progeny || markMatch ||   (groups && (zone.count > 0))))

			if  qualifies {
				result.prependUnique(item: zone) { (a, b) in
					if  let    aZone = a as? Zone,
						let    bZone = b as? Zone {
						return aZone.hasSameZoneLink(as:bZone)
					}

					return false
				}
			}
		}

		return result
	}

	func bookmarksMatching(_ type: ZWorkingListType) -> Bool {
		guard zoneLink != nil else { return false }

		return type.contains(.wBookmarks) || (type.contains(.wNotemarks) && bookmarkTarget?.hasNote ?? false)
	}

	// MARK: - dots
	// MARK: -

	func ungrabProgeny() {
		for     grabbed in gSelecting.currentMapGrabs {
			if  grabbed != self && grabbed.isProgenyOf(self) {
				grabbed.ungrab()
			}
		}
	}

	func dragDotClicked(_ flags: ZEventFlags) {
		let COMMAND = flags.hasCommand
		let   SHIFT = flags.hasShift

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

		gRelayoutMaps()
	}

	func revealDotClicked(_ flags: ZEventFlags, isCircularMode: Bool = false) {
		ungrabProgeny()

		let COMMAND = flags.hasCommand
		let  OPTION = flags.hasOption

		if  isCircularMode {
			toggleShowing()
			
			if  isShowing {
				parentZone?.expand()
			}
			
			gRelayoutMaps()
		} else if isBookmark || (isTraveller && (COMMAND || count == 0)) {
			invokeTravel(COMMAND) { reveal in      // note, email, bookmark, hyperlink
				gSignal([.spRelayout, .spCrumbs])
			}
		} else if count > 0, !OPTION {
			let show = !isExpanded

			if  isInFavorites {
				updateVisibilityInFavoritesMap(show)
				gRelayoutMaps()
			} else {
				let goal = (COMMAND && show) ? Int.max : nil
				generationalUpdate(show: show, to: goal) {
					gRelayoutMaps()
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

	func updateVisibilityInFavoritesMap(_ show: Bool) {

		// /////////////////////////////////////////////////////////// //
		// avoid annoying user: treat favorites map non-generationally //
		// /////////////////////////////////////////////////////////// //

		// show -> collapse parent, expand self, here = parent
		// hide -> collapse self, expand parent, here = self

		if  !isARoot || show {
			let hidden = show ? parentZone : self

			hidden?.collapse()

			if  let shown = show ? self : parentZone {
				shown.expand()

				if  isInFavorites {
					gFavoritesHereMaybe = shown
				}
			}
		}
	}

	var traitKeys   : StringsArray {
		var results = StringsArray()

		for key in traits.keys {
			results.append(key.rawValue)
		}

		return results
	}

	func centeredIndex(_ limit: CGFloat, _ multiplyBy: CGFloat) -> CGFloat {
		let power = 1.7
		var index = (((CGFloat(parentZone?.count ?? 0) / 2.0) - CGFloat(siblingIndex ?? 0)) * 0.8) * multiplyBy
		if  index < .zero {
			index = -(abs(max(index, -limit)) ** power)
		} else {
			index =       min(index,  limit)  ** power
		}

		return index
	}

	var centeredIndex: (CGFloat, CGFloat) {
		let limit = 12
		var index = (parentZone?.halfCount ?? 0) - (siblingIndex ?? 0)
		let  goUp = (index >= 0) ? 1.0 : -1.0
		if  index < .zero {
			index = max(index, -limit)
		} else {
			index = min(index,  limit)
		}

		return (goUp, CGFloat(index))

	}

	func plainDotParameters(_ isFilled: Bool, _ isReveal: Bool, _ isDragDrop: Bool = false) -> ZDotParameters {
		let           d = gDragging.dragLine?.parentWidget?.widgetZone
		var           p = ZDotParameters()
		let           t = bookmarkTarget
		let           g = groupOwner
		let           k = traitKeys
		p.color         = dotColor
		p.isGrouped     = g != nil
		p.showList      = isExpanded
		p.hasTarget     = isBookmark
		p.typeOfTrait   = k.first ?? kEmpty
		p.showAccess    = hasAccessDecoration
		p.hasTargetNote = t?.hasNote ?? false
		p.isGroupOwner  = g == self || g == t
		p.showSideDot   = gFavorites.isCurrent(self)
		p.childCount    = (gCountsMode == .progeny) ? progenyCount : indirectCount
		p.accessType    = (directAccess == .eProgenyWritable) ? .sideDot : .vertical
		p.isDragged     = gDragging.draggedZones.contains(self) && gDragging.dragLine != nil
		p.isReveal      = isReveal
		p.isDrop        = isDragDrop && d != nil && d == self
		p.isFilled      = isFilled
		p.fill          = isFilled ? dotColor.lighter(by: 2.5) : gBackgroundColor
		p.isCircle      = p.hasTarget || p.hasTargetNote || p.childCount == 0

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
		colorized = !colorized // WTF?
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
			textWidget?.updateGUI()
			editAndSelect(range: r)

			return true
		}

		return false
	}

	func convertToFromLine() -> Bool {
		if  var childName = textWidget?.extractTitleOrSelectedText(requiresAllOrTitleSelected: true) {
			var location = 12

			if      childName == zoneName {
				if  zoneName  == kLineOfDashes {
					zoneName   = kVerticalBar
					childName  = kVerticalBar
				}

				convertToTitledLine()
			} else {
				if  childName == kVerticalBar {
					childName  = kLineOfDashes
				}

				zoneName  = childName
				colorized = !colorized // WTF?
				location  = 0
			}

			gTextEditor.stopCurrentEdit()
			editAndSelect(range: NSMakeRange(location, childName.length))

			return true
		}

		return false
	}

	func convertFromLineWithTitle() {
		if  let childName = textWidget?.extractedTitle {
			zoneName  = childName
			colorized = !colorized // WTF?
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
			colorMaybe = nil                  // recompute color
			let parent = resolveParent

			if  let p = parent,
				!p.children.contains(self) {
				p.addChildNoDuplicate(self)
				p.respectOrder()              // assume newly fetched zone knows its order
			}

			columnarReport("   ->", unwrappedName)
			onCompletion?(parent)
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
				case "n":     showNote()
				case "d":     duplicate()
				case "b":     addBookmark()
				case "e":     editTraitForType(.tEmail)
				case "h":     editTraitForType(.tHyperlink)
				case "s":     gFiles.export(self, toFileAs: .eSeriously)
				case "a", "l",
					 "r":	  children.sortAccordingToKey(key); gRelayoutMaps()
				case "o":     importFromFile(.eSeriously)     { gRelayoutMaps() }
				case "t":     swapWithParent                  { gRelayoutMaps() }
				case kSlash:  gFocusing.grabAndFocusOn(self)  { gRelayoutMaps() }
				case kBackSpace,
					 kDelete: deleteSelf    { flag in if flag { gRelayoutMaps() } }
				case kSpace:  addIdea()
				default:      break
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

		addChildAndUpdateOrder(zone)

		return zone
	}

	// ////////////////////////// //
	// exemplar and scratch ideas //
	//  N.B. not to be persisted  //
	// ////////////////////////// //

	static func recordNameFor(_ rootName: String, at index: Int) -> String {
		var name = rootName

		if  index > 0 { // index of 0 means use just the root name parameter
			name.append(index.description)
		}

		return name
	}

	// never use closure
	static func create(within rootName: String, for index: Int = 0, databaseID: ZDatabaseID) -> Zone {
		let      name = recordNameFor(rootName, at: index)
		var   created : Zone
		if  let cloud = gRemoteStorage.cloud(for: .everyoneID),
			let found = cloud.maybeZoneForRecordName(name) {
			created   = found
		} else {
			created   = Zone.uniqueZone(recordName: name, in: databaseID)
		}

		created.parentLink = kNullLink

		return created
	}

	static func uniqueZoneNamed(_ named: String?, recordName: String? = nil,  databaseID: ZDatabaseID, checkCDStore: Bool = false) -> Zone {
		let created           = uniqueZone(       recordName: recordName, in: databaseID,              checkCDStore: checkCDStore)
		if  created.zoneName == nil || created.zoneName!.isEmpty {
			created.zoneName  = named
		}

		return created
	}

	static func uniqueZone(                         recordName: String?,    in  databaseID: ZDatabaseID, checkCDStore: Bool = false) ->  Zone {
		return uniqueZRecord(entityName: kZoneType, recordName: recordName, in: databaseID,              checkCDStore: checkCDStore) as! Zone
	}

	static func uniqueZone(from dict: ZStorageDictionary, in  databaseID: ZDatabaseID, checkCDStore: Bool = false) -> Zone {
		let check = checkCDStore || dict[.link] != nil          // assume all bookmarks may already be in CD store (this has a negligible performance impact)
		let  zone = uniqueZone(recordName: dict.recordName, in: databaseID, checkCDStore: check)

		zone.temporarilyIgnoreNeeds {
			do {
				try zone.extractFromStorageDictionary(dict, of: kZoneType, into: databaseID, checkCDStore: check)
			} catch {
				printDebug(.dError, "\(error)")    // de-serialization
			}
		}

		return zone
	}

	func updateZoneNamesForBookmkarksTargetingSelf() {
		if  let name = zoneName {
			bookmarksTargetingSelf.setZoneNameForAll(name)
		}
	}

	func updateRecordName(for type: ZStorageType) {
		if  let    name = type.rootName,
			recordName != name {

			for child in children {
				child.parentZone = self // because record name is different, children must be pointed through a ck reference to new record created above
			}
		}
	}

	override func extractFromStorageDictionary(_ dict: ZStorageDictionary, of iRecordType: String, into iDatabaseID: ZDatabaseID, checkCDStore: Bool = false) throws {
		if  let name = dict[.name] as? String,
			responds(to: #selector(setter: zoneName)) {
			zoneName = name
		}

		try super.extractFromStorageDictionary(dict, of: iRecordType, into: iDatabaseID, checkCDStore: checkCDStore) // do this step last so the assignment above is NOT pushed to cloud

		if  let childrenDicts: [ZStorageDictionary] = dict[.children] as! [ZStorageDictionary]? {
			for childDict: ZStorageDictionary in childrenDicts {
				let child = Zone.uniqueZone(from: childDict, in: iDatabaseID, checkCDStore: checkCDStore)
				zRecords?.temporarilyIgnoreAllNeeds() {        // prevent needsSave caused by child's parent intentionally not being in childDict
					addChildNoDuplicate(child, at: nil)
				}
			}

			respectOrder()
		}

		if  let traitsStore: [ZStorageDictionary] = dict[.traits] as! [ZStorageDictionary]? {
			for  traitStore:  ZStorageDictionary in traitsStore {
				let trait = ZTrait.uniqueTrait(from: traitStore, in: iDatabaseID)

				zRecords?.temporarilyIgnoreAllNeeds {       // prevent needsSave caused by trait intentionally not being in traits
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

	var traitsArray: ZRecordsArray {
		var values = ZRecordsArray ()

		for trait in traits.values {
			values.append(trait)
		}

		return values
	}

}

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
	static let    wGroups = ZWorkingListType(rawValue: 1 << 3)
	static let       wAll = ZWorkingListType(rawValue: 1 << 4)

}
