//
//  ZFocusing.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit



enum ZFocusKind: Int {
    case eSelected
    case eEdited
}


let gFocusing = ZFocusing()


class ZFocusing: NSObject {


    var  travelStack = [Zone] ()
    var currentIndex = -1
    var   priorIndex = -1
    var     topIndex : Int  { return travelStack.count - 1 }
    var       atHere : Bool { return currentIndex >= 0 && gHere == travelStack[currentIndex] }


    // MARK:- travel stack
    // MARK:-


    var isInStack : Int? {
        let     here  = gHere

        for (index, zone) in travelStack.enumerated() {
            if  here == zone {
                return index
            }
        }

        return nil
    }


    func debugDump() {
        for (index, zone) in travelStack.enumerated() {
            let isCurrentIndex = index == currentIndex
            let prefix = isCurrentIndex ? "                   •" : ""
            columnarReport(prefix, zone.zoneName)
        }
    }


    func pushHere() {
        var newIndex  = currentIndex + 1

        if topIndex  < 0 || !atHere {
            if  let index = isInStack {
                newIndex  = index   // prevent duplicates in stack
            } else if  topIndex == currentIndex {
                travelStack.append(gHere)
            } else {
                if  currentIndex < 0 {
                    currentIndex = 0
                    newIndex  = currentIndex + 1
                }

                travelStack.insert(gHere, at: newIndex)
            }

            currentIndex = newIndex
        }
    }


    func goBack(extreme: Bool = false) {
        if  let    index = isInStack {
            currentIndex = index
        } else if !atHere {
            pushHere()
        }

        if currentIndex <= 0 {
            currentIndex = topIndex
        } else if extreme {
            currentIndex = 0
        } else if currentIndex == topIndex || atHere {
            currentIndex -= 1
        }

        go()
    }


    func goForward(extreme: Bool = false) {
        if  let    index = isInStack {
            currentIndex = index
        } else if !atHere {
            pushHere()
        }

        if  currentIndex == topIndex {
            currentIndex  = 0
        } else if  extreme {
            currentIndex = topIndex
        } else if  currentIndex < topIndex {
            currentIndex += 1
        }

        go()
    }


    func go() {
        if  0          <= currentIndex, (!atHere ||
            priorIndex != currentIndex) {
            priorIndex  = currentIndex
            let dbID    = gHere.databaseID
            let here    = travelStack[currentIndex]
            if  dbID   != here.databaseID {
                toggleDatabaseID()         // update id before setting gHere
            }

            gHere       = here

            debugDump()
            gHere.grab()
            gFavorites.updateAllFavorites()
            redrawGraph()
        }
    }


    // MARK:- travel
    // MARK:-


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
        let   restoreID = gDatabaseID
        let restoreHere = gHere

        UNDO(self) { iUndoSelf in
            iUndoSelf.createUndoForTravelBackTo(gSelecting.currentMoveable, atArrival: atArrival)
            iUndoSelf.pushHere()
            self.debugDump()

            gDatabaseID = restoreID

            iUndoSelf.focus {
                gHere = restoreHere

                zone.grab()
                atArrival()
            }
        }
    }


    func focus(kind: ZFocusKind, _ COMMAND: Bool = false, _ atArrival: @escaping Closure) {
        
        // five states:
        // 1. COMMAND       -> select here
        // 2. is a bookmark -> target becomes here
        // 3. is here       -> update in favorites
        // 4. is a favorite -> grab here
        // 5. is not here   -> become here

        if  let zone = (kind == .eEdited) ? gEditedTextWidget?.widgetZone : gSelecting.firstSortedGrab {
            let focusClosure = { (zone: Zone) in
                gHere = zone

                gFavorites.updateCurrentFavorite()
                zone.grab()
                atArrival()
            }

            if  COMMAND {                   // state 1
                gFavorites.refocus {
                    atArrival()
                }
            } else if zone.isBookmark {     // state 2
                gFocusing.travelThrough(zone) { object, kind in
                    focusClosure(object as! Zone)
                }
            } else if zone == gHere {       // state 3
                gFavorites.updateGrab()
                atArrival()
            } else if zone.isInFavorites {  // state 4
                focusClosure(gHere)
            } else {                        // state 5
                focusClosure(zone)
            }
        }
    }


    func focus(_ atArrival: @escaping Closure) {
        createUndoForTravelBackTo(gSelecting.currentMoveable, atArrival: atArrival)

        gTextEditor.stopCurrentEdit()
        gBatches.focus { iSame in
            atArrival()
            gBatches.save { iSaveSame in
            }
        }
    }
    
    
    func focus(on: Zone, _ atArrival: @escaping Closure) {
        pushHere()
        
        gHere = on

        focus {
            gHere.grab()
            atArrival()
        }
    }


    @discardableResult func focus(through iBookmark: Zone?, _ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = iBookmark, bookmark.isBookmark {
            if  bookmark.isInFavorites {
                let targetParent = bookmark.bookmarkTarget?.parentZone
                let       parent = bookmark.parentZone

                targetParent?.revealChildren()
                targetParent?.needChildren()
                parent?.revealChildren()
                parent?.needChildren()
                travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    gFavorites.updateAllFavorites(iObject as? Zone)
                    atArrival()
                }

                return true
            } else if let dbID = bookmark.crossLink?.databaseID {
                pushHere()
                debugDump()

                gDatabaseID = dbID

                focus {
                    gHere.grab()
                    atArrival()
                }

                return true
            }

            performance("oops!")
        }

        return false
    }


    func travelThrough(_ iBookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let  targetZRecord = iBookmark.crossLink,
            let     targetDBID = targetZRecord.databaseID,
            let   targetRecord = targetZRecord.record {
            let targetRecordID = targetRecord.recordID
            let        iTarget = iBookmark.bookmarkTarget
            
            var   there: Zone?

            if  iBookmark.isInFavorites {
                gFavorites.currentFavorite = iBookmark
            }

            if  let target = iTarget, target.spawnedBy(gHere) {
                if  target.isGrabbed {
                    gHere = target
                } else {
                    target.asssureIsVisible()
                    target.grab()
                }

                atArrival(target, .eRelayout)

                return
            }
            
            pushHere()
            debugDump()

            if  gDatabaseID != targetDBID {
                gDatabaseID  = targetDBID

                /////////////////////////////////
                // TRAVEL TO A DIFFERENT GRAPH //
                /////////////////////////////////

                if  let target = iTarget, target.isFetched { // e.g., default root favorite
                    focus {
                        gHere  = target

                        gHere.prepareForArrival()
                        atArrival(gHere, .eRelayout)
                    }
                } else {
                    gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord,
                            let    newHere = gCloud?.zone(for: hereRecord) {
                            gHere          = newHere

                            newHere.prepareForArrival()
                            self.focus {
                                atArrival(newHere, .eRelayout)
                            }
                        } else {
                            atArrival(gHere, .eRelayout)
                        }
                    }
                }
            } else {

                ///////////////////////
                // STAY WITHIN GRAPH //
                ///////////////////////

                there = gCloud?.maybeZoneForRecordID(targetRecordID)
                let grabbed = gSelecting.firstSortedGrab
                let    here = gHere

                UNDO(self) { iUndoSelf in
                    self.UNDO(self) { iRedoSelf in
                        self.travelThrough(iBookmark, atArrival: atArrival)
                    }

                    gHere = here

                    grabbed.grab()
                    atArrival(here, .eRelayout)
                }

                let grabHere = {
                    gHere.prepareForArrival()

                    gBatches.children(.restore) { iSame in
                        atArrival(gHere, .eRelayout)
                    }
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else if gCloud?.databaseID != .favoritesID { // favorites does not have a cloud database
                    gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord,
                            let    newHere = gCloud?.zone(for: hereRecord) {
                            gHere          = newHere

                            grabHere()
                        }
                    }
                } // else ... favorites id with an unresolvable bookmark target
            }
        }
    }


    func maybeTravelThrough(_ iZone: Zone, onCompletion: Closure? = nil) {
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
        let doTryBookmark = bookmark.isBookmark

        if  doTryBookmark {
            travelThrough(bookmark) { object, kind in
                onCompletion?()
            }
        }

        return doTryBookmark
    }

}
