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


    var              rootZone:                      Zone!
    var manifestByStorageMode: [ZStorageMode : ZManifest] = [:]
    let                   key:                     String = "current storage mode"
    var              hereZone:     Zone? { get { return manifest.hereZone } set { manifest.hereZone = newValue } }


    var manifest: ZManifest {
        get {
            var found = manifestByStorageMode[storageMode]

            if found == nil {
                found                              = ZManifest(record: nil, storageMode: storageMode)
                manifestByStorageMode[storageMode] = found
            }

            return found!
        }
    }


    var storageMode: ZStorageMode {
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey:key)
        }

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


    func establishHere(_ onCompletion: (() -> Swift.Void)?) {
        if storageMode == .bookmarks {
            hereZone = bookmarksManager.rootZone
        } else if hereZone != nil && hereZone?.record != nil {
            hereZone?.needChildren()
            hereZone?.needFetch()
        } else {
            cloudManager.establishHere(onCompletion)

            return
        }

        onCompletion?()
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

                there = bookmarksManager.rootZone

                if index >= 0 && index < (there?.children.count)! {
                    there = there?.children[index]
                }
                
                arriveThere()
            }
        } else if zone.isBookmark, let link = zone.crossLink, let mode = link.storageMode {
            if  storageMode      != mode {
                storageMode       = mode // going in (right arrow)
                manifest.hereLink = link

                travel {

                    // arrive in a different graph

                    there = self.hereZone

                    arriveThere()
                }
            } else {
                // stay within graph

                let recordID = link.record.recordID
                there        = cloudManager.zoneForRecordID(recordID)

                if there != nil {
                    arriveThere()
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordID, storageMode: storageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) -> (Void) in
                        there = Zone(record: iRecord, storageMode: self.storageMode)

                        there?.needChildren()
                        arriveThere()
                    })
                }
            }
        }
    }
}
