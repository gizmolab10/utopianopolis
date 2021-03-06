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
	var hasMultipleGrab :  Bool  { return  currentGrabs.count > 1 }
	var currentMoveable :  Zone  { return  currentMovableMaybe! }
    var        lastGrab :  Zone  { return  lastGrab() }
    var  lastSortedGrab :  Zone  { return  lastGrab(using: sortedGrabs) }
    var firstSortedGrab :  Zone? { return firstGrab(using: sortedGrabs) }
	var       firstGrab :  Zone? { return firstGrab() }
	var      hasNewGrab :  Zone?
    var      cousinList : ZoneArray { get { maybeNewGrabUpdate(); return _cousinList }                               set { _cousinList     = newValue }}
	var     sortedGrabs : ZoneArray { get { updateSortedGrabs();  return _sortedGrabs }                              set { _sortedGrabs    = newValue }}
	var    currentGrabs : ZoneArray { get { return gIsEssayMode ? gEssayView?.grabbedZones ?? [] : currentMapGrabs } set { currentMapGrabs = newValue }}
    var currentMapGrabs = ZoneArray ()
    var    _sortedGrabs = ZoneArray ()
    var     _cousinList = ZoneArray ()
	var  pasteableZones = [Zone: (Zone?, Int?)] ()

	var traversalStart : Zone? {
		var start: Zone?

		if  let zone = firstGrab {
			start = zone.isInFavorites ? gFavoritesRoot : zone.isInRecents ? gRecentsRoot : zone.isInLostAndFound ? gLostAndFound : gHereMaybe
		}

		return start
	}

    var snapshot : ZSnapshot {
        let          snap = ZSnapshot()
        snap.currentGrabs = currentMapGrabs
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
        for     grab in currentMapGrabs {
            if  grab.count > 0 &&
                grab.expanded {
                return true
            }
        }

        return false
    }

    var grabbedColor: ZColor? {
        get { return firstGrab?.color }
        set {
            for grab in currentMapGrabs {
				let  colorized = grab.colorized
                grab.color     = newValue
				grab.colorized = colorized
            }
        }
    }

    var rootMostMoveable: Zone? {
        var candidate = currentMovableMaybe

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

	var currentMovableMaybe: Zone? {
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

			return pastable.ckRecordName
		}

		return nil
	}

    // MARK:- convenience
    // MARK:-

    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || gTextEditor.currentlyEditedZone == zone }
    func isGrabbed (_ zone: Zone) -> Bool { return currentMapGrabs.contains(zone) }
    func updateBrowsingLevel()            { gCurrentBrowseLevel = currentMoveable.level }
    func clearPaste()                     { pasteableZones = [:] }

	func updateAfterMove(_ selectionOnly: Bool = true, needsRedraw: Bool) {
		if !selectionOnly {
			currentMoveable.recount()
		}

		updateBrowsingLevel()
        updateCousinList()
        gFavorites.updateFavoritesAndRedraw(needsRedraw: needsRedraw)
    }
    
    func assureMinimalGrabs() {
        if  currentMapGrabs.count == 0,
			let here = gHereMaybe {
            grab([here])
        }
    }

	// MARK:- selection
	// MARK:-

    func ungrabAll(retaining: ZoneArray? = nil) {
        let        more = retaining ?? []
        let     grabbed = currentMapGrabs
		currentMapGrabs = []
        sortedGrabs     = []
        cousinList      = []

		if  more.count > 0 {
            hasNewGrab = more[0]
        }

		updateWidgetsNeedDisplay(for: grabbed)
		currentMapGrabs.append(contentsOf: more)
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
        if  currentMapGrabs.count == 0 {
            gCurrentBrowseLevel = nil
        }
    }

    
    func ungrabAssuringOne(_ iZone: Zone?) {
        ungrab(iZone)
        
        if  currentMapGrabs.count == 0 {
            grab([gHere])
        }
    }
    

    func ungrab(_ iZone: Zone?) {
        if let zone = iZone, let index = currentMapGrabs.firstIndex(of: zone) {
			currentMapGrabs.remove(at: index)
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

        updateWidgetsNeedDisplay(for: currentMapGrabs)
    }

    func addOneGrab(_ iZone: Zone?) { // caller must update widgets need display
        if  let zone = iZone,
//			zone    != gFavoritesHereMaybe, // disallow grab on non-visible favorite, avoid ugly looking highlight
            !currentMapGrabs.contains(zone) {
			currentMapGrabs.append(zone)

			currentMapGrabs = respectOrder(for: currentMapGrabs)
        }
    }
    
	@discardableResult func grabAndNoUI(_ iZones: ZoneArray?) -> ZoneArray? {
		if  let    newGrabs = iZones {
			let    oldGrabs = currentMapGrabs
			currentMapGrabs = [] // can't use ungrabAll because we need to keep cousinList
			sortedGrabs     = []

			if  newGrabs.count != 0 {
				hasNewGrab = newGrabs[0]
			}

			addMultipleGrabs(newGrabs)

			return oldGrabs
		}

		return nil
	}
    
    func grab(_ iZones: ZoneArray?, updateBrowsingLevel: Bool = true) {
		if  let oldGrabs = grabAndNoUI(iZones) {
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

        if  grabbed == nil || grabbed!.ckRecord == nil {
            grabbed = currentMovableMaybe ?? gHereMaybe
        }
        
        return grabbed
    }
    
    
    private func lastGrab(using: ZoneArray? = nil) -> Zone {
        let grabs = using == nil ? currentGrabs : using!
		var grabbed = grabs.last
        
        if  grabbed == nil || grabbed!.ckRecord == nil {
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

	func swapGrabsFrom(_ fromID: ZDatabaseID, toID: ZDatabaseID) {
		if  let moveInto  =   toID.zRecords?.hereZoneMaybe,
			let fromRoot  = fromID.zRecords?.rootZone {
			var moveThese = [Zone]()

			for grab in currentMapGrabs {
				if  let grabRoot = grab.root,
					grabRoot == fromRoot {
					moveThese.appendUnique(item: grab)
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
                    (cLevel  < level && (iChild.count == 0 || !iChild.expanded)) {
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
