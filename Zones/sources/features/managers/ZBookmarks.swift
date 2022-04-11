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

// MARK: - designated bookmark creator
// MARK: -

@discardableResult func gNewOrExistingBookmark(targeting target: Zone, addTo parent: Zone?) -> Zone {
	if  let    match = parent?.children.intersection(target.bookmarksTargetingSelf), match.count > 0 {
		return match[0]  // s bookmark for the target already exists, do nothing
	}

	if  target.isBookmark, target.parentZone == parent, parent != nil {
		return target    // it already exists, do nothing
	}

	var bookmark: Zone

	if  target.isBookmark {
		bookmark = target.deepCopy(dbID: .mineID)                               // zone  is a bookmark, pass a deep copy
	} else {
		bookmark = Zone.uniqueZoneNamed(target.zoneName, databaseID: .mineID) // zone not a bookmark, bookmark it
		bookmark.crossLink = target
	}

	if  let p = parent {
		p.addChildNoDuplicate(bookmark, at: target.siblingIndex)
	}

	gBookmarks.addToReverseLookup(bookmark)

	return bookmark
}

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

	func addToReverseLookup(_  iBookmark : Zone?) {
		if  let       bookmark = iBookmark,
			let linkRecordName =  bookmark.linkRecordName,
			let linkDatabaseID =  bookmark.linkDatabaseID {
			var   byRecordName = reverseLookup[linkDatabaseID] // returns nil for first registration
			var     registered = byRecordName?[linkRecordName]

			if  byRecordName  == nil {
				byRecordName   = [:]
				registered     = [bookmark]
			} else {
				if  registered == nil {
					registered  = []
				} else if bookmark.parentZone == nil,
						  !gFiles.isReading(for: bookmark.databaseID) {
					return
				}

				registered?.append(bookmark)
			}

			byRecordName?[linkRecordName] = registered
			reverseLookup[linkDatabaseID] = byRecordName
		}
	}

    func storageArray(for iDatabaseID: ZDatabaseID, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> [ZStorageDictionary]? {
        return try (allBookmarks as ZRecordsArray).createStorageArray(from: iDatabaseID, includeInvisibles: includeInvisibles) { zRecord -> Bool in
			var  okayToStore = false

			if  let bookmark = zRecord as? Zone,
				let     root = bookmark.root, root.isBigMapRoot,
				iDatabaseID != root.databaseID {       // only store inter-db, big-map bookmarks
                okayToStore  = true
            }

            return okayToStore
        }
    }

}