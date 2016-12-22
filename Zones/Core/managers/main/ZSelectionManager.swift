//
//  ZSelectionManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZSelectionManager: NSObject {


    var currentlyGrabbedZones = [Zone] ()
    var  currentlyEditingZone: Zone?


    func clear() {
        currentlyEditingZone  = nil
        currentlyGrabbedZones = []
    }


    func deselectDrags() {
        let             zones = currentlyGrabbedZones
        currentlyGrabbedZones = []

        for zone in zones {
            if zone != currentlyEditingZone {
                signal(zone, regarding: .datum)
            }
        }
    }


    func fullResign() {
        #if os(OSX)
        mainWindow.makeFirstResponder(nil) // ios broken
        #endif
    }


    func deselect() {
        let             zone = currentlyEditingZone
        currentlyEditingZone = nil

        if zone == nil || zone == travelManager.hereZone {
            signal(nil, regarding: .data)
        } else if let widget = widgetsManager.widgetForZone(zone) {
            widget.textWidget.captureText()
            signal(zone, regarding: .datum)
        }

        fullResign()
        deselectDrags()
    }


    func ungrab(_ zone: Zone?) {
        if zone != nil, let index = currentlyGrabbedZones.index(of: zone!) {
            currentlyGrabbedZones.remove(at: index)
        }
    }


    func grab(_ zone: Zone?) {
        if zone != nil {
            currentlyGrabbedZones = [zone!]
        }
    }


    func isGrabbed(_ zone: Zone) -> Bool {
        return currentlyGrabbedZones.contains(zone)
    }


    func deselectDragWithin(_ zone: Zone) {
        for child in zone.children {
            if child != zone {
                if currentlyGrabbedZones.contains(child) {
                    if let index = currentlyGrabbedZones.index(of: child) {
                        currentlyGrabbedZones.remove(at: index)
                    }
                }

                deselectDragWithin(child)
            }
        }
    }
    

    var firstGrabbableZone: Zone? {
        get {
            var grabbable: Zone? = nil

            if currentlyGrabbedZones.count > 0 {
                grabbable = currentlyGrabbedZones[0]
            }

            if grabbable == nil { // || (grabbable?.parentZone != nil && travelManager.storageMode != grabbable?.parentZone?.storageMode) {
                grabbable = travelManager.hereZone
            }

            return grabbable
        }
    }


    var currentlyMovableZone: Zone? {
        get {
            var movable: Zone? = nil

            if currentlyGrabbedZones.count > 0 {
                movable = currentlyGrabbedZones[0]
            } else if currentlyEditingZone != nil {
                movable = currentlyEditingZone
            }

            if movable == nil || (movable?.parentZone != nil && travelManager.storageMode != movable?.parentZone?.storageMode) {
                movable = travelManager.hereZone
            }

            return movable!
        }
    }
}
