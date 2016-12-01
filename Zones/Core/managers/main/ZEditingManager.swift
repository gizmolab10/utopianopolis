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
                            if isWindow || isOption {
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
                        case "t":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                travelManager.hereZone = zone
                                controllersManager.signal(nil, regarding: .data)
                            }
                            break
                        default:
                            
                            break
                        }
                    }
                }
            }
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

                setChildrenVisibilityTo(show, zone: parent, recursively: recursively)
            } else {
                zone?.showChildren = show

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


    func addZoneTo(_ parentZone: Zone?, onCompletion: ObjectClosure?) {
        if parentZone != nil && travelManager.storageMode != .bookmarks {
            let record = CKRecord(recordType: zoneTypeKey)
            let   zone = Zone(record: record, storageMode: travelManager.storageMode)
            let insert = asTask ? 0 : (parentZone?.children.count)!

            widgetsManager.widgetForZone(parentZone!)?.textField.resignFirstResponder()

            if asTask {
                parentZone?.children.insert(zone, at: 0)
            } else {
                parentZone?.children.append(zone)
            }

            zone.parentZone          = parentZone
            parentZone?.showChildren = true

            parentZone?.recomputeOrderingUponInsertionAt(insert)
            onCompletion?(zone)
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
        zone.recordState  = .needsDelete

        deleteZones(zone.children)

        if let parentZone = zone.parentZone {
            let siblings  = parentZone.children

            if var  index = siblings.index(of: zone) {
                cloudManager.records.removeValue(forKey: zone.record.recordID)
                parentZone.children.remove(at: index)

                index = max(0, index - 1)

                if siblings.count > 0 {
                    return siblings[index]
                } else  {
                    return parentZone
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
                        } else if travelManager.storageMode != .bookmarks {
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
                        controllersManager.signal(zone.parentZone, regarding: .data)
                    }
                } else if travelManager.storageMode == .bookmarks && zone.isBookmark {
                    travelManager.travelWhereThisZonePoints(zone, atArrival: { (object, kind) -> (Void) in
                        if let _: Zone = object as? Zone {
                            selectionManager.currentlyGrabbedZones = [zone]

                            controllersManager.signal(nil, regarding: .data)
                        }
                    })
                }
            }
        }
    }


    func actuallyMove(_ zone: Zone, persistently: Bool) {
        if travelManager.storageMode        != .bookmarks, let parentZone = zone.parentZone {
            let siblings                     = parentZone.children

            if let                     index = siblings.index(of: zone) {
                let              cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex             >= 0 && cousinIndex < siblings.count {
                    let          siblingZone = siblings[cousinIndex]
                    zone.parentZone          = siblingZone
                    siblingZone.showChildren = true
                    var               insert = 0

                    parentZone.children.remove(at: index)
                    parentZone .needsSave()
                    zone       .needsSave()
                    siblingZone.needsSave()

                    if asTask {
                        siblingZone.children.insert(zone, at: 0)
                    } else {
                        insert = siblingZone.children.count

                        siblingZone.children.append(zone)
                    }

                    siblingZone.recomputeOrderingUponInsertionAt(insert)
                    saveAfterMoveWithin(parentZone, persistently: persistently)
                }
            }
        }
    }


    func moveOut(selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let                              zone: Zone = selectionManager.firstGrabbableZone {
            var                             parentZone = zone.parentZone

            if selectionOnly {
                if parentZone == nil {
                    travelManager.travelWhereThisZonePoints(zone) { object, kind in
                        if let zone: Zone = object as? Zone {
                            selectionManager.currentlyGrabbedZones = [zone]

                            controllersManager.signal(nil, regarding: .data)
                        }
                    }

                    return
                } else if extreme {
                    parentZone                         = travelManager.hereZone
                } else if zone == travelManager.hereZone {
                    travelManager.hereZone = parentZone
                }

                selectionManager.currentlyGrabbedZones = [parentZone!]

                controllersManager.signal(parentZone, regarding: .data)
            } else if travelManager.storageMode != .bookmarks, let grandParentZone = parentZone?.parentZone {
                let                              index = parentZone?.children.index(of: zone)
                let                             insert = asTask ? 0 : grandParentZone.children.count
                zone.parentZone                        = grandParentZone

                grandParentZone.needsSave()
                parentZone?    .needsSave()
                zone           .needsSave()

                if asTask {
                    grandParentZone.children.insert(zone, at: 0)
                } else {
                    grandParentZone.children.append(zone)
                }

                parentZone?.children.remove(at: index!)
                grandParentZone.recomputeOrderingUponInsertionAt(insert)
                saveAfterMoveWithin(grandParentZone, persistently: persistently)
            }
        }
    }
}
