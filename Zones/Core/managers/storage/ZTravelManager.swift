//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZTravelManager: NSObject {


    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var hereZone: Zone? { get { return manifest.hereZone } set { manifest.hereZone = newValue } }
    var rootZone: Zone!


    var manifest: ZManifest {
        get {
            return manifestForMode(gStorageMode)
        }
    }


    func manifestForMode(_ mode: ZStorageMode) -> ZManifest {
        var found = manifestByStorageMode[mode]

        if found == nil {
            found                       = ZManifest(record: nil, storageMode: .mine)
            manifestByStorageMode[mode] = found
        }

        return found!
    }


    func establishRoot() {
        switch gStorageMode {
        case .favorites: rootZone = favoritesManager.favoritesRootZone
        default:        rootZone = Zone(record: nil, storageMode: gStorageMode)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, onCompletion: Closure?) {
        if storageMode == .favorites {
            hereZone = favoritesManager.favoritesRootZone
        } else if hereZone != nil && hereZone?.record != nil && hereZone?.zoneName != nil {
            hereZone?.needChildren()
            hereZone?.needFetch()
        } else {
            cloudManager.establishHere((storageMode, onCompletion: onCompletion))

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


    func travel(_ atArrival: @escaping Closure) {
        establishRoot          ()
        widgetsManager   .clear()
        selectionManager .clear()
        operationsManager.travel(atArrival)
    }


    func travelToFavorites(_ atArrival: @escaping SignalClosure) {

        //////////////////////////////
        // going out to favorites graph
        //////////////////////////////

        let index = indexOfMode(gStorageMode) // index is a KLUDGE

        gStorageMode = .favorites

        travel {
            var there = favoritesManager.favoritesRootZone

            if index >= 0 && index < there.children.count {
                there = there[index]!
            }

            atArrival(there, .redraw)
        }
    }


    func changeFocusThroughZone(_ zone: Zone, atArrival: @escaping SignalClosure) {
        var there: Zone? = nil

        if zone.isRoot {
            travelToFavorites(atArrival)
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
