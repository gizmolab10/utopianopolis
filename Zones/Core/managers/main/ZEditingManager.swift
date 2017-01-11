//
//  ZEditingManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


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
    var previousEvent: ZEvent?


    // MARK:- API
    // MARK:-


    func handleDeferredEvents() {
        while deferredEvents.count != 0 && operationsManager.isReady {
            let event = deferredEvents.remove(at: 0)

            handleEvent(event.event!, isWindow: event.isWindow)
        }
    }


    @discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> Bool {
        #if os(OSX)
            if !operationsManager.isReady {
                if deferredEvents.count < 1 {
                    deferredEvents.append(ZoneEvent(iEvent, iIsWindow: isWindow))
                }
            } else if !isEditing, iEvent != previousEvent, gWorkMode == .editMode, let  string = iEvent.charactersIgnoringModifiers {
                let   flags = iEvent.modifierFlags
                let isArrow = flags.contains(.numericPad) && flags.contains(.function)
                let     key = string[string.startIndex].description

                if !isArrow {
                    handleKey(key, flags: flags, isWindow: isWindow)
                } else if isWindow {
                    let arrow = ZArrowKey(rawValue: key.utf8CString[2])!

                    handleArrow(arrow, flags: flags)
                }
            }

        #endif

        return true
    }


    func handleArrow(_ arrow: ZArrowKey, flags: NSEventModifierFlags) {
        let isCommand = flags.contains(.command)
        let  isOption = flags.contains(.option)
        let   isShift = flags.contains(.shift)

        if !isShift {
            switch arrow {
            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand); break
            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand); break
            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand); break
            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand); break
            }
        } else if let zone = selectionManager.firstGrabbableZone {
            var show = true

            switch arrow {
            case .left: show = false; break
            case .right:              break
            default:                  return
            }

            showToggleDot(show, zone: zone, recursively: isCommand) { controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {} };
        }
    }


    func handleKey(_ key: String?, flags: NSEventModifierFlags, isWindow: Bool) {
        if  key != nil, !isEditing, let widget = widgetsManager.currentMovableWidget {
            let isCommand = flags.contains(.command)
            let  isOption = flags.contains(.option)
            let   isShift = flags.contains(.shift)

            switch key! {
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

                    signalFor(nil, regarding: .redraw)
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
                if  let zone = selectionManager.firstGrabbableZone {
                    let bookmark = bookmarksManager.addNewBookmarkFor(zone, inPatchboard: isShift)

                    selectionManager.grab(bookmark)

                    if !isShift {
                        controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
                    } else {
                        travelManager.travelToPatchboardGraph() { (iThere: Any?, iKind: ZSignalKind) in
                            controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
                        }
                    }
                }

                break
            case "p":
                printHere()

                break
            case "f":
                gShowsSearching = !gShowsSearching

                signalFor(nil, regarding: .search)

                break
            case "'":
                if isShift && isCommand {
                    travelManager.travelToPatchboardGraph() { (iThere: Any?, iKind: ZSignalKind) in
                        controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
                    }
                } else {
                    travelManager.cycleStorageMode {
                        controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
                    }
                }

                break
            case "/":
                if let zone = selectionManager.firstGrabbableZone {
                    focusOnZone(zone)
                }

                break
            default:

                // TODO: needs test against -100 (expressed as a one-character string) ...
                // let arrowFirstKey = String("%c", -100)

                if isEditing, let arrow = ZArrowKey(rawValue: (key?.utf8CString[2])!) {
                    handleArrow(arrow, flags: flags)
                }

                break
            }
        }
    }


    func printHere() {
        if  let         view = widgetsManager.widgetForZone(hereZone) {
            let    printInfo = NSPrintInfo.shared()
            let pmPageFormat = PMPageFormat(printInfo.pmPageFormat())
            let      isWider = view.bounds.size.width > view.bounds.size.height
            let  orientation = PMOrientation(isWider ? kPMLandscape : kPMPortrait)
            let       length = Double(isWider ? view.bounds.size.width : view.bounds.size.height)
            let        scale = 64800.0 / length // 72 dpi * 9 inches * 100 percent

            PMSetScale(pmPageFormat, scale)
            PMSetOrientation(pmPageFormat, orientation, false)
            printInfo.updateFromPMPageFormat()
            NSPrintOperation(view: view, printInfo: printInfo).run()
        }
    }


    func focusOnZone(_ iZone: Zone) {
        let closure = { (kind: ZSignalKind) in
            selectionManager.deselect()
            selectionManager.grab(iZone)
            self.signalFor(iZone, regarding: .datum)
            controllersManager.syncToCloudAndSignalFor(nil, regarding: kind) {}
        }

        if !iZone.isBookmark {
            hereZone = iZone

            closure(.data)
        } else {
            travelManager.changeFocusThroughZone(iZone, atArrival: { (object, kind) in
                closure(.redraw)
            })
        }
    }


    var isEditing: Bool {
        get {
            if let editedZone = selectionManager.currentlyEditingZone, let editedWidget = widgetsManager.widgetForZone(editedZone) {
                return editedWidget.textWidget.isTextEditing
            }

            return false
        }
    }


    // MARK:- async reveal
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
        let           parent = iZone.parentZone
        parent?.showChildren = true

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


    func recursivelyRevealSiblingsOf(_ descendent: Zone, toZone: Zone, onCompletion: ZoneClosure?) {
        if toZone != descendent {
            revealParentAndSiblingsOf(descendent) {
                if let parent = descendent.parentZone {
                    self.recursivelyRevealSiblingsOf(parent, toZone: toZone, onCompletion: onCompletion)
                }
            }
        }

        onCompletion?(descendent)
    }


    func revealSiblingsOf(_ descendent: Zone, toHere: Zone) {
        recursivelyRevealSiblingsOf(descendent, toZone: toHere) { (iZone: Zone) in
            if iZone == toHere {
                self.hereZone = toHere

                travelManager.manifest.needSave()
            }

            controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
        }
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


    func showToggleDot(_ show: Bool, zone: Zone, recursively: Bool, onCompletion: Closure?) {
        let       isChildless = zone.children.count == 0
        let noVisibleChildren = !zone.showChildren || isChildless

        if !show && noVisibleChildren && selectionManager.isGrabbed(zone) {
            zone.showChildren = false

            zone.needSave()

            revealParentAndSiblingsOf(zone) {
                let parent = zone.parentZone

                if  self.hereZone == zone {
                    self.hereZone = parent!
                }

                selectionManager.grab(parent)
                self.showToggleDot(show, zone: parent!, recursively: recursively, onCompletion: onCompletion)
            }
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
                        self.showToggleDot(show, zone: child, recursively: recursively, onCompletion: nil)
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


    func toggleDotActionOnZone(_ zone: Zone, recursively: Bool) {
        if zone.isBookmark {
            travelThroughBookmark(zone)
        } else {
            let show = zone.showChildren == false

            showToggleDot(show, zone: zone, recursively: recursively) {
                controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
            }
        }
    }


    func travelThroughBookmark(_ bookmark: Zone) {
        travelManager.changeFocusThroughZone(bookmark, atArrival: { (object, kind) in
            if let there: Zone = object as? Zone {
                selectionManager.grab(there)
                controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
            }
        })
    }
    

    // MARK:- creation
    // MARK:-


    func addZoneTo(_ parentZone: Zone?) {
        addZoneTo(parentZone) { (iZone: Zone) in
            controllersManager.syncToCloudAndSignalFor(parentZone, regarding: .redraw) {
                operationsManager.isReady = true

                widgetsManager.widgetForZone(iZone)?.textWidget.becomeFirstResponder()
                self.signalFor(nil, regarding: .redraw)
            }
        }
    }


    func addZoneTo(_ zone: Zone?, onCompletion: ZoneClosure?) {
        if zone != nil && gStorageMode != .bookmarks {
            zone?.needChildren()

            operationsManager.children(false) {
                if operationsManager.isReady {
                    let record = CKRecord(recordType: zoneTypeKey)
                    let insert = asTask ? 0 : (zone?.children.count)!
                    let  child = Zone(record: record, storageMode: gStorageMode)

                    child.needCreate()
                    widgetsManager.widgetForZone(zone!)?.textWidget.resignFirstResponder()

                    if asTask {
                        zone?.children.insert(child, at: 0)
                    } else {
                        zone?.children.append(child)
                    }

                    child.parentZone              = zone
                    zone?.showChildren            = true
                    travelManager.manifest.total += 1

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

        controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
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

        if !zone.isRoot && !zone.isDeleted {
            if parentZone != nil {
                if zone == travelManager.hereZone {
                    let toHere = parentZone

                    revealParentAndSiblingsOf(zone) {
                        travelManager.hereZone = toHere

                        selectionManager.grab(parentZone)
                        controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
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

            if gStorageMode != .bookmarks {
                travelManager.manifest.total -= 1
                zone               .isDeleted = true

                zone.needSave()
            }

            deleteZones(zone.children, in: zone)
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
                } else if gStorageMode != .bookmarks {
                    parentZone.children.remove(at: index)
                    parentZone.children.insert(zone, at:newIndex)
                }

                signalFor(parentZone, regarding: .redraw)
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
                            signalFor(nil, regarding: .redraw)
                        } else {
                            there.children.remove(at: index)
                            there.children.insert(zone, at:newIndex)
                            there.recomputeOrderingUponInsertionAt(newIndex)
                            controllersManager.syncToCloudAndSignalFor(there, regarding: .redraw) {}
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


    func moveOut(selectionOnly: Bool, extreme: Bool) {
        if let zone: Zone = selectionManager.firstGrabbableZone {
            let    parent = zone.parentZone

            if selectionOnly {

                /////////////////
                // move selection
                /////////////////

                if zone.isRoot {

                    // for "travelling out", root "points to" corresponding zone in bookmarks graph

                    travelManager.changeFocusThroughZone(zone) { object, kind in
                        if let there: Zone = object as? Zone {
                            selectionManager.grab(there)

                            controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
                        }
                    }
                } else if extreme {
                    if !hereZone.isRoot {
                        let here = hereZone // revealRoot changes hereZone, so nab it first

                        selectionManager.grab(zone)

                        revealRoot {
                            self.revealSiblingsOf(here, toHere: self.rootZone)
                        }
                    } else if !zone.isRoot {
                        hereZone = zone

                        travelManager.manifest.needSave()
                        controllersManager.syncToCloudAndSignalFor(nil, regarding: .data) {}
                    }
                } else if zone == hereZone || parent == nil {
                    revealParentAndSiblingsOf(zone) {
                        if  let here = self.hereZone.parentZone {

                            selectionManager.grab(here)
                            self.revealSiblingsOf(self.hereZone, toHere: here)
                        }
                    }
                } else if parent != nil {
                    selectionManager.grab(parent!)
                    signalFor(parent!, regarding: .data)
                }
            } else if gStorageMode != .bookmarks {
                parent?.needSave() // for when zone is orphaned

                ////////////
                // move zone
                ////////////

                var grandparent = parent?.parentZone

                let moveIntoHereIsGrandparent = {
                    self.hereZone = grandparent!

                    travelManager.manifest.needSave()
                    self.moveZone(zone, outTo: grandparent!, orphan: true) {
                        controllersManager.syncToCloudAndSignalFor(grandparent, regarding: .redraw) {}
                    }
                }

                if extreme {
                    if hereZone.isRoot {
                        moveIntoHereIsGrandparent()
                    } else {
                        revealRoot {
                            grandparent = self.rootZone

                            moveIntoHereIsGrandparent()
                        }
                    }
                } else if (hereZone == zone || hereZone == parent) {
                    revealParentAndSiblingsOf(hereZone) {
                        grandparent = parent?.parentZone

                        if grandparent != nil {
                            moveIntoHereIsGrandparent()
                        }
                    }
                } else {
                    moveZone(zone, outTo: grandparent!, orphan: true){
                        controllersManager.syncToCloudAndSignalFor(grandparent, regarding: .redraw) {}
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
            controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
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

                        moveZone(zone, into: toThere, orphan: true){
                            controllersManager.syncToCloudAndSignalFor(parent, regarding: .redraw) {}
                        }
                    } else {

                        ///////////////////////////////
                        // move zone through a bookmark
                        ///////////////////////////////

                        var         mover = zone
                        let     sameGraph = zone.storageMode == toThere.crossLink?.storageMode
                        let grabAndTravel = {
                            selectionManager.grab(mover)

                            travelManager.changeFocusThroughZone(toThere, atArrival: { (object, kind) in
                                let there = object as! Zone

                                if !sameGraph {
                                    self.applyModeRecursivelyTo(mover)
                                }

                                self.report("at arrival")
                                self.moveZone(mover, into: there, orphan: false){
                                    controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
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
            zone?.record    = CKRecord(recordType: zoneTypeKey)
            zone?.storageMode = gStorageMode

            for child in (zone?.children)! {
                applyModeRecursivelyTo(child)
            }

            zone!.needCreate()
            zone?.updateCloudProperties()
        }
    }


    func moveZone(_ zone: Zone, outTo: Zone, orphan: Bool, onCompletion: Closure?) {
        var insert = -1

        recursivelyRevealSiblingsOf(zone, toZone: outTo) { (iZone: Zone) in
            if iZone.parentZone == outTo {
                insert = iZone.siblingIndex + (asTask ? 1 : -1)
                // to compute the insertion index
                // so that moving back in returns exactly:
                // if orphan == true
                // visit zone's parent and parent of that, etc, until sibling's parent matches "into"
                // grab sibling.siblingIndex
                // then regarding atTask
                // apply (+/- 1) so afterwards (code is above)
                // if == count, use -1, means "append" (no insertion index)
                // else use as insertion index

            } else if iZone == outTo {
                zone.needSave()
                outTo.needSave()

                if orphan {
                    zone.orphan()
                }

                zone.parentZone  = outTo
                let siblingCount = outTo.children.count

                if insert == siblingCount {
                    outTo.children.append(zone)
                } else if insert > -1 {
                    outTo.children.insert(zone, at: insert)
                }

                outTo.recomputeOrderingUponInsertionAt(insert)
                zone.updateLevel()
                onCompletion?()
            }
        }
    }


    func moveZone(_ zone: Zone, into: Zone, orphan: Bool, onCompletion: Closure?) {
        zone.needSave()
        into.needSave()
        into.needChildren()

        into.showChildren = true

        operationsManager.children(false) {
            let siblingCount = into.children.count
            let       insert = asTask ? 0 : siblingCount

            if orphan {
                zone.orphan()
            }

            zone.parentZone = into

            if insert == siblingCount {
                into.children.append(zone)
            } else {
                into.children.insert(zone, at: insert)
            }

            into.recomputeOrderingUponInsertionAt(insert)
            zone.updateLevel()
            onCompletion?()
        }
    }
}
