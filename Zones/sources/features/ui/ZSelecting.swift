//
//  ZSelecting.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

enum ZRelation: Int {
    case above = 0 // do not change these values
	case below = 1
    case upon  = 2

	var lineCurveKind: ZLineCurveKind {
		switch self {
		case .upon:  return .straight
		case .above: return .above
		case .below: return .below
		}
	}
}

let gSelecting = ZSelecting()

class ZSnapshot: NSObject {

    var    grabbed = ZoneArray ()
    var databaseID : ZDatabaseID?
    var       here : Zone?
    var     isSame : Bool { return gSelecting.snapshot == self }

    static func == ( left: ZSnapshot, right: ZSnapshot) -> Bool {
        let   goodIDs = left.databaseID != nil && right.databaseID != nil
        let  goodHere = left      .here != nil && right      .here != nil
        let sameCount = left.grabbed.count == right.grabbed.count

        if  goodHere && goodIDs && sameCount {
            let sameHere = left.here == right.here
            let  sameIDs = left.databaseID == right.databaseID

            if  sameHere && sameIDs {
                for (index, grab) in left.grabbed.enumerated() {
                    if  grab != right.grabbed[index] {
                        return false
                    }
                }

                return true
            }
        }

        return false
    }

}

class ZSelecting: NSObject {

	var    movableIsHere : Bool      { return gHereMaybe != nil && gHereMaybe == currentMoveableMaybe }
	var          hasGrab : Bool      { return  currentGrabs.count > 0 }
	var hasMultipleGrabs : Bool      { return  currentGrabs.count > 1 }
	var  currentMoveable : Zone      { return  currentMoveableMaybe ?? gHere }
    var         lastGrab : Zone      { return  lastGrab() }
    var   lastSortedGrab : Zone      { return  lastGrab(using: sortedGrabs) }
    var  firstSortedGrab : Zone?     { return firstGrab(using: sortedGrabs) }
	var       hasNewGrab : Zone?
    var       cousinList : ZoneArray { get { updateCousinListForNewGrab(); return _cousinList }                       set { _cousinList     = newValue }}
	var      sortedGrabs : ZoneArray { get { updateSortedGrabs();          return _sortedGrabs }                      set { _sortedGrabs    = newValue }}
	var     currentGrabs : ZoneArray { get { return gIsEssayMode ? gEssayView?.grabbedZones ?? [] : currentMapGrabs } set { currentMapGrabs = newValue }}
    var  currentMapGrabs = ZoneArray ()
    var     _sortedGrabs = ZoneArray ()
    var      _cousinList = ZoneArray ()
	var   pasteableZones = [Zone: (Zone?, Int?)] ()

	var traversalStart : Zone? {
		var start: Zone?

		if  let zone = firstGrab() {
			start = zone.isInFavorites ? gFavoritesRoot : zone.isInLostAndFound ? gLostAndFound : gHereMaybe
		}

		return start
	}

    var snapshot : ZSnapshot {
        let          snap = ZSnapshot()
        snap.grabbed = currentMapGrabs
        snap  .databaseID = gDatabaseID
        snap        .here = gHereMaybe

        return snap
    }

    var writableGrabsCount: Int {
        var count = 0

        for zone in currentMapGrabs {
            if  zone.userCanWrite {
                count += 1
            }
        }

        return count
    }

    var simplifiedGrabs: ZoneArray {
        let current = currentMapGrabs
        var   grabs = ZoneArray ()

        for grab in current {
            var found = false

            grab.traverseAncestors { iZone -> ZTraverseStatus in
                if  grab != iZone && current.contains(iZone) {
                    found = true

                    return .eStop
                }

                return .eContinue
            }

            if !found {
                grabs.append(grab)
            }
        }

		grabs.respectOrder()

        return grabs
    }
    
    /// If currently only a single grab, auto-grab subsequent zones until the next non-line
    var possiblyAutoGrabbed: ZoneArray {
        var s = simplifiedGrabs

        if s.count == 1 {
            let zone = s.first

            if let parent = zone?.parentZone,
                var index = zone?.siblingIndex {
                let max = parent.count - 1

                while index < max {
                    index += 1 // skip past first

                    let sibling = parent.children[index]

                    if  sibling.zoneName?.isDashedLine ?? false {
                        break // found another dashed line, no more extending
                    } else {
                        s.append(sibling)
                    }
                }
            }
        }
        
        return s
    }

    var currentMapGrabsHaveVisibleChildren: Bool {
        for     grab in currentMapGrabs {
            if  grab.count > 0 &&
                grab.isExpanded {
                return true
            }
        }

        return false
    }

    var grabbedColor: ZColor? {
        get { return firstGrab()?.color }
        set {
            for grab in currentMapGrabs {
				let  colorized = grab.colorized
                grab.color     = newValue
				grab.colorized = colorized
            }
        }
    }

    var rootMostMoveable: Zone? {
        var candidate = currentMoveableMaybe

		if  let level = candidate?.level {
			for grabbed in currentMapGrabs {
				if  grabbed.level < level {
					candidate = grabbed
				}
			}
		}

        return candidate
    }
    
    var currentMoveableLine: Zone? {
        for grab in currentMapGrabs + [gHere] {
            if grab.zoneName?.isLineWithTitle ?? false {
                return grab
            }
        }
        
        return nil
    }

	var currentMoveableMaybe: Zone? {
        var movable: Zone?

        if  currentMapGrabs.count > 0 {
			movable = currentMapGrabs.first
        } else if let zone = gTextEditor.currentlyEditedZone {
            movable = zone
        }

        if  movable == nil {
            movable = gHereMaybe
        }

        return movable
    }

	var pastableRecordName: String? {
		let pastables = pasteableZones

		if  pastables.count > 0 {
			let (pastable, (_, _)) = pastables.first!

			return pastable.recordName
		}

		return nil
	}

    // MARK: - convenience
    // MARK: -

    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || gTextEditor.currentlyEditedZone == zone }
    func isGrabbed (_ zone: Zone) -> Bool { return currentMapGrabs.contains(zone) }
    func updateBrowsingLevel()            { gCurrentBrowseLevel = currentMoveable.level }
    func clearPaste()                     { pasteableZones = [:] }

	func addSibling(_ OPTION: Bool = false) {
		gTextEditor.stopCurrentEdit()
		currentMoveable.addNextAndRedraw(containing: OPTION)
	}

	func updateAfterMove(_ selectionOnly: Bool = true, needsRedraw: Bool) {
		if !selectionOnly {
			currentMoveable.recount()
		}
		
		updateBrowsingLevel()
		updateCousinList()
		gFavorites.updateFavoritesAndRedraw(needsRedraw: needsRedraw) {
			gSignal([.sDetails])
		}
	}

	func handleDuplicates(_ COMMAND: Bool) {
		let grabs = simplifiedGrabs

		if  COMMAND {
			grabs.deleteDuplicates()
		} else {
			grabs.cycleToNextDuplicate()
		}
	}

	// MARK: - selection
	// MARK: -

	func assureMinimalGrabs() {
		if  currentMapGrabs.count == 0,
			let here = gHereMaybe {
			grab([here])
		}
	}

    func ungrabAssuringOne(_ iZone: Zone?) {
        ungrab(iZone)
        
        if  currentMapGrabs.count == 0 {
            grab([gHere])
        }
    }

    func ungrab(_ iZone: Zone?) {
        if  let  zone = iZone,
			let index = currentMapGrabs.firstIndex(of: zone) {
			currentMapGrabs.remove(at: index)
//			zone.updateToolTips()
        }
    }

	func ungrabAll(retaining: ZoneArray? = nil) {
		let  all = currentMapGrabs + sortedGrabs + cousinList
		let more = retaining ?? []

		for zone in all {
			if !more.contains(zone) {
				ungrab(zone)
			}
		}

		if  more.count > 0 {
			updateCousinList(for: more[0])
		}

		for zone in more {
			if !currentMapGrabs.contains(zone) {
				currentMapGrabs.append(zone)
//				zone.updateToolTips()
			}
		}
	}

    func addMultipleGrabs(_ iZones: ZoneArray) {
		for zone in iZones {
            addOneGrab(zone)
        }
    }

    func addOneGrab(_ iZone: Zone?) { // caller must update widgets need display
        if  let zone = iZone,
            !currentMapGrabs.contains(zone) {
			currentMapGrabs.append(zone)
//			zone.updateToolTips()
			currentMapGrabs.respectOrderAndLevel()
        }
    }

    func grab(_ iZones: ZoneArray?, updateBrowsingLevel: Bool = true) {
		if  let zones = iZones {
			ungrabAll(retaining: zones)

            if  updateBrowsingLevel,
                let 		  level = zones.rootMost?.level {
                gCurrentBrowseLevel = level
            }

			gSignal([.spCrumbs, .sDetails, .spSmallMap, .spPreferences])                // so color wells and breadcrumbs are updated
        }
    }
    
    func firstGrab(using: ZoneArray? = nil) -> Zone? {
		let grabs    = (using == nil || using!.count == 0) ? currentGrabs : using!
		var grabbed  = grabs.first

        if  grabbed == nil || grabbed!.recordName == nil {
            grabbed  = currentMoveableMaybe ?? gHereMaybe
        }
        
        return grabbed
    }
    
    
    private func lastGrab(using: ZoneArray? = nil) -> Zone {
        let grabs = using == nil ? currentGrabs : using!
		var grabbed = grabs.last
        
        if  grabbed == nil || grabbed!.recordName == nil {
            grabbed = gHere
        }
        
        return grabbed!
    }


    func deselectGrabsWithin(_ zone: Zone) {
        zone.traverseAllProgeny { iZone in
            if iZone != zone && currentMapGrabs.contains(iZone), let index = currentMapGrabs.firstIndex(of: iZone) {
				currentMapGrabs.remove(at: index)
            }
        }
    }

	func swapGrabsFrom(_ fromID: ZDatabaseID, toID: ZDatabaseID, _ createNewGroup: Bool = false) {
		if  let toRecords = toID.zRecords,
			var moveInto  = toRecords.hereZoneMaybe,
			let fromRoot  = fromID.zRecords?.rootZone {
			var moveThese = [Zone]()

			for grab in currentMapGrabs {
				if  let grabRoot = grab.root,
					grabRoot == fromRoot {
					moveThese.appendUnique(item: grab)
				}
			}

			if  createNewGroup {
				moveInto  = Zone.uniqueZoneNamed(nil, databaseID: toID)

				moveInto.moveZone(to: toRecords.rootZone)

				if  gFavorites == toRecords {
					gFavorites.setHere(to: moveInto)
				}
			}

			for mover in moveThese {
				mover.moveZone(to: moveInto)   // move mover into to
			}
		}
	}

    // MARK: - internals
    // MARK: -

    
    func updateCousinListForNewGrab() {
        if  let   grab = hasNewGrab ?? firstGrab() {
            hasNewGrab = nil

            updateCousinList(for: grab)
        }
    }
    
    
    func updateCurrentBrowserLevel() {
        if  let level = currentMapGrabs.rootMost?.level {
            gCurrentBrowseLevel = level
        }
    }
    
    
    func updateCousinList(for iZone: Zone? = nil) {
        _cousinList .removeAll()
        _sortedGrabs.removeAll()
        
        if  let level = gCurrentBrowseLevel,
            let start = traversalStart {
            start.traverseAllVisibleProgeny { iChild in
                let  cLevel  = iChild.level

                if   cLevel == level ||
                    (cLevel  < level && (iChild.count == 0 || !iChild.isExpanded)) {
                    _cousinList.append(iChild)
                }
                
                if  currentMapGrabs.contains(iChild) {
                    _sortedGrabs.append(iChild)
                }
            }
        }
    }

    func updateSortedGrabs() {
        _sortedGrabs.removeAll()
        
		if  let start = traversalStart {
            start.traverseAllProgeny { iChild in
                if  currentMapGrabs.contains(iChild) {
                    _sortedGrabs.append(iChild)
                }
            }
        }
    }
    
}
