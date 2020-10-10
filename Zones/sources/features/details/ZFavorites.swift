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

    let databaseRootFavorites = Zone(record: nil, databaseID: nil)

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

	var workingFavorites : [Zone] {
		return (gBrowsingIsConfined ? hereZoneMaybe?.bookmarks : rootZone?.allBookmarkProgeny) ?? []
	}

    var hasTrash: Bool {
        for favorite in workingFavorites {
            if  let target = favorite.bookmarkTarget, target.isTrashRoot {
                return true
            }
        }

        return false
    }

	var favoritesIndex : Int? {
		for (index, zone) in workingFavorites.enumerated() {
			if  zone == currentBookmark {
				return index
			}
		}

		return nil
	}

    func createRootFavorites() {
        if  databaseRootFavorites.count == 0 {
            for (index, dbID) in kAllDatabaseIDs.enumerated() {
                let          name = dbID.rawValue
                let      favorite = create(withBookmark: nil, .aCreateFavorite, parent: databaseRootFavorites, atIndex: index, name, identifier: name + kFavoritesSuffix)
                favorite.zoneLink =  "\(name)\(kColonSeparator)\(kColonSeparator)"
                favorite   .order = Double(index) * 0.001
                
                favorite.clearAllStates()
            }
        }
    }

    func favoriteTargetting(_ iTarget: Zone?, iSpawned: Bool = true) -> Zone? {
        var found: Zone?

        if  iTarget?.databaseID != nil {
			found                = rootZone?.allBookmarkProgeny.bookmarksTargeting([iTarget!], iSpawned: iSpawned)
        }

        if  iSpawned  &&  found == nil {
            return favoriteTargetting(iTarget, iSpawned: false)
        }

        return found
    }


    // MARK:- API
    // MARK:-

    func setup(_ onCompletion: IntClosure?) {
        let   mine = gMineCloud
        let finish = {
            self.createRootFavorites()

            if  let root = gFavoritesRoot {
                root.reallyNeedProgeny()
            }

            onCompletion?(0)
        }

        if  let root = mine?.maybeZoneForRecordName(kFavoritesRootName) {
			gFavorites.rootZone = root

            finish()
        } else {
            mine?.assureRecordExists(withRecordID: CKRecord.ID(recordName: kFavoritesRootName), recordType: kZoneType) { (iRecord: CKRecord?) in
                let        ckRecord = iRecord ?? CKRecord(recordType: kZoneType, recordID: CKRecord.ID(recordName: kFavoritesRootName))
                let            root = Zone(record: ckRecord, databaseID: .mineID)
                root.directAccess   = .eProgenyWritable
                root.zoneName       = kFavoritesName
				gFavorites.rootZone = root

                finish()
            }
        }
    }

    func updateCurrentFavorite(_ currentZone: Zone? = nil, reveal: Bool = false) {
        if  let     favorite = favoriteTargetting(currentZone ?? gHereMaybe),
            let       target = favorite.bookmarkTarget,
            (gHere == target || !(currentBookmark?.bookmarkTarget?.spawnedBy(gHere) ?? false)),
			!gIsRecentlyMode {
            currentBookmark = favorite
            
            if  reveal {
                
                // ///////////////////////////////////////////////////////////////
                // not reveal current favorite if user has hidden all favorites //
                // ///////////////////////////////////////////////////////////////
                
                favorite.traverseAllAncestors { iAncestor in
                    iAncestor.revealChildren()
                }
            }
        }
    }
    
    func updateFavoritesAndRedraw(avoidRedraw: Bool = false, _ onCompletion: Closure? = nil) {
        if  updateAllFavorites() || !avoidRedraw {
            gRedrawGraph { onCompletion?() }
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
					} else if  link == kLostAndFoundLink {
						if  missingLost {
							missingLost  = false
						} else {
							hasDuplicate = true
						}
					} else if let      t = bookmark.bookmarkTarget, t.isARoot,
							  let         dbID = t.databaseID {
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
							if iZone.notFetched, let index = self.workingFavorites.firstIndex(of: iZone) {
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
				if  index < workingFavorites.count {
					let discard = workingFavorites[index]
					discard.needDestroy()
					discard.orphan()
				}
			}

			// //////////////////////////////////////////////
			// add missing trash + lost and found favorite //
			// //////////////////////////////////////////////

			if  missingTrash {
				let          trash = Zone(databaseID: .mineID, named: kTrashName, identifier: kTrashName + kFavoritesSuffix)
				trash    .zoneLink = kTrashLink // convert into a bookmark
				trash.directAccess = .eProgenyWritable

				gFavoritesRoot?.addAndReorderChild(trash)
				trash.clearAllStates()
				trash.markNotFetched()
			}

			if  missingLost {
				let identifier = kLostAndFoundName + kFavoritesSuffix
				var       lost = gMineCloud?.maybeZoneForRecordName(identifier)

				if  lost      == nil {
					lost       = Zone(databaseID: .mineID, named: kLostAndFoundName, identifier: identifier)
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

			for template in databaseRootFavorites.children {
				if  let          dbID = template.linkDatabaseID, !hasDatabaseIDs.contains(dbID) {
					let      bookmark = template.deepCopy
					bookmark.zoneName = bookmark.bookmarkTarget?.zoneName

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

    func next(_ index: Int, _ forward: Bool) -> Int {
        let  increment = (forward ? 1 : -1)
        var       next = index + increment
        let      count = workingFavorites.count
        if next       >= count {
            next       = 0
        } else if next < 0 {
            next       = count - 1
        }

        return next
    }

    func got(_ forward: Bool, atArrival: @escaping Closure) {
		if  let   fIndex = favoritesIndex {
			let    index = next(fIndex, forward)
			var     bump : IntClosure?
			bump         = { (iIndex: Int) in
				let zone = self.workingFavorites[iIndex]

				if	!zone.focusThrough(atArrival) {

					// /////////////////
					// error: RECURSE //
					// /////////////////

					bump?(self.next(iIndex, forward))
				}
			}

			bump?(index)
		}
	}

	// MARK:- create
    // MARK:-

    @discardableResult func create(withBookmark: Zone?, _ iName: String?, identifier: String? = nil) -> Zone {
        var           bookmark = withBookmark
        if  bookmark          == nil {
            bookmark           = Zone(databaseID: .mineID, named: iName, identifier: identifier)
        } else if let     name = iName {
            bookmark!.zoneName = name
        }

        return bookmark!
    }

    @discardableResult func create(withBookmark: Zone?, _ action: ZBookmarkAction, parent: Zone, atIndex: Int, _ name: String?, identifier: String? = nil) -> Zone {
        let bookmark: Zone = create(withBookmark: withBookmark, name, identifier: identifier)
        let insertAt: Int? = atIndex == parent.count ? nil : atIndex

        if  action != .aNotABookmark {
            parent.addChild(bookmark, at: insertAt) // calls update progeny count
        }
        
        bookmark.updateCKRecordProperties() // is this needed?

        return bookmark
    }

	@discardableResult func createFavorite(for iZone: Zone?, action: ZBookmarkAction) -> Zone? {

		// /////////////////////////////////////////////
		// 1. zone is a bookmark, pass a deep copy it //
		// 2. not a bookmark, pass it                 //
		// /////////////////////////////////////////////

		if  let         zone = iZone,
			let         root = rootZone {
			var parent: Zone = zone.parentZone ?? gFavoritesHereMaybe ?? gFavoritesRoot!
			let   isBookmark = zone.isBookmark
			let    actNormal = action == .aBookmark

			if  !actNormal {
				let basis: ZRecord = isBookmark ? zone.crossLink! : zone

				if  let recordName = basis.recordName {
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
				index           = next(fIndex, gListsGrowDown)
			}

			bookmark            = create(withBookmark: bookmark, action, parent: parent, atIndex: index, zone.zoneName)

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

		if  let       favorite = favoriteTargetting(here, iSpawned: false) {
			hereZoneMaybe?.concealChildren()
			favorite.asssureIsVisibleAndGrab()                                          // state 1

			hereZoneMaybe      = gSelecting.firstGrab?.parentZone
			currentBookmark    = favorite
		} else if let favorite = createFavorite(for: here, action: .aCreateFavorite) {  // state 3
			currentBookmark    = favorite

			favorite.asssureIsVisibleAndGrab()
		}

		updateAllFavorites()
	}

    func delete(_ favorite: Zone) {
        favorite.moveZone(to: favorite.trashZone)
        gBookmarks.forget(favorite)
        updateAllFavorites()
    }

}
