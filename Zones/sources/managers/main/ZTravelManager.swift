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
        gDBOperationsManager.travel { iSame in
            atArrival()
            gDBOperationsManager.save { iSaveSame in
            }
        }
    }


    func travelThrough(_ bookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = bookmark.crossLink,
            let           mode = crossLink.storageMode,
            let         record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if bookmark.isFavorite {
                gFavoritesManager.currentFavorite = bookmark
            }

            if  gStorageMode  != mode {
                gStorageMode   = mode

                /////////////////////////////////
                // TRAVEL TO A DIFFERENT GRAPH //
                /////////////////////////////////

                if crossLink.isRoot { // e.g., default root favorite
                    travel {
                        gHere = bookmark.bookmarkTarget!

                        atArrival(gHere, .redraw)
                    }
                } else {
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord {
                            gHere          = gCloudManager.zoneForCKRecord(hereRecord)

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

                there = gCloudManager.maybeZoneForRecordID(recordIDOfLink)
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

                    gDBOperationsManager.children(.restore) { iSame in
                        atArrival(gHere, .redraw)
                    }
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else if gCloudManager.storageMode != .favoritesMode { // favorites does not have a cloud database
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord {
                            gHere          = gCloudManager.zoneForCKRecord(hereRecord)

                            grabHere()
                        }
                    }
                } // else ... favorites mode with an unresolvable bookmark target
            }
        }
    }


    func maybeTravelThrough(_ iZone: Zone, onCompletion: Closure?) {
        if     !travelThroughBookmark(iZone, onCompletion: onCompletion) {
            if !travelThroughHyperlink(iZone) {
                travelThroughEmail(iZone)
            }
        }
    }


    @discardableResult func travelThroughEmail(_ iZone: Zone) -> Bool {
        if  let link  = iZone.email {
            let email = "mailTo:" + link
            email.openAsURL()

            return true
        }

        return false
    }


    @discardableResult func travelThroughHyperlink(_ iZone: Zone) -> Bool {
        if  let link = iZone.hyperLink,
            link    != kNullLink {
            link.openAsURL()

            return true
        }

        return false
    }


    @discardableResult func travelThroughBookmark(_ bookmark: Zone, onCompletion: Closure?) -> Bool {
        let doThis = bookmark.isBookmark

        if  doThis {
            travelThrough(bookmark) { object, kind in
                onCompletion?()
            }
        }

        return doThis
    }

}
