//
//  ZSelectionManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


enum ZRelation: Int {
    case above
    case below
    case upon
}


class ZSelectionManager: NSObject {


    var               hasGrab:  Bool { return currentlyGrabbedZones.count > 0 }
    var     targetLineIndices:  NSMutableIndexSet?
    var  currentlyEditingZone:  Zone?
    var      zoneBeingDragged:  Zone?
    var        targetDropZone:  Zone?
    var       pasteableZones = [Zone] ()
    var currentlyGrabbedZones: [Zone] {
        get { return gTravelManager.manifest.currentlyGrabbedZones }
        set { gTravelManager.manifest.currentlyGrabbedZones = newValue }
    }


    var firstGrabbableZone: Zone {
        get {
            var grabbable: Zone? = nil

            if currentlyGrabbedZones.count > 0 {
                grabbable = currentlyGrabbedZones[0]
            }

            if grabbable == nil || grabbable?.record == nil {
                grabbable = gTravelManager.hereZone
            }

            return grabbable!
        }
    }


    var currentlyMovableZone: Zone {
        get {
            var movable: Zone? = nil

            if currentlyGrabbedZones.count > 0 {
                movable = currentlyGrabbedZones[0]
            } else if currentlyEditingZone != nil {
                movable = currentlyEditingZone
            }

            if movable == nil || (movable?.parentZone != nil && gStorageMode != movable?.parentZone?.storageMode) {
                movable = gTravelManager.hereZone
            }
            
            return movable!
        }
    }


    func clear() {
        currentlyEditingZone = nil
    }


    func clearGrab() {
        currentlyGrabbedZones = []
    }


    func clearPaste() {
        pasteableZones = []
    }


    func deselectGrabs() {
        let zones = currentlyGrabbedZones

        clearGrab()

        for zone in zones {
            if zone != currentlyEditingZone, let widget = gWidgetsManager.widgetForZone(zone) {
                widget.dragDot.innerDot?.needsDisplay = true
                widget                  .needsDisplay = true
            }
        }
    }


    func fullResign() {
        assignAsFirstResponder(nil) // ios broken
    }


    func deselect() {
        let      editingZone = currentlyEditingZone
        currentlyEditingZone = nil
        let           widget = gWidgetsManager.widgetForZone(editingZone)
        widget?.needsDisplay = true

        if editingZone != nil && editingZone != gTravelManager.hereZone {
            widget?.textWidget.captureText()
        }

        fullResign()
        deselectGrabs()
    }


    func ungrab(_ zone: Zone?) {
        if zone != nil, let index = currentlyGrabbedZones.index(of: zone!) {
            currentlyGrabbedZones.remove(at: index)
        }
    }


    func addToGrab(_ zone: Zone?) {
        if zone != nil {
            currentlyGrabbedZones.append(zone!)

            let                             widget = gWidgetsManager.widgetForZone(zone!)
            widget?                  .needsDisplay = true
            widget?.dragDot.innerDot?.needsDisplay = true
        }
    }


    func grab(_ zone: Zone?) {
        deselectGrabs()
        addToGrab(zone!)
    }


    func isEditing(_ zone: Zone) -> Bool {
        return currentlyEditingZone == zone
    }


    func isSelected(_ zone: Zone) -> Bool {
        return isGrabbed(zone) || isEditing(zone)
    }


    func isGrabbed(_ zone: Zone) -> Bool {
        return currentlyGrabbedZones.contains(zone)
    }


    func deselectDragWithin(_ zone: Zone) {
        zone.traverseApply { iZone -> Bool in
            if iZone != zone && currentlyGrabbedZones.contains(iZone), let index = currentlyGrabbedZones.index(of: iZone) {
                currentlyGrabbedZones.remove(at: index)
            }

            return false
        }
    }
}
