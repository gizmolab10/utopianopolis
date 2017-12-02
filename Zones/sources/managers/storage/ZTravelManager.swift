//
//  ZTravelManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gTravelManager = ZTravelManager()


class ZTravelManager: NSObject {


    // MARK:- travel
    // MARK:-


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
        let restoreMode = gStorageMode
        let restoreHere = gHere

        UNDO(self) { iUndoSelf in
            iUndoSelf.createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)

            gStorageMode = restoreMode

            iUndoSelf.travel {
                gHere = restoreHere

                zone.grab()
                atArrival()
            }
        }
    }


    func travel(_ atArrival: @escaping Closure) {
        createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)

        gSelectionManager.clearEdit()
        gDBOperationsManager.travel {
            atArrival()
            gDBOperationsManager.save {}
        }
    }


    func travelThrough(_ bookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = bookmark.crossLink,
            let           mode = crossLink.storageMode,
            let         record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if bookmark.isInFavorites {
                gFavoritesManager.currentFavorite = bookmark
            }

            if  gStorageMode  != mode {
                gStorageMode   = mode

                /////////////////////////////////
                // TRAVEL TO A DIFFERENT GRAPH //
                /////////////////////////////////

                if crossLink.isRoot { // e.g., default root favorite
                    travel {
                        atArrival(gHere, .redraw)
                    }
                } else {
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: gZoneTypeKey) { (iRecord: CKRecord?) in
                        if iRecord != nil {
                            gHere        = gCloudManager.zoneForRecord(iRecord!)
                            gHere.record = iRecord!

                            gHere.prepareForArrival()
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

                there = gCloudManager.zoneForRecordID(recordIDOfLink)
                let grabbed = gSelectionManager.firstGrab
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
                    gHere.prepareForArrival()

                    gDBOperationsManager.children(.restore) {
                        atArrival(gHere, .redraw)
                    }
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else if gCloudManager.storageMode != .favoritesMode { // favorites does not have a cloud database
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: gZoneTypeKey) { (iRecord: CKRecord?) in
                        if  let   record = iRecord {
                            gHere        = gCloudManager.zoneForRecord(record)
                            gHere.record = record

                            grabHere()
                        }
                    }
                } // else ... favorites mode with an unresolvable bookmark target
            }
        }
    }
}
