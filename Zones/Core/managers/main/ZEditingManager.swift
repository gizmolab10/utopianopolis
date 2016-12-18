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


    var rootZone: Zone { get { return travelManager.rootZone! } set { travelManager.rootZone = newValue } }
    var hereZone: Zone { get { return travelManager.hereZone! } set { travelManager.hereZone = newValue } }
    var deferredEvents: [ZoneEvent] = []
    var previousEvent: ZEvent?


    // MARK:- API
    // MARK:-


    func handleDeferredEvents() {
        while deferredEvents.count != 0 {
            let event = deferredEvents.remove(at: 0)

            handleEvent(event.event!, isWindow: event.isWindow)
        }
    }


    @discardableResult func handleEvent(_ event: ZEvent, isWindow: Bool) -> Bool {
        if !operationsManager.isReady {
            if deferredEvents.count < 1 {
                deferredEvents.append(ZoneEvent(event, iIsWindow: isWindow))
            }
        } else if event == previousEvent {
            return true
        } else {
            #if os(OSX)
            previousEvent = event

                if  let    widget = widgetsManager.currentMovableWidget, let string = event.charactersIgnoringModifiers {
                    let       key = string[string.startIndex].description
                    let     flags = event.modifierFlags
                    let   isShift = flags.contains(.shift)
                    let  isOption = flags.contains(.option)
                    let isCommand = flags.contains(.command)
                    let   isArrow = flags.contains(.numericPad) && flags.contains(.function)

                    if !isArrow {
                        switch key {
                        case "\t":
                            widget.textWidget.resignFirstResponder()

                            if let parent = widget.widgetZone.parentZone {
                                if widget.widgetZone == hereZone {
                                    hereZone            = parent
                                    parent.showChildren = true
                                }

                                addZoneTo(parent)
                            } else {
                                selectionManager.currentlyEditingZone = nil

                                controllersManager.signal(nil, regarding: .data)
                            }

                            return true
                        case " ":
                            if (isWindow || isOption) && !widget.widgetZone.isBookmark {
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
                                if isCommand {
                                    selectionManager.deselect()
                                } else {
                                    widget.textWidget.becomeFirstResponder()
                                }

                                return true
                            } else if selectionManager.currentlyEditingZone != nil {
                                widget.textWidget.resignFirstResponder()

                                return true
                            }

                            break
                        case "b":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                let bookmark = bookmarksManager.addNewBookmarkFor(zone)

                                selectionManager.grab(bookmark)
                                controllersManager.syncToCloudAndSignalFor(nil)
                            }

                            break
                        case "f":
                            if isCommand {
                                showsSearching = !showsSearching

                                controllersManager.signal(nil, regarding: .search)
                            }

                            break
                        case "t":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                if !zone.isBookmark {
                                    hereZone = zone

                                    controllersManager.syncToCloudAndSignalFor(nil)
                                } else {
                                    travelManager.travelWhereThisZonePoints(zone, atArrival: { (object, kind) -> (Void) in
                                        self.hereZone = object as! Zone!
                                        
                                        controllersManager.syncToCloudAndSignalFor(nil)
                                    })
                                }
                            }
                            
                            break
                        default:
                            
                            break
                        }
                    } else if isWindow {
                        let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                        if isShift {
                            if let zone = selectionManager.firstGrabbableZone {

                                switch arrow {
                                case .right: makeToggleDotShow(true,  zone: zone, recursively: isCommand);                                            break
                                case .left:  makeToggleDotShow(false, zone: zone, recursively: isCommand); selectionManager.deselectDragWithin(zone); break
                                default: return true
                                }

                                controllersManager.syncToCloudAndSignalFor(nil)
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
                }
            #endif
        }
        
        return false
    }


    // MARK:- layout
    // MARK:-


    func makeToggleDotShow(_ show: Bool, zone: Zone?, recursively: Bool) {
        if zone != nil {
            let noVisibleChildren = !(zone?.showChildren)! || ((zone?.children.count)! == 0)

            if !show && noVisibleChildren && selectionManager.isGrabbed(zone!), let parent = zone?.parentZone {
                selectionManager.grab(parent)
                zone?.showChildren = false
                zone?.needSave()

                makeToggleDotShow(show, zone: parent, recursively: recursively)
            } else {
                if  zone?.showChildren != show {
                    zone?.showChildren  = show

                    zone?.needSave()
                }

                if recursively {
                    for child: Zone in (zone?.children)! {
                        makeToggleDotShow(show, zone: child, recursively: recursively)
                    }
                }
            }
        }
    }


    func toggleDotActionOnZone(_ zone: Zone?) {
        if zone != nil {
            if (zone?.isBookmark)! {
                travelThroughBookmark(zone!, persistently: true)
            } else {
                let show = zone?.showChildren == false

                makeToggleDotShow(show, zone: zone, recursively: false)

                if !show {
                    selectionManager.deselectDragWithin(zone!)
                }

                controllersManager.syncToCloudAndSignalFor(nil)
            }
        }
    }


    // MARK:- creation
    // MARK:-


    func addZoneTo(_ parentZone: Zone?) {
        addZoneTo(parentZone) { (object) -> (Void) in
            controllersManager.syncToCloudAndSignalFor(parentZone, onCompletion: { () -> (Void) in
                operationsManager.isReady = true

                widgetsManager.widgetForZone(object as? Zone)?.textWidget.becomeFirstResponder()
                controllersManager.signal(parentZone, regarding: .data)
            })
        }
    }


    // this is currently not being called
    
    func addParentTo(_ zone: Zone?) {
        if let grandParentZone = zone?.parentZone {
            addZoneTo(grandParentZone, onCompletion: { (parentZone) -> (Void) in
                selectionManager.grab(zone!)

                // self.actuallyMoveInto(zone!, forceIntoNew: true, persistently: false)
                self.dispatchAsyncInForegroundAfter(0.5, closure: { () -> (Void) in
                    operationsManager.isReady = true

                    widgetsManager.widgetForZone(parentZone as? Zone)?.textWidget.becomeFirstResponder()
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

            child.markForStates([.needsCreate])
            widgetsManager.widgetForZone(zone!)?.textWidget.resignFirstResponder()

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
            selectionManager.grab(last!)
        }

        controllersManager.syncToCloudAndSignalFor(nil)
    }


    @discardableResult private func deleteZones(_ zones: [Zone]) -> Zone? {
        var last: Zone? = nil

        for zone in zones {
            last = deleteZone(zone)
        }

        return last
    }


    @discardableResult private func deleteZone(_ zone: Zone) -> Zone? {
        if !zone.isRoot {
            if travelManager.storageMode != .bookmarks {
                zone.markForStates([.needsDelete])
            }

            deleteZones(zone.children)

            if var parentZone = zone.parentZone {
                if zone == travelManager.hereZone {
                    dispatchAsyncInForeground {
                        self.revealParent {
                            travelManager.hereZone = parentZone

                            selectionManager.grab(parentZone)
                            controllersManager.syncToCloudAndSignalFor(nil)
                        }
                    }
                }

                let siblings = parentZone.children

                if var index = siblings.index(of: zone) {
                    if siblings.count > 1 {
                        if index < siblings.count - 1 && (!asTask || index == 0) {
                            index += 1
                        } else if index > 0 {
                            index -= 1
                        }

                        parentZone = siblings[index]
                    }
                }

                zone.orphan()

                return parentZone
            }
        }

        return nil
    }


    // MARK:- experimental
    // MARK:-


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
                        selectionManager.grab(next!)
                    }
                } else if travelManager.storageMode != .bookmarks {
                    parentZone.children.remove(at: index)
                    parentZone.children.insert(zone, at:newIndex)
                }

                controllersManager.signal(parentZone, regarding: .data)
            }
        }
    }
    

    // MARK:- move
    // MARK:-


    func syncAndSignalAfterMoveAffecting(_ zone: Zone?, persistently: Bool) {
        if persistently {
            controllersManager.syncToCloudAndSignalFor(zone)
        } else {
            controllersManager.signal(zone, regarding: .data)
        }
    }


    //    if beyond end, search for uncles aunts whose children or email


    func moveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let        zone: Zone = selectionManager.firstGrabbableZone {
            if let         there = zone.parentZone {
                let     siblings = there.children
                
                if let     index = siblings.index(of: zone) {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : siblings.count - 1
                    }

                    if newIndex >= 0 && newIndex < siblings.count {
                        if zone == hereZone {
                            hereZone = there
                        }

                        if selectionOnly {
                            selectionManager.grab(siblings[newIndex])

                            controllersManager.signal(there, regarding: .data)
                        } else {
                            there.children.remove(at: index)
                            there.children.insert(zone, at:newIndex)
                            there.recomputeOrderingUponInsertionAt(newIndex)
                            syncAndSignalAfterMoveAffecting(there, persistently: persistently)
                        }
                    }
                }
            } else if !zone.isRoot {
                revealParent {
                    self.moveUp(moveUp, selectionOnly: selectionOnly, extreme: extreme, persistently: persistently)
                }
            }
        }
    }


    // MARK:- move out
    // MARK:-


    func revealRoot(_ onCompletion: Closure?) {
        if rootZone.record != nil {
            onCompletion?()
        } else {
            operationsManager.root {
                onCompletion?()
            }
        }
    }


    func revealParent(_ onCompletion: Closure?) {
        hereZone.markForStates([.needsParent])
        operationsManager.sync {
            onCompletion?()
        }
    }


    func moveOut(selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let zone: Zone = selectionManager.firstGrabbableZone {
            var toThere = zone.parentZone

            if selectionOnly {
                if zone.isRoot {
                    travelManager.travelWhereThisZonePoints(zone) { object, kind in
                        if let there: Zone = object as? Zone {
                            selectionManager.grab(there)

                            self.syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
                        }
                    }
                } else if extreme {
                    revealRoot {
                        self.hereZone =  self.rootZone

                        selectionManager.grab(self.rootZone)
                        controllersManager.syncToCloudAndSignalFor(nil)
                    }
                } else if zone == hereZone || toThere == nil {
                    revealParent {
                        if let there = self.hereZone.parentZone {
                            self.hereZone =  there

                            selectionManager.grab(there)
                            travelManager.manifest.needSave()
                            self.syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
                        }
                    }
                } else if toThere != nil {
                    selectionManager.grab(toThere!)

                    controllersManager.signal(toThere, regarding: .data)
                }
            } else if travelManager.storageMode != .bookmarks, let fromThere = toThere {
                toThere     = fromThere.parentZone
                let closure = {
                    self.hereZone = toThere!

                    zone.orphan()
                    travelManager.manifest.needSave()
                    self.moveZone(zone, into: toThere!)
                    self.syncAndSignalAfterMoveAffecting(toThere, persistently: persistently)
                }

                fromThere.needSave()

                if extreme {
                    if hereZone.isRoot {
                        closure()
                    } else {
                        revealRoot {
                            toThere = self.rootZone

                            closure()
                        }
                    }
                } else if (hereZone == zone || hereZone == fromThere) {
                    revealParent {
                        toThere = fromThere.parentZone

                        if toThere != nil {
                            closure()
                        }
                    }
                } else {
                    zone.orphan()
                    moveZone(zone, into: toThere!)
                    syncAndSignalAfterMoveAffecting(toThere, persistently: persistently)
                }
            }
        }
    }


    // MARK:- move in
    // MARK:-


    func travelThroughBookmark(_ bookmark: Zone, persistently: Bool) {
        travelManager.travelWhereThisZonePoints(bookmark, atArrival: { (object, kind) -> (Void) in
            if let there: Zone = object as? Zone {
                self.hereZone  = there

                selectionManager.grab(there)
                travelManager.manifest.needSave()
                self.syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
            }
        })
    }


    func moveInto(selectionOnly: Bool, extreme: Bool, persistently: Bool) {
        if let zone: Zone = selectionManager.firstGrabbableZone {
            if !selectionOnly {
                actuallyMoveInto(zone, persistently: persistently)
            } else if zone.isBookmark {
                travelThroughBookmark(zone, persistently: persistently)
            } else if zone.children.count > 0 {
                let  hideChildren = !zone.showChildren
                zone.showChildren = true

                selectionManager.grab(asTask ? zone.children.first! : zone.children.last!)

                if hideChildren {
                    controllersManager.syncToCloudAndSignalFor(nil)
                } else {
                    controllersManager.signal(nil, regarding: .data)
                }
            }
        }
    }


    func actuallyMoveInto(_ zone: Zone, persistently: Bool) {
        if  var         toThere = zone.parentZone {
            let        siblings = toThere.children

            if  let       index = siblings.index(of: zone) {
                let cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex >= 0 && cousinIndex < siblings.count {
                    toThere     = siblings[cousinIndex]

                    if !toThere.isBookmark {
                        zone.parentZone?.needSave()
                        zone.orphan()
                        moveZone(zone, into: toThere)
                        syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
                    } else {
                        let    same = zone.storageMode == toThere.crossLink?.storageMode
                        var   mover = zone
                        let closure = {
                            selectionManager.grab(mover)

                            travelManager.travelWhereThisZonePoints(toThere, atArrival: { (object, kind) -> (Void) in
                                let              there = object as! Zone
                                travelManager.hereZone = there

                                if !same {
                                    self.applyModeRecursivelyTo(mover, parentZone: nil)
                                }

                                self.report("at arrival")
                                self.moveZone(mover, into: there)
                                self.syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
                            })
                        }

                        if same {
                            mover.orphan()

                            closure()
                        } else {
                            let       link = zone.crossLink
                            let linkIsRoot = link?.record == nil || link?.record.recordID.recordName == rootNameKey

                            if linkIsRoot || !zone.isBookmark {
                                mover = zone.deepCopy()
                            } else {
                                mover.orphan()
                            }

                            operationsManager.sync {
                                self.dispatchAsyncInForeground(closure)
                            }
                        }
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

            zone!.markForStates([.needsCreate])
            zone?.updateCloudProperties()
        }
    }


    func moveZone(_ zone: Zone, into: Zone) {
        zone.needSave()
        into.needSave()

        zone.parentZone   = into
        into.showChildren = true
        let        insert = asTask ? 0 : into.children.count

        if asTask {
            into.children.insert(zone, at: 0)
        } else {
            into.children.append(zone)
        }

        into.recomputeOrderingUponInsertionAt(insert)
    }
}
