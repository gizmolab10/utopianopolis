//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZTravelManager: NSObject {


    var      storageModeStack = [ZStorageMode] ()
    var     rootByStorageMode = [ZStorageMode : Zone] ()
    var manifestByStorageMode = [ZStorageMode : ZManifest] ()
    var manifest: ZManifest { return manifestForMode(gStorageMode) }
    var rootZone: Zone {
        get {
            switch gStorageMode {
            case .favorites: return gFavoritesManager.favoritesRootZone
            default:
                if rootByStorageMode[gStorageMode] == nil {
                    establishModeSpecificRoot()
                }

                return rootByStorageMode[gStorageMode]!
            }
        }

        set {
            switch gStorageMode {
            case .favorites: break
            default:         rootByStorageMode[gStorageMode] = newValue;
            }
        }
    }


    func manifestForMode(_ mode: ZStorageMode) -> ZManifest {
        var found = manifestByStorageMode[mode]

        if  found == nil {
            found                       = ZManifest(record: nil, storageMode: .mine) // N.B. do not alter storageMode ... MUST be .mine
            manifestByStorageMode[mode] = found
        }

        return found!
    }


    func establishModeSpecificRoot() {
        switch gStorageMode {
        case .favorites: rootZone = gFavoritesManager.favoritesRootZone
        default:         rootZone = Zone(record: nil, storageMode: gStorageMode)
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        if storageMode == .favorites {
            gHere = gFavoritesManager.favoritesRootZone
        } else if gHere.record != nil && gHere.zoneName != nil {
            gHere.maybeNeedChildren()
            gHere.needFetch()
        } else {
            gCloudManager.establishHere((storageMode, onCompletion))

            return
        }

        onCompletion?(0)
    }


    func pushMode(_ mode: ZStorageMode) {
        storageModeStack.append(gStorageMode)

        gStorageMode = mode
    }
    

    func popMode() {
        if storageModeStack.count != 0, let mode = storageModeStack.popLast() {
            gStorageMode = mode
        }
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

            let    zone = gCloudManager.modeSpecificZoneForRecordID(targetID)
            targetID    = zone?.parent?.recordID
        }

        return false
    }


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
        let restoreMode = gStorageMode
        let restoreHere = gHere

        UNDO(self) { iUndoSelf in
            iUndoSelf.createUndoForTravelBackTo(gSelectionManager.currentlyMovableZone, atArrival: atArrival)

            gStorageMode = restoreMode

            iUndoSelf.travel {
                gHere = restoreHere

                zone.grab()
                atArrival()
            }
        }
    }


    func travel(_ atArrival: @escaping Closure) {
        createUndoForTravelBackTo(gSelectionManager.currentlyMovableZone, atArrival: atArrival)

        gWidgetsManager   .clear()
        gSelectionManager .clear()
        gOperationsManager.travel(atArrival)
    }


    func travelThrough(_ bookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = bookmark.crossLink, let mode = crossLink.storageMode, let record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if  gStorageMode != mode {
                gStorageMode  = mode

                /////////////////////////////////
                // TRAVEL TO A DIFFERENT GRAPH //
                /////////////////////////////////

                if crossLink.isRoot { // e.g., default root favorite
                    travel {
                        atArrival(gHere, .redraw)
                    }
                } else {
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: mode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        if iRecord != nil {
                            gHere = gCloudManager.modeSpecificZoneForRecord(iRecord!)

                            gHere.grab()
                            self.travel {
                                atArrival(gHere, .redraw)
                            }
                        }
                    }
                }
            } else {

                ///////////////////////
                // STAY WITHIN GRAPH //
                ///////////////////////

                there = gCloudManager.modeSpecificZoneForRecordID(recordIDOfLink)
                let grabbed = gSelectionManager.firstGrabbedZone
                let    here = gHere

                UNDO(self) { iUndoSelf in
                    self.UNDO(self) { iRedoSelf in
                        self.travelThrough(bookmark, atArrival: atArrival)
                    }

                    gHere = here

                    grabbed.grab()
                    atArrival(here, .redraw)
                }

                let grabHere = {
                    gHere.grab()
                    gHere.maybeNeedChildren()
                    atArrival(gHere, .redraw)
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else {
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: gStorageMode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        gHere = gCloudManager.modeSpecificZoneForRecord(iRecord!)

                        grabHere()
                    }
                }
            }
        }
    }
}
