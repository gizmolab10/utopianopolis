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


    class UpdateClosureObject {
        let closure: UpdateClosure!

        init(iClosure: @escaping UpdateClosure) {
            closure = iClosure
        }
    }


    var               widgets: [CKRecordID : ZoneWidget] = [:]
    var              closures:     [UpdateClosureObject] = []
    var      _storageRootZone: Zone?
    var             _rootZone: Zone?


    func clear() {
        _rootZone             = nil
        _storageRootZone      = nil

        widgets.removeAll()
    }


    var rootZone: Zone! {
        set { _rootZone = newValue }
        get {
            if  _rootZone == nil {
                _rootZone = Zone(record: nil, storageMode: cloudManager.storageMode)
            }

            return _rootZone
        }
    }


    var storageRootZone: Zone! {
        set { _storageRootZone = newValue }
        get {
            if  _storageRootZone == nil {
                _storageRootZone = Zone(record: nil, storageMode: cloudManager.storageMode)
            }

            return _storageRootZone
        }
    }


    // MARK:- widgets
    // MARK:-


    func clearWidgets() {
        widgets.removeAll()
    }


    func registerWidget(_ widget: ZoneWidget) {
        if let zone = widget.widgetZone, let record = zone.record {
            widgets[record.recordID] = widget
        }
    }


    func widgetForZone(_ zone: Zone) -> ZoneWidget? {
        if let record = zone.record {
            return widgets[record.recordID]
        }

        return nil
    }


    // MARK:- closures
    // MARK:-


    func registerUpdateClosure(_ closure: @escaping UpdateClosure) {
        closures.append(UpdateClosureObject(iClosure: closure))
    }


    func updateToClosures(_ object: NSObject?, regarding: ZUpdateKind, onCompletion: Closure?) {
        DispatchQueue.main.async {
            for closureObject: UpdateClosureObject in self.closures {
                closureObject.closure(object, regarding)
            }

            if onCompletion != nil {
                onCompletion!()
            }
        }
    }


    func updateToClosures(_ object: NSObject?, regarding: ZUpdateKind) {
        updateToClosures(object, regarding: regarding, onCompletion: nil)
    }


    func saveAndUpdateFor(_ zone: Zone?, onCompletion: Closure?) {
        updateToClosures(zone, regarding: .data, onCompletion: onCompletion)
        zfileManager.save()
        cloudManager.flushOnCompletion {}
    }


    func saveAndUpdateFor(_ zone: Zone?) {
        saveAndUpdateFor(zone, onCompletion: nil)
    }

    
    // MARK:- editing, moving and revealing
    // MARK:-


    func toggleChildrenVisibility(_ ofZone: Zone?) {
        if ofZone != nil {
            ofZone?.showChildren = (ofZone?.showChildren == false)

            selectionManager.deselectDragWithin(ofZone!)
            saveAndUpdateFor(nil)
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

            widgetForZone(parentZone!)?.textField.stopEditing()
            parentZone?.children.append(zone)

            selectionManager.currentlyEditingZone = zone
            parentZone?.showChildren              = true
            parentZone?.recordState               = .needsSave
            zone.recordState                      = .needsSave
            zone.parentZone                       = parentZone

            saveAndUpdateFor(parentZone, onCompletion: { () -> (Void) in
                let when = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: when) {
                    self.widgetForZone(zone)?.textField.becomeFirstResponder()
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

        saveAndUpdateFor(nil)
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

                        saveAndUpdateFor(parentZone)
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

                        saveAndUpdateFor(parentZone)
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

                    saveAndUpdateFor(grandParentZone)
                }
            }
        }
    }
}
