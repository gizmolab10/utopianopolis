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


    var  travelStack = [Zone] ()
    var currentIndex = -1
    var     topIndex : Int  { return travelStack.count - 1 }
    var      notHere : Bool { return gHere != travelStack[currentIndex] }


    func pushHere(updateCurrentIndex: Bool = true) {
        let     newIndex  = currentIndex + 1
        if      topIndex  < 0 || notHere {
            if  topIndex == currentIndex {
                travelStack.append(gHere)
            } else {
                travelStack.insert(gHere, at: updateCurrentIndex ? currentIndex : newIndex)
            }

            if  updateCurrentIndex {
                currentIndex = newIndex
            }
        }
    }


    func goBack() {
        let shouldPush = notHere
        let      atTop = topIndex == currentIndex

        if  shouldPush {
            pushHere(updateCurrentIndex: false)
        }

        if  currentIndex  > 0 && (!shouldPush || !atTop) {
            currentIndex -= 1
        }

        go()
    }


    func goForward() {
        let shouldPush    = notHere
        if  currentIndex  < topIndex {
            currentIndex += 1

            if  shouldPush {
                pushHere()
            }

            go()
        }
    }


    func go() {
        let dbID  = gHere.databaseiD
        let here  = travelStack[currentIndex]
        if  dbID != here.databaseiD {
            toggleDatabaseiD()         // update id before setting gHere
        }

        gHere     = here

        gHere.grab()
        gFavoritesManager.updateFavorites()
        signalFor(nil, regarding: .redraw)
    }


    // MARK:- travel
    // MARK:-


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
        let   restoreID = gDatabaseiD
        let restoreHere = gHere

        UNDO(self) { iUndoSelf in
            iUndoSelf.createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)
            iUndoSelf.pushHere()

            gDatabaseiD = restoreID

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
            let           dbID = crossLink.databaseiD,
            let         record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if bookmark.isFavorite {
                gFavoritesManager.currentFavorite = bookmark
            }

            pushHere()

            if  gDatabaseiD  != dbID {
                gDatabaseiD   = dbID

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
                } else if gCloudManager.databaseiD != .favoritesID { // favorites does not have a cloud database
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord {
                            gHere          = gCloudManager.zoneForCKRecord(hereRecord)

                            grabHere()
                        }
                    }
                } // else ... favorites id with an unresolvable bookmark target
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
