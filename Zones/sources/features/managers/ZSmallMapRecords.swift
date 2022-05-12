//
//  ZSmallMapRecords.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/22/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

func gSetHereZoneForID(here: Zone?, _ dbID: ZDatabaseID) {
	gRemoteStorage.zRecords(for: dbID)?.hereZoneMaybe = here
}

func gHereZoneForIDMaybe(_ dbID: ZDatabaseID) -> Zone? {
	if  let    cloud = gRemoteStorage.zRecords(for: dbID) {
		return cloud.maybeZoneForRecordName(cloud.hereRecordName, trackMissing: false)
	}

	return nil
}

// working zones depends on if we are in essay editing mode

class ZSmallMapRecords: ZRecords {

	var currentRecent    : Zone?
	var currentFavorite  : Zone?
	var working          : ZoneArray { return  gIsEssayMode ? workingNotemarks : workingBookmarks }
	var workingGroups    : ZoneArray { return  rootZone?.allGroups ?? [] }
	var workingBookmarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.bookmarks : rootZone?.allBookmarkProgeny) ?? [] }
	var workingNotemarks : ZoneArray { return (gBrowsingIsConfined ? hereZoneMaybe?.notemarks : rootZone?.allNotemarkProgeny) ?? [] }

	// MARK: - cycle
	// MARK: -

	func nextBookmark(down: Bool, amongNotes: Bool = false, moveCurrent: Bool = false, withinRecents: Bool = false) {
		if  currentFavorite == nil {
			gFavorites.push()
		}

		let        recents = gFavorites.recentsGroupZone.children
		let       notNotes = withinRecents ? recents.count > 0 ? recents : working : working
		let          zones = amongNotes ? workingNotemarks : notNotes
		let          count = zones.count
		if  count          > 1 {            // there is no next for count == 0 or 1
			let   maxIndex = count - 1
			var    toIndex = down ? 0 : maxIndex
			if  let target = currentFavorite?.zoneLink {
				for (index, bookmark) in zones.enumerated() {
					if  let b = bookmark.zoneLink, b == target {
						if         down, index < maxIndex {
							toIndex = index + 1         // go down
						} else if !down, index > 0 {
							toIndex = index - 1         // go up
						}

						break
					}
				}

				if  toIndex.isWithin(0 ... maxIndex) {
					let newCurrent = zones[toIndex]

					if  moveCurrent {
						moveCurrentTo(newCurrent)
					} else {
						setAsCurrent(newCurrent, alterHere: true)
					}
				}
			}
		}
	}

	func moveCurrentTo(_ iZone: Zone) {
		if  let parent = iZone.parentZone,
			let      p = currentFavorite?.parentZone, p == parent,
			let   from = currentFavorite?.siblingIndex,
			let     to = iZone.siblingIndex {
			parent.moveChildIndex(from: from, to: to)
		}
	}

	func setAsCurrent(_  iZone: Zone?, alterHere: Bool = false) {
		if  alterHere,
			makeVisibleAndMarkInSmallMap(iZone) {
			iZone?.grab()
		}

		if  let       tHere = iZone?.bookmarkTarget {
			currentFavorite = iZone

			if  alterHere {
				gDatabaseID          = tHere.databaseID
				gRecords.currentHere = tHere // avoid push

				gHere.grab()
			}

			if  gIsMapMode {
				gFocusing.focusOnGrab(.eSelected) {
					gSignal([.spRelayout])
				}
			} else if gCurrentEssayZone != tHere {
				gEssayView?.resetCurrentEssay(tHere.note)
			}
		}
	}

	func targeting(_ target: Zone, in array: ZoneArray?, orSpawnsIt: Bool = true) -> Zone? {
		return array?.whoseTargetIntersects(with: [target], orSpawnsIt: orSpawnsIt)
	}

	func workingBookmark(for target: Zone?) -> Zone? {
		return target == nil ? workingBookmarks.first : targeting(target!, in: workingBookmarks, orSpawnsIt: false)
	}

	func bookmarkTargeting(_ target: Zone, orSpawnsIt: Bool = false) -> Zone? {
		return targeting(target, in: rootZone?.allBookmarkProgeny, orSpawnsIt: orSpawnsIt)
	}

	// MARK: - pop and push
	// MARK: -

	func push(_ zone: Zone? = gHere) {}

	@discardableResult func pop(_ zone: Zone? = gHereMaybe) -> Bool {
		if  workingBookmarks.count > 1,
			let bookmark = workingBookmark(for: zone) {
			nextBookmark(down: true)
			bookmark.deleteSelf(permanently: true) {}

			return true
		}

		return false
	}

	func popAndUpdateCurrent() {
		if  let       index = currentFavorite?.siblingIndex,
			let    children = currentFavorite?.parentZone?.children,
			let        next = children.next(from: index, forward: false),
			pop() {
			currentFavorite = next
			if  let    here = currentFavorite?.bookmarkTarget {
				gHere       = here

				gHere.grab()
			}
		}

		gSignal([.sDetails])
		gRelayoutMaps()
	}

	func insertAsNext(_ zone: Zone) {
		if  let           r = rootZone {
			currentFavorite = zone
			let      cIndex = r.children.firstIndex(of: zone) ?? 0
			let       index = cIndex.next(forward: gListsGrowDown, max: r.count - 1)

			r.addChildNoDuplicate(zone, at: index)
		}
	}

	func removeBookmark(for zone: Zone? = gHereMaybe) {
		workingBookmark(for: zone)?.deleteSelf(permanently: true) {}
	}

	// MARK: - focus
	// MARK: -

	func revealBookmark(of target: Zone) {

		// locate and make bookmark of target visible and mark it

		if  let b = bookmarkTargeting(target, orSpawnsIt: false) {
			makeVisibleAndMarkInSmallMap(b)
		}
	}

	@discardableResult func makeVisibleAndMarkInSmallMap(_  iZone: Zone? = nil) -> Bool {
		if  let zone     = iZone,
			let parent   = zone.parentZone,
			currentHere != parent {
			currentHere.collapse()

			currentHere = parent

			currentHere.expand()

			return true
		}

		return false
	}

	var currentTargets: ZoneArray {
		var  targets = ZoneArray()

		if  gIsEssayMode,
			let zone = gCurrentEssayZone {
			targets.append(zone)
		} else if let here = gHereMaybe {
			targets.append(here)

			if  let grab = gSelecting.firstGrab,
				!targets.contains(grab) {
				targets.append(grab)
			}
		}

		return targets
	}

	var computedCurrrentBookmark: Zone? {
		if  let bookmarks = rootZone?.allBookmarkProgeny, bookmarks.count > 0 {
			let targets   = currentTargets

			if  let bookmark = bookmarks.whoseTargetIntersects(with: targets, orSpawnsIt: false) {
				return bookmark
			}
		}

		return nil
	}


	@discardableResult func updateCurrentFavorite() -> Zone? {
		if  let bookmark = computedCurrrentBookmark {
			currentFavorite = bookmark

			return currentFavorite
		}

		return nil
	}

	func grab(_ zone: Zone) {
		zone.grab()

		if  let p = zone.parentZone {
			if  let h = hereZoneMaybe, h != p {
				hereZoneMaybe = p

				h.collapse()
			}

			p.expand()
		}
	}

	@discardableResult func swapBetweenBookmarkAndTarget(doNotGrab: Bool = true) -> Bool {
		if  let cb = currentFavorite,
			cb.isGrabbed {
			cb.bookmarkTarget?.grab() // grab target in big map
		} else if doNotGrab {
			return false
		} else if let bookmark = computedCurrrentBookmark {
			grab(bookmark)
		} else {
			let bookmarks = gHere.bookmarksTargetingSelf

			for bookmark in bookmarks {
				if  bookmark.isInFavorites {
					if  bookmark.root == rootZone {
						grab(bookmark)
					} else {
						bookmark.grab()
					}

					gShowDetailsView = true

					gDetailsController?.showViewFor(.vFavorites)
					gSignal([.spMain, .sDetails, .spRelayout])

					return true
				}
			}

			push()
		}

		return true
	}

}
