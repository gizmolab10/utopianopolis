//
//  ZBookmarks.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/10/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation

// ////////////////////////////////
// gather bookmarks for:         //
// • storing on filesystem       //
// • lookup by their zone target //
// ////////////////////////////////

let gBookmarks = ZBookmarks()

class ZBookmarks: NSObject {

	var reverseLookup = [ZDatabaseID : [String : ZoneArray]] ()

	var allBookmarks: ZoneArray {
		var bookmarks = ZoneArray ()

		for dict in reverseLookup.values {
			for zones in dict.values {
				bookmarks += zones
			}
		}

		return bookmarks
	}

	// MARK: - designated bookmark creator
	// MARK: -

	@discardableResult static func newBookmark(targeting target: Zone) -> Zone {
		var bookmark: Zone

		if  target.isBookmark {
			bookmark = target.deepCopy(into: .mineID)                                                 // zone  is a bookmark, pass a deep copy
		} else {
			bookmark = Zone.uniqueZoneNamed(target.zoneName, databaseID: .mineID, checkCDStore: true) // zone not a bookmark, bookmark it
			bookmark.crossLink = target
		}

		gBookmarks.addToReverseLookup(bookmark)
		gRelationships.addBookmarkRelationship(bookmark, target: target, in: .mineID)

		return bookmark
	}

	@discardableResult static func newOrExistingBookmark(targeting target: Zone, addTo parent: Zone?) -> Zone {
		if  let    match = parent?.children.intersection(target.bookmarksTargetingSelf), match.count > 0 {
			return match[0]  // bookmark for the target already exists, do nothing
		}

		if  target.isBookmark, target.parentZone == parent, parent != nil {
			return target    // it already exists, do nothing
		}

		let bookmark = newBookmark(targeting: target)

		parent?.addChildNoDuplicate(bookmark, at: target.siblingIndex)

		return bookmark
	}

	// MARK: - forget
	// MARK: -

    func forget(_ iBookmark: Zone?) {
        if  let       bookmark = iBookmark,
            let linkDatabaseID = bookmark.linkDatabaseID,
            let linkRecordName = bookmark.linkRecordName,
            var           dict = reverseLookup[linkDatabaseID],
            var          zones = dict[linkRecordName],
            let          index = zones.firstIndex(of: bookmark) {
            zones.remove(at: index)

            dict         [linkRecordName] = zones
            reverseLookup[linkDatabaseID] = dict
        }
    }

	// MARK: - persist
	// MARK: -

	@discardableResult func addToReverseLookup(_  iBookmark : Zone?) -> Bool {
		if  let       bookmark = iBookmark,
			let linkRecordName =  bookmark.linkRecordName,
			let linkDatabaseID =  bookmark.linkDatabaseID {
			var   byRecordName = reverseLookup[linkDatabaseID] // returns nil for first registration
			var     registered = byRecordName?[linkRecordName]

			if  byRecordName  == nil {
				byRecordName   = [String : ZoneArray]()
				registered     = [bookmark]
			} else {
				if  registered == nil {
					registered  = ZoneArray()
				}

				registered?.append(bookmark)
			}

			byRecordName?[linkRecordName] = registered
			reverseLookup[linkDatabaseID] = byRecordName

			return true
		}

		return false
	}

    func storageArray(for iDatabaseID: ZDatabaseID, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> [ZStorageDictionary]? {
        return try (allBookmarks as ZRecordsArray).createStorageArray(from: iDatabaseID, includeInvisibles: includeInvisibles) { zRecord -> Bool in
			var  okayToStore = false

			if  let bookmark = zRecord?.maybeZone,
				let     root = bookmark.root, root.isMainMapRoot,
				iDatabaseID != root.databaseID {       // only store inter-db, main map bookmarks
                okayToStore  = true
            }

            return okayToStore
        }
    }

}
