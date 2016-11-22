//
//  ZEditingManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZEditingManager: NSObject {


    func setChildrenVisibilityTo(_ show: Bool, zone: Zone?, recursively: Bool) {
        if zone != nil {
            zone?.showChildren = show

            if recursively {
                for child: Zone in (zone?.children)! {
                    setChildrenVisibilityTo(show, zone: child, recursively: true)
                }
            }
        }
    }


    func toggleChildrenVisibility(_ zone: Zone?) {
        if zone != nil {
            setChildrenVisibilityTo(zone?.showChildren == false, zone: zone, recursively: false)

            selectionManager.deselectDragWithin(zone!)
            controllersManager.saveAndUpdateFor(nil)
        }
    }


    func move(_ arrow: ZArrowKey, modifierFlags: ZKeyModifierFlags) {
        let isOption = modifierFlags.contains(.option)

        if modifierFlags.contains(.shift) {
            if selectionManager.currentlyGrabbedZones.count > 0 {
                let zone = selectionManager.currentlyGrabbedZones[0]

                switch arrow {
                case .right: setChildrenVisibilityTo(true,  zone: zone, recursively: isOption); break
                case .left:  setChildrenVisibilityTo(false, zone: zone, recursively: isOption); break
                default: return
                }

                selectionManager.deselectDragWithin(zone)
                controllersManager.saveAndUpdateFor(nil)
            }
        } else if isOption {
            switch arrow {
            case .right: moveIntoSibling(); break
            case .left:     moveToParent(); break
            case .down:      moveUp(false); break
            case .up:        moveUp(true ); break
            }
        }
    }
    

    func editingAction(_ action: ZEditAction) {
        switch action {
        case .add:                         add(); break
        case .delete:                   delete(); break
        case .moveUp:               moveUp(true); break
        case .moveDown:            moveUp(false); break
        case .moveToParent:       moveToParent(); break
        case .moveIntoSibling: moveIntoSibling(); break
        }
    }


    func normalize() {
        widgetsManager.clear()
        travelManager.rootZone.normalize()
        controllersManager.saveAndUpdateFor(nil)
    }


    func add() {
        addZoneTo(selectionManager.currentlyMovableZone)
    }


    func addZoneTo(_ parentZone: Zone?) {
        if parentZone != nil {
            let record = CKRecord(recordType: zoneTypeKey)
            let   zone = Zone(record: record, storageMode: cloudManager.storageMode)

            widgetsManager.widgetForZone(parentZone!)?.textField.stopEditing()
            parentZone?.children.append(zone)

            parentZone?.showChildren = true
            parentZone?.recordState  = .needsSave
            zone.recordState         = .needsSave
            zone.parentZone          = parentZone

            controllersManager.saveAndUpdateFor(parentZone, onCompletion: { () -> (Void) in
                self.dispatchAsyncInForegroundAfter(0.1, closure: {
                    widgetsManager.widgetForZone(zone)?.textField.becomeFirstResponder()
                })
            })
        }
    }


    func delete() {
        if let zone: Zone = selectionManager.currentlyEditingZone {
            deleteZone(zone)

            selectionManager.currentlyEditingZone = nil
        } else {
            deleteZones(selectionManager.currentlyGrabbedZones)

            selectionManager.currentlyGrabbedZones = []
        }

        controllersManager.saveAndUpdateFor(nil)
    }


    private func deleteZones(_ zones: [Zone]) {
        for zone in zones {
            deleteZone(zone)
        }
    }


    private func deleteZone(_ zone: Zone) {
        zone.recordState  = .needsDelete

        deleteZones(zone.children)

        if let parentZone = zone.parentZone {
            if let  index = parentZone.children.index(of: zone) {
                parentZone.children.remove(at: index)
            }
        }
    }


    func moveUp(_ moveUp: Bool) {
        if let        zone: Zone = selectionManager.currentlyMovableZone {
            if let    parentZone = zone.parentZone {
                if let     index = parentZone.children.index(of: zone) {
                    let newIndex = index + (moveUp ? -1 : 1)

                    if newIndex >= 0 && newIndex < parentZone.children.count {
                        parentZone.children.remove(at: index)
                        parentZone.children.insert(zone, at:newIndex)

                        zone.recordState = .needsSave

                        controllersManager.saveAndUpdateFor(parentZone)
                    }
                }
            }
        }
    }


    func moveIntoSibling() {
        if let            zone: Zone = selectionManager.currentlyMovableZone {
            if let        parentZone = zone.parentZone {
                if let         index = parentZone.children.index(of: zone) {
                    let siblingIndex = index - 1

                    if siblingIndex >= 0 {
                        let  siblingZone = parentZone.children[siblingIndex]

                        parentZone.children.remove(at: index)
                        siblingZone.children.append(zone)

                        siblingZone.showChildren = true
                        siblingZone.recordState  = .needsSave
                        parentZone.recordState   = .needsSave
                        zone.recordState         = .needsSave
                        zone.parentZone          = siblingZone
                        controllersManager.saveAndUpdateFor(parentZone)
                    }
                }
            }
        }
    }


    func moveToParent() {
        if let                       zone: Zone = selectionManager.currentlyMovableZone {
            if let                   parentZone = zone.parentZone {
                if let          grandParentZone = parentZone.parentZone {
                    let                   index = parentZone.children.index(of: zone)
                    grandParentZone.recordState = .needsSave
                    parentZone.recordState      = .needsSave
                    zone.recordState            = .needsSave
                    zone.parentZone             = grandParentZone

                    grandParentZone.children.append(zone)
                    parentZone.children.remove(at: index!)
                    controllersManager.saveAndUpdateFor(grandParentZone)
                }
            }
        }
    }
}
