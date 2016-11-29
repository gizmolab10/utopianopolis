//
//  ZSelectionManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZSelectionManager: NSObject {


    var currentlyGrabbedZones: [Zone] = []
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
                controllersManager.signal(zone, regarding: .datum)
            }
        }
    }


    func fullResign() {
        mainWindow?.makeFirstResponder(nil) // ios broken
    }


    func deselect() {
        let             zone = currentlyEditingZone
        currentlyEditingZone = nil

        if zone == nil || zone == travelManager.hereZone {
            controllersManager.signal(nil, regarding: .data)
        } else if let widget = widgetsManager.widgetForZone(zone) {
            widget.textField.captureText()
            controllersManager.signal(zone, regarding: .datum)
        }

        fullResign()
        deselectDrags()
    }


    func isGrabbed(_ zone: Zone) -> Bool {
        return currentlyGrabbedZones.contains(zone)
    }


    func deselectDragWithin(_ zone: Zone) {
        for child in zone.children {
            if currentlyGrabbedZones.contains(child) {
                if let index = currentlyGrabbedZones.index(of: child) {
                    currentlyGrabbedZones.remove(at: index)
                }
            }

            deselectDragWithin(child)
        }
    }


    var firstGrabbableZone: Zone? {
        get {
            var grabbable: Zone? = nil

            if currentlyGrabbedZones.count > 0 {
                grabbable = currentlyGrabbedZones[0]
            } else {
                grabbable = travelManager.hereZone
            }

            return grabbable
        }
    }


    var currentlyMovableZone: Zone? {
        get {
            var movable: Zone?

            if currentlyGrabbedZones.count > 0 {
                movable = currentlyGrabbedZones[0]
            } else if currentlyEditingZone != nil {
                movable = currentlyEditingZone
            } else {
                movable = travelManager.hereZone
            }

            return movable!
        }
    }
}
