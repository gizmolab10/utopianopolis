//
//  ZBookmarks.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/10/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//


import Foundation


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


    func registerBookmark(_  iBookmark : Zone?) {
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
                    let recordNameOfParentOfBookmark  = parentOfBookmark.recordName
                    if  recordNameOfParentOfBookmark != kLostAndFoundName {
                        for     existing in registered! {
                            if  existing.parentZone?.recordName == recordNameOfParentOfBookmark {
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


    func unregisterBookmark(_ iBookmark: Zone?) {
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


    func bookmarks(for iZone: Zone) -> ZoneArray? {
        if  let dbID = iZone.databaseID,
            let name = iZone.recordName,
            let dict = registry[dbID] {
            return dict[name]
        }

        return nil
    }


    func storageArray(for iDatabaseID: ZDatabaseID, includeInvisibles: Bool = true, includeAncestors: Bool = false) throws -> [ZStorageDictionary]? {
        return try Zone.createStorageArray(for: allBookmarks, from: iDatabaseID, includeInvisibles: includeInvisibles) { zRecord -> Bool in
            if  let    bookmark = zRecord as? Zone,
                let        root = bookmark.root {
                return root.databaseID != iDatabaseID && !root.isRootOfFavorites // only store cross-linked, non-favorite bookarks
            }

            return false
        }
    }

}
