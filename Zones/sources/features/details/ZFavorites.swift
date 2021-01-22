//
//  ZFavorites.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

enum ZBookmarkAction: Int {
    case aBookmark
    case aNotABookmark
    case aCreateFavorite
}

let gFavorites = ZFavorites(ZDatabaseID.favoritesID)
var gFavoritesRoot : Zone? { return gFavorites.rootZone }

class ZFavorites: ZRecords {

    // MARK:- initialization
    // MARK:-

	let cloudRootTemplates = Zone(as: kTemplatesRootName)

	var hasTrash: Bool {
		for favorite in workingBookmarks {
			if  let target = favorite.bookmarkTarget, target.isTrashRoot {
				return true
			}
		}

		return false
	}

	var favoritesIndex : Int? {
		for (index, zone) in workingBookmarks.enumerated() {
			if  zone == currentBookmark {
				return index
			}
		}

		return nil
	}

	override var rootZone : Zone? {
		get {
			return gMineCloud?.favoritesZone
		}

		set {
			if  let n = newValue {
				gMineCloud?.favoritesZone = n
			}
		}
	}

	func setup(_ onCompletion: IntClosure?) {
		let   mine = gMineCloud
		let finish = {
			self.createRootTemplates()

			if  let root = gFavoritesRoot {
				root.needProgeny()
			}

			onCompletion?(0)
		}

		if  let root = mine?.maybeZoneForRecordName(kFavoritesRootName) {
			gFavorites.rootZone = root

			finish()
		} else {
			// create favorites root
			mine?.assureRecordExists(withRecordID: CKRecordID(recordName: kFavoritesRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
				let        ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecordID(recordName: kFavoritesRootName))
				let            root = Zone(record: ckRecord, databaseID: .mineID)
				root.directAccess   = .eProgenyWritable
				root.zoneName       = kFavoritesRootName
				gFavorites.rootZone = root

				finish()
			}
		}
	}

    func createRootTemplates() {
        if  cloudRootTemplates.count == 0 {
            for (index, dbID) in kAllDatabaseIDs.enumerated() {
                let          name = dbID.rawValue
				let      bookmark = gBookmarks.create(withBookmark: nil, .aCreateFavorite, parent: cloudRootTemplates, atIndex: index, name, recordName: name + kFavoritesSuffix)
				bookmark.zoneLink =  "\(name)\(kColonSeparator)\(kColonSeparator)"
				bookmark   .order = Double(index) * 0.001
                
				bookmark.clearAllStates()
            }
        }
	}

	override func push(intoNotes: Bool = false) {
		createFavorite(for: gHere, action: .aCreateFavorite)?.grab()
	}

	@discardableResult func createFavorite(for iZone: Zone?, action: ZBookmarkAction) -> Zone? {

		// ////////////////////////////////////////////
		// 1. zone not a bookmark, pass the original //
		// 2. zone is a bookmark, pass a deep copy   //
		// ////////////////////////////////////////////

		if  let       zone = iZone,
			let       root = rootZone,
			var     parent = zone.parentZone,
			let  newParent = gFavoritesHereMaybe ?? gFavoritesRoot {
			let isBookmark = zone.isBookmark
			let  actNormal = action == .aBookmark

			if  !actNormal {
				let          basis = isBookmark ? zone.crossLink! : zone

				if  let recordName = basis.ckRecordName {
					parent         = gFavoritesHereMaybe ?? gFavoritesRoot!

					for workingFavorite in root.allBookmarkProgeny {
						if  !workingFavorite.isInTrash,
							recordName == workingFavorite.linkRecordName,
							let  target = workingFavorite.bookmarkTarget,
							!target.isARoot {
							currentBookmark = workingFavorite

							return workingFavorite
						}
					}
				}
			}

			let           count = parent.count
			var bookmark: Zone? = isBookmark ? zone.deepCopy : nil               // 1. and 2.
			var           index = parent.children.firstIndex(of: zone) ?? count

			if  action         == .aCreateFavorite,
				let      fIndex = favoritesIndex {
				index           = nextWorkingIndex(after: fIndex, going: gListsGrowDown)
			}

			bookmark            = gBookmarks.create(withBookmark: bookmark, action, parent: newParent, atIndex: index, zone.zoneName)

			bookmark?.maybeNeedSave()

			if  actNormal {
				parent.updateCKRecordProperties()
				parent.maybeNeedMerge()
			}

			if !isBookmark {
				bookmark?.crossLink = zone

				gBookmarks.persistForLookupByTarget(bookmark!)
			}

			return bookmark!
		}

		return nil
	}

    // MARK:- update
    // MARK:-

    func updateCurrentFavorite(_ currentZone: Zone? = nil) {
        if  let     bookmark = whichBookmarkTargets(currentZone ?? gHereMaybe),
            let       target = bookmark.bookmarkTarget,
            (gHere == target || !(currentBookmark?.bookmarkTarget?.spawnedBy(gHere) ?? false)),
			!gIsRecentlyMode {
            currentBookmark = bookmark
        }
    }
    
    func updateFavoritesAndRedraw(avoidRedraw: Bool = false, _ onCompletion: Closure? = nil) {
        if  updateAllFavorites() || !avoidRedraw {
            gRedrawMaps { onCompletion?() }
        } else {
            onCompletion?()
        }
    }

    @discardableResult func updateAllFavorites(_ currentZone: Zone? = nil) -> Bool {
		var result = true

		// /////////////////////////////////////////////
		// assure at least one root favorite per db   //
		// call every time favorites MIGHT be altered //
		// /////////////////////////////////////////////

		if  let        bookmarks = rootZone?.allBookmarkProgeny {
			var   hasDatabaseIDs = [ZDatabaseID] ()
			var         discards = IndexPath()
			var      testedSoFar = ZoneArray ()
			var      missingLost = true
			var     missingTrash = true
			var     hasDuplicate = false

			// //////////////////////////////////
			// detect ids which have bookmarks //
			//   remove unfetched duplicates   //
			// //////////////////////////////////

			for bookmark in bookmarks {
				if  let            link  = bookmark.zoneLink { // always true: all working favorites have a zone link
					if             link == kTrashLink {
						if  missingTrash {
							missingTrash = false
						} else {
							hasDuplicate = true
						}
					} else if      link == kLostAndFoundLink {
						if  missingLost {
							missingLost  = false
						} else {
							hasDuplicate = true
						}
					} else if let   dbID = bookmark.linkDatabaseID, bookmark.linkIsRoot {
						if !hasDatabaseIDs.contains(dbID) {
							hasDatabaseIDs.append(dbID)
						} else {
							hasDuplicate = true
						}
					} else {    // target is not a root -> don't bother adding to testedSoFar
						continue
					}

					// ///////////////////////////////////////
					// mark to discard unfetched duplicates //
					// ///////////////////////////////////////

					if  hasDuplicate {
						let isUnfetched: ZoneClosure = { iZone in
							if iZone.notFetched, let index = self.workingBookmarks.firstIndex(of: iZone) {
								discards.append(index)
							}
						}

						for     duplicate in testedSoFar {
							if  duplicate.bookmarkTarget == bookmark.bookmarkTarget {
								isUnfetched(bookmark)
								isUnfetched(duplicate)

								break
							}
						}
					}

					testedSoFar.append(bookmark)
				}
			}

			// ////////////////////////////
			// discard marked duplicates //
			// ////////////////////////////

			while   let   index = discards.popLast() {
				if  index < workingBookmarks.count {
					let discard = workingBookmarks[index]
					discard.needDestroy()
					discard.orphan()
				}
			}

			// //////////////////////////////////////////////
			// add missing trash + lost and found favorite //
			// //////////////////////////////////////////////

			if  missingTrash {
				let          trash = Zone(databaseID: .mineID, named: kTrashName, recordName: kTrashName + kFavoritesSuffix)
				trash    .zoneLink = kTrashLink // convert into a bookmark
				trash.directAccess = .eProgenyWritable

				gFavoritesRoot?.addAndReorderChild(trash)
				trash.clearAllStates()
				trash.markNotFetched()
			}

			if  missingLost {
				let recordName = kLostAndFoundName + kFavoritesSuffix
				var       lost = gMineCloud?.maybeZoneForRecordName(recordName)

				if  lost      == nil {
					lost       = Zone(databaseID: .mineID, named: kLostAndFoundName, recordName: recordName)
				}

				lost?    .zoneLink = kLostAndFoundLink // convert into a bookmark
				lost?.directAccess = .eProgenyWritable

				gFavoritesRoot?.addAndReorderChild(lost!)
				lost?.clearAllStates()
				lost?.markNotFetched()
			}

			// /////////////////////////////
			// add missing root favorites //
			// /////////////////////////////

			for template in cloudRootTemplates.children {
				if  let          dbID = template.linkDatabaseID, !hasDatabaseIDs.contains(dbID) {
					let      bookmark = template.deepCopy
					bookmark.zoneName = template.bookmarkTarget?.zoneName

					gFavoritesRoot?.addChildAndRespectOrder(bookmark)
					bookmark.clearAllStates() // erase side-effect of add
					bookmark.markNotFetched()
				}
			}

			result = missingLost || missingTrash || hasDuplicate
		}

        updateCurrentFavorite(currentZone)

		return result
    }

    // MARK:- switch
    // MARK:-

    func nextWorkingIndex(after index: Int, going down: Bool) -> Int {
        let  increment = (down ? 1 : -1)
        var       next = index + increment
        let      count = workingBookmarks.count
        if next       >= count {
            next       = 0
        } else if next < 0 {
            next       = count - 1
        }

        return next
    }

    // MARK:- toggle
    // MARK:-

    func updateGrab() {
		if  gIsRecentlyMode { return }

		let here = gHere

		// /////////////////////////////////////////////////////////////////////////////////////
        // three states, for which the bookmark that targets here is...                       //
        // 1. in favorites, not grabbed  -> grab favorite                                     //
        // 2. in favorites, grabbed      -> doesn't invoke this method                        //
        // 3. not in favorites           -> create and grab new favorite (its target is here) //
		// /////////////////////////////////////////////////////////////////////////////////////

		if  let       bookmark = whichBookmarkTargets(here, orSpawnsIt: false) {
			hereZoneMaybe?.collapse()
			bookmark.asssureIsVisibleAndGrab()                                          // state 1

			hereZoneMaybe      = gSelecting.firstGrab?.parentZone
			currentBookmark    = bookmark
		} else if let bookmark = createFavorite(for: here, action: .aCreateFavorite) {  // state 3
			currentBookmark    = bookmark

			bookmark.asssureIsVisibleAndGrab()
		}

		updateAllFavorites()
	}

    func delete(_ favorite: Zone) {
        favorite.moveZone(to: favorite.trashZone)
        gBookmarks.forget(favorite)
        updateAllFavorites()
    }

}
