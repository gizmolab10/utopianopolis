//
//  ZSelecting.swift
//  Thoughtful
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

    
    var currentGrabs = [Zone] ()
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


    var         hasGrab :  Bool  { return currentGrabs.count > 0 }
    var        lastGrab :  Zone  { return  lastGrab() }
    var       firstGrab :  Zone? { return firstGrab() }
    var  lastSortedGrab :  Zone  { return  lastGrab(using: sortedGrabs) }
    var firstSortedGrab :  Zone? { return firstGrab(using: sortedGrabs) }
    var      cousinList : [Zone] { get { maybeNewGrabUpdate(); return _cousinList  } set { _cousinList  = newValue }}
    var     sortedGrabs : [Zone] { get { updateSortedGrabs();  return _sortedGrabs } set { _sortedGrabs = newValue }}
    var  pasteableZones = [Zone: (Zone?, Int?)] ()
    var    currentGrabs = [Zone] ()
    var    _sortedGrabs = [Zone] ()
    var     _cousinList = [Zone] ()
    var      hasNewGrab :  Zone?


    var snapshot : ZSnapshot {
        let          snap = ZSnapshot()
        snap.currentGrabs = currentGrabs
        snap  .databaseID = gDatabaseID
        snap        .here = gCloud?.hereIsValid ?? false ? gHere : nil

        return snap
    }


    var writableGrabsCount: Int {
        var count = 0

        for zone in currentGrabs {
            if zone.isTextEditable {
                count += 1
            }
        }

        return count
    }


    var simplifiedGrabs: [Zone] {
        let current = currentGrabs
        var   grabs = [Zone] ()

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
    var possiblyAutoGrabbed: [Zone] {
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
                grab.color = newValue
            }
        }
    }
    

    var rootMostMoveable: Zone {
        var candidate = currentMoveable

        for grabbed in currentGrabs {
            if  grabbed.level < candidate.level {
                candidate = grabbed
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


    var currentMoveable: Zone {
        var movable: Zone?

        if  currentGrabs.count > 0 {
            movable = firstGrab
        } else if let zone = gTextEditor.currentlyEditingZone {
            movable = zone
        }

        if  movable == nil {
            movable = gHereMaybe
        }

        return movable!
    }
    

    // MARK:- convenience
    // MARK:-


    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || gTextEditor.currentlyEditingZone == zone }
    func isGrabbed (_ zone: Zone) -> Bool { return currentGrabs.contains(zone) }
    func updateBrowsingLevel()            { gCurrentBrowseLevel = currentMoveable.level }
    func clearPaste()                     { pasteableZones = [:] }
    
    
    func updateAfterMove() {
        updateBrowsingLevel()
        updateCousinList()
        gFavorites.updateFavoritesRedrawSyncRedraw()
    }
    
    
    func assureMinimalGrabs() {
        if  currentGrabs.count == 0 {
            grab([gHere])
        }
    }

    
    // MARK:- selection
    // MARK:-


    func ungrabAll(retaining: [Zone]? = nil) {
        let    isEmpty = retaining == nil || retaining!.count == 0
        let       more = isEmpty ? [] : retaining!
        let    grabbed = currentGrabs + more
        currentGrabs   = []
        sortedGrabs    = []
        cousinList     = []

        if !isEmpty {
            hasNewGrab = more[0]
        }
        
        currentGrabs.append(contentsOf: more)
        updateWidgets(for: grabbed)
    }
    
    
    func updateWidgets(for zones: [Zone]) {
        for zone in zones {
            updateWidget(for: zone)
        }
    }


    func updateWidget(for zone: Zone?) {
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
            updateWidget(for: zone)
            maybeClearBrowsingLevel()
        }
    }


    func respectOrder(for zones: [Zone]) -> [Zone] {
        return zones.sorted { (a, b) -> Bool in
            return a.order < b.order || a.level < b.level // compare levels from multiple parents
        }
    }


    func addMultipleGrabs(_ iZones: [Zone], startFresh: Bool = false) {
        for zone in iZones {
            addOneGrab(zone, startFresh: startFresh)
        }

        updateWidgets(for: currentGrabs)
    }


    // private because it doesn't update widgets

    private func addOneGrab(_ iZone: Zone?, startFresh: Bool = false) {
        if  let zone = iZone,
            (!currentGrabs.contains(zone) || startFresh) {
            gTextEditor.stopCurrentEdit()

            if  startFresh {
                ungrabAll()
                
                hasNewGrab = zone
            }

            currentGrabs.append(zone)

            currentGrabs = respectOrder(for: currentGrabs)
        }
    }
    
    
    func makeVisibleAndGrab(_ iZone: Zone?, updateBrowsingLevel: Bool = true) {
        makeVisible(iZone, updateBrowsingLevel: updateBrowsingLevel) {
            iZone?.grab()
        }
    }
    
    
    func makeVisible(_ iZone: Zone?, updateBrowsingLevel: Bool = true, onCompletion: Closure?) {
        if  let zone = iZone,
            let dbID = zone.databaseID,
            let target = gRemoteStorage.cloud(for: dbID)?.hereZone {
            zone.traverseAncestors { iAncestor -> ZTraverseStatus in
                if  iAncestor != zone {
                    iAncestor.revealChildren()
                }
                
                if  iAncestor == target {
                    return .eStop
                }
                
                return .eContinue
            }
            
            onCompletion?()
        }
    }
    
    
    func grab(_ iZones: [Zone]?, updateBrowsingLevel: Bool = true) {
        if  let newGrabs = iZones {
            let oldGrabs = currentGrabs
            currentGrabs = [] // can't use ungrabAll because we need to keep cousinList
            sortedGrabs  = []

            updateWidgets(for: oldGrabs)
            addMultipleGrabs(newGrabs, startFresh: true)

            if  updateBrowsingLevel,
                let 		  level = newGrabs.rootMost?.level {
                gCurrentBrowseLevel = level
            }
        }
    }
    
    
    private func firstGrab(using: [Zone]? = nil) -> Zone? {
        let grabs = using == nil ? currentGrabs : using!
        let count = grabs.count
        var grabbed: Zone?
        
        if  count > 0 {
            grabbed = grabs[0]
        }
        
        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHereMaybe
        }
        
        return grabbed
    }
    
    
    private func lastGrab(using: [Zone]? = nil) -> Zone {
        let grabs = using == nil ? currentGrabs : using!
        let count = grabs.count
        var grabbed: Zone?
        
        if  count > 0 {
            grabbed = grabs[count - 1]
        }
        
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


    // MARK:- internals
    // MARK:-

    
    func maybeNewGrabUpdate() {
        if  let grab = hasNewGrab {
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
        
        if  let level =  gCurrentBrowseLevel,
            let  zone = iZone ?? firstGrab,
            let start =  zone.isInFavorites ? gFavoritesRoot : gHereMaybe {
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
        
        if  let  zone = firstGrab {
            let start = zone.isInFavorites ? gFavoritesRoot : gHere
            
            start?.traverseAllVisibleProgeny { iChild in
                if  currentGrabs.contains(iChild) {
                    _sortedGrabs.append(iChild)
                }
            }
        }
    }
    
}
