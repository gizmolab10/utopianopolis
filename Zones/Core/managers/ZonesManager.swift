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


    var                widgets: [Zone : ZoneWidget]   = [:]
    var               closures: [UpdateClosureObject] = []
    var              _rootZone: Zone!
    var  _currentlyEditingZone: Zone?
    var _currentlyGrabbedZones: [Zone]                = []


    var rootZone: Zone! {
        set { _rootZone = newValue }
        get {
            if  _rootZone == nil {
                _rootZone = Zone(record: nil, database: cloudManager.currentDB)
            }

            return _rootZone
        }
    }


    var currentlyEditingZone: Zone? {
        get {
            return _currentlyEditingZone
        }

        set {
            if  _currentlyEditingZone != newValue {
                _currentlyEditingZone  = newValue

                for zone in currentlyGrabbedZones {
                    if zone != _currentlyEditingZone {
                        updateToClosures(zone, regarding: .datum)
                    }
                }

                currentlyGrabbedZones = []

            }
        }
    }


    var currentlyGrabbedZones: [Zone] {
        get { return _currentlyGrabbedZones }
        set { _currentlyGrabbedZones = newValue; }
    }


    func deselect() {
        let               zone = currentlyMovableZone
        _currentlyEditingZone  = nil
        _currentlyGrabbedZones = []

        widgetForZone(rootZone)?.stopEditingRecursively()

        if zone != nil {
            updateToClosures(zone, regarding: .datum)
        }
    }


    func isGrabbed(zone: Zone) -> Bool {
        return currentlyGrabbedZones.contains(zone)
    }


    var currentlyMovableZone: Zone? {
        get {
            var movable: Zone?

            if currentlyGrabbedZones.count > 0 {
                movable = currentlyGrabbedZones[0]
            } else if currentlyEditingZone != nil {
                movable = currentlyEditingZone
            } else {
                movable = rootZone
            }

            return movable!
        }
    }


    var canDelete: Bool {
        get {
            return (currentlyEditingZone != nil     &&  currentlyEditingZone != rootZone) ||
                (   currentlyGrabbedZones.count > 0 && !currentlyGrabbedZones.contains(rootZone))
        }
    }


    // MARK:- widgets
    // MARK:-


    func clearWidgets() {
        widgets.removeAll()
    }


    func registerWidget(_ widget: ZoneWidget) {
        widgets[widget.widgetZone] = widget
    }


    func widgetForZone(_ zone: Zone) -> ZoneWidget? {
        return widgets[zone]
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
        persistenceManager.save()
        cloudManager.flushOnCompletion {}
    }


    func saveAndUpdateFor(_ zone: Zone?) {
        saveAndUpdateFor(zone, onCompletion: nil)
    }

    
    // MARK:- editing, moving and revealing
    // MARK:-


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


    func toggleChildrenVisibility(_ ofZone: Zone?) {
        if ofZone != nil {
            ofZone?.showChildren = (ofZone?.showChildren == false)

            deselectDragWithin(ofZone!)
            updateToClosures(nil, regarding: .data)
            persistenceManager.save()
        }
    }


    func takeAction(_ action: ZEditAction) {
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
        addZoneTo(currentlyMovableZone)
    }


    func addZoneTo(_ parentZone: Zone?) {
        if parentZone != nil {
            let record = CKRecord(recordType: zoneTypeKey)
            let   zone = Zone(record: record, database: cloudManager.currentDB)

            widgetForZone(parentZone!)?.stopEditing()
            parentZone?.children.append(zone)

            _currentlyEditingZone    = zone
            parentZone?.showChildren = true
            parentZone?.recordState  = .needsSave
            zone.recordState         = .needsSave
            zone.parentZone          = parentZone

            saveAndUpdateFor(parentZone, onCompletion: { () -> (Void) in
                let when = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: when) {
                    self.widgetForZone(zone)?.textField.becomeFirstResponder()
                }
            })
        }
    }


    func delete() {
        if let zone: Zone = currentlyEditingZone {
            deleteZone(zone)

            currentlyEditingZone = nil
        } else {
            deleteZones(currentlyGrabbedZones)

            _currentlyGrabbedZones = []
        }

        saveAndUpdateFor(nil)
    }


    private func deleteZones(_ zones: [Zone]) {
        for zone in zones {
            deleteZone(zone)
        }
    }


    private func deleteZone(_ zone: Zone) {
        if let        parentZone = zone.parentZone {
            let            index = parentZone.children.index(of: zone)
            zone.recordState     = .needsDelete

            parentZone.children.remove(at: index!)
        }
    }


    func moveUp(_ moveUp: Bool) {
        if let        zone: Zone = currentlyMovableZone {
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
        if let            zone: Zone = currentlyMovableZone {
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
                        zone.parentZone          = siblingZone

                        saveAndUpdateFor(parentZone)
                    }
                }
            }
        }
    }


    func moveToParent() {
        if let              zone: Zone = currentlyMovableZone {
            if let          parentZone = zone.parentZone {
                if let grandParentZone = parentZone.parentZone {
                    let          index = parentZone.children.index(of: zone)

                    parentZone.children.remove(at: index!)
                    grandParentZone.children.append(zone)

                    parentZone.recordState      = .needsSave
                    grandParentZone.recordState = .needsSave
                    zone.parentZone             = grandParentZone

                    saveAndUpdateFor(grandParentZone)
                }
            }
        }
    }
}
