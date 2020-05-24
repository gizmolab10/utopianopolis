//
//  ZRecents.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/18/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

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

			root?.reallyNeedProgeny()
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

	func updateCurrentRecent() {
		if  let  bookmark = root?.children.bookmarksTargeting(gHereMaybe) {
			currentRecent = bookmark
		}
	}

	func push() {
		if  let r = root {
			for bookmark in r.children {
				if  let name = bookmark.bookmarkTarget?.recordName(),
					name == gHereMaybe?.recordName() {
					updateCurrentRecent()

					return
				}
			}

			if  let bookmark = gFavorites.createBookmark(for: gHereMaybe, action: .aBookmark) {
				r.children.append(bookmark)
			}

			updateCurrentRecent()
		}
	}

	func go(forward: Bool) {
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

			gHere.grab()
			focus(kind: .eSelected) {
				gSignal([.sRelayout])
			}
		}
	}

	func focus(kind: ZFocusKind = .eEdited, _ COMMAND: Bool = false, _ atArrival: @escaping Closure) {

		// for grabbed/edited zone, five states:
		// 1. is a bookmark      -> target becomes here
		// 2. is here            -> update in favorites, not push
		// 3. in favorite/recent -> grab here
		// 4. not here, COMMAND  -> become here
		// 5. not COMMAND        -> select here

		if  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab {
			let focusClosure = { (zone: Zone) in
				gHere = zone

				gFavorites.updateCurrentFavorite()
				zone.grab()
				atArrival()
			}

			if  zone.isBookmark {     		// state 1
				travelThrough(zone) { object, kind in
					focusClosure(object as! Zone)
				}
			} else if zone == gHere {       // state 2
				updateCurrentRecent()
				gFavorites.updateGrab()
				atArrival()
			} else if zone.isInFavorites || zone.isInRecently {  // state 3
				focusClosure(gHere)
			} else if COMMAND {             // state 4
				gFavorites.refocus {
					self.push()
					atArrival()
				}
			} else {                        // state 5
				focusClosure(zone)
			}
		}
	}

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

}
