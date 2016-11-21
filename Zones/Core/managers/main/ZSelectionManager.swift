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
                controllersManager.updateToClosures(zone, regarding: .datum)
            }
        }
    }


    func fullResign() {
        mainWindow?.makeFirstResponder(nil) // ios broken
    }


    func deselect() {
        let             zone = currentlyEditingZone
        currentlyEditingZone = nil

        if zone == nil || zone == travelManager.rootZone {
            controllersManager.updateToClosures(nil, regarding: .data)
        } else if let widget = widgetsManager.widgetForZone(zone) {
            widget.textField.captureText()
            controllersManager.updateToClosures(zone, regarding: .datum)
        }

        fullResign()
        deselectDrags()
    }


    func isGrabbed(zone: Zone) -> Bool {
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
    

    var currentlyMovableZone: Zone? {
        get {
            var movable: Zone?

            if currentlyGrabbedZones.count > 0 {
                movable = currentlyGrabbedZones[0]
            } else if currentlyEditingZone != nil {
                movable = currentlyEditingZone
            } else {
                movable = travelManager.rootZone
            }

            return movable!
        }
    }


    var canDelete: Bool {
        get {
            return (currentlyEditingZone != nil     &&  currentlyEditingZone != travelManager.rootZone!) ||
                (   currentlyGrabbedZones.count > 0 && !currentlyGrabbedZones.contains(travelManager.rootZone!))
        }
    }
    

}
