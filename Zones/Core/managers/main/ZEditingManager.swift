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


    var rootZone: Zone { get { return gTravelManager.rootZone! } set { gTravelManager.rootZone = newValue } }
    var hereZone: Zone { get { return gTravelManager.hereZone  } set { gTravelManager.hereZone = newValue } }
    var stalledEvents = [ZoneEvent] ()
    var previousEvent: ZEvent?


    var isEditing: Bool {
        get {
            if let editedZone = gSelectionManager.currentlyEditingZone, let editedWidget = editedZone.widget {
                return editedWidget.textWidget.isTextEditing
            }

            return false
        }
    }


    // MARK:- user input event handlers
    // MARK:-


    func handleStalledEvents() {
        while stalledEvents.count != 0 && gOperationsManager.isReady {
            let event = stalledEvents.remove(at: 0)

            handleEvent(event.event!, isWindow: event.isWindow)
        }
    }


    @discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> Bool {
        if !gOperationsManager.isReady {
            if stalledEvents.count < 1 {
                stalledEvents.append(ZoneEvent(iEvent, iIsWindow: isWindow))
            }
        } else if !isEditing, iEvent != previousEvent, gWorkMode == .editMode {
            let string = iEvent.input
            let  flags = iEvent.modifierFlags
            let    key = string[string.startIndex].description

            handleKey(key, flags: flags, isWindow: isWindow)
        }

        return true
    }


    func handleMenuItem(_ iItem: ZMenuItem?) {
        #if os(OSX)
            var flags = (iItem?.keyEquivalentModifierMask)!
            var   key = (iItem?.keyEquivalent)!

            if key != key.lowercased() {
                flags.insert(.shift)    // add isShift to flags

                key = key.lowercased()
            }

            handleKey(key, flags: flags, isWindow: true)
        #endif
    }


    func handleKey(_ key: String?, flags: ZEventFlags, isWindow: Bool) {
        if  !isEditing &&   key != nil {
            if  let     arrow = key?.arrow, isWindow {
                handleArrow(arrow, flags: flags)
            } else {
                let    widget = gWidgetsManager.currentMovableWidget
                let isCommand = flags.isCommand
                let  isOption = flags.isOption
                let   isShift = flags.isShift
                let hasWidget = widget != nil
                let isSpecial = isWindow || isOption

                switch key! {
                case "f":       find()
                case "p":       printHere()
                case "b":       createBookmark()
                case "'":       doFavorites(isShift, isOption)
                case "\"":      doFavorites(true,    isOption)
                case "\u{7F}":  if isSpecial { delete() } // delete
                case "\t":      if hasWidget { addSibling() } // tab
                case "/":       focusOnZone(gSelectionManager.firstGrabbableZone)
                case " ":
                    if hasWidget && isSpecial && !(widget?.widgetZone.isBookmark)! {
                        addNewChildTo(widget?.widgetZone)
                    }
                case "\r":
                    if hasWidget && gSelectionManager.hasGrab {
                        gSelectionManager.deselect()

                        if !isCommand {
                            widget?.textWidget.becomeFirstResponder()
                        }
                    }
                default:
                    break
                }
            }
        }
    }


    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        let isCommand = flags.isCommand
        let  isOption = flags.isOption
        let   isShift = flags.isShift

        if !isShift {
            switch arrow {
            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand)
            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand)
            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand)
            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand)
            }
        } else {

            let zone = gSelectionManager.firstGrabbableZone
            var show = true

            switch arrow {
            case .left:  show = false
            case .right: break
            default:     return
            }

            showToggleDot(show, zone: zone, recursively: isCommand) { self.syncAndRedraw() };
        }
    }

    // MARK:- API
    // MARK:-


    func copyToPaste() {
        gSelectionManager.clearPaste()

        for zone in gSelectionManager.currentlyGrabbedZones {
            addToPasteCopyOf(zone)
        }
    }


    func paste() {
        pasteInto(gSelectionManager.firstGrabbableZone)
    }


    func delete() {
        prepareUndoForDelete()

        let last = deleteZones(gSelectionManager.currentlyGrabbedZones, in: nil)

        last?.grab()

        gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {
            self.signalFor(nil, regarding: .redraw)
        }
    }


    func find() {
        if gStorageMode != .favorites {
            gShowsSearching = !gShowsSearching

            signalFor(nil, regarding: .search)
        }
    }


    func createBookmark() {
        let zone = gSelectionManager.firstGrabbableZone

        if gStorageMode != .favorites, !zone.isRoot {
            let closure = {
                var bookmark: Zone? = nil

                self.invokeWithMode(.mine) {
                    bookmark = gFavoritesManager.createBookmarkFor(zone, isFavorite: false)
                }

                bookmark?.grab()
                self.signalFor(nil, regarding: .redraw)
                gOperationsManager.sync {}
            }

            if hereZone != zone {
                closure()
            } else {
                self.revealParentAndSiblingsOf(zone) {
                    self.hereZone = zone.parentZone ?? self.hereZone

                    closure()
                }
            }
        }
    }


    func printHere() {
        #if os(OSX)

        if  let         view = hereZone.widget {
            let    printInfo = NSPrintInfo.shared()
            let pmPageFormat = PMPageFormat(printInfo.pmPageFormat())
            let      isWider = view.bounds.size.width > view.bounds.size.height
            let  orientation = PMOrientation(isWider ? kPMLandscape : kPMPortrait)
            let       length = Double(isWider ? view.bounds.size.width : view.bounds.size.height)
            let        scale = 46800.0 / length // 72 dpi * 6.5 inches * 100 percent

            PMSetScale(pmPageFormat, scale)
            PMSetOrientation(pmPageFormat, orientation, false)
            printInfo.updateFromPMPageFormat()
            NSPrintOperation(view: view, printInfo: printInfo).run()
        }

        #endif
    }


    // MARK:- other
    // MARK:-


    func syncAndRedraw() {
        gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw, onCompletion: nil)
    }


    func doFavorites(_ isShift: Bool, _ isOption: Bool) {
        if                !isShift || !isOption {
            let backward = isShift ||  isOption

            gFavoritesManager.switchToNext(!backward) { self.syncAndRedraw() }
        } else {
            gFavoritesManager.showFavoritesAndGrab(gSelectionManager.firstGrabbableZone) { object, kind in
                self.syncAndRedraw()
            }
        }
    }


    func travelThroughBookmark(_ bookmark: Zone) {
        gFavoritesManager.updateGrabAndIndexFor(bookmark)
        gTravelManager.travelThrough(bookmark) { object, kind in
            self.syncAndRedraw()
        }
    }


    func focusOnZone(_ iZone: Zone) {
        let focusOn = { (zone: Zone, kind: ZSignalKind) in
            self.hereZone = zone

            gSelectionManager.deselect()
            zone.grab()
            gControllersManager.syncToCloudAndSignalFor(nil, regarding: kind) {}
        }

        if iZone.isBookmark {
            gTravelManager.travelThrough(iZone) { object, kind in
                focusOn((object as! Zone), .redraw)
            }
        } else {
            gFavoritesManager.createBookmarkFor(iZone, isFavorite: true)
            focusOn(iZone, .redraw)

        }
    }


    // MARK:- async reveal
    // MARK:-


    func revealRoot(_ onCompletion: Closure?) {
        if rootZone.record != nil {
            onCompletion?()
        } else {
            gOperationsManager.root {
                onCompletion?()
            }
        }
    }


    func revealParentAndSiblingsOf(_ iZone: Zone, onCompletion: Closure?) {
        let           parent = iZone.parentZone
        parent?.showChildren = true

        if parent != nil && parent?.zoneName != nil {
            parent?.needChildren()

            gOperationsManager.children(recursively: false) {
                onCompletion?()
            }
        } else {
            iZone.markForStates([.needsParent])

            gOperationsManager.families {
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

                gTravelManager.manifest.needUpdateSave()
            }

            self.syncAndRedraw()
        }
    }


    // MARK:- layout
    // MARK:-


    func levelFor(_ show: Bool, zone: Zone) -> Int {
        var level = gUnlevel

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

            zone.needUpdateSave()

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

                zone.needUpdateSave()

                if !show {
                    gSelectionManager.deselectDragWithin(zone);
                } else if isChildless {
                    zone.needChildren()
                }
            }

            let recurseMaybe = {
                isChildless = zone.count == 0

                if  zone.hasChildren == isChildless {
                    zone.hasChildren = !isChildless

                    zone.needUpdateSave()
                }

                if gOperationsManager.isReady {
                    onCompletion?()
                }

                if recursively {
                    for child: Zone in zone.children {
                        if child != zone {
                            self.showToggleDot(show, zone: child, recursively: true, onCompletion: nil)
                        }
                    }
                }
            }

            if !show || !isChildless {
                recurseMaybe()
            } else {
                gOperationsManager.children(recursively: recursively) {
                    recurseMaybe()
                }
            }
        }
    }


    func toggleDotActionOnZone(_ zone: Zone?, recursively: Bool) {
        if zone != nil {
            if zone!.isBookmark {
                travelThroughBookmark(zone!)
            } else {
                let show = !zone!.showChildren

                showToggleDot(show, zone: zone!, recursively: recursively) {
                    self.syncAndRedraw()
                }
            }
        }
    }


    // MARK:- creation
    // MARK:-


    func addSibling() {
        let widget = gWidgetsManager.currentMovableWidget

        widget?.textWidget.resignFirstResponder()

        if let parent = widget?.widgetZone.parentZone {
            if widget?.widgetZone == hereZone {
                hereZone            = parent
                parent.showChildren = true
            }

            addNewChildTo(parent)
        }
    }


    func addNewChildTo(_ parentZone: Zone?) {
        addNewChildTo(parentZone) { (iZone: Zone) in
            var beenHereBefore = false

            gControllersManager.syncToCloudAndSignalFor(parentZone, regarding: .redraw) {
                if !beenHereBefore {
                    beenHereBefore             = true
                    gOperationsManager.isReady = true

                    iZone.widget?.textWidget.becomeFirstResponder()
                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }


    func addNewChildTo(_ zone: Zone?, onCompletion: ZoneClosure?) {
        if zone != nil && gStorageMode != .favorites {
            let addNewClosure = {
                let record = CKRecord(recordType: zoneTypeKey)
                let  child = Zone(record: record, storageMode: gStorageMode)

                child.needCreate()
                zone!.widget?.textWidget.resignFirstResponder()
                zone!.addAndReorderChild(child, at: asTask ? 0 : nil)

                gTravelManager.manifest.total += 1

                onCompletion?(child)
            }

            zone!.showChildren = true // needed for logic internal to needChildren

            if zone!.count != 0 {
                addNewClosure()
            } else {
                zone!.needChildren()

                gOperationsManager.children(recursively: false) {
                    addNewClosure()
                }
            }
        }
    }


    func addToPasteCopyOf(_ zone: Zone) {
        let        copy = zone.deepCopy()
        copy.isDeleted  = false
        copy.parentZone = nil

        gSelectionManager.pasteableZones.append(copy)
    }


    @discardableResult private func deleteZones(_ zones: [Zone], in parent: Zone?) -> Zone? {
        var last: Zone? = nil

        for zone in zones {
            if  zone != parent { // detect and avoid infinite recursion
                last  = deleteZone(zone)
            }
        }

        return last
    }


    @discardableResult private func deleteZone(_ zone: Zone) -> Zone? {
        var grabThisZone = zone.parentZone
        var     deleteMe = !zone.isRoot && !zone.isDeleted && zone.parentZone?.record != nil

        if !deleteMe && zone.isBookmark, let name = zone.crossLink?.record.recordID.recordName {
            deleteMe = ![rootNameKey, favoritesRootNameKey].contains(name)
        }

        if deleteMe {
            if grabThisZone != nil {
                if zone == hereZone { // this can only happen once during recursion (multiple places, below)
                    revealParentAndSiblingsOf(zone) {
                        self.hereZone = grabThisZone!

                        self.deleteZone(zone) // recurse
                    }

                    return grabThisZone
                }

                let siblings = grabThisZone!.children
                let    count = siblings.count

                if count > 1, var index = siblings.index(of: zone) {
                    if index < count - 1 && (!asTask || index == 0) {
                        index += 1
                    } else if index > 0 {
                        index -= 1
                    }

                    grabThisZone = siblings[index]
                }
            }

            let  bookmarks  = gCloudManager.bookmarksFor(zone)
            let   manifest  = gTravelManager.manifestForMode(zone.storageMode!)
            zone.isDeleted  = true // will be saved, then ignored after next launch
            manifest.total -= 1

            deleteZones(zone.children, in: zone) // recurse
            deleteZones(bookmarks,     in: zone) // recurse
            zone.orphan()
            zone    .needUpdateSave()
            manifest.needUpdateSave()
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
        let                  zone: Zone = gSelectionManager.firstGrabbableZone
        if  let              parentZone = zone.parentZone {
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


    // MARK:- move
    // MARK:-


    func moveOut(selectionOnly: Bool, extreme: Bool) {
        let zone: Zone = gSelectionManager.firstGrabbableZone
        let     parent = zone.parentZone

        if selectionOnly {

            /////////////////
            // move selection
            /////////////////

            if zone.isRoot {
                gFavoritesManager.showFavoritesAndGrab(zone) { object, kind in
                    self.syncAndRedraw()
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

                    gTravelManager.manifest.needUpdateSave()
                    gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
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
            parent?.needUpdateSave() // for when zone is orphaned

            ////////////
            // move zone
            ////////////

            let grandparent = parent?.parentZone

            let moveIntoHere = { (iHere: Zone?) in
                if iHere != nil {
                    self.hereZone = iHere!

                    gTravelManager.manifest.needUpdateSave()
                    self.moveZone(zone, outTo: iHere!, orphan: true) {
                        self.syncAndRedraw()
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
                    gControllersManager.syncToCloudAndSignalFor(grandparent!, regarding: .redraw) {}
                }
            } else if parent != nil && parent!.isRoot {
                gFavoritesManager.showFavoritesAndGrab(nil) { object, kind in
                    zone.isFavorite = true

                    moveIntoHere(gFavoritesManager.favoritesRootZone)
                }
            } else {
                revealParentAndSiblingsOf(hereZone) {
                    if let grandparent = parent?.parentZone {
                        moveIntoHere(grandparent)
                    }
                }
            }
        }
    }


    func moveInto(selectionOnly: Bool, extreme: Bool) {
        let zone: Zone = gSelectionManager.firstGrabbableZone

        if !selectionOnly {
            actuallyMoveZone(zone)
        } else if zone.isBookmark {
            travelThroughBookmark(zone)
        } else if zone.count > 0 {
            moveSelectionInto(zone)
        } else {
            zone.showChildren = true

            zone.needChildren()

            gOperationsManager.children(recursively: false) {
                if zone.count > 0 {
                    self.moveSelectionInto(zone)
                }
            }
        }
    }


    func moveSelectionInto(_ zone: Zone) {
        let  showChildren = zone.showChildren
        zone.showChildren = true

        gSelectionManager.grab(asTask ? zone.children.first! : zone.children.last!)

        if showChildren {
            zone.hasChildren = zone.count != 0

            zone.needUpdateSave()
        }

        syncAndRedraw()
    }


    func moveZone(_ zone: Zone, _ toThere: Zone) {
        if !toThere.isBookmark {
            let parent = zone.parentZone

            moveZone(zone, into: toThere, orphan: true){
                gControllersManager.syncToCloudAndSignalFor(parent, regarding: .redraw) {}
            }
        } else if !gTravelManager.isZone(zone, ancestorOf: toThere) {

            ///////////////////////////////
            // move zone through a bookmark
            ///////////////////////////////

            var         mover = zone
            let    targetLink = toThere.crossLink
            let     sameGraph = zone.storageMode == targetLink?.storageMode
            mover .isFavorite = false
            let grabAndTravel = {
                gTravelManager.travelThrough(toThere) { object, kind in
                    let there = object as! Zone

                    if !sameGraph {
                        self.applyModeRecursivelyTo(mover)
                    }

                    self.moveZone(mover, into: there, orphan: false) {
                        self.syncAndRedraw()
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

                gOperationsManager.sync {
                    grabAndTravel()
                }
            }
        }
    }


    func actuallyMoveZone(_ zone: Zone) {
        if  var         toThere = zone.parentZone {
            let        siblings = toThere.children

            if  let       index = siblings.index(of: zone) {
                let cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex >= 0 && cousinIndex < siblings.count {
                    toThere     = siblings[cousinIndex]

                    moveZone(zone, toThere)
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


    func moveZone(_ zone: Zone, into: Zone, orphan: Bool, onCompletion: Closure?) {
        moveZone(zone, into: into, at: asTask ? 0 : nil, orphan: orphan, onCompletion: onCompletion)
    }


    // MARK:- undoables
    // MARK:-


    func pasteInto(_ zone: Zone) {
        let pastables = gSelectionManager.pasteableZones

        var count = pastables.count

        if count > 0, !zone.isBookmark {
            var originals = [Zone] ()

            for pastable in pastables {
                let pasteThis = pastable.deepCopy()

                originals.append(pasteThis)
                pasteThis.orphan() // disable undo inside moveZone
                moveZone(pasteThis, into: zone, orphan: false) {
                    count -= 1

                    if count == 0 {
                        self.syncAndRedraw()
                    }
                }
            }

            UNDO(self) { iUndoSelf in
                iUndoSelf.prepareUndoForDelete()
                iUndoSelf.deleteZones(originals, in: nil)
                zone.grab()
                iUndoSelf.syncAndRedraw()
            }
        }
    }


    func prepareUndoForDelete() {
        gSelectionManager.clearPaste()

        for zone in gSelectionManager.currentlyGrabbedZones {
            if let into = zone.parentZone {
                addToPasteCopyOf(zone)

                UNDO(self) { iUndoSelf in
                    iUndoSelf.pasteInto(into)
                }
            }
        }
    }


    func moveZone(_ zone: Zone, outTo: Zone, orphan: Bool, onCompletion: Closure?) {
        var completedYet = false

        recursivelyRevealSiblingsOf(zone, toZone: outTo) { (iRevealedZone: Zone) in
            if !completedYet && iRevealedZone == outTo {
                completedYet     = true
                var insert: Int? = zone.parentZone?.siblingIndex

                if outTo.storageMode == .favorites {
                    insert = gFavoritesManager.nextFavoritesIndex(forward: !asTask)
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

                if  let  from = zone.parentZone {
                    let index = zone.siblingIndex

                    self.UNDO(self) { iUndoSelf in
                        iUndoSelf.moveZone(zone, into: from, at: index, orphan: orphan) { onCompletion?() }
                    }
                }

                if orphan {
                    zone.orphan()
                }

                if  insert != nil && insert! > outTo.count {
                    insert  = nil
                }

                outTo.addAndReorderChild(zone, at: insert)
                outTo.needUpdateSave()
                zone .needUpdateSave()
                onCompletion?()
            }
        }
    }


    func moveZone(_ zone: Zone, into: Zone, at iIndex: Int?, orphan: Bool, onCompletion: Closure?) {
        if  let parent = zone.parentZone {
            let  index = zone.siblingIndex

            UNDO(self) { iUndoSelf in
                iUndoSelf.moveZone(zone, into: parent, at: index, orphan: orphan) { onCompletion?() }
            }
        }

        gOperationsManager.children(recursively: false) {
            zone.needUpdateSave()
            into.needUpdateSave()
            into.needChildren()
            zone.grab()

            into.showChildren = true
            
            if orphan {
                zone.orphan()
            }

            into.addAndReorderChild(zone, at: iIndex)
            onCompletion?()
        }
    }


    func moveUp(_ iMoveUp: Bool, selectionOnly: Bool, extreme: Bool) {
        let         zone = gSelectionManager.firstGrabbableZone
        let       isHere = zone == hereZone
        if  let    there = zone.parentZone, !isHere, let index = zone.siblingIndex {
            var newIndex = index + (iMoveUp ? -1 : 1)

            if extreme {
                newIndex = iMoveUp ? 0 : there.count - 1
            }

            if newIndex >= 0 && newIndex < there.count {
                if zone == hereZone {
                    hereZone = there
                }

                UNDO(self) { iUndoSelf in
                    iUndoSelf.moveUp(!iMoveUp, selectionOnly: selectionOnly, extreme: extreme)
                }

                if selectionOnly {
                    there.children[newIndex].grab()
                    signalFor(there, regarding: .redraw)
                } else {
                    gSelectionManager.deselectGrabs()
                    there.moveChild(from: index, to: newIndex)
                    there.children[newIndex].grab()
                    there.updateOrdering()
                    gControllersManager.syncToCloudAndSignalFor(there, regarding: .redraw) {}
                }

            }
        } else if !zone.isRoot {
            revealParentAndSiblingsOf(zone) {
                if let parent = zone.parentZone {
                    if isHere {
                        self.hereZone = parent

                        self.signalFor(nil, regarding: .redraw)
                    }

                    if parent.count > 1 {
                        self.moveUp(iMoveUp, selectionOnly: selectionOnly, extreme: extreme)
                    }
                }
            }
        }
    }
}
