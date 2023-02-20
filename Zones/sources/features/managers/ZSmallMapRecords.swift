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

	func isCurrent(_ zone: Zone) -> Bool {
		return [currentRecent, currentFavorite].contains(zone)
	}

	func current(mustBeRecents: Bool = false) -> Zone? {
		let useRecents = mustBeRecents || currentHere.isInRecentsGroup

		return useRecents ? currentRecent : currentFavorite
	}

	func setCurrent(_ zone: Zone?, mustBeRecents: Bool = false) {
		let useRecents = mustBeRecents || currentHere.isInRecentsGroup || (zone?.isInRecentsGroup ?? false)

		if  useRecents {
			currentRecent   = zone
		} else {
			currentFavorite = zone
		}
	}

	func nextBookmark(down: Bool, amongNotes: Bool = false, moveCurrent: Bool = false, withinRecents: Bool = false) {
		var current  = current(mustBeRecents: withinRecents)
		if  current == nil {
			current  = gFavorites.push()
		}

		let         recents = gFavorites.recentsGroupZone.children
		let        notNotes = withinRecents ? recents.count > 0 ? recents : working : working
		let           zones = amongNotes ? workingNotemarks : notNotes
		let           count = zones.count
		if  count           > 1 {            // there is no next for count == 0 or 1
			let      adjust = moveCurrent ? 2 : 1
			let    maxIndex = count - adjust
			var     toIndex = down ? 0 : maxIndex
			if  let  target = current?.zoneLink {
				for (index, bookmark) in zones.enumerated() {
					var next         = index
					while target    == bookmark.zoneLink,
						let realNext = next.next(forward: !down, max: maxIndex) {

						if  !zones[realNext].isBookmark {
							next     = realNext
						} else {
							toIndex  = realNext

							break
						}
					}
				}

				if  toIndex.isWithin(0 ... maxIndex) {
					let newCurrent = zones[toIndex]

					if  moveCurrent {
						moveCurrentTo(newCurrent)
					} else {
						setAsCurrent (newCurrent, alterBigMapFocus: !amongNotes, makeVisible: false)
					}
				}
			}
		}
	}

	func moveCurrentTo(_ zone: Zone) {
		if  let parent = zone.parentZone,
			let      p = currentFavorite?.parentZone, p == parent,
			let   from = currentFavorite?.siblingIndex,
			let     to = zone.siblingIndex {
			parent.moveChildIndex(from: from, to: to)
		}
	}

	func setCurrentBookmarksTargeting(_ zone: Zone) {
		for bookmark in zone.bookmarksTargetingSelf {
			setCurrent(bookmark)
		}
	}

	func setAsCurrent(_ zone: Zone?, alterBigMapFocus: Bool = false, makeVisible: Bool = false) {
		if  makeVisible {
			makeVisibleAndMarkInSmallMap(zone)
		}

		if  let target = zone?.bookmarkTarget {
			setCurrentBookmarksTargeting(target)

			if  alterBigMapFocus {
				gDatabaseID          = target.databaseID
				gRecords.currentHere = target // avoid push

				target.grab()
			}

			if  gIsMapMode {
				gFocusing.focusOnGrab(.eSelected) {
					gSignal([.spCrumbs, .spRelayout, .spDataDetails])
				}
			} else if gCurrentEssayZone != target {
				gEssayView?.resetCurrentEssay(target.note)
				gSignal([.spCrumbs, .spRelayout, .spDataDetails])
			}
		}
	}

	func targeting(_ target: Zone, in array: ZoneArray?, orSpawnsIt: Bool = true) -> ZoneArray? {
		return array?.whoseTargetIntersects(with: [target], orSpawnsIt: orSpawnsIt)
	}

	func workingBookmarks(for target: Zone) -> ZoneArray? {
		return targeting(target, in: workingBookmarks, orSpawnsIt: false)
	}

	func favoritesTargeting(_ target: Zone, orSpawnsIt: Bool = false) -> ZoneArray? {
		return targeting(target, in: rootZone?.allBookmarkProgeny, orSpawnsIt: orSpawnsIt)
	}

	// MARK: - pop and push
	// MARK: -

	@discardableResult func push(_ zone: Zone? = gHere) -> Zone? { return nil }

	@discardableResult func pop(_ iZone: Zone? = gHereMaybe) -> Bool {
		if  let zone = iZone {
			if  zone.isInFavorites {
				zone.deleteSelf(permanently: true) {}

				return true
			} else if let bookmarks = workingBookmarks(for: zone) {
				for bookmark in bookmarks {
					bookmark.deleteSelf(permanently: true) {}
				}

				return true
			}
		}

		return false
	}

	func popAndUpdateCurrent() {
		if  let           c = currentRecent ?? currentFavorite,
			let       index = c.siblingIndex,
			let    children = c.siblings,
			let        next = children.next(from: index, forward: gListsGrowDown),
			pop(c) {
			setCurrent(next)

			if  let    here = next.bookmarkTarget {
				gHere       = here

				gHere.grab()
			}
		}

		gSignal([.sDetails])
		gRelayoutMaps()
	}

	func popNoteAndUpdate() -> Bool {
		if  pop(),
			let  notemark = rootZone?.notemarks.first,
			let      note = notemark.bookmarkTarget?.note {
			gCurrentEssay = note

			setAsCurrent(notemark, makeVisible: true)
			gSignal([.spSmallMap, .spCrumbs])

			return true
		}

		return false
	}

	func insertAsNext(_ zone: Zone) {
		if  let           r = rootZone {
			let      cIndex = r.children.firstIndex(of: zone) ?? 0
			let       index = cIndex.next(forward: gListsGrowDown, max: r.count - 1)

			r.addChildNoDuplicate(zone, at: index)
			setCurrent(zone)
		}
	}

	func removeBookmarks(for iZone: Zone? = gHereMaybe) {
		if  let      zone = iZone,
			let bookmarks = workingBookmarks(for: zone) {
			for bookmark in bookmarks {
				bookmark.deleteSelf(permanently: true) {}
			}
		}
	}

	// MARK: - focus
	// MARK: -

	func revealBookmark(of target: Zone) {

		// locate and make bookmark of target visible and mark it

		if  let bookmarks = favoritesTargeting(target, orSpawnsIt: false) {
			for bookmark in bookmarks {
				makeVisibleAndMarkInSmallMap(bookmark)
			}
		}
	}

	func makeVisibleAndMarkInSmallMap(_  iZone: Zone? = nil) {
		if  let zone         = iZone {
			if  let parent   = zone.parentZone,
				currentHere != parent {
				let here     = currentHere
				currentHere  = parent

				here.collapse()
			}

			currentHere.expand()
			setCurrent(zone)
		}
	}

	var currentTargets: ZoneArray {
		var  targets = ZoneArray()

		if  gIsEssayMode,
			let zone = gCurrentEssayZone {
			targets.append(zone)
		} else if let here = gHereMaybe {
			targets.append(here)

			if  let grab = gSelecting.firstGrab(),
				!targets.contains(grab) {
				targets.append(grab)
			}
		}

		return targets
	}

	var bookmarksTargetingHere: ZoneArray? {
		if  let bookmarks = rootZone?.allBookmarkProgeny, bookmarks.count > 0 {
			let matches   = bookmarks.whoseTargetIntersects(with: currentTargets, orSpawnsIt: false)
			if  matches.count > 0 {
				return matches
			}
		}

		return nil
	}

	func updateCurrentWithBookmarksTargetingHere() {
		if  let      bookmarks = bookmarksTargetingHere {
			let      inRecents = currentHere.isInRecentsGroup
			var markedRecent   = false
			var markedFavorite = false
			for bookmark in bookmarks {
				let toRecents  = bookmark.isInRecentsGroup
				if  toRecents {
					if !markedRecent {
						markedRecent   = true
						currentRecent  = bookmark
					}
				} else if !markedFavorite, !inRecents {
					currentFavorite    = bookmark

					if  bookmark.isInFavoritesHere {
						markedFavorite = true
					}
				}

				if  markedRecent, markedFavorite {
					return
				}
			}
		}
	}

	func grab(_ zones: ZoneArray) {
		gSelecting.ungrabAll()

		for zone in zones {
			grab(zone, onlyOne: false)
		}
	}

	func grab(_ zone: Zone, onlyOne: Bool = true) {
		if  onlyOne {
			zone.grab()
		} else {
			zone.addToGrabs()
		}

		if  let p = zone.parentZone {
			if  let h = hereZoneMaybe, h != p {
				hereZoneMaybe = p

				h.collapse()
			}

			p.expand()
		}
	}

	@discardableResult func swapBetweenBookmarkAndTarget(_ flags: ZEventFlags = ZEventFlags(), doNotGrab: Bool = true) -> Bool {
		if  let cb = currentFavorite,
			cb.isGrabbed {            // grabbed in small map, so ...
			cb.bookmarkTarget?.grab() // grab target in big map
		} else if doNotGrab {
			return false
		} else {
			let bookmarks = gHere.bookmarksTargetingSelf

			for bookmark in bookmarks {
				let isInHere = bookmark.isInFavoritesHere

				if !bookmark.isDeleted, flags.hasCommand ? bookmark.isInRecentsGroup : isInHere {
					gShowDetailsView = true

					if  !isInHere {
						makeVisibleAndMarkInSmallMap(bookmark)
					}

					bookmark.grab()
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
