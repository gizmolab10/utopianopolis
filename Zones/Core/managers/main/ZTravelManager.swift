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
    var rootProgenyCount: Int { return hasRootZone ? rootZone.progenyCount : 0 }
    var     hasRootZone: Bool { return rootByStorageMode.keys.contains(gStorageMode) }
    var   manifest: ZManifest { return manifest(for: gStorageMode) }
    var        rootZone: Zone {
        get { return rootZone(for: gStorageMode) }

        set {
            switch gStorageMode {
            case .favorites: break
            default:         setRoot(newValue, for: gStorageMode)
            }
        }
    }


    func setRoot(_ iRoot: Zone, for mode: ZStorageMode) { iRoot.level = 0; rootByStorageMode[mode] = iRoot }


    func rootZone(for mode: ZStorageMode) -> Zone {
        switch mode {
        case .favorites: return gFavoritesManager.favoritesRootZone
        default:
            assert(hasRootZone, "root zone not yet established")

            return rootByStorageMode[mode]!
        }
    }


    func manifest(for mode: ZStorageMode) -> ZManifest {
        var found = manifestByStorageMode[mode]

        if  found == nil {
            found                       = ZManifest(record: nil, storageMode: .mine)
            found!        .manifestMode = mode
            manifestByStorageMode[mode] = found
        }

        return found!
    }


    func establishRoot(for storageMode: ZStorageMode) {
        switch storageMode {
        case .favorites: rootZone = gFavoritesManager.favoritesRootZone
        default:         gCloudManager.establishRoot(storageMode) { iResult in }
        }
    }


    func establishHere(_ storageMode: ZStorageMode, _ onCompletion: IntegerClosure?) {
        let manifest = self.manifest(for: storageMode)
        let     here = manifest.hereZone

        if storageMode == .favorites {
            manifest.hereZone = gFavoritesManager.favoritesRootZone
        } else if here.record != nil && here.zoneName != nil {
            here.maybeNeedChildren()
            here.needFetch()
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
        if  let        link = bookmark.crossLink, let mode = link.storageMode {
            var    targetID = link.record.recordID as CKRecordID?
            let  identifier = zone.record.recordID.recordName

            while  targetID != nil {
                if targetID!.recordName == identifier {
                    return true
                }

                let zone = gCloudManager.zoneForRecordID(targetID, in: mode)
                targetID = zone?.parent?.recordID
            }
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

        gWidgetsManager   .clearWidgets()
        gSelectionManager .clearEdit()
        gOperationsManager.travel(atArrival)
    }


    func travelThrough(_ bookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = bookmark.crossLink,
            let           mode = crossLink.storageMode,
            let         record = crossLink.record {
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
                            gHere = gCloudManager.zoneForRecord(iRecord!, in: mode)

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

                there = gCloudManager.zoneForRecordID(recordIDOfLink, in: mode)
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
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, storageMode: mode, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        gHere = gCloudManager.zoneForRecord(iRecord!, in: mode)

                        grabHere()
                    }
                }
            }
        }
    }
}
