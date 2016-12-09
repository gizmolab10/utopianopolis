//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZStorageMode: String {     ///// move this to cloud manager  //////////
    case bookmarks = "bookmarks"
    case everyone  = "everyone"
    case group     = "group"
    case mine      = "mine"
}


class ZTravelManager: NSObject {


    var rootZone:     Zone!
    var manifest: ZManifest = ZManifest()
    let      key:    String = "current storage mode"


    var hereZone: Zone? { get { return manifest.hereZone } set { manifest.hereZone = newValue } }


    var storageMode: ZStorageMode {
        set { UserDefaults.standard.set(newValue.rawValue, forKey:key) }
        get {
            var mode: ZStorageMode? = nil

            if let           object = UserDefaults.standard.object(forKey:key) {
                mode                = ZStorageMode(rawValue: object as! String)
            }

            if mode == nil {
                mode                = .everyone
                self.storageMode    = mode!     // wow! this works
            }

            return mode!
        }
    }


    func setup() {
        switch storageMode {
        case .bookmarks:
            rootZone = bookmarksManager.rootZone
        default:
            rootZone = Zone(record: nil, storageMode: storageMode)
        }
    }


    // MARK:- kludge for selecting within bookmark view
    // MARK:-


    func indexOfMode(_ mode: ZStorageMode) -> Int { // KLUDGE, perhaps use ordered set or dictionary
        switch mode {
        case .mine:     return  1
        case .everyone: return  0
        default:        return -1
        }
    }


    private func travel(_ atArrival: (() -> Swift.Void)?) {
        setup                   ()
        cloudManager      .clear()
        widgetsManager    .clear()
        selectionManager  .clear()
        bookmarksManager  .clear()
        operationsManager.travel(atArrival)
    }


    func travelWhereThisZonePoints(_ zone: Zone, atArrival: @escaping SignalClosure) {
        var there: Zone? = nil
        let  arriveThere = { atArrival(there, .data) }

        if zone.isRoot {
            let index = indexOfMode(storageMode) // index is a KLUDGE

            storageMode = .bookmarks // going out (left arrow)

            travel {

                // arrive in bookmarks graph

                there = self.hereZone

                // there is WRONG second time through:
                // its storage mode is correct
                // its record and record id are both wrong
                // its children are wrong
                // likely culprit is establishHere

                if index >= 0 && index < (there?.children.count)! {
                    there = there?.children[index]
                }
                
                arriveThere()
            }
        } else if zone.isBookmark, let link = zone.crossLink, let mode = link.storageMode {
            if storageMode == mode {

                // stay within graph

                there = cloudManager.zoneForRecordID(link.record.recordID)

                arriveThere()
            } else {
                storageMode = mode // going in (right arrow)

                travel {

                    // arrive in a different graph

                    there = link.record == nil ? self.hereZone : cloudManager.zoneForRecordID(link.record.recordID) ?? self.hereZone

                    arriveThere()
                }
            }
        }
    }
}
