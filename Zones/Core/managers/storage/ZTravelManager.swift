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


    let                   key = "current storage mode"
    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var              rootZone: Zone!
    var              hereZone: Zone? { get { return manifest.hereZone } set { manifest.hereZone = newValue } }


    var manifest: ZManifest {
        get {
            var found = manifestByStorageMode[storageMode]

            if found == nil {
                found                              = ZManifest(record: nil, storageMode: .mine)
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
        case .bookmarks: rootZone = bookmarksManager.rootZone
        default:         rootZone = Zone(record: nil, storageMode: storageMode)
        }
    }


    func establishHere(_ onCompletion: Closure?) {
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
        case .everyone: return  1
        case .mine:     return  0
        default:        return -1
        }
    }


    private func travel(_ atArrival: @escaping Closure) {
        setup                   ()
        widgetsManager    .clear()
        selectionManager  .clear()
        bookmarksManager  .clear()
        operationsManager.travel(atArrival)
    }


    func travelToWhereThisZonePoints(_ zone: Zone, atArrival: @escaping SignalClosure) {
        var there: Zone? = nil

        if zone.isRoot {

            ///////////////////////////////
            // going out to bookmarks graph
            ///////////////////////////////

            let index = indexOfMode(storageMode) // index is a KLUDGE

            storageMode = .bookmarks

            travel {
                there = bookmarksManager.rootZone

                if index >= 0 && index < (there?.children.count)! {
                    there = there?[index]
                }

                atArrival(there, .data)
            }
        } else if zone.isBookmark, let crossLink = zone.crossLink, let mode = crossLink.storageMode {

            ////////////////////////
            // going into a bookmark
            ////////////////////////

            let recordIDOfLink = crossLink.record.recordID
            let pointsAtHere   = recordIDOfLink.recordName == rootNameKey

            if  storageMode != mode {
                storageMode  = mode

                //////////////////////////////
                // travel to a different graph
                //////////////////////////////

                if pointsAtHere {
                    travel {
                        atArrival(self.hereZone, .data)
                    }
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: mode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) in
                        if iRecord != nil {
                            self.hereZone = cloudManager.zoneForRecord(iRecord!)

                            self.manifest.needSave()
                            self.travel {
                                atArrival(self.hereZone, .data)
                            }
                        }
                    })
                }
            } else {

                ////////////////////
                // stay within graph
                ////////////////////

                there = cloudManager.zoneForRecordID(recordIDOfLink)

                if there != nil {
                    self.hereZone = there

                    there?.needChildren()

                    atArrival(there, .data)
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: storageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) in
                        self.hereZone = cloudManager.zoneForRecord(iRecord!)

                        self.manifest.needSave()
                        atArrival(self.hereZone, .data)
                    })
                }
            }
        }
    }
}
