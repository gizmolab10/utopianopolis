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
                zonesManager.updateToClosures(zone, regarding: .datum)
            }
        }
    }


    func fullResign() {
        currentlyEditingZone = nil
        let           window = zonesManager.widgetForZone(zonesManager.rootZone)?.window

        window?.makeFirstResponder(nil) // ios broken
    }


    func deselect() {
        let             zone = currentlyEditingZone
        currentlyEditingZone = nil

        if zone == nil || zone == zonesManager.rootZone {
            zonesManager.updateToClosures(nil, regarding: .data)
        } else {
            let widget = zonesManager.widgetForZone(zone!)

            widget?.textField.captureText()
            zonesManager.updateToClosures(zone, regarding: .datum)
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
                movable = zonesManager.rootZone
            }

            return movable!
        }
    }


    var canDelete: Bool {
        get {
            return (currentlyEditingZone != nil     &&  currentlyEditingZone != zonesManager.rootZone) ||
                (   currentlyGrabbedZones.count > 0 && !currentlyGrabbedZones.contains(zonesManager.rootZone))
        }
    }
    

}
