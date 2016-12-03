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


    var    hereZone:  Zone!
    var storageZone:  Zone!
    let         key: String = "current storage mode"


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
            storageZone = bookmarksManager.storageZone
        default:
            storageZone = Zone(record: nil, storageMode: storageMode)
        }

        hereZone        = storageZone
    }


    func travel(_ block: (() -> Swift.Void)?) {
        widgetsManager    .clear()
        selectionManager  .clear()
        setup                   ()
        operationsManager.travel(block)
    }


    // MARK:- storage and cloud zones
    // MARK:-


    func indexOfMode(_ mode: ZStorageMode) -> Int { // KLUDGE, perhaps use ordered set or dictionary
        switch mode {
        case .mine:     return  1
        case .everyone: return  0
        default:        return -1
        }
    }


    func travelWhereThisZonePoints(_ zone: Zone, atArrival: @escaping SignalClosure) {
        var there: Zone? = nil

        if zone.isBookmark {
            if let link = zone.crossLink, let mode = link.storageMode {
                if storageMode == mode {
                    there = cloudManager.zoneForRecordID(link.record.recordID) ?? hereZone

                    atArrival(there, .data)
                } else {
                    storageMode = mode // going in arrow to right

                    travel {
                        there = link.record == nil ? self.hereZone : cloudManager.zoneForRecordID(link.record.recordID) ?? self.hereZone

                        atArrival(there, .data)
                    }
                }
            }
        } else if zone.parentZone == nil {
            storageMode = .bookmarks // going out arrow to left

            let index = indexOfMode(storageMode) // index is a KLUDGE

            travel {
                there = self.hereZone

                if index >= 0 && index < (there?.children.count)! {
                    there = there?.children[index]
                }

                atArrival(there, .data)
            }
        }
    }
}
