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

    var registry = [ZDatabaseID : [String : ZoneArray]] ()

    var allBookmarks: ZoneArray {
        var bookmarks = ZoneArray ()

        for dict in registry.values {
            for zones in dict.values {
                bookmarks += zones
            }
        }

        return bookmarks
    }

	func bookmarks(for iZone: Zone) -> ZoneArray? {
		if  let dbID = iZone.databaseID,
			let name = iZone.ckRecordName,
			let dict = registry[dbID] {
			return dict[name]    // returned value is an array
		}

		return nil
	}

	// MARK:- create
	// MARK:-

	@discardableResult func createZone(withBookmark: Zone?, _ iName: String?, recordName: String? = nil) -> Zone {
		var bookmark           = withBookmark
		if  bookmark          == nil {
			bookmark           = Zone(databaseID: .mineID, named: iName, recordName: recordName)
		} else if let     name = iName {
			bookmark?.zoneName = name
		}

		return bookmark!
	}

	@discardableResult func create(withBookmark: Zone?, _ action: ZBookmarkAction, parent: Zone, atIndex: Int, _ name: String?, recordName: String? = nil) -> Zone {
		let bookmark: Zone = createZone(withBookmark: withBookmark, name, recordName: recordName)
		let insertAt: Int? = atIndex == parent.count ? nil : atIndex

		if  action != .aNotABookmark {
			parent.addChild(bookmark, at: insertAt) // calls update progeny count
		}

		bookmark.updateCKRecordProperties() // is this needed?

		return bookmark
	}

	// MARK:- forget
	// MARK:-

    func forget(_ iBookmark: Zone?) {
        if  let       bookmark = iBookmark,
            let linkDatabaseID = bookmark.linkDatabaseID,
            let linkRecordName = bookmark.linkRecordName,
            var           dict = registry[linkDatabaseID],
            var          zones = dict[linkRecordName],
            let          index = zones.firstIndex(of: bookmark) {
            zones.remove(at: index)

            dict[linkRecordName]     = zones
            registry[linkDatabaseID] = dict
        }
    }

	// MARK:- persist
	// MARK:-

	func persistForLookupByTarget(_  iBookmark : Zone?) {
		if  let       bookmark = iBookmark,
			let linkRecordName = bookmark.linkRecordName,
			let linkDatabaseID = bookmark.linkDatabaseID {
			var   byRecordName = registry[linkDatabaseID] // returns nil for first registration
			var     registered = byRecordName?[linkRecordName]

			if  byRecordName  == nil {
				byRecordName   = [:]
				registered     = [bookmark]
			} else {
				let markBookmarkAsLost = {
					bookmark.temporarilyMarkNeeds {
						bookmark.needFound()
					}
				}

				if  registered == nil {
					registered  = []
				} else if let       parentOfBookmark  = bookmark.parentZone {
					let recordNameOfParentOfBookmark  = parentOfBookmark.ckRecordName
					if  recordNameOfParentOfBookmark != kLostAndFoundName {
						for     existing in registered! {
							if  existing.parentZone?.ckRecordName == recordNameOfParentOfBookmark {
								markBookmarkAsLost()    // bookmark is sibling to its target

								return
							}
						}
					}
				} else if !gFiles.isReading(for: bookmark.databaseID) {
					markBookmarkAsLost()                // bookmark has no parent

					return
				}

				registered?.append(bookmark)
			}

			byRecordName?[linkRecordName] = registered
			registry     [linkDatabaseID] = byRecordName
		}
	}

    func storageArray(for iDatabaseID: ZDatabaseID, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> [ZStorageDictionary]? {
        return try (allBookmarks as ZRecordsArray).createStorageArray(from: iDatabaseID, includeInvisibles: includeInvisibles) { zRecord -> Bool in
			var  okayToStore = false

			if  let bookmark = zRecord as? Zone,
                let     root = bookmark.root,
				iDatabaseID != root.databaseID,
				root.isBigMapRoot {       // only store cross-linked, main map bookarks
                okayToStore  = true
            }

            return okayToStore
        }
    }

}
