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


    var    focusRing = ZoneArray ()
    var currentIndex = -1
    var   priorIndex = -1
    var     topIndex : Int  { return focusRing.count - 1 }
    var       atHere : Bool { return currentIndex >= 0 && currentIndex <= topIndex && gHereMaybe == focusRing[currentIndex] }


	func setHereRecordName(_ iName: String, for databaseID: ZDatabaseID) {
		if  let         index = databaseID.index {
			var    references = gHereRecordNames.components(separatedBy: kSeparator)
			references[index] = iName
			gHereRecordNames  = references.joined(separator: kSeparator)
		}
	}
	
	
	func hereRecordName(for databaseID: ZDatabaseID) -> String? {
		let references = gHereRecordNames.components(separatedBy: kSeparator)
		
		if  let  index = databaseID.index {
			return references[index]
		}
		
		return nil
	}
	

    // MARK:- travel stack
    // MARK:-


    var indexOfHere : Int? {
		if  let here = gHereMaybe {
			for (index, zone) in focusRing.enumerated() {
				if  here == zone {
					return index
				}
			}
		}

        return nil
    }

    
    func debugDump() {
        if gDebugReport {
            for (index, zone) in focusRing.enumerated() {
                let isCurrentIndex = index == currentIndex
                let prefix = isCurrentIndex ? "                   •" : ""
                columnarReport(prefix, zone.zoneName)
            }
        }
    }


    func pushHere() {
        var newIndex  = currentIndex + 1

        if topIndex < 0 || !atHere {
            if  let index = indexOfHere {
                newIndex  = index   // prevent duplicates in stack
            } else if topIndex <= currentIndex {
				if  let here = gHereMaybe {
					focusRing.append(here)
				}
            } else {
                if  currentIndex < 0 {
                    currentIndex = 0
                    newIndex  = currentIndex + 1
                }

                focusRing.insert(gHere, at: newIndex)
            }

            currentIndex = newIndex
        }
    }


    func goBack(extreme: Bool = false) {
        if  let    index = indexOfHere {
            currentIndex = index
        } else if !atHere {
            pushHere()
        }

        if  currentIndex <= 0 || currentIndex > topIndex {
            currentIndex = topIndex
        } else if extreme {
            currentIndex = 0
        } else if currentIndex == topIndex || atHere {
            currentIndex -= 1
        }

        go()
    }


    func goForward(extreme: Bool = false) {
        if  let    index = indexOfHere {
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
        let         max = focusRing.count

        if  0          <= currentIndex,
            max         > currentIndex, (!atHere ||
            priorIndex != currentIndex) {
            priorIndex  = currentIndex
            let dbID    = gHere.databaseID
            let here    = focusRing[currentIndex]
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

    
    func pop() {
        if  let i = indexOfHere {
            goBack()
            focusRing.remove(at: i)
        } else {
            go()
        }
    }
	
	
	func removeFromStack(_ iZone: Zone) {
		for (index, zone) in focusRing.enumerated() {
			if zone == iZone {
				focusRing.remove(at: index)

				return
			}
		}
	}
    

    // MARK:- travel
    // MARK:-


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
		if  let restoreHere = gHereMaybe {
			let   restoreID = gDatabaseID

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
    }


    func focus(kind: ZFocusKind, _ COMMAND: Bool = false, _ atArrival: @escaping Closure) {
        
        // five states:
        // 1. is a bookmark     -> target becomes here
        // 2. is here           -> update in favorites
        // 3. is a favorite     -> grab here
        // 4. not here, COMMAND -> become here
        // 5. not COMMAND       -> select here

        if  let zone = (kind == .eEdited) ? gEditedTextWidget?.widgetZone : gSelecting.firstSortedGrab {
            let focusClosure = { (zone: Zone) in
                self.pushHere()

                gHere = zone

                gFavorites.updateCurrentFavorite()
                zone.grab()
                atArrival()
            }

            if zone.isBookmark {     // state 2
                travelThrough(zone) { object, kind in
                    focusClosure(object as! Zone)
                }
            } else if zone == gHere {       // state 3
                gFavorites.updateGrab()
                atArrival()
            } else if zone.isInFavorites {  // state 4
                focusClosure(gHere)
            } else if COMMAND {                   // state 1
                gFavorites.refocus {
                    atArrival()
                }
            } else {                        // state 5
                focusClosure(zone)
            }
        }
    }


    func focus(_ atArrival: @escaping Closure) {
        createUndoForTravelBackTo(gSelecting.currentMoveable, atArrival: atArrival)
		gTextEditor.stopCurrentEdit()
        gBatches.focus { iSame in
			gShowFavorites = gDatabaseID == .favoritesID

			self.showTopLevelFunctions()
            atArrival()
            gBatches.save { iSaveSame in
            }
        }
    }
    
    
    func focusOn(_ iHere: Zone, _ atArrival: @escaping Closure) {
        pushHere()
        
        gHere = iHere

        focus {
            gHere.grab()
            gFavorites.updateCurrentFavorite()
            atArrival()
        }
    }


    @discardableResult func focusThrough(_ iBookmark: Zone?, _ atArrival: @escaping Closure) -> Bool {
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

			let complete : SignalClosure = { (iObject, iKind) in
				self.showTopLevelFunctions()
				atArrival(iObject, iKind)
			}
            
            var there: Zone?

            if  iBookmark.isInFavorites {
                gFavorites.currentFavorite = iBookmark
            }

            if  let target = iTarget, target.spawnedBy(gHereMaybe) {
                if !target.isGrabbed {
                    target.asssureIsVisible()
                    target.grab()
                } else {
                    pushHere()

                    gHere = target
                }

				gShowFavorites = targetDBID == .favoritesID

				complete(target, .eRelayout)
			} else {
				pushHere()
				debugDump()

				gShowFavorites = targetDBID == .favoritesID

				if  gDatabaseID != targetDBID {
					gDatabaseID  = targetDBID
					
					/////////////////////////////////
					// TRAVEL TO A DIFFERENT GRAPH //
					/////////////////////////////////
					
					if  let target = iTarget, target.isFetched { // e.g., default root favorite
						focus {
							gHere  = target
							
							gHere.prepareForArrival()
							complete(gHere, .eRelayout)
						}
					} else {
						gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
							if  let hereRecord = iRecord,
								let    newHere = gCloud?.zone(for: hereRecord) {
								gHere          = newHere
								
								newHere.prepareForArrival()
								self.focus {
									complete(newHere, .eRelayout)
								}
							} else {
								complete(gHere, .eRelayout)
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
							self.travelThrough(iBookmark, atArrival: complete)
						}
						
						gHere = here
						
						grabbed?.grab()
						complete(here, .eRelayout)
					}
					
					let grabHere = {
						gHereMaybe?.prepareForArrival()
						
						gBatches.children(.restore) { iSame in
							complete(gHereMaybe, .eRelayout)
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
    }


    func maybeTravelThrough(_ iZone: Zone?, onCompletion: Closure? = nil) {
        guard let zone = iZone else { onCompletion?(); return }

        if  !invokeBookmark(zone, onCompletion: onCompletion),
            !invokeHyperlink(zone),
			!revealEssay(zone) {
            invokeEmail(zone)
        }
    }

	func revealEssay(_ iZone: Zone) -> Bool { // false means not handled
		if  iZone.essayMaybe != nil {
			gEssayEditor.swapGraphAndEssay()

			return true
		}

		return false
	}

    @discardableResult func invokeEmail(_ iZone: Zone) -> Bool { // false means not traveled
        if  let link  = iZone.email {
            let email = "mailTo:" + link
            email.openAsURL()

            return true
        }

        return false
    }


    @discardableResult func invokeHyperlink(_ iZone: Zone) -> Bool { // false means not traveled
        if  let link = iZone.hyperLink,
            link    != kNullLink {
            link.openAsURL()

            return true
        }

        return false
    }


    @discardableResult func invokeBookmark(_ bookmark: Zone, onCompletion: Closure?) -> Bool { // false means not traveled
        let doTryBookmark = bookmark.isBookmark

        if  doTryBookmark {
            travelThrough(bookmark) { object, kind in
				#if os(iOS)
				gActionsController.alignView()
				#endif
                onCompletion?()
            }
        }

        return doTryBookmark
    }

}
