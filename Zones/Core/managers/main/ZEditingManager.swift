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
    var deferredEvents = [ZoneEvent] ()
    var previousEvent:    ZEvent?


    func syncToCloudAndSignal() {
        controllersManager.syncToCloudAndSignalFor(nil, onCompletion: nil)
    }


    // MARK:- API
    // MARK:-


    func handleDeferredEvents() {
        while deferredEvents.count != 0 && operationsManager.isReady {
            let event = deferredEvents.remove(at: 0)

            handleEvent(event.event!, isWindow: event.isWindow)
        }
    }


    @discardableResult func handleEvent(_ event: ZEvent, isWindow: Bool) -> Bool {
        if !operationsManager.isReady {
            if deferredEvents.count < 1 {
                deferredEvents.append(ZoneEvent(event, iIsWindow: isWindow))
            }
        } else if event != previousEvent && workMode == .editMode {
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

                                signalFor(nil, regarding: .data)
                            }

                        case " ":
                            if (isWindow || isOption) && !widget.widgetZone.isBookmark {
                                addZoneTo(widget.widgetZone)
                            }

                            break
                        case "\u{7F}":
                            if isWindow || isOption {
                                delete()
                            }

                            break
                        case "\r":
                            if selectionManager.currentlyGrabbedZones.count != 0 {
                                if isCommand {
                                    selectionManager.deselect()
                                } else {
                                    widget.textWidget.becomeFirstResponder()
                                }
                            } else if selectionManager.currentlyEditingZone != nil {
                                widget.textWidget.resignFirstResponder()
                            }

                            break
                        case "b":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                let bookmark = bookmarksManager.addNewBookmarkFor(zone)

                                selectionManager.grab(bookmark)
                                syncToCloudAndSignal()
                            }

                            break
                        case "f":
                            if isCommand {
                                showsSearching = !showsSearching

                                signalFor(nil, regarding: .search)
                            }

                            break
                        case "t":
                            if isCommand, let zone = selectionManager.firstGrabbableZone {
                                if !zone.isBookmark {
                                    hereZone = zone

                                    syncToCloudAndSignal()
                                } else {
                                    travelManager.travelWhereThisZonePoints(zone, atArrival: { (object, kind) -> (Void) in
                                        self.hereZone = object as! Zone!
                                        
                                        self.syncToCloudAndSignal()
                                    })
                                }
                            }
                            
                            break
                        default:
                            
                            break
                        }
                    } else if isWindow {
                        let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                        if !isShift {
                            switch arrow {
                            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand, persistently: true); break
                            }
                        } else if let zone = selectionManager.firstGrabbableZone {
                            switch arrow {
                            case .right: showRevealerDot(true,  zone: zone, recursively: isCommand) { self.syncToCloudAndSignal() }; break
                            case .left:  showRevealerDot(false, zone: zone, recursively: isCommand) { self.syncToCloudAndSignal() }; break
                            default:                                                                                                 break
                            }
                        }
                    }
                }
            #endif
        }
        
        return true
    }


    // MARK:- layout
    // MARK:-


    func showRevealerDot(_ show: Bool, zone: Zone, recursively: Bool, onCompletion: Closure?) {
        let       isChildless = zone.children.count == 0
        let noVisibleChildren = !zone.showChildren || isChildless

        if !show && noVisibleChildren && selectionManager.isGrabbed(zone), let parent = zone.parentZone {
            zone.showChildren = show

            zone.needSave()
            selectionManager.grab(parent)
            showRevealerDot(show, zone: parent, recursively: recursively, onCompletion: onCompletion)
        } else {
            if  zone.showChildren != show {
                zone.showChildren  = show

                zone.needSave()

                if !show {
                    selectionManager.deselectDragWithin(zone);
                } else if isChildless {
                    zone.needChildren()
                }
            }

            let recurseMaybe = {
                if operationsManager.isReady {
                    onCompletion?()
                }

                if recursively {
                    for child: Zone in zone.children {
                        self.showRevealerDot(show, zone: child, recursively: recursively, onCompletion: nil)
                    }
                }
            }

            if !show || !isChildless {
                recurseMaybe()
            } else {
                operationsManager.getChildren(recursively) {
                    recurseMaybe()
                }
            }
        }
    }


    func revealerDotActionOnZone(_ zone: Zone) {
        if zone.isBookmark {
            travelThroughBookmark(zone, persistently: true)
        } else {
            let show = zone.showChildren == false

            showRevealerDot(show, zone: zone, recursively: false) {
                self.syncToCloudAndSignal()
            }
        }
    }


    // MARK:- creation
    // MARK:-


    func addZoneTo(_ parentZone: Zone?) {
        addZoneTo(parentZone) { iObject in
            controllersManager.syncToCloudAndSignalFor(parentZone) {
                operationsManager.isReady = true

                widgetsManager.widgetForZone(iObject as? Zone)?.textWidget.becomeFirstResponder()
                self.signalFor(parentZone, regarding: .data)
            }
        }
    }


    func addZoneTo(_ zone: Zone?, onCompletion: ObjectClosure?) {
        if zone != nil && travelManager.storageMode != .bookmarks {
            zone?.needChildren()

            operationsManager.getChildren(false) {
                if operationsManager.isReady {
                    let record = CKRecord(recordType: zoneTypeKey)
                    let insert = asTask ? 0 : (zone?.children.count)!
                    let  child = Zone(record: record, storageMode: travelManager.storageMode)

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
        }
    }


    func delete() {
        var last: Zone? = nil

        if let zone: Zone = selectionManager.currentlyEditingZone {
            last = deleteZone(zone)

            selectionManager.currentlyEditingZone = nil
        } else {
            last = deleteZones(selectionManager.currentlyGrabbedZones, in: nil)

            selectionManager.currentlyGrabbedZones = []
        }

        if last != nil {
            selectionManager.grab(last!)
        }

        syncToCloudAndSignal()
    }


    @discardableResult private func deleteZones(_ zones: [Zone], in parent: Zone?) -> Zone? {
        var last: Zone? = nil

        for zone in zones {
            if  zone != parent {
                last  = deleteZone(zone)
            }
        }

        return last
    }


    @discardableResult private func deleteZone(_ zone: Zone) -> Zone? {
        if !zone.isRoot {
            var parentZone = zone.parentZone

            if travelManager.storageMode != .bookmarks && !zone.isDeleted {
                zone.isDeleted = true

                zone.needSave()
            }

            deleteZones(zone.children, in: zone)
            zone.orphan()

            if parentZone != nil {
                if zone == travelManager.hereZone {
                    dispatchAsyncInForeground {
                        self.revealParent {
                            travelManager.hereZone = parentZone

                            selectionManager.grab(parentZone)
                            self.syncToCloudAndSignal()
                        }
                    }
                }

                let siblings = parentZone?.children
                let    count = (siblings?.count)!

                if var index = siblings?.index(of: zone) {
                    if count > 1 {
                        if index < count - 1 && (!asTask || index == 0) {
                            index += 1
                        } else if index > 0 {
                            index -= 1
                        }

                        parentZone = siblings?[index]
                    }
                }

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

                signalFor(parentZone, regarding: .data)
            }
        }
    }
    

    // MARK:- move
    // MARK:-


    func syncAndSignalAfterMoveAffecting(_ zone: Zone?, persistently: Bool) {
        if persistently {
            controllersManager.syncToCloudAndSignalFor(zone) {}
        } else {
            signalFor(zone, regarding: .data)
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

                            signalFor(there, regarding: .data)
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

                        self.syncToCloudAndSignal()
                    }
                } else if zone == hereZone || toThere == nil {
                    revealParent {
                        if let      there = self.hereZone.parentZone {
                            self.hereZone = there

                            selectionManager.grab(there)
                            travelManager.manifest.needSave()
                            self.syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
                        }
                    }
                } else if toThere != nil {
                    selectionManager.grab(toThere!)

                    signalFor(toThere, regarding: .data)
                }
            } else if travelManager.storageMode != .bookmarks, let fromThere = toThere {
                toThere     = fromThere.parentZone
                let closure = {
                    self.hereZone = toThere!

                    travelManager.manifest.needSave()
                    self.moveZone(zone, into: toThere!, orphan: true) {
                        self.syncAndSignalAfterMoveAffecting(toThere, persistently: persistently)
                    }
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
                    moveZone(zone, into: toThere!, orphan: true){
                        self.syncAndSignalAfterMoveAffecting(toThere, persistently: persistently)
                    }
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
                actuallyMoveZone(zone, persistently: persistently)
            } else if zone.isBookmark {
                travelThroughBookmark(zone, persistently: persistently)
            } else if zone.children.count > 0 {
                moveSelectionInto(zone)
            } else {
                zone.showChildren = true

                zone.needChildren()

                operationsManager.getChildren(false) {
                    if zone.children.count > 0 {
                        self.moveSelectionInto(zone)
                    }
                }
            }
        }
    }


    func moveSelectionInto(_ zone: Zone) {
        let  hideChildren = !zone.showChildren
        zone.showChildren = true

        selectionManager.grab(asTask ? zone.children.first! : zone.children.last!)

        if hideChildren {
            syncToCloudAndSignal()
        } else {
            signalFor(nil, regarding: .data)
        }
    }


    func actuallyMoveZone(_ zone: Zone, persistently: Bool) {
        if  var         toThere = zone.parentZone {
            let        siblings = toThere.children

            if  let       index = siblings.index(of: zone) {
                let cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex >= 0 && cousinIndex < siblings.count {
                    toThere     = siblings[cousinIndex]

                    if !toThere.isBookmark {
                        let parent = zone.parentZone
                        parent?.needSave()
                        moveZone(zone, into: toThere, orphan: true){
                            self.syncAndSignalAfterMoveAffecting(parent, persistently: persistently)
                        }
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
                                self.moveZone(mover, into: there, orphan: false){
                                    self.syncAndSignalAfterMoveAffecting(nil, persistently: persistently)
                                }
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


    func moveZone(_ zone: Zone, into: Zone, orphan: Bool, onCompletion: Closure?) {
        zone.needSave()
        into.needSave()
        into.needChildren()

        into.showChildren = true

        operationsManager.getChildren(false) {
            if orphan {
                zone.orphan()
            }

            zone.parentZone = into
            let      insert = asTask ? 0 : into.children.count

            if asTask {
                into.children.insert(zone, at: 0)
            } else {
                into.children.append(zone)
            }

            into.recomputeOrderingUponInsertionAt(insert)
            onCompletion?()
        }
    }
}
