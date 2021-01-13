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


enum ZRelation: Int {
    case above
    case below
    case upon
}

let gSelecting = ZSelecting()

class ZSnapshot: NSObject {

    var currentGrabs = ZoneArray ()
    var   databaseID : ZDatabaseID?
    var         here : Zone?
    var       isSame : Bool { return gSelecting.snapshot == self }

    static func == ( left: ZSnapshot, right: ZSnapshot) -> Bool {
        let   goodIDs = left.databaseID != nil && right.databaseID != nil
        let  goodHere = left      .here != nil && right      .here != nil
        let sameCount = left.currentGrabs.count == right.currentGrabs.count

        if  goodHere && goodIDs && sameCount {
            let sameHere = left.here == right.here
            let  sameIDs = left.databaseID == right.databaseID

            if  sameHere && sameIDs {
                for (index, grab) in left.currentGrabs.enumerated() {
                    if  grab != right.currentGrabs[index] {
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

    var         hasGrab :  Bool  { return  currentGrabs.count > 0 }
	var currentMoveable :  Zone  { return  currentMovableMaybe! }
    var        lastGrab :  Zone  { return  lastGrab() }
    var  lastSortedGrab :  Zone  { return  lastGrab(using: sortedGrabs) }
    var firstSortedGrab :  Zone? { return firstGrab(using: sortedGrabs) }
	var       firstGrab :  Zone? { return firstGrab() }
    var      cousinList : ZoneArray { get { maybeNewGrabUpdate(); return _cousinList  } set { _cousinList  = newValue }}
    var     sortedGrabs : ZoneArray { get { updateSortedGrabs();  return _sortedGrabs } set { _sortedGrabs = newValue }}
    var  pasteableZones = [Zone: (Zone?, Int?)] ()
    var    currentGrabs = ZoneArray ()
    var    _sortedGrabs = ZoneArray ()
    var     _cousinList = ZoneArray ()
    var      hasNewGrab :  Zone?

	var traversalStart : Zone? {
		var start: Zone?

		if  let zone = firstGrab {
			start = zone.isInFavorites ? gFavoritesRoot : zone.isInRecents ? gRecentsRoot : zone.isInLostAndFound ? gLostAndFound : gHereMaybe
		}

		return start
	}

    var snapshot : ZSnapshot {
        let          snap = ZSnapshot()
        snap.currentGrabs = currentGrabs
        snap  .databaseID = gDatabaseID
        snap        .here = gHereMaybe

        return snap
    }

    var writableGrabsCount: Int {
        var count = 0

        for zone in currentGrabs {
            if  zone.userCanWrite {
                count += 1
            }
        }

        return count
    }

    var simplifiedGrabs: ZoneArray {
        let current = currentGrabs
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

    var currentGrabsHaveVisibleChildren: Bool {
        for     grab in currentGrabs {
            if  grab.count > 0 &&
                grab.showingChildren {
                return true
            }
        }

        return false
    }

    var grabbedColor: ZColor? {
        get { return firstGrab?.color }
        set {
            for grab in currentGrabs {
				let  colorized = grab.colorized
                grab.color     = newValue
				grab.colorized = colorized
            }
        }
    }

    var rootMostMoveable: Zone? {
        var candidate = currentMovableMaybe

		if  let level = candidate?.level {
			for grabbed in currentGrabs {
				if  grabbed.level < level {
					candidate = grabbed
				}
			}
		}

        return candidate
    }
    
    var currentMoveableLine: Zone? {
        for grab in currentGrabs + [gHere] {
            if grab.zoneName?.isLineWithTitle ?? false {
                return grab
            }
        }
        
        return nil
    }

	var currentMovableMaybe: Zone? {
        var movable: Zone?

        if  currentGrabs.count > 0 {
            movable = firstGrab
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

    // MARK:- convenience
    // MARK:-

    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || gTextEditor.currentlyEditedZone == zone }
    func isGrabbed (_ zone: Zone) -> Bool { return currentGrabs.contains(zone) }
    func updateBrowsingLevel()            { gCurrentBrowseLevel = currentMoveable.level }
    func clearPaste()                     { pasteableZones = [:] }

    func updateAfterMove() {
        updateBrowsingLevel()
        updateCousinList()
        gFavorites.updateFavoritesAndRedraw()
    }
    
    func assureMinimalGrabs() {
        if  currentGrabs.count == 0,
			let here = gHereMaybe {
            grab([here])
        }
    }

    // MARK:- selection
    // MARK:-


    func ungrabAll(retaining: ZoneArray? = nil) {
        let       more = retaining ?? []
        let    grabbed = currentGrabs
        currentGrabs   = []
        sortedGrabs    = []
        cousinList     = []

		if  more.count > 0 {
            hasNewGrab = more[0]
        }

		updateWidgetsNeedDisplay(for: grabbed)
        currentGrabs.append(contentsOf: more)
    }
    
    
    func updateWidgetsNeedDisplay(for zones: ZoneArray) {
        for zone in zones {
            updateWidgetNeedDisplay(for: zone)
        }
    }


    func updateWidgetNeedDisplay(for zone: Zone?) {
        if  zone != nil, let widget = zone!.widget {
            widget                  .setNeedsDisplay()
            widget.dragDot.innerDot?.setNeedsDisplay()
        }
    }
    
    
    func maybeClearBrowsingLevel() {
        if  currentGrabs.count == 0 {
            gCurrentBrowseLevel = nil
        }
    }

    
    func ungrabAssuringOne(_ iZone: Zone?) {
        ungrab(iZone)
        
        if currentGrabs.count == 0 {
            grab([gHere])
        }
    }
    

    func ungrab(_ iZone: Zone?) {
        if let zone = iZone, let index = currentGrabs.firstIndex(of: zone) {
            currentGrabs.remove(at: index)
            updateWidgetNeedDisplay(for: zone)
            maybeClearBrowsingLevel()
        }
    }


    func respectOrder(for zones: ZoneArray) -> ZoneArray {
        return zones.sorted { (a, b) -> Bool in
            return a.order < b.order || a.level < b.level // compare levels from multiple parents
        }
    }

    func addMultipleGrabs(_ iZones: ZoneArray) {
		for zone in iZones {
            addOneGrab(zone)
        }

        updateWidgetsNeedDisplay(for: currentGrabs)
    }

    func addOneGrab(_ iZone: Zone?) { // caller must update widgets need display
        if  let zone = iZone,
			zone    != gFavoritesHereMaybe, // disallow grab on non-visible favorite, avoid ugly looking highlight
            !currentGrabs.contains(zone) {
            currentGrabs.append(zone)

            currentGrabs = respectOrder(for: currentGrabs)
        }
    }
    
	func zone(with recordName: String) -> Zone? {
		var found: Zone?

		for records in gRemoteStorage.allRecordsArrays {
			if  let zone = records.maybeZoneForRecordName(recordName) {
				found = zone

				break
			}
		}

		return found
	}

	@discardableResult func primitiveGrab(_ iZones: ZoneArray?) -> ZoneArray? {
		if  let newGrabs = iZones {
			let oldGrabs = currentGrabs
			currentGrabs = [] // can't use ungrabAll because we need to keep cousinList
			sortedGrabs  = []

			if  newGrabs.count != 0 {
				hasNewGrab = newGrabs[0]
			}

			addMultipleGrabs(newGrabs)

			return oldGrabs
		}

		return nil
	}
    
    func grab(_ iZones: ZoneArray?, updateBrowsingLevel: Bool = true) {
		if  let oldGrabs = primitiveGrab(iZones) {
            updateWidgetsNeedDisplay(for: oldGrabs)
			gSignal([.sPreferences]) // so color wells are updated

            if  updateBrowsingLevel,
                let 		  level = iZones?.rootMost?.level {
                gCurrentBrowseLevel = level
            }
        }
    }
    
    
    private func firstGrab(using: ZoneArray? = nil) -> Zone? {
		let   grabs = (using == nil || using!.count == 0) ? currentGrabs : using!
		var grabbed = grabs.first

        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHereMaybe ?? currentMovableMaybe
        }
        
        return grabbed
    }
    
    
    private func lastGrab(using: ZoneArray? = nil) -> Zone {
        let grabs = using == nil ? currentGrabs : using!
		var grabbed = grabs.last
        
        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }
        
        return grabbed!
    }


    func deselectGrabsWithin(_ zone: Zone) {
        zone.traverseAllProgeny { iZone in
            if iZone != zone && currentGrabs.contains(iZone), let index = currentGrabs.firstIndex(of: iZone) {
                currentGrabs.remove(at: index)
            }
        }
    }

	func swapGrabsFrom(_ fromID: ZDatabaseID, toID: ZDatabaseID) {
		if  let moveInto  =   toID.zRecords?.hereZoneMaybe,
			let fromRoot  = fromID.zRecords?.rootZone {
			var moveThese = [Zone]()

			for grab in currentGrabs {
				if  let grabRoot = grab.root,
					grabRoot == fromRoot {
					moveThese.appendUnique(contentsOf: [grab])
				}
			}

			for mover in moveThese {
				mover.moveZone(to: moveInto)   // move mover into to
			}
		}
	}

    // MARK:- internals
    // MARK:-

    
    func maybeNewGrabUpdate() {
        if  let   grab = hasNewGrab ?? firstGrab {
            hasNewGrab = nil

            updateCousinList(for: grab)
        }
    }
    
    
    func updateCurrentBrowserLevel() {
        if  let level = currentGrabs.rootMost?.level {
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
                    (cLevel  < level && (iChild.count == 0 || !iChild.showingChildren)) {
                    _cousinList.append(iChild)
                }
                
                if  currentGrabs.contains(iChild) {
                    _sortedGrabs.append(iChild)
                }
            }
        }
    }
    
    
    func updateSortedGrabs() {
        _sortedGrabs.removeAll()
        
		if  let start = traversalStart {
            start.traverseAllVisibleProgeny { iChild in
                if  currentGrabs.contains(iChild) {
                    _sortedGrabs.append(iChild)
                }
            }
        }
    }
    
}