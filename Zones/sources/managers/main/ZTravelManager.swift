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
    var   priorIndex = -1
    var     topIndex : Int  { return travelStack.count - 1 }
    var      notHere : Bool { return currentIndex < 0 || gHere != travelStack[currentIndex] }


    var isInStack : Int? {
        var found: Int? = nil
        let        here = gHere

        for (index, zone) in travelStack.enumerated() {
            if  zone == here {
                if  index == currentIndex {
                    return index
                }

                found = index
            }
        }

        return found
    }


    func pushHere() {
        var newIndex  = currentIndex + 1

        if topIndex  < 0 || notHere {
            if  let index = isInStack {
                newIndex  = index   // prevent duplicates in stack
            } else if  topIndex == currentIndex {
                travelStack.append(gHere)
            } else {
                if  currentIndex < 0 {
                    currentIndex = 0
                }

                travelStack.insert(gHere, at: currentIndex)
            }

            currentIndex = newIndex
        }
    }


    func goBack(extreme: Bool = false) {
        if  let    index = isInStack {
            currentIndex = index
        } else if notHere {
            pushHere()
        }

        if extreme {
            currentIndex = 0
        } else if currentIndex > 0 && (currentIndex == topIndex || !notHere) {
            currentIndex -= 1
        }

        go()
    }


    func goForward(extreme: Bool = false) {
        if  let    index = isInStack {
            currentIndex = index
        } else if  notHere {
            pushHere()
        }

        if  extreme {
            currentIndex = topIndex
        } else if  currentIndex < topIndex {
            currentIndex += 1
        }

        go()
    }


    func go() {
        if  0          <= currentIndex, (notHere ||
            priorIndex != currentIndex) {
            priorIndex  = currentIndex
            let dbID    = gHere.databaseID
            let here    = travelStack[currentIndex]
            if  dbID   != here.databaseID {
                toggleDatabaseID()         // update id before setting gHere
            }

            gHere       = here

            gHere.grab()
            gFavoritesManager.updateFavorites()
            signalFor(nil, regarding: .redraw)
        }
    }


    // MARK:- travel
    // MARK:-


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
        let   restoreID = gDatabaseID
        let restoreHere = gHere

        UNDO(self) { iUndoSelf in
            iUndoSelf.createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)
            iUndoSelf.pushHere()

            gDatabaseID = restoreID

            iUndoSelf.travel {
                gHere = restoreHere

                zone.grab()
                atArrival()
            }
        }
    }


    func travel(_ atArrival: @escaping Closure) {
        createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)

        gTextManager.stopCurrentEdit()
        gBatchManager.travel { iSame in
            atArrival()
            gBatchManager.save { iSaveSame in
            }
        }
    }


    func travelThrough(_ bookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = bookmark.crossLink,
            let           dbID = crossLink.databaseID,
            let         record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if bookmark.isFavorite {
                gFavoritesManager.currentFavorite = bookmark
            }

            pushHere()

            if  gDatabaseID  != dbID {
                gDatabaseID   = dbID

                /////////////////////////////////
                // TRAVEL TO A DIFFERENT GRAPH //
                /////////////////////////////////

                if bookmark.bookmarkTarget!.isFetched { // e.g., default root favorite
                    travel {
                        gHere = bookmark.bookmarkTarget!

                        gHere.prepareForArrival()
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
                        } else {
                            atArrival(gHere, .redraw)
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

                    gBatchManager.children(.restore) { iSame in
                        atArrival(gHere, .redraw)
                    }
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else if gCloudManager.databaseID != .favoritesID { // favorites does not have a cloud database
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
