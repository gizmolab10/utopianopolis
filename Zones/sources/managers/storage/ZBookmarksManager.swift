//
//  ZBookmarksManager.swift
//  Zones
//
//  Created by Jonathan Sand on 1/10/18.
//  Copyright © 2018 Zones. All rights reserved.
//


import Foundation


let gBookmarksManager = ZBookmarksManager()


class ZBookmarksManager: NSObject {


    var registry = [ZStorageMode : [String : [Zone]]] ()


    func registerBookmark(_  iBookmark : Zone?) {
        if  let   bookmark = iBookmark,
            let       mode = bookmark.linkMode,
            let       link = bookmark.linkName {
            var       dict = registry[mode]
            var      zones = dict?[link]

            if  dict      == nil {
                dict       = [:]
                zones      = [bookmark]
            } else {
                if  zones == nil {
                    zones  = []
                }

                zones?.append(bookmark)
            }

            dict?[link]    = zones
            registry[mode] = dict

            columnarReport("BOOKMARK", bookmark.unwrappedName)
        }
    }


    func unregisterBookmark(_ iBookmark: Zone?) {
        if  let   bookmark = iBookmark,
            let       mode = bookmark.linkMode,
            let       link = bookmark.linkName,
            var       dict = registry[mode],
            var      zones = dict[link],
            let      index = zones.index(of: bookmark) {
            zones.remove(at: index)

            dict[link]     = zones
            registry[mode] = dict
        }
    }


    func bookmarks(for iZone: Zone) -> [Zone]? {
        if  let mode = iZone.storageMode,
            let name = iZone.recordName,
            let dict = registry[mode] {
            return dict[name]
        }

        return nil
    }

}
