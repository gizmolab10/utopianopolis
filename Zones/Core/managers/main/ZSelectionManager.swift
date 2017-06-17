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
    var             isDragging:   Bool { return draggedZone != nil }
    var isEditingStateChanging:   Bool               = false
    var        dragDropIndices:   NSMutableIndexSet? = nil
    var           dragRelation:   ZRelation?         = nil
    var              dragPoint:   CGPoint?           = nil
    var   currentlyEditingZone:   Zone?              = nil
    var           dragDropZone:   Zone?              = nil
    var            draggedZone:   Zone?              = nil
    var         pasteableZones = [Zone] ()


    var currentGrabs: [Zone] {
        get { return gManifest.currentGrabs            }
        set {        gManifest.currentGrabs = newValue }
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
            if grabbed.level < candidate.level {
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

        if  movable == nil || (movable?.parentZone != nil && gStorageMode != movable?.parentZone?.storageMode) {
            movable = gHere
        }

        return movable!
    }


    func clearEdit()   { currentlyEditingZone  = nil }
    func clearGrab()   { currentGrabs = [] }
    func clearPaste()  { pasteableZones        = [] }
    func fullResign()  { assignAsFirstResponder (nil) } // ios broken
    func editCurrent() { edit(currentMoveable) }
    func isEditing (_ zone: Zone) -> Bool { return currentlyEditingZone == zone }
    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || isEditing(zone) }
    func isGrabbed (_ zone: Zone) -> Bool { return currentGrabs.contains(zone) }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        dispatchAsyncInForegroundAfter(0.1) {
            self.isEditingStateChanging = false
        }
    }


    func edit(_ iZone: Zone) {
        if  let textWidget = iZone.widget?.textWidget, !textWidget.isTextEditing, !isEditingStateChanging {
            currentlyEditingZone = iZone

            assignAsFirstResponder(textWidget)
            deferEditingStateChange()
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
            if  zone != currentlyEditingZone, let widget = zone.widget {
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
            columnarReport("grab -", zone.zoneName ?? "---")
        }
    }


    func respectOrder(for zones: [Zone]) -> [Zone] {
        return zones.sorted { (a, b) -> Bool in
            return a.order < b.order
        }
    }


    func addMultipleToGrab(_ iZones: [Zone]) {
        for zone in iZones {
            addToGrab(zone)
        }
    }


    func addToGrab(_ iZone: Zone?) {
        if let zone = iZone {
            stopCurrentEdit()
            currentGrabs.append(zone)

            currentGrabs = respectOrder(for: currentGrabs)

            updateWidgetFor(zone)
            // columnarReport("grab", zone.zoneName ?? "---")
        }
    }


    func grab(_ zone: Zone?) {
        deselectGrabs()
        addToGrab(zone!)
    }


    func deselectDragWithin(_ zone: Zone) {
        zone.traverseAll { iZone in
            if iZone != zone && currentGrabs.contains(iZone), let index = currentGrabs.index(of: iZone) {
                currentGrabs.remove(at: index)
            }
        }
    }
}
