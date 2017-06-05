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

                let zone = gRemoteStoresManager.recordsManagerFor(mode).zoneForRecordID(targetID)
                targetID = zone?.parent?.recordID
            }
        }
        
        return false
    }


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
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        if iRecord != nil {
                            gHere        = gCloudManager.zoneForRecord(iRecord!)
                            gHere.record = iRecord!

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
                    gHere.grab()
                    gHere.maybeNeedChildren()
                    atArrival(gHere, .redraw)
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else {
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
                        gHere        = gCloudManager.zoneForRecord(iRecord!)
                        gHere.record = iRecord!

                        grabHere()
                    }
                }
            }
        }
    }
}
