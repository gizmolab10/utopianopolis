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
        if  let   bookmark = iBookmark,
            let       dbID = bookmark.linkDatabaseID,
            let       link = bookmark.linkName {
            var       dict = registry[dbID] // returns nil for first registration
            var      zones = dict?[link]

            if  dict      == nil {
                dict       = [:]
                zones      = [bookmark]
            } else {
                let markNeedFound = {
                    bookmark.temporarilyMarkNeeds {
                        bookmark.needFound()
                    }
                }

                if  zones == nil {
                    zones  = []
                } else if let      parent = bookmark.parentZone {
                    if parent.recordName != kLostAndFoundName {
                        for     zone in zones! {
                            if  zone.parentZone?.recordName == parent.recordName {
                                markNeedFound()

                                return
                            }
                        }
                    }
                } else if !gFiles.isReading(for: bookmark.databaseID) {
                    markNeedFound()

                    return
                }

                zones?.append(bookmark)
            }

            dict?[link]    = zones
            registry[dbID] = dict

//            columnarReport("BOOKMARK", bookmark.unwrappedName)
        }
    }


    func unregisterBookmark(_ iBookmark: Zone?) {
        if  let   bookmark = iBookmark,
            let       dbID = bookmark.linkDatabaseID,
            let       link = bookmark.linkName,
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
