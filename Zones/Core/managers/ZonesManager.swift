//
//  ZonesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZonesManager: NSObject {


    var storageRootZone: Zone! = Zone(record: nil, storageMode: cloudManager.storageMode)
    var        rootZone: Zone! = Zone(record: nil, storageMode: cloudManager.storageMode)


    func clear() {
        rootZone        = Zone(record: nil, storageMode: cloudManager.storageMode)
        storageRootZone = Zone(record: nil, storageMode: cloudManager.storageMode)
    }

    
    // MARK:- editing, moving and revealing
    // MARK:-


    func toggleChildrenVisibility(_ ofZone: Zone?) {
        if ofZone != nil {
            ofZone?.showChildren = (ofZone?.showChildren == false)

            selectionManager.deselectDragWithin(ofZone!)
            controllersManager.saveAndUpdateFor(nil)
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


    func add() {
        addZoneTo(selectionManager.currentlyMovableZone)
    }


    func addZoneTo(_ parentZone: Zone?) {
        if parentZone != nil {
            let record = CKRecord(recordType: zoneTypeKey)
            let   zone = Zone(record: record, storageMode: cloudManager.storageMode)

            widgetsManager.widgetForZone(parentZone!)?.textField.stopEditing()
            parentZone?.children.append(zone)

            selectionManager.currentlyEditingZone = zone
            parentZone?.showChildren              = true
            parentZone?.recordState               = .needsSave
            zone.recordState                      = .needsSave
            zone.parentZone                       = parentZone

            controllersManager.saveAndUpdateFor(parentZone, onCompletion: { () -> (Void) in
                let when = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: when) {
                    widgetsManager.widgetForZone(zone)?.textField.becomeFirstResponder()
                }
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
