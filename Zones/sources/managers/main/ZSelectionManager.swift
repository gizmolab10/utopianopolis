//
//  ZSelectionManager.swift
//  Zones
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


class ZSelectionManager: NSObject {


    var                hasGrab:   Bool { return currentGrabs.count > 0 }
    var isEditingStateChanging:   Bool               = false
    var   currentlyEditingZone:   Zone?              = nil
    var         pasteableZones = [Zone: (Zone?, Int?)] ()


    var currentGrabs: [Zone] {
        get { return gManifest.currentGrabs            }
        set {        gManifest.currentGrabs = newValue }
    }


    var simplifiedGrabs: [Zone] {
        let current = currentGrabs
        var   grabs = [Zone] ()

        for grab in current {
            var found = false

            grab.traverseAncestors() { iZone -> ZTraverseStatus in
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


    var currentGrabsHaveChildren: Bool {
        for grab in currentGrabs {
            if grab.count > 0 {
                return true
            }
        }

        return false
    }


    var firstGrab: Zone {
        var grabbed: Zone? = nil

        if  currentGrabs.count > 0 {
            grabbed = currentGrabs[0]
        }

        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }

        return grabbed!
    }


    var lastGrab: Zone {
        var grabbed: Zone? = nil
        let count = currentGrabs.count

        if  count > 0 {
            grabbed = currentGrabs[count - 1]
        }

        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }

        return grabbed!
    }


    var rootMostMoveable: Zone {
        var candidate = currentMoveable

        for grabbed in currentGrabs {
            if  grabbed.parentZone != nil && grabbed.level < candidate.level {
                candidate = grabbed
            }
        }

        return candidate
    }


    var currentMoveable: Zone {
        var movable: Zone? = nil

        if currentGrabs.count > 0 {
            movable = firstGrab
        } else if currentlyEditingZone != nil {
            movable = currentlyEditingZone
        }

        if  movable == nil {
            movable = gHere
        }

        return movable!
    }


    func clearGrab()   { currentGrabs          = [ ] }
    func clearPaste()  { pasteableZones        = [:] }
    func clearEdit()   { currentlyEditingZone  = nil }
    func fullResign()  { assignAsFirstResponder (nil) } // ios broken
    func editCurrent() { edit(currentMoveable) }
    func isEditing (_ zone: Zone) -> Bool { return currentlyEditingZone == zone }
    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || isEditing(zone) }
    func isGrabbed (_ zone: Zone) -> Bool { return currentGrabs.contains(zone) }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        FOREGROUND(after: 0.1) {
            self.isEditingStateChanging = false
        }
    }


    func edit(_ iZone: Zone) {
        if  let textWidget = iZone.widget?.textWidget, textWidget.window != nil, !textWidget.isTextEditing, !isEditingStateChanging {
            assignAsFirstResponder(textWidget)
            deferEditingStateChange()
            deselectGrabs()

            currentlyEditingZone = iZone
        }
    }


    func stopCurrentEdit() {
        if currentlyEditingZone != nil {
            stopEdit(for: currentlyEditingZone!)
        }
    }


    func stopEdit(for iZone: Zone) {
        if  let textWidget = iZone.widget?.textWidget, textWidget.isTextEditing, !isEditingStateChanging {
            clearEdit()
            fullResign()
        }
    }
    

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
        if  let editingZone = currentlyEditingZone {
            if  let  widget = editingZone.widget {
                widget.setNeedsDisplay()
                widget.textWidget.captureText(force: false)
            }

            clearEdit()
        }

        fullResign()
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
            //columnarReport("grab -", zone.unwrappedName)
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


    func addToGrab(_ iZone: Zone?) {
        if let zone = iZone, !currentGrabs.contains(zone) {
            stopCurrentEdit()
            currentGrabs.append(zone)
            // columnarReport("grab", zone.unwrappedName)

            currentGrabs = respectOrder(for: currentGrabs)

            for grab in currentGrabs {
                updateWidgetFor(grab)
            }
        }
    }


    func grab(_ zone: Zone?) {
        deselectGrabs()
        addToGrab(zone!)
    }


    func deselectDragWithin(_ zone: Zone) {
        zone.traverseAllProgeny { iZone in
            if iZone != zone && currentGrabs.contains(iZone), let index = currentGrabs.index(of: iZone) {
                currentGrabs.remove(at: index)
            }
        }
    }
}
