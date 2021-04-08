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

	// MARK:- create
	// MARK:-

	// designated bookmark creator

	@discardableResult func createZone(withBookmark: Zone?, _ iName: String?, recordName: String? = nil) -> Zone {
		var bookmark           = withBookmark
		if  bookmark          == nil {
			bookmark           = Zone.create(databaseID: .mineID, named: iName, recordName: recordName)
		} else if let     name = iName {
			bookmark?.zoneName = name
		}

		persistForLookupByTarget(bookmark!)
		bookmark?.updateCKRecordProperties()

		return bookmark!
	}

	func createBookmark(targetting target: Zone) -> Zone {
		let bookmark: Zone = createZone(withBookmark: nil, target.zoneName)
		bookmark.crossLink =  target
		if  let     parent =  target.parentZone {
			let   insertAt = (target.siblingIndex ?? 0) + (gListsGrowDown ? 1 : 0)

			parent.addChild(bookmark, at: insertAt) // calls update progeny count
		}

		return bookmark
	}

	@discardableResult func create(withBookmark: Zone?, _ action: ZBookmarkAction, parent: Zone, atIndex: Int, _ name: String?, recordName: String? = nil) -> Zone {
		let bookmark: Zone = createZone(withBookmark: withBookmark, name, recordName: recordName)
		let insertAt: Int? = atIndex == parent.count ? nil : atIndex

		if  action != .aNotABookmark {
			parent.addChild(bookmark, at: insertAt) // calls update progeny count
		}

		return bookmark
	}

	// MARK:- forget
	// MARK:-

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

	// MARK:- persist
	// MARK:-

	func persistForLookupByTarget(_  iBookmark : Zone?) {
		if  let       bookmark = iBookmark,
			let linkRecordName = bookmark.linkRecordName,
			let linkDatabaseID = bookmark.linkDatabaseID {
			var   byRecordName = reverseLookup[linkDatabaseID] // returns nil for first registration
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
			reverseLookup[linkDatabaseID] = byRecordName
		}
	}

    func storageArray(for iDatabaseID: ZDatabaseID, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> [ZStorageDictionary]? {
        return try (allBookmarks as ZRecordsArray).createStorageArray(from: iDatabaseID, includeInvisibles: includeInvisibles) { zRecord -> Bool in
			var  okayToStore = false

			if  let bookmark = zRecord as? Zone,
                let     root = bookmark.root,
				iDatabaseID != root.databaseID,
				root.isMapRoot {       // only store cross-linked, main map bookarks
                okayToStore  = true
            }

            return okayToStore
        }
    }

}
