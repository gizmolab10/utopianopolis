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
            previousEvent = event

            #if os(OSX)
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
                                controllersManager.syncToCloudAndSignalFor(nil) {}
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

                                    controllersManager.syncToCloudAndSignalFor(nil) {}
                                } else {
                                    travelManager.travelToWhereThisZonePoints(zone, atArrival: { (object, kind) in
                                        controllersManager.syncToCloudAndSignalFor(nil) {}
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
                            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand); break
                            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand); break
                            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand); break
                            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand); break
                            }
                        } else if let zone = selectionManager.firstGrabbableZone {
                            switch arrow {
                            case .right: showRevealerDot(true,  zone: zone, recursively: isCommand) { controllersManager.syncToCloudAndSignalFor(nil) {} }; break
                            case .left:  showRevealerDot(false, zone: zone, recursively: isCommand) { controllersManager.syncToCloudAndSignalFor(nil) {} }; break
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


    func levelFor(_ show: Bool, zone: Zone) -> Int {
        var level = unlevel

        zone.traverseApply { iZone -> Bool in
            let zoneLevel = iZone.level

            if (!show && level < zoneLevel) || (show && iZone.hasChildren && !iZone.showChildren && level > zoneLevel) {
                level = zoneLevel
            }

            return false
        }

        return level
    }


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
                operationsManager.children(recursively) {
                    recurseMaybe()
                }
            }
        }
    }


    func revealerDotActionOnZone(_ zone: Zone) {
        if zone.isBookmark {
            travelThroughBookmark(zone)
        } else {
            let show = zone.showChildren == false

            showRevealerDot(show, zone: zone, recursively: false) {
                controllersManager.syncToCloudAndSignalFor(nil) {}
            }
        }
    }


    func travelThroughBookmark(_ bookmark: Zone) {
        travelManager.travelToWhereThisZonePoints(bookmark, atArrival: { (object, kind) in
            if let there: Zone = object as? Zone {
                selectionManager.grab(there)
                travelManager.manifest.needSave()
                controllersManager.syncToCloudAndSignalFor(nil) {}
            }
        })
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

            operationsManager.children(false) {
                if operationsManager.isReady {
                    let record = CKRecord(recordType: zoneTypeKey)
                    let insert = asTask ? 0 : (zone?.children.count)!
                    let  child = Zone(record: record, storageMode: travelManager.storageMode)

                    child.needCreate()
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

        controllersManager.syncToCloudAndSignalFor(nil) {}
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
        var parentZone = zone.parentZone

        if !zone.isRoot {
            if travelManager.storageMode != .bookmarks && !zone.isDeleted {
                zone.isDeleted = true

                zone.needSave()
            }

            deleteZones(zone.children, in: zone)

            if parentZone != nil {
                if zone == travelManager.hereZone {
                    dispatchAsyncInForeground {
                        self.revealParentAndSiblingsOf(zone) {
                            travelManager.hereZone = parentZone

                            selectionManager.grab(parentZone)
                            controllersManager.syncToCloudAndSignalFor(nil) {}
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
            }

            zone.orphan()
        }

        return parentZone
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


    //    if beyond end, search for uncles aunts whose children or email


    func moveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool) {
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
                            signalFor(nil, regarding: .data)
                        } else {
                            there.children.remove(at: index)
                            there.children.insert(zone, at:newIndex)
                            there.recomputeOrderingUponInsertionAt(newIndex)
                            controllersManager.syncToCloudAndSignalFor(there) {}
                        }
                    }
                }
            } else if !zone.isRoot {
                revealParentAndSiblingsOf(zone) {
                    if zone.parentZone != nil {
                        self.moveUp(moveUp, selectionOnly: selectionOnly, extreme: extreme)
                    }
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


    func revealParentAndSiblingsOf(_ iZone: Zone, onCompletion: Closure?) {
        let parent = iZone.parentZone

        if parent != nil && parent?.zoneName != nil {
            parent?.needChildren()

            operationsManager.children(false) {
                onCompletion?()
            }
        } else {
            iZone.markForStates([.needsParent])

            operationsManager.families {
                onCompletion?()
            }
        }
    }


    func revealSiblingsOf(_ descendent: Zone, toHere: Zone) {
        if toHere   == descendent {
            hereZone = descendent

            travelManager.manifest.needSave()
        } else if let parent = descendent.parentZone {
            hereZone = parent

            revealParentAndSiblingsOf(descendent) {
                self.revealSiblingsOf(parent, toHere: toHere)
            }
        }

        controllersManager.syncToCloudAndSignalFor(nil) {}
    }


    func moveOut(selectionOnly: Bool, extreme: Bool) {
        if let zone: Zone = selectionManager.firstGrabbableZone {
            var toThere = zone.parentZone

            if selectionOnly {
                if zone.isRoot {

                    // for "travelling out", root "points to" corresponding zone in bookmarks graph

                    travelManager.travelToWhereThisZonePoints(zone) { object, kind in
                        if let there: Zone = object as? Zone {
                            selectionManager.grab(there)

                            controllersManager.syncToCloudAndSignalFor(nil) {}
                        }
                    }
                } else if extreme {
                    if !hereZone.isRoot {
                        let here = hereZone // revealRoot changes here, so nab it first

                        selectionManager.grab(zone)

                        revealRoot {
                            self.revealSiblingsOf(here, toHere: self.rootZone)
                        }
                    } else if !zone.isRoot {
                        hereZone = zone

                        travelManager.manifest.needSave()
                        controllersManager.syncToCloudAndSignalFor(nil) {}
                    }
                } else if zone == hereZone || toThere == nil {
                    revealParentAndSiblingsOf(zone) {
                        if  let here = self.hereZone.parentZone {

                            selectionManager.grab(here)
                            self.revealSiblingsOf(self.hereZone, toHere: here)
                        }
                    }
                } else if toThere != nil {
                    selectionManager.grab(toThere!)
                    signalFor(toThere!, regarding: .data)
                }
            } else if travelManager.storageMode != .bookmarks, let fromThere = toThere {
                toThere     = fromThere.parentZone
                let closure = {
                    self.hereZone = toThere!

                    travelManager.manifest.needSave()
                    self.moveZone(zone, into: toThere!, orphan: true) {
                        controllersManager.syncToCloudAndSignalFor(toThere) {}
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
                    revealParentAndSiblingsOf(hereZone) {
                        toThere = fromThere.parentZone

                        if toThere != nil {
                            closure()
                        }
                    }
                } else {
                    moveZone(zone, into: toThere!, orphan: true){
                        controllersManager.syncToCloudAndSignalFor(toThere) {}
                    }
                }
            }
        }
    }


    // MARK:- move in
    // MARK:-


    func moveInto(selectionOnly: Bool, extreme: Bool) {
        if let zone: Zone = selectionManager.firstGrabbableZone {
            if !selectionOnly {
                actuallyMoveZone(zone)
            } else if zone.isBookmark {
                travelThroughBookmark(zone)
            } else if zone.children.count > 0 {
                moveSelectionInto(zone)
            } else {
                zone.showChildren = true

                zone.needChildren()

                operationsManager.children(false) {
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


    func actuallyMoveZone(_ zone: Zone) {
        if  var         toThere = zone.parentZone {
            let        siblings = toThere.children

            if  let       index = siblings.index(of: zone) {
                let cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex >= 0 && cousinIndex < siblings.count {
                    toThere     = siblings[cousinIndex]

                    if !toThere.isBookmark {
                        let parent = zone.parentZone

                        zone.orphan()
                        moveZone(zone, into: toThere, orphan: true){
                            controllersManager.syncToCloudAndSignalFor(parent) {}
                        }
                    } else {

                        ///////////////////////////////
                        // move zone through a bookmark
                        ///////////////////////////////

                        var         mover = zone
                        let     sameGraph = zone.storageMode == toThere.crossLink?.storageMode
                        let grabAndTravel = {
                            selectionManager.grab(mover)

                            travelManager.travelToWhereThisZonePoints(toThere, atArrival: { (object, kind) in
                                let there = object as! Zone

                                if !sameGraph {
                                    self.applyModeRecursivelyTo(mover)
                                }

                                self.report("at arrival")
                                self.moveZone(mover, into: there, orphan: false){
                                    controllersManager.syncToCloudAndSignalFor(nil) {}
                                }
                            })
                        }

                        if sameGraph {
                            mover.orphan()

                            grabAndTravel()
                        } else {
                            let crossLink = mover.crossLink

                            if mover.isBookmark && crossLink?.record != nil && !(crossLink?.isRoot)! {
                                mover.orphan()
                            } else {
                                mover = zone.deepCopy()
                            }

                            operationsManager.sync {
                                grabAndTravel()
                            }
                        }
                    }
                }
            }
        }
    }


    func applyModeRecursivelyTo(_ zone: Zone?) {
        if zone != nil {
            zone?.record      = CKRecord(recordType: zoneTypeKey)
            zone?.storageMode = travelManager.storageMode

            for child in (zone?.children)! {
                applyModeRecursivelyTo(child)
            }

            zone!.needCreate()
            zone?.updateCloudProperties()
        }
    }


    func moveZone(_ zone: Zone, into: Zone, orphan: Bool, onCompletion: Closure?) {
        zone.needSave()
        into.needSave()
        into.needChildren()

        into.showChildren = true

        operationsManager.children(false) {
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
            zone.updateLevel()
            onCompletion?()
        }
    }
}
