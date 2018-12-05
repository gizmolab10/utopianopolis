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


    static func == ( left: ZSnapshot, right: ZSnapshot) -> Bool {
        let   goodIDs = left.databaseID != nil && right.databaseID != nil
        let  goodHere = left      .here != nil && right      .here != nil
        let sameCount = left.currentGrabs.count == right.currentGrabs.count

        if  goodHere && goodIDs && sameCount {
            let sameHere = left.here == right.here
            let  sameIDs = left.databaseID == right.databaseID

            if sameHere && sameIDs {
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


    var        hasGrab : Bool { return currentGrabs.count > 0 }
    var pasteableZones = [Zone: (Zone?, Int?)] ()
    var   currentGrabs = [Zone] ()
    var    cousinsList = [Zone] ()

    
    var sortedGrabs: [Zone] {
        var grabs = [Zone]()
        
        updateCousinsList(for: (currentGrabs.count == 0) ? nil : currentGrabs[0])
        
        for zone in cousinsList {
            if  currentGrabs.contains(zone) {
                grabs.append(zone)
            }
        }
        
        return grabs
    }
    

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


    var currentGrabsHaveVisibleChildren: Bool {
        for     grab in currentGrabs {
            if  grab.count > 0 &&
                grab.showingChildren {
                return true
            }
        }

        return false
    }


    var grabbedColor: ZColor {
        get { return firstGrab.color }
        set {
            for grab in currentGrabs {
                grab.color = newValue
            }
        }
    }


    var firstGrab: Zone {
        let grabs = sortedGrabs
        let count = grabs.count
        var grabbed: Zone?

        if  count > 0 {
            grabbed = grabs[0]
        }

        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }

        return grabbed!
    }


    var lastGrab: Zone {
        let grabs = sortedGrabs
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


    var rootMostMoveable: Zone {
        var candidate = currentMoveable

        for grabbed in currentGrabs {
            if  grabbed.level < candidate.level {
                candidate = grabbed
            }
        }

        return candidate
    }


    var currentMoveable: Zone {
        var movable: Zone?

        if currentGrabs.count > 0 {
            movable = firstGrab
        } else if let zone = gTextEditor.currentlyEditingZone {
            movable = zone
        }

        if  movable == nil {
            movable = gHere
        }

        return movable!
    }
    

    // MARK:- convenience
    // MARK:-


    func clearGrab()   { currentGrabs          = [ ] }
    func clearPaste()  { pasteableZones        = [:] }
    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || gTextEditor.currentlyEditingZone == zone }
    func isGrabbed (_ zone: Zone) -> Bool { return currentGrabs.contains(zone) }


    func setHereRecordName(_ iName: String, for databaseID: ZDatabaseID) {
        if  let         index = index(of: databaseID) {
            var    references = gHereRecordNames.components(separatedBy: kSeparator)
            references[index] = iName
            gHereRecordNames  = references.joined(separator: kSeparator)
        }
    }


    func hereRecordName(for databaseID: ZDatabaseID) -> String? {
        let references = gHereRecordNames.components(separatedBy: kSeparator)

        if  let  index = index(of: databaseID) {
            return references[index]
        }

        return nil
    }


    // MARK:- selection
    // MARK:-


    func deselectGrabs(retaining zones: [Zone]? = nil) {
        var grabbed = currentGrabs

        clearGrab()

        if let more = zones {
            grabbed += more

            currentGrabs.append(contentsOf: more)
        }

        for zone in grabbed {
            if  let widget = zone.widget {
                widget.dragDot.innerDot?.setNeedsDisplay()
                widget                  .setNeedsDisplay()
            }
        }
    }


    func deselect(retaining zones: [Zone]? = nil) {
        gTextEditor.stopCurrentEdit()
        deselectGrabs(retaining: zones)
    }


    func updateWidgetFor(_ zone: Zone?) {
        if  zone != nil, let widget = zone!.widget {
            widget                  .setNeedsDisplay()
            widget.dragDot.innerDot?.setNeedsDisplay()
        }
    }


    func ungrab(_ iZone: Zone?) {
        if let zone = iZone, let index = currentGrabs.index(of: zone) {
            currentGrabs.remove(at: index)
            updateWidgetFor(zone)
        }
    }


    func respectOrder(for zones: [Zone]) -> [Zone] {
        return zones.sorted { (a, b) -> Bool in
            return a.order < b.order || a.level < b.level // compare levels from multiple parents
        }
    }


    func addMultipleToGrab(_ iZones: [Zone]) {
        for zone in iZones {
            addToGrab(zone)
        }
    }


    func addToGrab(_ iZone: Zone?, onlyOne: Bool = false) {
        if  let zone = iZone, (!currentGrabs.contains(zone) || onlyOne) { // if onlyOne AND already grabbed, shrink grab list to iZone
            gTextEditor.stopCurrentEdit()

            if  onlyOne {
                deselectGrabs()
            }

            currentGrabs.append(zone)

            currentGrabs = respectOrder(for: currentGrabs)

            for grab in currentGrabs {
                updateWidgetFor(grab)
            }
        }
    }


    func grab(_ zone: Zone?) {
        addToGrab(zone!, onlyOne: true)
        updateCousinsList(for: zone)
    }


    func deselectDragWithin(_ zone: Zone) {
        zone.traverseAllProgeny { iZone in
            if iZone != zone && currentGrabs.contains(iZone), let index = currentGrabs.index(of: iZone) {
                currentGrabs.remove(at: index)
            }
        }
    }


    // MARK:- internals
    // MARK:-

    
    func updateCousinsList(for lastGrab: Zone?) {
        cousinsList.removeAll()

        if  let  grab = lastGrab {
            let level = grab.level
            let start = grab.isInFavorites ? gFavoritesRoot : gHere
            
            start?.traverseAllVisibleProgeny { iZone in
                if  iZone.level == level || (iZone.level < level && (iZone.count == 0 || !iZone.showingChildren)) {
                    cousinsList.append(iZone)
                }
            }
        }
    }
    
}
