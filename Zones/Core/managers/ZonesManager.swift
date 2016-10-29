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


    var                closures: [UpdateClosureObject] = []
    var              _rootZone: Zone!
    var  _currentlyEditingZone: Zone?
    var _currentlyGrabbedZones: [Zone] = []


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
        set { _currentlyEditingZone = newValue; updateToClosures(nil, regarding: .data) }
    }


    var currentlyGrabbedZones: [Zone] {
        get { return _currentlyGrabbedZones }
        set { _currentlyGrabbedZones = newValue; updateToClosures(nil, regarding: .data) }
    }


    func isGrabbed(zone: Zone) -> Bool {
        return currentlyGrabbedZones.contains(zone)
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


    var currentlyMovableZone: Zone? {
        get {
            var movable = currentlyEditingZone

            if movable == nil {
                if currentlyGrabbedZones.count > 0 {
                    movable = currentlyGrabbedZones[0]
                } else {
                    movable = rootZone
                }
            }

            return movable!
        }
    }


    var canDelete: Bool {
        get {
            return (currentlyEditingZone != nil && currentlyEditingZone != rootZone) ||
                (currentlyGrabbedZones.count > 0 && !currentlyGrabbedZones.contains(rootZone))
        }
    }


    func takeAction(_ action: ZEditAction) {
        switch action {
        case .add:      add();         break
        case .delete:   delete();      break
        case .moveUp:   moveUp(true);  break
        case .moveDown: moveUp(false); break
        }
    }


    func add() {
        addZoneTo(currentlyMovableZone)
    }


    func addZoneTo(_ parent: Zone?) {
        if parent != nil {
            let             record = CKRecord(recordType: zoneTypeKey)
            let               zone = Zone(record: record, database: cloudManager.currentDB)
            zone.links[parentsKey] = [parent!]
            currentlyEditingZone   = zone

            parent?.children.append(zone)
            updateToClosures(nil, regarding: .data)
            persistenceManager.save()

            cloudManager.currentDB.save(record) { (iRecord: CKRecord?, iError: Error?) in
                if iError != nil {
                    print(iError)
                } else {
                    zone.record = iRecord
                }
            }
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
        if let parent = zone.parent {
            let index = parent.children.index(of: zone)
            currentlyEditingZone = nil

            parent.children.remove(at: index!)
            persistenceManager.save()

            cloudManager.currentDB.delete(withRecordID: zone.record.recordID, completionHandler: { (deleted, error) in
                self.updateToClosures(zone, regarding: .delete)
            })
        }
    }


    func moveUp(_ moveUp: Bool) {
        if let zone: Zone = currentlyMovableZone {
            if let parent = zone.parent {
                if let index = parent.children.index(of: zone) {
                    let newIndex = index + (moveUp ? -1 : 1)

                    if newIndex >= 0 && newIndex < parent.children.count {
                        parent.children.remove(at: index)
                        parent.children.insert(zone, at:newIndex)
                        persistenceManager.save()
                        updateToClosures(nil, regarding: .data)
                    }
                }
            }
        }
    }


    func toggleChildrenVisibility(_ ofZone: Zone?) {
        if ofZone != nil {
            ofZone?.showChildren = !(ofZone?.showChildren)!
            
            updateToClosures(nil, regarding: .data)
        }
    }

}
