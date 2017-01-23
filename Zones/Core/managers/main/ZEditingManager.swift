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
    var stalledEvents = [ZoneEvent] ()
    var previousEvent: ZEvent?


    var isEditing: Bool {
        get {
            if let editedZone = selectionManager.currentlyEditingZone, let editedWidget = widgetsManager.widgetForZone(editedZone) {
                return editedWidget.textWidget.isTextEditing
            }

            return false
        }
    }


    // MARK:- API
    // MARK:-


    func handleStalledEvents() {
        while stalledEvents.count != 0 && operationsManager.isReady {
            let event = stalledEvents.remove(at: 0)

            handleEvent(event.event!, isWindow: event.isWindow)
        }
    }


    @discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> Bool {
        #if os(OSX)
            if !operationsManager.isReady {
                if stalledEvents.count < 1 {
                    stalledEvents.append(ZoneEvent(iEvent, iIsWindow: isWindow))
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
            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand)
            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand)
            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand)
            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand)
            }
        } else if let zone = selectionManager.firstGrabbableZone {
            var show = true

            switch arrow {
            case .left:  show = false
            case .right: break
            default:     return
            }

            showToggleDot(show, zone: zone, recursively: isCommand) { self.syncAnd(.redraw) };
        }
    }


    func handleKey(_ key: String?, flags: NSEventModifierFlags, isWindow: Bool) {
        if  key != nil, !isEditing {
            let    widget = widgetsManager.currentMovableWidget
            let isCommand = flags.contains(.command)
            let  isOption = flags.contains(.option)
            let   isShift = flags.contains(.shift)

            switch key! {
            case "p":  printHere()
            case "b":  createBookmark()
            case "\"": doFavorites(true, isOption)
            case "'":  doFavorites(isShift, isOption)
            case "/":
                if let zone = selectionManager.firstGrabbableZone {
                    focusOnZone(zone)
                }
            case "\u{7F}": // delete key
                if isWindow || isOption {
                    delete()
                }
            case " ":
                if widget != nil && (isWindow || isOption) && !(widget?.widgetZone.isBookmark)! {
                    addZoneTo(widget?.widgetZone)
                }
            case "f":
                if gStorageMode != .favorites {
                    gShowsSearching = !gShowsSearching

                    signalFor(nil, regarding: .search)
                }
            case "\r":
                if widget != nil {
                    if selectionManager.currentlyGrabbedZones.count != 0 {
                        if isCommand {
                            selectionManager.deselect()
                        } else {
                            widget?.textWidget.becomeFirstResponder()
                        }
                    } else if selectionManager.currentlyEditingZone != nil {
                        widget?.textWidget.resignFirstResponder()
                    }
                }
            case "\t":
                if widget != nil {
                    widget?.textWidget.resignFirstResponder()

                    if let parent = widget?.widgetZone.parentZone {
                        if widget?.widgetZone == hereZone {
                            hereZone            = parent
                            parent.showChildren = true
                        }

                        addZoneTo(parent)
                    } else {
                        selectionManager.currentlyEditingZone = nil

                        signalFor(nil, regarding: .redraw)
                    }
                }
            default:
                if key?.characters.first?.asciiValue == nil, !isEditing, let arrow = ZArrowKey(rawValue: (key?.utf8CString[2])!) {
                    handleArrow(arrow, flags: flags)
                }
            }
        }
    }


    // MARK:- other
    // MARK:-


    func syncAnd(_ kind: ZSignalKind) {
        controllersManager.syncToCloudAndSignalFor(nil, regarding: kind) {}
    }


    func doFavorites(_ isShift: Bool, _ isOption: Bool) {
        if                !isShift || !isOption {
            let backward = isShift ||  isOption

            favoritesManager.switchToNext(!backward) {
                self.syncAnd(.redraw)
            }
        } else {
            let zone = selectionManager.firstGrabbableZone

            favoritesManager.showFavoritesAndGrab(zone) { object, kind in
                self.syncAnd(.redraw)
            }
        }
    }


    func travelThroughBookmark(_ bookmark: Zone) {
        favoritesManager.updateGrabAndIndexFor(bookmark)
        travelManager.travelThrough(bookmark) { object, kind in
            self.syncAnd(.redraw)
        }
    }


    func createBookmark() {
        if gStorageMode != .favorites, let zone = selectionManager.firstGrabbableZone, !zone.isRoot {
            var bookmark: Zone? = nil

            invokeWithMode(.mine) {
                bookmark = favoritesManager.createBookmarkFor(zone, isFavorite: false)
            }

            bookmark?.grab()
            self.signalFor(nil, regarding: .redraw)
            operationsManager.sync {}
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
        let focusOn = { (zone: Zone, kind: ZSignalKind) in
            self.hereZone = zone

            selectionManager.deselect()
            zone.grab()
            self.signalFor(zone, regarding: .datum)
            self.syncAnd(kind)
        }

        if !iZone.isBookmark {
            favoritesManager.createBookmarkFor(iZone, isFavorite: true)
            focusOn(iZone, .data)
        } else {
            travelManager.travelThrough(iZone) { object, kind in
                focusOn((object as! Zone), .redraw)
            }
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

        onCompletion?(toZone)
    }


    func revealSiblingsOf(_ descendent: Zone, toHere: Zone) {
        recursivelyRevealSiblingsOf(descendent, toZone: toHere) { (iZone: Zone) in
            if iZone == toHere {
                self.hereZone = toHere

                travelManager.manifest.needSave()
            }

            self.syncAnd(.redraw)
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
        var       isChildless = zone.count == 0
        let noVisibleChildren = !zone.showChildren || isChildless

        if !show && noVisibleChildren && zone.isGrabbed {
            zone.showChildren = false

            zone.needSave()

            revealParentAndSiblingsOf(zone) {
                if let parent = zone.parentZone {
                    if  self.hereZone == zone {
                        self.hereZone = parent
                    }

                    parent.grab()
                    self.showToggleDot(show, zone: parent, recursively: recursively, onCompletion: onCompletion)
                }
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
                isChildless = zone.count == 0

                if  zone.hasChildren == isChildless {
                    zone.hasChildren = !isChildless

                    zone.needSave()
                }

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
                self.syncAnd(.redraw)
            }
        }
    }


    // MARK:- creation
    // MARK:-


    func addZoneTo(_ parentZone: Zone?) {
        addZoneTo(parentZone) { (iZone: Zone) in
            var beenHereBefore = false

            controllersManager.syncToCloudAndSignalFor(parentZone, regarding: .redraw) {
                if !beenHereBefore {
                    beenHereBefore            = true
                    operationsManager.isReady = true

                    widgetsManager.widgetForZone(iZone)?.textWidget.becomeFirstResponder()
                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }


    func addZoneTo(_ zone: Zone?, onCompletion: ZoneClosure?) {
        if zone != nil && gStorageMode != .favorites {
            zone?.needChildren()

            operationsManager.children(false) {
                if operationsManager.isReady {
                    let record = CKRecord(recordType: zoneTypeKey)
                    let  child = Zone(record: record, storageMode: gStorageMode)

                    child.needCreate()
                    widgetsManager.widgetForZone(zone!)?.textWidget.resignFirstResponder()
                    zone?.addAndReorderChild(child, at: asTask ? 0 : nil)

                    zone?.showChildren            = true
                    travelManager.manifest.total += 1

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
            last!.grab()
        }

        controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {
            self.signalFor(nil, regarding: .redraw)
        }
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
        var grabThisZone = zone.parentZone
        var     deleteMe = !zone.isRoot && !zone.isDeleted && zone.parentZone?.record != nil

        if !deleteMe && zone.isBookmark {
            deleteMe = zone.crossLink?.record.recordID.recordName != rootNameKey
        }

        if deleteMe {
            if grabThisZone != nil {
                if zone == travelManager.hereZone {
                    revealParentAndSiblingsOf(zone) {
                        travelManager.hereZone = grabThisZone

                        grabThisZone!.grab()
                        self.syncAnd(.redraw)
                    }
                }

                let siblings = grabThisZone!.children
                let    count = siblings.count

                if var index = siblings.index(of: zone) {
                    if count > 1 {
                        if index < count - 1 && (!asTask || index == 0) {
                            index += 1
                        } else if index > 0 {
                            index -= 1
                        }

                        grabThisZone = siblings[index]
                    }
                }
            }

            let   toDelete  = cloudManager.bookmarksFor(zone)
            let   manifest  = travelManager.manifestForMode(zone.storageMode!)
            zone.isDeleted  = true // will be saved, then ignored after next launch
            manifest.total -= 1

            deleteZones(toDelete,      in: zone)
            deleteZones(zone.children, in: zone)
            manifest.needSave()
            zone.needSave()
            zone.orphan()
            zone.updateCloudProperties()
        }

        return grabThisZone
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
                        next!.grab()
                    }
                } else if gStorageMode != .favorites {
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
        if      let         zone = selectionManager.firstGrabbableZone {
            if  let        there = zone.parentZone {
                if let     index = there.children.index(of: zone) {
                    var newIndex = index + (moveUp ? -1 : 1)

                    if extreme {
                        newIndex = moveUp ? 0 : there.count - 1
                    }

                    if newIndex >= 0 && newIndex < there.count {
                        if zone == hereZone {
                            hereZone = there
                        }

                        if selectionOnly {
                            there.children[newIndex].grab()
                            signalFor(nil, regarding: .redraw)
                        } else {
                            there.moveChild(from: index, to: newIndex)
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
                    favoritesManager.showFavoritesAndGrab(zone) { object, kind in
                        self.syncAnd(.redraw)
                    }
                } else if extreme {
                    if !hereZone.isRoot {
                        let here = hereZone // revealRoot changes hereZone, so nab it first

                        zone.grab()

                        revealRoot {
                            self.revealSiblingsOf(here, toHere: self.rootZone)
                        }
                    } else if !zone.isRoot {
                        hereZone = zone

                        travelManager.manifest.needSave()
                        syncAnd(.data)
                    }
                } else if zone == hereZone || parent == nil {
                    revealParentAndSiblingsOf(zone) {
                        if  let here = self.hereZone.parentZone {

                            here.grab()
                            self.revealSiblingsOf(self.hereZone, toHere: here)
                        }
                    }
                } else if parent != nil {
                    parent!.grab()
                    signalFor(parent!, regarding: .data)
                }
            } else if gStorageMode != .favorites {
                parent?.needSave() // for when zone is orphaned

                ////////////
                // move zone
                ////////////

                let grandparent = parent?.parentZone

                let moveIntoHere = { (iHere: Zone?) in
                    if iHere != nil {
                        self.hereZone = iHere!

                        travelManager.manifest.needSave()
                        self.moveZone(zone, outTo: iHere!, orphan: true) {
                            self.syncAnd(.redraw)
                        }
                    }
                }

                if extreme {
                    if hereZone.isRoot {
                        moveIntoHere(grandparent)
                    } else {
                        revealRoot {
                            moveIntoHere(self.rootZone)
                        }
                    }
                } else if hereZone != zone && hereZone != parent && grandparent != nil {
                    moveZone(zone, outTo: grandparent!, orphan: true){
                        controllersManager.syncToCloudAndSignalFor(grandparent!, regarding: .redraw) {}
                    }
                } else if parent != nil && parent!.isRoot {
                    favoritesManager.showFavoritesAndGrab(nil) { object, kind in
                        zone.isFavorite = true

                        moveIntoHere(favoritesManager.favoritesRootZone)
                    }
                } else {
                    revealParentAndSiblingsOf(hereZone) {
                        if parent?.parentZone != nil {
                            moveIntoHere((parent?.parentZone)!)
                        }
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
            } else if zone.count > 0 {
                moveSelectionInto(zone)
            } else {
                zone.showChildren = true

                zone.needChildren()

                operationsManager.children(false) {
                    if zone.count > 0 {
                        self.moveSelectionInto(zone)
                    }
                }
            }
        }
    }


    func moveSelectionInto(_ zone: Zone) {
        let  showChildren = zone.showChildren
        zone.showChildren = true

        selectionManager.grab(asTask ? zone.children.first! : zone.children.last!)

        if showChildren {
            zone.hasChildren = zone.count != 0

            zone.needSave()
        }

        syncAnd(.redraw)
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
                    } else if !travelManager.isZone(zone, ancestorOf: toThere) {

                        ///////////////////////////////
                        // move zone through a bookmark
                        ///////////////////////////////

                        var         mover = zone
                        let    targetLink = toThere.crossLink
                        let     sameGraph = zone.storageMode == targetLink?.storageMode
                        mover .isFavorite = false
                        let grabAndTravel = {
                            travelManager.travelThrough(toThere) { object, kind in
                                let there = object as! Zone

                                if !sameGraph {
                                    self.applyModeRecursivelyTo(mover)
                                }

                                self.report("at arrival")
                                self.moveZone(mover, into: there, orphan: false) {
                                    mover.grab()
                                    self.syncAnd(.redraw)
                                }
                            }
                        }

                        if sameGraph {
                            mover.orphan()

                            grabAndTravel()
                        } else {

                            if mover.isBookmark && mover.crossLink?.record != nil && !(mover.crossLink?.isRoot)! {
                                mover.orphan()
                            } else {
                                mover = zone.deepCopy()

                                mover.grab()
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
            zone?.storageMode = gStorageMode

            for child in (zone?.children)! {
                applyModeRecursivelyTo(child)
            }

            zone?.needCreate()
            zone?.updateLevel()
            zone?.updateCloudProperties()
        }
    }


    func moveZone(_ zone: Zone, outTo: Zone, orphan: Bool, onCompletion: Closure?) {
        var completedYet = false

        recursivelyRevealSiblingsOf(zone, toZone: outTo) { (iRevealedZone: Zone) in
            if !completedYet && iRevealedZone == outTo {
                completedYet     = true
                var insert: Int? = zone.parentZone?.siblingIndex

                zone.needSave()
                outTo.needSave()

                if outTo.storageMode == .favorites {
                    insert = favoritesManager.nextFavoritesIndex(forward: !asTask)
                } else if zone.parentZone?.parentZone == outTo {
                    if insert != nil {
                        insert = insert! + (asTask ? 1 : -1)

                        // to compute the insertion index
                        // so that moving back in returns exactly:
                        // if orphan == true
                        // visit zone's parent and parent of that, etc, until sibling's parent matches "into"
                        // grab sibling.siblingIndex
                        // then regarding atTask
                        // apply (+/- 1) so afterwards (code is above)
                        // if == count, use -1, means "append" (no insertion index)
                        // else use as insertion index

                    }
                }

                if orphan {
                    zone.orphan()
                }

                if  insert != nil && insert! > outTo.count {
                    insert = nil
                }

                outTo.addAndReorderChild(zone, at: insert)

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
            if orphan {
                zone.orphan()
            }

            into.addAndReorderChild(zone, at: asTask ? 0 : nil)
            onCompletion?()
        }
    }
}
