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


    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var              rootZone: Zone!
    var              hereZone: Zone? { get { return manifest.hereZone } set { manifest.hereZone = newValue } }


    var manifest: ZManifest {
        get {
            var found = manifestByStorageMode[gStorageMode]

            if found == nil {
                found                               = ZManifest(record: nil, storageMode: .mine)
                manifestByStorageMode[gStorageMode] = found
            }

            return found!
        }
    }


    func setup() {
        switch gStorageMode {
        case .bookmarks: rootZone = bookmarksManager.rootZone
        default:         rootZone = Zone(record: nil, storageMode: gStorageMode)
        }
    }


    func establishHere(_ onCompletion: Closure?) {
        if gStorageMode == .bookmarks {
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


    // MARK:- travel
    // MARK:-


    func cycleStorageMode(_ atArrival: @escaping Closure) {
        var mode = gStorageMode

        switch mode {
        case .everyone: mode = .mine;     break
        case .mine:     mode = .everyone; break
        default: return
        }

        gStorageMode = mode

        travel(atArrival)
    }


    private func travel(_ atArrival: @escaping Closure) {
        setup                   ()
        widgetsManager    .clear()
        selectionManager  .clear()
        bookmarksManager  .clear()
        operationsManager.travel(atArrival)
    }


    func changeFocusThroughZone(_ zone: Zone, atArrival: @escaping SignalClosure) {
        var there: Zone? = nil

        if zone.isRoot {

            ///////////////////////////////
            // going out to bookmarks graph
            ///////////////////////////////

            let index = indexOfMode(gStorageMode) // index is a KLUDGE

            gStorageMode = .bookmarks

            travel {
                there = bookmarksManager.rootZone

                if index >= 0 && index < (there?.children.count)! {
                    there = there?[index]
                }

                atArrival(there, .redraw)
            }
        } else if zone.isBookmark, let crossLink = zone.crossLink, let mode = crossLink.storageMode {

            ////////////////////////
            // going into a bookmark
            ////////////////////////

            let recordIDOfLink = crossLink.record.recordID
            let pointsAtHere   = crossLink.isRoot

            if  gStorageMode != mode {
                gStorageMode  = mode

                //////////////////////////////
                // travel to a different graph
                //////////////////////////////

                if pointsAtHere {
                    travel {
                        atArrival(self.hereZone, .redraw)
                    }
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: mode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) in
                        if iRecord != nil {
                            self.hereZone = cloudManager.zoneForRecord(iRecord!)

                            self.manifest.needSave()
                            self.travel {
                                atArrival(self.hereZone, .redraw)
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
                    selectionManager.grab(there)
                    atArrival(there, .redraw)
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: gStorageMode, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) in
                        self.hereZone = cloudManager.zoneForRecord(iRecord!)

                        self.hereZone?.needChildren()
                        self.manifest.needSave()
                        selectionManager.grab(there)
                        atArrival(self.hereZone, .redraw)
                    })
                }
            }
        }
    }
}
