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


    var                hasGrab:   Bool { return currentlyGrabbedZones.count > 0 }
    var             isDragging:   Bool { return draggedZone != nil }
    var isEditingStateChanging:   Bool               = false
    var        dragDropIndices:   NSMutableIndexSet? = nil
    var           dragRelation:   ZRelation?         = nil
    var              dragPoint:   CGPoint?           = nil
    var   currentlyEditingZone:   Zone?              = nil
    var           dragDropZone:   Zone?              = nil
    var            draggedZone:   Zone?              = nil
    var         pasteableZones = [Zone] ()


    var currentlyGrabbedZones: [Zone] {
        get { return gManifest.currentlyGrabbedZones            }
        set {        gManifest.currentlyGrabbedZones = newValue }
    }


    var firstGrabbedZone: Zone {
        var grabbed: Zone? = nil

        if  currentlyGrabbedZones.count > 0 {
            grabbed = currentlyGrabbedZones[0]
        }

        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }

        return grabbed!
    }


    var currentlyMovableZone: Zone {
        var movable: Zone? = nil

        if currentlyGrabbedZones.count > 0 {
            movable = firstGrabbedZone
        } else if currentlyEditingZone != nil {
            movable = currentlyEditingZone
        }

        if  movable == nil || (movable?.parentZone != nil && gStorageMode != movable?.parentZone?.storageMode) {
            movable = gHere
        }

        return movable!
    }


    func clearEdit()   { currentlyEditingZone  = nil }
    func clearGrab()   { currentlyGrabbedZones = [] }
    func clearPaste()  { pasteableZones        = [] }
    func fullResign()  { assignAsFirstResponder (nil) } // ios broken
    func editCurrent() { edit(currentlyMovableZone) }
    func isEditing (_ zone: Zone) -> Bool { return currentlyEditingZone == zone }
    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || isEditing(zone) }
    func isGrabbed (_ zone: Zone) -> Bool { return currentlyGrabbedZones.contains(zone) }


    func deferEditingStateChange() {
        isEditingStateChanging          = true

        dispatchAsyncInForegroundAfter(0.1) {
            self.isEditingStateChanging = false
        }
    }


    func edit(_ iZone: Zone) {
        if !isEditingStateChanging {
            currentlyEditingZone = iZone

            assignAsFirstResponder(iZone.widget?.textWidget)
            deferEditingStateChange()
        }
    }


    func stopEdit(for iZone: Zone) {
        if !isEditingStateChanging {
            clearEdit()
            fullResign()
        }
    }
    

    func deselectGrabs() {
        let grabbed = currentlyGrabbedZones

        clearGrab()

        for zone in grabbed {
            if  zone != currentlyEditingZone, let widget = zone.widget {
                widget.dragDot.innerDot?.setNeedsDisplay()
                widget                  .setNeedsDisplay()
            }
        }
    }


    func deselect() {
        if  let editingZone = currentlyEditingZone {
            if  let  widget = editingZone.widget {
                widget.setNeedsDisplay()
                widget.textWidget.captureText(force: false)
            }

            clearEdit()
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


    func addToGrab(_ iZone: Zone?) {
        if let zone = iZone {
            stopEdit(for: zone)
            currentlyGrabbedZones.append(zone)
            updateWidgetFor(zone)
        }
    }


    func grab(_ zone: Zone?) {
        deselectGrabs()
        addToGrab(zone!)
    }


    func deselectDragWithin(_ zone: Zone) {
        zone.traverseApply { iZone -> ZTraverseStatus in
            if iZone != zone && currentlyGrabbedZones.contains(iZone), let index = currentlyGrabbedZones.index(of: iZone) {
                currentlyGrabbedZones.remove(at: index)
            }

            return .eDescend
        }
    }
}
