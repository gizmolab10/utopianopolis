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
            let show = zone?.showChildren == false

            setChildrenVisibilityTo(show, zone: zone, recursively: false)

            if !show {
                selectionManager.deselectDragWithin(zone!)
            }

            controllersManager.saveAndUpdateFor(nil)
        }
    }


    func move(_ arrow: ZArrowKey, modifierFlags: ZKeyModifierFlags) {
        let isOption = modifierFlags.contains(.option)

        if modifierFlags.contains(.shift) {
            if let zone = selectionManager.currentlyMovableZone {

                switch arrow {
                case .right: setChildrenVisibilityTo(true,  zone: zone, recursively: isOption);                                            break
                case .left:  setChildrenVisibilityTo(false, zone: zone, recursively: isOption); selectionManager.deselectDragWithin(zone); break
                default: return
                }

                controllersManager.saveAndUpdateFor(nil)
            }
        } else {
            switch arrow {
            case .right: moveIntoSibling(selectionOnly: !isOption); break
            case .left:     moveToParent(selectionOnly: !isOption); break
            case .down:    moveUp(false, selectionOnly: !isOption); break
            case .up:      moveUp(true,  selectionOnly: !isOption); break
            }
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


    func moveUp(_ moveUp: Bool, selectionOnly: Bool) {
        if let        zone: Zone = selectionManager.currentlyMovableZone {
            if let    parentZone = zone.parentZone {
                if let     index = parentZone.children.index(of: zone) {
                    let newIndex = index + (moveUp ? -1 : 1)

                    if newIndex >= 0 && newIndex < parentZone.children.count {
                        if selectionOnly {
                            selectionManager.currentlyGrabbedZones = [parentZone.children[newIndex]]
                        } else {
                            parentZone.children.remove(at: index)
                            parentZone.children.insert(zone, at:newIndex)
                        }

                        controllersManager.updateToClosures(parentZone, regarding: .data)
                    }
                }
            }
        }
    }


    func moveIntoSibling(selectionOnly: Bool) {
        if let                                  zone: Zone = selectionManager.currentlyMovableZone {
            if selectionOnly {
                if zone.children.count > 0 {
                    selectionManager.currentlyGrabbedZones = [zone.children.last!]
                    zone.showChildren                      = true

                    controllersManager.updateToClosures(zone, regarding: .data)
                }
            } else if let                       parentZone = zone.parentZone {
                if let                               index = parentZone.children.index(of: zone) {
                    let                       siblingIndex = index - 1

                    if siblingIndex                       >= 0 {
                        let                    siblingZone = parentZone.children[siblingIndex]
                        siblingZone.showChildren           = true

                        parentZone.children.remove(at: index)
                        siblingZone.children.append(zone)

                        siblingZone.recordState            = .needsSave
                        parentZone.recordState             = .needsSave
                        zone.recordState                   = .needsSave
                        zone.parentZone                    = siblingZone

                        controllersManager.saveAndUpdateFor(parentZone)
                    }
                }
            }
        }
    }


    func moveToParent(selectionOnly: Bool) {
        if let                                  zone: Zone = selectionManager.currentlyMovableZone {
            if let                              parentZone = zone.parentZone {
                if selectionOnly {
                    selectionManager.currentlyGrabbedZones = [parentZone]

                    controllersManager.updateToClosures(parentZone, regarding: .data)
                } else if let              grandParentZone = parentZone.parentZone {
                    let                              index = parentZone.children.index(of: zone)
                    grandParentZone.recordState            = .needsSave
                    parentZone.recordState                 = .needsSave
                    zone.recordState                       = .needsSave
                    zone.parentZone                        = grandParentZone

                    grandParentZone.children.append(zone)
                    parentZone.children.remove(at: index!)
                    controllersManager.saveAndUpdateFor(grandParentZone)
                }
            }
        }
    }
}
