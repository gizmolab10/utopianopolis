//
//  ZEditingManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZArrowKey: CChar {
    case up    = -128
    case down
    case left
    case right
}


class ZEditingManager: NSObject {


    class ZoneEvent: NSObject {
        var event: ZEvent?
        var isWindow: Bool = true

        convenience init(_ iEvent: ZEvent, iIsWindow: Bool) {
            self.init()

            isWindow = iIsWindow
            event    = iEvent
        }
    }


    var deferredEvents: [ZoneEvent] = []
    var previousEvent: ZEvent?
    var asTask: Bool { get { return editMode == .task } }


    // MARK:- API
    // MARK:-


    func handleDeferredEvents() {
        while deferredEvents.count != 0 {
            let event = deferredEvents.remove(at: 0)

            handleKey(event.event!, isWindow: event.isWindow)
        }
    }


    @discardableResult func handleKey(_ event: ZEvent, isWindow: Bool) -> Bool {
        if !operationsManager.isReady {
            if deferredEvents.count < 1 {
                deferredEvents.append(ZoneEvent(event, iIsWindow: isWindow))
            }
        } else if event == previousEvent {
            return true
        } else {
            #if os(OSX)
            previousEvent = event
            let     flags = event.modifierFlags
            let   isShift = flags.contains(.shift)
            let  isOption = flags.contains(.option)
            let isCommand = flags.contains(.command)
            let   isArrow = flags.contains(.numericPad) && flags.contains(.function)

            if let widget = widgetsManager.currentMovableWidget {
                if let string = event.charactersIgnoringModifiers {
                    let key   = string[string.startIndex].description

                    if isArrow {
                        if isWindow {
                            let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                            if isShift {
                                if let zone = selectionManager.firstGrabbableZone {

                                    switch arrow {
                                    case .right: setChildrenVisibilityTo(true,  zone: zone, recursively: isCommand);                                            break
                                    case .left:  setChildrenVisibilityTo(false, zone: zone, recursively: isCommand); selectionManager.deselectDragWithin(zone); break
                                    default: return true
                                    }

                                    controllersManager.saveAndUpdateFor(nil)
                                }
                            } else {
                                switch arrow {
                                case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                                case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                                case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                                case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                                }
                            }

                            return true
                        }
                    } else {
                        switch key {
                        case "\t":
                            widget.textField.resignFirstResponder()

                            if let parent = widget.widgetZone.parentZone {
                                addZoneTo(parent)
                            } else {
                                selectionManager.currentlyEditingZone = nil

                                controllersManager.signal(nil, regarding: .data)
                            }

                            return true
                        case " ":
                            if isWindow || isOption && !widget.widgetZone.isBookmark {
                                addZoneTo(widget.widgetZone)

                                return true
                            }

                            break
                        case "\u{7F}":
                            if isWindow || isOption {
                                delete()

                                return true
                            }

                            break
                        case "\r":
                            if selectionManager.currentlyGrabbedZones.count != 0 {
//                                if isShift {
//                                    addParentTo(selectionManager.firstGrabbableZone)
//                                } else {
                                    widget.textField.becomeFirstResponder()
//                                }

                                return true
                            } else if selectionManager.currentlyEditingZone != nil {
                                widget.textField.resignFirstResponder()
                                
                                return true
                            }

                            break
                        case "b":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                bookmarksManager.addNewBookmarkFor(zone)
                            }

                            break
                        case "t":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                if !zone.isBookmark {
                                    travelManager.hereZone = zone

                                    controllersManager.signal(nil, regarding: .data)
                                } else {
                                    travelManager.travelWhereThisZonePoints(zone, atArrival: { (object, kind) -> (Void) in
                                        travelManager.hereZone = object as! Zone!

                                        controllersManager.signal(nil, regarding: .data)
                                    })
                                }
                            }

                            break
                        default:
                            
                            break
                        }
                    }
                }
            }
            #endif
        }
        
        return false
    }


    // MARK:- layout
    // MARK:-


    func setChildrenVisibilityTo(_ show: Bool, zone: Zone?, recursively: Bool) {
        if zone != nil {
            let noVisibleChildren = !(zone?.showChildren)! || ((zone?.children.count)! == 0)

            if !show && noVisibleChildren && selectionManager.isGrabbed(zone!), let parent = zone?.parentZone {
                selectionManager.currentlyGrabbedZones = [parent]
                zone?.showChildren                     = false
                zone?.needSave()

                setChildrenVisibilityTo(show, zone: parent, recursively: recursively)
            } else {
                if  zone?.showChildren != show {
                    zone?.showChildren  = show

                    zone?.needSave()
                }

                if recursively {
                    for child: Zone in (zone?.children)! {
                        setChildrenVisibilityTo(show, zone: child, recursively: recursively)
                    }
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


    // MARK:- creation
    // MARK:-


    func addZoneTo(_ parentZone: Zone?) {
        addZoneTo(parentZone) { (object) -> (Void) in
            controllersManager.saveAndUpdateFor(parentZone, onCompletion: { () -> (Void) in
                operationsManager.isReady = true

                widgetsManager.widgetForZone(object as? Zone)?.textField.becomeFirstResponder()
                controllersManager.signal(parentZone, regarding: .data)
            })
        }
    }


    // this is currently not being called
    
    func addParentTo(_ zone: Zone?) {
        if let grandParentZone = zone?.parentZone {
            addZoneTo(grandParentZone, onCompletion: { (parentZone) -> (Void) in
                selectionManager.currentlyGrabbedZones = [zone!]

                // self.actuallyMove(zone!, forceIntoNew: true, persistently: false)
                self.dispatchAsyncInForegroundAfter(0.5, closure: { () -> (Void) in
                    operationsManager.isReady = true

                    widgetsManager.widgetForZone(parentZone as? Zone)?.textField.becomeFirstResponder()
                    controllersManager.signal(grandParentZone, regarding: .data)
                })
            })
        }
    }


    func addZoneTo(_ zone: Zone?, onCompletion: ObjectClosure?) {
        if zone != nil && travelManager.storageMode != .bookmarks {
            let record = CKRecord(recordType: zoneTypeKey)
            let   child = Zone(record: record, storageMode: travelManager.storageMode)
            let insert = asTask ? 0 : (zone?.children.count)!

            cloudManager.addRecord(child, forState: .needsCreate)
            widgetsManager.widgetForZone(zone!)?.textField.resignFirstResponder()

            if asTask {
                zone?.children.insert(child, at: 0)
            } else {
                zone?.children.append(child)
            }

            child.parentZone   = zone
            zone?.showChildren = true

            zone?.recomputeOrderingUponInsertionAt(insert)
            onCompletion?(child)
        }
    }


    func delete() {
        var last: Zone? = nil

        if let zone: Zone = selectionManager.currentlyEditingZone {
            last = deleteZone(zone)

            selectionManager.currentlyEditingZone = nil
        } else {
            last = deleteZones(selectionManager.currentlyGrabbedZones)

            selectionManager.currentlyGrabbedZones = []
        }

        if last != nil {
            selectionManager.currentlyGrabbedZones = [last!]
        }

        controllersManager.saveAndUpdateFor(nil)
    }


    @discardableResult private func deleteZones(_ zones: [Zone]) -> Zone? {
        var last: Zone? = nil

        for zone in zones {
            last = deleteZone(zone)
        }

        return last
    }


    private func deleteZone(_ zone: Zone) -> Zone? {
        if !zone.isRoot {
            cloudManager.addRecord(zone, forState: .needsDelete)

            deleteZones(zone.children)

            if let parentZone = zone.parentZone {
                let siblings  = parentZone.children

                if var  index = siblings.index(of: zone) {
                    index = max(0, index - 1)

                    if siblings.count > 0 {
                        return siblings[index]
                    } else  {
                        return parentZone
                    }
                }
            }
        }

        return nil
    }


    // MARK:- movement
    // MARK:-


    func saveAfterMoveWithin(_ zone: Zone?, persistently: Bool) {
        if zone != nil {
            if persistently {
                controllersManager.saveAndUpdateFor(zone)
            } else {
                controllersManager.signal(zone, regarding: .data)
            }
        }
    }


    //    if beyond end, search for uncles aunts whose children or email


    func nextUpward(_ moveUp: Bool, extreme: Bool,  zone: Zone?) -> (Zone?, Int, Int) {
        if let siblings = zone?.parentZone?.children {
            if siblings.count > 0 {
                if let     index = siblings.index(of: zone!)  {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : siblings.count - 1
                    }

                    if newIndex >= 0 && newIndex < siblings.count {
                        return (siblings[newIndex], index, newIndex)
                    }
                }
            }
        }

        return (nil, 0, 0)
    }


    func newmoveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool) {
        if let        zone: Zone = selectionManager.firstGrabbableZone {
            if let    parentZone = zone.parentZone {
                let (next, index, newIndex) = nextUpward(moveUp, extreme: extreme, zone: parentZone)

                if selectionOnly {
                    if next != nil {
                        selectionManager.currentlyGrabbedZones = [next!]
                    }
                } else if travelManager.storageMode != .bookmarks {
                    parentZone.children.remove(at: index)
                    parentZone.children.insert(zone, at:newIndex)
                }
                
                controllersManager.signal(parentZone, regarding: .data)
            }
        }
    }


    func moveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let        zone: Zone = selectionManager.firstGrabbableZone {
            if let    parentZone = zone.parentZone {
                let     siblings = parentZone.children
                
                if let     index = siblings.index(of: zone) {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : siblings.count - 1
                    }

                    if newIndex >= 0 && newIndex < siblings.count {
                        if selectionOnly {
                            selectionManager.currentlyGrabbedZones = [siblings[newIndex]]

                            controllersManager.signal(parentZone, regarding: .data)
                        } else {
                            parentZone.children.remove(at: index)
                            parentZone.children.insert(zone, at:newIndex)
                            parentZone.recomputeOrderingUponInsertionAt(newIndex)
                            saveAfterMoveWithin(parentZone, persistently: persistently)
                        }
                    }
                }
            }
        }
    }


    func moveInto(selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let                                  zone: Zone = selectionManager.firstGrabbableZone {
            if !selectionOnly {
                actuallyMove(zone, persistently: persistently)
            } else {
                if zone.children.count > 0 {
                    let                           saveThis = !zone.showChildren
                    selectionManager.currentlyGrabbedZones = [asTask ? zone.children.first! : zone.children.last!]
                    zone.showChildren                      = true

                    if saveThis {
                        controllersManager.saveAndUpdateFor(nil)
                    } else {
                        controllersManager.signal(nil, regarding: .data)
                    }
                } else if zone.isBookmark {
                    travelManager.travelWhereThisZonePoints(zone, atArrival: { (object, kind) -> (Void) in
                        if let there: Zone = object as? Zone {
                            selectionManager.currentlyGrabbedZones = [there]
                            travelManager.hereZone                 = there

                            controllersManager.signal(nil, regarding: .data)
                        }
                    })
                }
            }
        }
    }


    func actuallyMove(_ zone: Zone, persistently: Bool) {
        if let           parentZone = zone.parentZone {
            let siblings            = parentZone.children

            if let            index = siblings.index(of: zone) {
                let     cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex     >= 0 && cousinIndex < siblings.count {
                    let siblingZone = siblings[cousinIndex]

                    if !siblingZone.isBookmark {
                        parentZone.removeChild(zone)
                        parentZone.needSave()
                        moveZone(zone, into: siblingZone)
                        saveAfterMoveWithin(parentZone, persistently: persistently)
                    } else {
                        // move into bookmark (== siblingZone)
                        travelManager.travelWhereThisZonePoints(siblingZone, atArrival: { (object, kind) -> (Void) in
                            let there = object as! Zone

                            self.applyModeRecursivelyTo(zone, parentZone: nil)
                            self.moveZone(zone, into: there)
                            self.saveAfterMoveWithin(nil, persistently: true)
                        })
                    }
                }
            }
        }
    }


    func applyModeRecursivelyTo(_ zone: Zone?, parentZone: Zone?) {
        if zone != nil {
            zone?.record      = CKRecord(recordType: zoneTypeKey)
            zone?.storageMode = travelManager.storageMode

            if parentZone != nil {
                zone?.parentZone = parentZone
            }

            for child in (zone?.children)! {
                applyModeRecursivelyTo(child, parentZone: zone)
            }

            cloudManager.addRecord(zone!, forState: .needsCreate)
            zone?.updateCloudProperties()
        }
    }


    func moveZone(_ zone: Zone, into: Zone) {
        zone.parentZone   = into
        into.showChildren = true
        let        insert = asTask ? 0 : into.children.count

        zone.needSave()
        into.needSave()

        if asTask {
            into.children.insert(zone, at: 0)
        } else {
            into.children.append(zone)
        }

        into.recomputeOrderingUponInsertionAt(insert)
    }


    func moveOut(selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let  zone: Zone = selectionManager.firstGrabbableZone {
            let parentZone = zone.parentZone

            if selectionOnly {
                if zone.isRoot {
                    travelManager.travelWhereThisZonePoints(zone) { object, kind in
                        if let there: Zone = object as? Zone {
                            selectionManager.currentlyGrabbedZones = [there]

                            controllersManager.signal(nil, regarding: .data)
                        }
                    }

                    return
                } else if extreme {
                    travelManager.hereZone = travelManager.rootZone
                } else if zone == travelManager.hereZone {
                    travelManager.hereZone = parentZone
                }

                selectionManager.currentlyGrabbedZones = [parentZone!]

                controllersManager.signal(parentZone, regarding: .data)
            } else if travelManager.storageMode != .bookmarks, let grandParentZone = parentZone?.parentZone {
                parentZone?.removeChild(zone)
                parentZone?.needSave()

                if travelManager.hereZone == parentZone {
                    travelManager.hereZone = grandParentZone
                }

                moveZone(zone, into: grandParentZone)
                saveAfterMoveWithin(grandParentZone, persistently: persistently)
            }
        }
    }
}
