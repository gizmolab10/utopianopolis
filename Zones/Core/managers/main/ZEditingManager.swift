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


    func normalize() {
        widgetsManager.clear()
        travelManager.rootZone.normalize()
        controllersManager.saveAndUpdateFor(nil)
    }


    // MARK:- layout
    // MARK:-


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


    // MARK:- creation
    // MARK:-


    func add() {
        addZoneTo(selectionManager.currentlyMovableZone)
    }


    func addZoneTo(_ parentZone: Zone?) {
        if parentZone != nil {
            let record = CKRecord(recordType: zoneTypeKey)
            let   zone = Zone(record: record, storageMode: cloudManager.storageMode)

            widgetsManager.widgetForZone(parentZone!)?.textField.resignFirstResponder()

            if asTask {
                parentZone?.children.insert(zone, at: 0)
            } else {
                parentZone?.children.append(zone)
            }

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
            if var  index = parentZone.children.index(of: zone) {
                parentZone.children.remove(at: index)

                index = max(0, index - 1)

                if parentZone.children.count > 0 {
                    return parentZone.children[index]
                } else  {
                    return parentZone
                }
            }
        }

        return nil
    }


    // MARK:- movement
    // MARK:-


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

                if !selectionOnly {
                    parentZone.children.remove(at: index)
                    parentZone.children.insert(zone, at:newIndex)
                } else if next != nil {
                    selectionManager.currentlyGrabbedZones = [next!]
                }
                
                controllersManager.updateToClosures(parentZone, regarding: .data)
            }
        }
    }


    func moveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool) {
        if let        zone: Zone = selectionManager.firstGrabbableZone {
            if let    parentZone = zone.parentZone {
                if let     index = parentZone.children.index(of: zone) {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : parentZone.children.count - 1
                    }

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


    var asTask: Bool { get { return editMode == .task } }


    func moveInto(selectionOnly: Bool, extreme: Bool) {
        if let                                  zone: Zone = selectionManager.firstGrabbableZone {
            if selectionOnly {
                if zone.children.count > 0 {
                    selectionManager.currentlyGrabbedZones = [asTask ? zone.children.first! : zone.children.last!]
                    zone.showChildren                      = true

                    controllersManager.updateToClosures(zone, regarding: .data)
                }
            } else if let                       parentZone = zone.parentZone {
                if let                               index = parentZone.children.index(of: zone) {
                    let                       siblingIndex = index == 0 ? 1 : index - 1

                    if siblingIndex                       >= 0 {
                        let                    siblingZone = parentZone.children[siblingIndex]
                        siblingZone.showChildren           = true

                        parentZone.children.remove(at: index)

                        if asTask {
                            siblingZone.children.insert(zone, at: 0)
                        } else {
                            siblingZone.children.append(zone)
                        }

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


    func moveOut(selectionOnly: Bool, extreme: Bool) {
        if let                                  zone: Zone = selectionManager.firstGrabbableZone {
            if var                              parentZone = zone.parentZone {
                if selectionOnly {
                    if extreme {
                        parentZone                         = travelManager.rootZone
                    }

                    selectionManager.currentlyGrabbedZones = [parentZone]

                    controllersManager.updateToClosures(parentZone, regarding: .data)
                } else if let              grandParentZone = parentZone.parentZone {
                    let                              index = parentZone.children.index(of: zone)
                    grandParentZone.recordState            = .needsSave
                    parentZone.recordState                 = .needsSave
                    zone.recordState                       = .needsSave
                    zone.parentZone                        = grandParentZone

                    if asTask {
                        grandParentZone.children.insert(zone, at: 0)
                    } else {
                        grandParentZone.children.append(zone)
                    }

                    parentZone.children.remove(at: index!)
                    controllersManager.saveAndUpdateFor(grandParentZone)
                }
            }
        }
    }


    // MARK:- events
    // MARK:-


    func move(_ arrow: ZArrowKey, modifierFlags: ZKeyModifierFlags) {
        let isCommand = modifierFlags.contains(.command)
        let  isOption = modifierFlags.contains(.option)

        if modifierFlags.contains(.shift) {
            if let zone = selectionManager.firstGrabbableZone {

                switch arrow {
                case .right: setChildrenVisibilityTo(true,  zone: zone, recursively: isCommand);                                            break
                case .left:  setChildrenVisibilityTo(false, zone: zone, recursively: isCommand); selectionManager.deselectDragWithin(zone); break
                default: return
                }

                controllersManager.saveAndUpdateFor(nil)
            }
        } else {
            switch arrow {
            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand); break
            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand); break
            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand); break
            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand); break
            }
        }
    }


    @discardableResult func handleKey(_ event: ZEvent, isWindow: Bool) -> Bool {
        let     flags = event.modifierFlags
        let   isShift = flags.contains(.shift)
        let  isOption = flags.contains(.option)
        let isCommand = flags.contains(.command)
        let   isArrow = flags.contains(.numericPad) && flags.contains(.function)

        if let widget = widgetsManager.currentMovableWidget {
            if let string = event.charactersIgnoringModifiers {
                let key   = string[string.startIndex].description

                if isArrow {
                    let arrow = ZArrowKey(rawValue: key.utf8CString[2])!
                    var flags = ZKeyModifierFlags.none

                    if isShift   { flags.insert(.shift ) }
                    if isOption  { flags.insert(.option) }
                    if isCommand { flags.insert(.command) }

                    move(arrow, modifierFlags: flags)

                    return true
                } else {
                    switch key {
                    case "\t":
                        widget.textField.resignFirstResponder()

                        if let parent = widget.widgetZone.parentZone {
                            addZoneTo(parent)
                        } else {
                            selectionManager.currentlyEditingZone = nil

                            controllersManager.updateToClosures(nil, regarding: .data)
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
                            selectionManager.currentlyGrabbedZones = []

                            widget.textField.becomeFirstResponder()

                            return true
                        } else if selectionManager.currentlyEditingZone != nil {
                            selectionManager.currentlyGrabbedZones = [selectionManager.currentlyEditingZone!]

                            widget.textField.resignFirstResponder()
                            
                            return true
                        }

                        break
                    default:

                        break
                    }
                }
            }
        }
        
        return false
    }
}
