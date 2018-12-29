//
//  ZBookmarksManager.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/10/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//


import Foundation


let gBookmarks = ZBookmarks()


class ZBookmarks: NSObject {


    var registry = [ZDatabaseID : [String : [Zone]]] ()


    var allBookmarks: [Zone] {
        var bookmarks = [Zone] ()

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
                let markAsLost = {
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
                                markAsLost()  // found matching existing parent's record name to bookmark's parent's record name

                                return
                            }
                        }
                    }
                } else if !gFiles.isReading(for: linkDatabaseID) {
                    markAsLost() // bookmark has no parent

                    return
                }

                registered?.append(bookmark)
            }

            byRecordName?[linkRecordName] = registered
            registry     [linkDatabaseID] = byRecordName
        }
    }


    func unregisterBookmark(_ iBookmark: Zone?) {
        if  let   bookmark = iBookmark,
            let       dbID = bookmark.linkDatabaseID,
            let       link = bookmark.linkRecordName,
            var       dict = registry[dbID],
            var      zones = dict[link],
            let      index = zones.index(of: bookmark) {
            zones.remove(at: index)

            dict[link]     = zones
            registry[dbID] = dict
        }
    }


    func bookmarks(for iZone: Zone) -> [Zone]? {
        if  let dbID = iZone.databaseID,
            let name = iZone.recordName,
            let dict = registry[dbID] {
            return dict[name]
        }

        return nil
    }


    func storageArray(for iDatabaseID: ZDatabaseID) -> [ZStorageDictionary]? {
        return Zone.storageArray(for: allBookmarks, from: iDatabaseID) { zRecord -> Bool in
            if  let    bookmark = zRecord as? Zone,
                let        root = bookmark.root {
                return root.databaseID != iDatabaseID && !root.isRootOfFavorites // only store cross-linked, non-favorite bookarks
            }

            return false
        }
    }

}