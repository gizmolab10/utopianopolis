//
//  ZSelectionManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
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


class ZSelectionManager: NSObject {


    var               hasGrab:  Bool { return currentlyGrabbedZones.count > 0 }
    var            isDragging:  Bool { return zoneBeingDragged != nil }
    var       dragDropIndices:  NSMutableIndexSet? = nil
    var  currentlyEditingZone:  Zone?              = nil
    var      zoneBeingDragged:  Zone?              = nil
    var          dragDropZone:  Zone?              = nil
    var             dragPoint:  CGPoint?           = nil
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
                grabbable = gHere
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
                movable = gHere
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
            if  zone != currentlyEditingZone, let widget = zone.widget {
                widget.dragDot.innerDot?.setNeedsDisplay()
                widget                  .setNeedsDisplay()
            }
        }
    }


    func fullResign() {
        assignAsFirstResponder(nil) // ios broken
    }


    func deselect() {
        let      editingZone = currentlyEditingZone
        currentlyEditingZone = nil
        let           widget = editingZone?.widget
        widget?.setNeedsDisplay()

        if editingZone != nil && editingZone != gHere {
            widget?.textWidget.captureText()
        }

        fullResign()
        deselectGrabs()
    }


    func updateWidgetFor(_ zone: Zone?) {
        if  zone != nil, let widget = zone!.widget {
            widget                  .setNeedsDisplay()
            widget.dragDot.innerDot?.setNeedsDisplay()
        }
    }


    func ungrab(_ zone: Zone?) {
        if zone != nil, let index = currentlyGrabbedZones.index(of: zone!) {
            currentlyGrabbedZones.remove(at: index)
            updateWidgetFor(zone)
        }
    }


    func addToGrab(_ zone: Zone?) {
        if zone != nil {
            currentlyGrabbedZones.append(zone!)
            updateWidgetFor(zone)
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
