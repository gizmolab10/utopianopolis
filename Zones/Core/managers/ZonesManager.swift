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
        get { return _currentlyEditingZone }
        set {
            _currentlyEditingZone = newValue;

            updateToClosures(nil, regarding: .data)
        }
    }


    var currentlyGrabbedZones: [Zone] {
        get { return _currentlyGrabbedZones }
        set { _currentlyGrabbedZones = newValue; updateToClosures(nil, regarding: .data) }
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


    func updateToClosures(_ object: NSObject?, regarding: ZUpdateKind) {
        DispatchQueue.main.async(execute: {
            //self.resetBadgeCounter()

            for closureObject: UpdateClosureObject in self.closures {
                closureObject.closure(object, regarding)
            }
        })
    }

    
    // MARK:- editing and moving
    // MARK:-


    func takeAction(_ action: ZEditAction) {
        switch action {
        case .add:                     add(); break
        case .delete:               delete(); break
        case .moveUp:           moveUp(true);  break
        case .moveDown:        moveUp(false); break
        case .moveToParent:   moveToParent(); break
        case .moveToSibling: moveToSibling(); break
        }
    }


    func add() {
        addZoneTo(currentlyMovableZone)
    }


    func addZoneTo(_ parentZone: Zone?) {
        if parentZone != nil {
            let             record = CKRecord(recordType: zoneTypeKey)
            let               zone = Zone(record: record, database: cloudManager.currentDB)
            zone.parentZone            = parentZone
            parentZone?.showChildren   = true

            widgetForZone(parentZone!)?.stopEditing()
            parentZone?.children.append(zone)

            currentlyEditingZone   = zone

            updateToClosures(nil, regarding: .data)
            persistenceManager.save()
            zone.saveToCloud()
        }
    }


    func delete() {
        if let zone: Zone = currentlyEditingZone {
            deleteZone(zone)
        } else {
            deleteZones(currentlyGrabbedZones)
        }
    }


    func deleteZones(_ zones: [Zone]) {
        for zone in zones {
            deleteZone(zone)
        }
    }


    func deleteZone(_ zone: Zone) {
        if let        parentZone = zone.parentZone {
            let            index = parentZone.children.index(of: zone)
            currentlyEditingZone = nil

            parentZone.children.remove(at: index!)
            persistenceManager.save()

            cloudManager.currentDB.delete(withRecordID: zone.record.recordID, completionHandler: { (deleted, error) in
                self.updateToClosures(zone, regarding: .delete)
                parentZone.saveToCloud()
            })
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
                        persistenceManager.save()
                        updateToClosures(nil, regarding: .data)
                    }
                }
            }
        }
    }


    func moveToSibling() {
        if let            zone: Zone = currentlyMovableZone {
            if let        parentZone = zone.parentZone {
                if let         index = parentZone.children.index(of: zone) {
                    let siblingIndex = index - 1

                    if siblingIndex >= 0 {
                        let  siblingZone = parentZone.children[siblingIndex]

                        parentZone.children.remove(at: index)
                        siblingZone.children.append(zone)
                        zone.parentZone = siblingZone
                        persistenceManager.save()
                        updateToClosures(nil, regarding: .data)

                        // operation to save all three: zone, sibling, parent
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
                    zone.parentZone = grandParentZone
                    updateToClosures(nil, regarding: .data)

                    // operation to save all three: zone, parent, grand
                }
            }
        }
    }


    func toggleChildrenVisibility(_ ofZone: Zone?) {
        if ofZone != nil {
            ofZone?.showChildren = !(ofZone?.showChildren)!

            persistenceManager.save()
            updateToClosures(nil, regarding: .data)
        }
    }
}
