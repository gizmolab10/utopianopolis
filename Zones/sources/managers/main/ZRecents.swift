//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

enum ZFocusKind: Int {
	case eSelected
	case eEdited
}

let   gRecents = ZRecents(ZDatabaseID.recentsID)

class ZRecents : ZRecords {

	var currentRecent: Zone?

	var root : Zone? {
		get {
			return gMineCloud?.recentsZone
		}

		set {
			if  let n = newValue {
				gMineCloud?.recentsZone = n
			}
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		let        mine = gMineCloud
		if  let newRoot = mine?.maybeZoneForRecordName(kRecentsRootName) {
			root        = newRoot

			newRoot.reallyNeedProgeny()
			onCompletion?(0)
		} else {
			mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kRecentsRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let            ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kRecentsRootName))
				self.root               = Zone(record: ckRecord, databaseID: .mineID)
				self.root?.directAccess = .eProgenyWritable
				self.root?.zoneName     = kRecentsRootName

				self.root?.reallyNeedProgeny()
				onCompletion?(0)
			}
		}
	}

	func updateRecents(shouldGrab: Bool = false) {
		if  currentRecent?.isGrabbed ?? false {
			currentRecent?.bookmarkTarget?.grab()
		} else if updateCurrentRecent(),
			gIsRecentlyMode,
			shouldGrab {
			currentRecent?.grab()
		}
	}

	@discardableResult func updateCurrentRecent() -> Bool {
		if  let recents = root?.children {
			var targets = ZoneArray()

			if  let grab = gSelecting.firstGrab {
				targets.append(grab)
			}

			if  let here = gHereMaybe {
				targets.append(here)
			}

			if  let bookmark  = recents.bookmarksTargeting(targets) {
				currentRecent = bookmark

				return true
			}
		}

		return false
	}

	func push(intoNotes: Bool = false) {
		if  let r = root {
			for bookmark in r.children {
				if  let name = bookmark.bookmarkTarget?.recordName(),
					name    == gHereMaybe?.recordName() {
					updateCurrentRecent()

					return
				}
			}

			if  let bookmark = gFavorites.createBookmark(for: gHereMaybe, action: .aBookmark) {
				bookmark.moveZone(to: r)
			}

			updateCurrentRecent()
		}
	}

	@discardableResult func pop(fromNotes: Bool = false) -> Bool {
		return remove(gHereMaybe, fromNotes: fromNotes)
	}

	@discardableResult func remove(_ iItem: NSObject?, fromNotes: Bool = false) -> Bool {
		if  let  zone = iItem as? Zone,
			let     r = root {
			var found = kCFNotFound

			for (index, bookmark) in r.children.enumerated() {
				if  let name = bookmark.bookmarkTarget?.recordName(),
					name    == zone.recordName() {
					found    = index

					break
				}
			}

			if  found != kCFNotFound {
				go(forward: true)
				r.children.remove(at: found)

				return true
			}
		}

		return false
	}

	func go(forward: Bool, amongNotes: Bool = false) {
		if  let zones = root?.children {
			let   max = zones.count - 1
			var found = 0

			for (index, recent) in zones.enumerated() {
				if  recent == currentRecent {
					if  forward {
						if  index < max {
							found = index + 1
						}
					} else if  index == 0 {
						found = max
					} else if   index > 1 {
						found = index - 1
					}

					break
				}
			}

			setCurrent(zones[found])
		}
	}

	func setCurrent(_ recent: Zone) {
		currentRecent = recent
		if  let here  = recent.bookmarkTarget {
			gHere     = here

			focus(kind: .eSelected) {
				gHere.grab()
				gSignal([.sRelayout])
			}
		}
	}

	func object(for id: String) -> NSObject? {
		let parts = id.components(separatedBy: kColonSeparator)

		if  parts.count == 2 {
			if  parts[0] == "note" {
				return ZNote .object(for: parts[1], isExpanded: false)
			} else {
				return ZEssay.object(for: parts[1], isExpanded: true)
			}
		}

		return nil
	}

	// MARK:- focus
	// MARK:-

	func focusOn(_ iHere: Zone, _ atArrival: @escaping Closure) {
		gHere = iHere // side-effect does recents push

		focus(kind: .eSelected) {
			iHere.grab()
			self.updateCurrentRecent()
			gFavorites.updateCurrentFavorite()
			atArrival()
		}
	}

	func focus(kind: ZFocusKind = .eEdited, _ COMMAND: Bool = false, shouldGrab: Bool = false, _ atArrival: @escaping Closure) {

		// regarding grabbed/edited zone, five states:
		// 1. is a bookmark      -> target becomes here
		// 2. is here            -> update in favorites, not push
		// 3. in favorite/recent -> grab here
		// 4. not here, COMMAND  -> become here
		// 5. not COMMAND        -> select here

		guard  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab else {
			atArrival()

			return
		}

		let finishAndGrab = { (zone: Zone) in
			gFavorites.updateCurrentFavorite()
			zone.grab()
			atArrival()
		}

		if  zone.isBookmark {     		// state 1
			travelThrough(zone) { object, kind in
				gHere = object as! Zone

				finishAndGrab(gHere)
			}
		} else if zone == gHere {       // state 2
			updateRecents(shouldGrab: shouldGrab)
			gFavorites.updateGrab()
			atArrival()
		} else if zone.isInDetails {    // state 3
			finishAndGrab(gHere)
		} else if COMMAND {             // state 4
			refocus {
				atArrival()
			}
		} else {                        // state 5
			if  shouldGrab {
				gHere = zone
			}

			finishAndGrab(zone)
		}
	}

	@discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
		if  let current = currentRecent {
			return focusThrough(current, atArrival)
		}

		return false
	}

	@discardableResult func focusThrough(_ iBookmark: Zone?, _ atArrival: @escaping Closure) -> Bool {
		if  let bookmark = iBookmark, bookmark.isBookmark {
			if  bookmark.isInDetails {
				let targetParent = bookmark.bookmarkTarget?.parentZone

				targetParent?.revealChildren()
				targetParent?.needChildren()
				travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
					self.updateCurrentRecent()
					gFavorites.updateAllFavorites(iObject as? Zone)
					atArrival()
				}

				return true
			} else if let dbID = bookmark.crossLink?.databaseID {
				gDatabaseID = dbID

				focus {
					gHere.grab()
					atArrival()
				}

				return true
			}

			performance("oops!")
		}

		return false
	}

	// MARK:- travel
	// MARK:-

	func travelThrough(_ iBookmark: Zone, atArrival: @escaping SignalClosure) {
		if  let  targetZRecord = iBookmark.crossLink,
			let     targetDBID = targetZRecord.databaseID,
			let   targetRecord = targetZRecord.record {
			let targetRecordID = targetRecord.recordID
			let        iTarget = iBookmark.bookmarkTarget

			let complete : SignalClosure = { (iObject, iKind) in
				self.showTopLevelFunctions()
				atArrival(iObject, iKind)
			}

			var there: Zone?

			if  iBookmark.isInFavorites {
				gFavorites.currentFavorite = iBookmark
			}

			if  iBookmark.isInRecently {
				gRecents.currentRecent     = iBookmark
			}

			if  let target = iTarget, target.spawnedBy(gHereMaybe) {
				if !target.isGrabbed {
					target.asssureIsVisible()
					target.grab()
				} else {
					gHere = target

					push()
				}

				gShowFavorites = targetDBID == .favoritesID

				complete(target, .sRelayout)
			} else {
				gShowFavorites = targetDBID == .favoritesID

				if  gDatabaseID != targetDBID {
					gDatabaseID  = targetDBID

					// /////////////////////////// //
					// TRAVEL TO A DIFFERENT GRAPH //
					// /////////////////////////// //

					if  let target = iTarget, target.isFetched { // e.g., default root favorite
						focus(kind: .eSelected) {
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
								self.focus {
									complete(newHere, .sRelayout)
								}
							} else {
								complete(gHere, .sRelayout)
							}
						}
					}
				} else {

					// ///////////////// //
					// STAY WITHIN GRAPH //
					// ///////////////// //

					there = gCloud?.maybeZoneForRecordID(targetRecordID)
					let grabbed = gSelecting.firstSortedGrab
					let    here = gHere

					UNDO(self) { iUndoSelf in
						self.UNDO(self) { iRedoSelf in
							self.travelThrough(iBookmark, atArrival: complete)
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

	func invokeTravel(_ iZone: Zone?, onCompletion: Closure? = nil) {
		guard let zone = iZone else {
			onCompletion?()

			return
		}

		if  !invokeBookmark(zone, onCompletion: onCompletion),
			!invokeHyperlink(zone),
			!invokeEssay(zone) {
			invokeEmail(zone)
		}
	}

	@discardableResult func invokeBookmark(_ bookmark: Zone, onCompletion: Closure?) -> Bool { // false means not traveled
		let doTryBookmark = bookmark.isBookmark

		if  doTryBookmark {
			travelThrough(bookmark) { object, kind in
				#if os(iOS)
				gActionsController.alignView()
				#endif
				onCompletion?()
			}
		}

		return doTryBookmark
	}

	@discardableResult func invokeHyperlink(_ iZone: Zone) -> Bool { // false means not traveled
		if  let link = iZone.hyperLink,
			link    != kNullLink {
			link.openAsURL()

			return true
		}

		return false
	}

	@discardableResult func invokeEssay(_ iZone: Zone) -> Bool { // false means not handled
		if  iZone.hasNote {
			iZone.grab()

			gCurrentEssay = iZone.note

			gControllers.swapGraphAndEssay()

			return true
		}

		return false
	}

	@discardableResult func invokeEmail(_ iZone: Zone) -> Bool { // false means not traveled
		if  let  link = iZone.email {
			let email = "mailTo:" + link
			email.openAsURL()

			return true
		}

		return false
	}

}
