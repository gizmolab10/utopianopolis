//
//  ZFocus.swift
//  Seriously
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

let gFocusRing = ZFocus()

class ZFocus: ZRing {

	override var          isEssay : Bool              { return false }
	override var    possiblePrime : NSObject?         { return gHereMaybe }
	override var visibleRingTypes : ZTinyDotTypeArray { return ZTinyDotTypeArray.ideaTypes(ring.count) }
	override func object(for id: String) -> NSObject? { return Zone.object(for: id, isExpanded: false) }
	override func removeEmpties() {}

	override var isPrime : Bool {
		guard let zone = ringPrime as? Zone else { return false }

		return gHereMaybe == zone
	}

	func setHereRecordName(_ iName: String, for databaseID: ZDatabaseID) {
		if  let         index = databaseID.index {
			var    references = gHereRecordNames.components(separatedBy: kColonSeparator)
			references[index] = iName
			gHereRecordNames  = references.joined(separator: kColonSeparator)
		}
	}

	func hereRecordName(for databaseID: ZDatabaseID) -> String? {
		let references = gHereRecordNames.components(separatedBy: kColonSeparator)
		
		if  let  index = databaseID.index {
			return references[index]
		}
		
		return nil
	}

    func focus(kind: ZFocusKind, _ COMMAND: Bool = false, _ atArrival: @escaping Closure) {
        
        // five states:
        // 1. is a bookmark     -> target becomes here
        // 2. is here           -> update in favorites, not push
        // 3. is a favorite     -> grab here
        // 4. not here, COMMAND -> become here
        // 5. not COMMAND       -> select here

        if  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab {
            let focusClosure = { (zone: Zone) in
                gHere = zone

                gFavorites.updateCurrentFavorite()
                zone.grab()
                atArrival()
            }

            if zone.isBookmark {     		// state 1
                travelThrough(zone) { object, kind in
                    focusClosure(object as! Zone)
                }
            } else if zone == gHere {       // state 2
                gFavorites.updateGrab()
                atArrival()
            } else if zone.isInFavorites {  // state 3
                focusClosure(gHere)
            } else if COMMAND {             // state 4
                gFavorites.refocus {
					self.push()
                    atArrival()
                }
            } else {                        // state 5
                focusClosure(zone)
            }
        }
    }

	override func update() {
		if !isEmpty,
			let here = ring[currentIndex] as? Zone {
			if  here.databaseID != gHere.databaseID {
				toggleDatabaseID()         // update id before setting gHere
			}

			gHere = here

			gHere.grab()
			gFavorites.updateAllFavorites()
			gRedrawGraph()
		}
	}

	@discardableResult override func removeFromStack(_ iItem: NSObject?, okayToRecurse: Bool = true) -> Bool {
		if  ring.count > 1,
			let zone = iItem as? Zone {
			for (index, item) in ring.enumerated() {
				if  let other = item as? Zone,
					other === zone {

					removeFromRing(at: index)     // TODO: MAJOR: recursive
					storeRingIDs()

					if  okayToRecurse {
						gRingView?.updateNecklace()
					}

					if  index == currentIndex || zone == gHere {
						goBack()
					}

					return true
				}
			}
		}

		return false
	}

	// MARK:- travel
	// MARK:-

	func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
		if  let restoreHere = gHereMaybe {
			let   restoreID = gDatabaseID

			UNDO(self) { iUndoSelf in
				iUndoSelf.createUndoForTravelBackTo(gSelecting.currentMoveable, atArrival: atArrival)

				gDatabaseID = restoreID

				iUndoSelf.focus {
					gHere = restoreHere

					zone.grab()
					atArrival()
				}
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
            gBatches.save { iSaveSame in }
        }
    }

    func focusOn(_ iHere: Zone, _ atArrival: @escaping Closure) {
        gHere = iHere

		push()
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
                push()
                dump()

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
                    gHere = target

					push()
                }

				gShowFavorites = targetDBID == .favoritesID

				complete(target, .sRelayout)
			} else {
				dump()

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
							complete(gHere, .sRelayout)
						}
					} else {
						gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
							if  let hereRecord = iRecord,
								let    newHere = gCloud?.zoneForRecord(hereRecord) {
								gHere          = newHere

								newHere.prepareForArrival()
								self.focus {
									complete(newHere, .sRelayout)
								}
							} else {
								complete(gHere, .sRelayout)
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
						complete(here, .sRelayout)
					}
					
					let grabHere = {
						gHereMaybe?.prepareForArrival()
						complete(gHereMaybe, .sRelayout)
					}
					
					if  there != nil {
						gHere = there!

						grabHere()
					} else if gCloud?.databaseID != .favoritesID { // favorites does not have a cloud database
						gCloud?.assureRecordExists(withRecordID: targetRecordID, recordType: kZoneType) { (iRecord: CKRecord?) in
							if  let hereRecord = iRecord,
								let    newHere = gCloud?.zoneForRecord(hereRecord) {
								gHere          = newHere
								
								grabHere()
							}
						}
					} // else ... favorites id with an unresolvable bookmark target
				}
			}
		}
    }

    func invokeTravel(_ iZone: Zone?, onCompletion: Closure? = nil) {
        guard let zone = iZone else {
			onCompletion?()

			return
		}

        if  !invokeBookmark(zone, onCompletion: onCompletion),
            !invokeHyperlink(zone),
			!invokeEssay(zone) {
            invokeEmail(zone)
        }
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

	@discardableResult func invokeHyperlink(_ iZone: Zone) -> Bool { // false means not traveled
		if  let link = iZone.hyperLink,
			link    != kNullLink {
			link.openAsURL()

			return true
		}

		return false
	}

	@discardableResult func invokeEssay(_ iZone: Zone) -> Bool { // false means not handled
		if  iZone.hasEssay {
			iZone.grab()

			gCurrentEssay = iZone.note

			gControllers.swapGraphAndEssay()

			return true
		}

		return false
	}

    @discardableResult func invokeEmail(_ iZone: Zone) -> Bool { // false means not traveled
        if  let  link = iZone.email {
            let email = "mailTo:" + link
            email.openAsURL()

            return true
        }

        return false
    }

}
