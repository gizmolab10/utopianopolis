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
    var     rootByStorageMode = [ZStorageMode : Zone] ()
    var       hereZone: Zone? { get { return manifest.hereZone } set { manifest.hereZone = newValue } }
    var       rootZone: Zone? {
        get {
            switch gStorageMode {
            case .favorites: return favoritesManager.favoritesRootZone
            default:         return rootByStorageMode[gStorageMode]
            }
        }

        set {
            switch gStorageMode {
            case .favorites: break
            default:         rootByStorageMode[gStorageMode] = newValue; break
            }
        }
    }


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
        default:         rootZone = Zone(record: nil, storageMode: gStorageMode)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if storageMode == .favorites {
            hereZone = favoritesManager.favoritesRootZone
        } else if hereZone != nil && hereZone?.record != nil && hereZone?.zoneName != nil {
            hereZone?.needChildren()
            hereZone?.needFetch()
        } else {
            cloudManager.establishHere((storageMode, onCompletion))

            return
        }

        onCompletion?(0)
    }


    // MARK:- travel
    // MARK:-


    func isZone(_ zone: Zone, ancestorOf bookmark: Zone) -> Bool {
        var    targetID = bookmark.crossLink?.record.recordID
        let  identifier = zone.record.recordID.recordName

        while  targetID != nil {
            if targetID!.recordName == identifier {
                return true
            }

            let    zone = cloudManager.zoneForRecordID(targetID)
            targetID    = zone?.parent?.recordID
        }

        return false
    }


    func travel(_ atArrival: @escaping Closure) {
        widgetsManager   .clear()
        selectionManager .clear()
        operationsManager.travel(atArrival)
    }


    func travelThrough(_ bookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = bookmark.crossLink, let mode = crossLink.storageMode, let record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if  gStorageMode != mode {
                gStorageMode  = mode

                //////////////////////////////
                // travel to a different graph
                //////////////////////////////

                if crossLink.isRoot { // e.g., default root favorite
                    travel {
                        atArrival(self.hereZone, .redraw)
                    }
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: mode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        if iRecord != nil {
                            self.hereZone = cloudManager.zoneForRecord(iRecord!)

                            self.hereZone?.grab()
                            self.manifest.needSave()
                            self.travel {
                                atArrival(self.hereZone, .redraw)
                            }
                        }
                    }
                }
            } else {

                ////////////////////
                // stay within graph
                ////////////////////

                there = cloudManager.zoneForRecordID(recordIDOfLink)

                if there != nil {
                    self.hereZone = there

                    there?.needChildren()
                    there?.grab()
                    atArrival(there, .redraw)
                } else {
                    cloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: gStorageMode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        self.hereZone = cloudManager.zoneForRecord(iRecord!)

                        there?.grab()
                        self.manifest.needSave()
                        self.hereZone?.needChildren()
                        atArrival(self.hereZone, .redraw)
                    }
                }
            }
        }
    }
}
