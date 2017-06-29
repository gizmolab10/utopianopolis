//
//  ZEditingManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/29/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZEditingManager: NSObject {


    class ZStalledEvent: NSObject {
        var event: ZEvent?
        var isWindow: Bool = true

        convenience init(_ iEvent: ZEvent, iIsWindow: Bool) {
            self.init()

            isWindow = iIsWindow
            event    = iEvent
        }
    }


    var    previousEvent:          ZEvent?
    var editedTextWidget:  ZoneTextWidget? { return gSelectionManager.currentlyEditingZone?.widget?.textWidget }
    var        isEditing:            Bool  { return editedTextWidget == nil ? false : editedTextWidget!.isTextEditing }


    var undoManager: UndoManager {
        var manager = gUndoManager

        if editedTextWidget != nil && editedTextWidget!.undoManager != nil {
            manager = editedTextWidget!.undoManager!
        }

        return manager
    }


    // MARK:- events
    // MARK:-


    func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) {
        if  let         key = iKey {
            let      widget = gWidgetsManager.currentMovableWidget
            let   isControl = flags.isControl
            let   isCommand = flags.isCommand
            let    isOption = flags.isOption
            let     isShift = flags.isShift
            let   hasWidget = widget != nil
            let       force = isOption || isWindow
            let    hasFlags = isOption || isCommand || isShift

            if  isEditing {
                switch key {
                case "a":         if isCommand { gSelectionManager.currentlyEditingZone?.widget?.textWidget.selectAllText() }
                case gSpaceKey:   if isControl { addChild() }
                default:          break
                }
            } else if isWindow, let arrow = key.arrow {
                handleArrow(arrow, flags: flags)
            } else {
                switch key {
                case "f":         find()
                case "r":         reverse()
                case "p":         printHere()
                case "b":         createBookmark()
                case "'":         doFavorites(isShift, isOption, isCommand)
                case "\"":        doFavorites(true,    isOption, isCommand)
                case ",", ".":    gInsertionMode = key == "." ? .follow : .precede; signalFor(nil, regarding: .preferences)
                case "/", "?":    onZone(gSelectionManager.firstGrab, toggleFavorite: hasFlags)
                case "-":         addSibling  (with: "-------------------------") { iChild in iChild.grab() }
                case "=":         addSibling  (with: "----------- | -----------") { iChild in iChild.grab() }
                case gTabKey:     if hasWidget { addSibling(containing: isOption) { iChild in gSelectionManager.edit(iChild) } }
                case "z":         if isCommand { if isShift { gUndoManager.redo() } else { gUndoManager.undo() } }
                case gSpaceKey:   if force { addChild() }
                case gBackspaceKey,
                     gDeleteKey:  if force { delete(preserveChildren: isOption && isWindow) }
                case "\r":
                    if hasWidget && gSelectionManager.hasGrab {
                        if isCommand {
                            gSelectionManager.deselect()
                        } else {
                            gSelectionManager.editCurrent()
                        }
                    }
                default:          break
                }
            }
        }
    }


    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        let isCommand = flags.isCommand
        let  isOption = flags.isOption
        let   isShift = flags.isShift

        switch arrow {
        case .down:     moveUp(false, selectionOnly: !isOption, extreme: isCommand, extend: isShift)
        case .up:       moveUp(true,  selectionOnly: !isOption, extreme: isCommand, extend: isShift)
        default:
            if !isShift {
                switch arrow {
                case .right: moveInto(selectionOnly: !isOption, extreme: isCommand)
                case .left:  moveOut( selectionOnly: !isOption, extreme: isCommand)
                default: break
                }
            } else {

                //////////////////
                // GENERATIONAL //
                //////////////////

                let zone = gSelectionManager.firstGrab
                var show = true

                switch arrow {
                case .right: break
                case .left:  show = false
                default:     return
                }

                var goal: Int? = nil

                if !show {
                    goal = isCommand ? zone.level - 1 : zone.highestExposed - 1
                } else if isCommand {
                    goal = Int.max
                } else if let lowest = zone.lowestExposed {
                    goal = lowest + 1
                }

                toggleDotUpdate(show: show, zone: zone, to: goal)
            }
        }
    }


    @discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> Bool {
        if !isEditing, iEvent != previousEvent, gWorkMode == .editMode {
            handleKey(iEvent.key, flags: iEvent.modifierFlags, isWindow: isWindow)
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


    // MARK:- miscellaneous features
    // MARK:-


    func find() {
        if gStorageMode != .favorites {
            gShowsSearching = !gShowsSearching

            signalFor(nil, regarding: .search)
        }
    }


    func reverse() {
        if  var commonParent = gSelectionManager.firstGrab.parentZone {
            var        zones = gSelectionManager.currentGrabs
            for zone in zones {
                if let parent = zone.parentZone, parent != commonParent {
                    return
                }
            }

            if zones.count == 1 {
                zones        = gSelectionManager.firstGrab.children
                commonParent = gSelectionManager.firstGrab
            }

            if zones.count > 1 {
                UNDO(self) { iUndoSelf in
                    iUndoSelf.reverse()
                }

                zones.sort { (a, b) -> Bool in
                    return a.order < b.order
                }

                let   max = zones.count - 1
                let range = 0 ... max / 2

                for index in range {
                    let a = zones[index]
                    let b = zones[max - index]
                    let o = a.order
                    a.order = b.order
                    b.order = o
                }

                commonParent.respectOrder()
                redrawAndSync()
            }
        }
    }


    func printHere() {
        #if os(OSX)

            if  let         view = gHere.widget {
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


    // MARK:- focus
    // MARK:-


    func doFavorites(_ isShift: Bool, _ isOption: Bool, _ isCommand: Bool) {
        if isCommand || (isShift && isOption) {
            gFavoritesManager.refocus() {
                self.redrawAndSync()
            }
        } else {
            let backward = isShift || isOption

            gFavoritesManager.switchToNext(!backward) {
                self.redrawAndSync() {
                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }


    func travelThroughBookmark(_ bookmark: Zone) {
        gFavoritesManager.updateGrabAndIndexFor(bookmark)
        gTravelManager.travelThrough(bookmark) { object, kind in
            self.redrawAndSync()
        }
    }


    func onZone(_ iZone: Zone, toggleFavorite: Bool) {
        let focusOn = { (zone: Zone) in
            gHere = zone

            zone.grab()
            self.redrawAndSync(zone)
        }

        if iZone.isBookmark {
            gTravelManager.travelThrough(iZone) { object, kind in
                gSelectionManager.deselect()
                focusOn(object as! Zone)
            }

            return
        } else if toggleFavorite {
            gFavoritesManager.toggleFavorite(for: iZone)
        }

        focusOn(iZone)
    }


    // MARK:- async reveal
    // MARK:-


    func revealRoot(_ onCompletion: Closure?) {
        if gRoot?.record != nil {
            onCompletion?()
        } else {
            gOperationsManager.root {
                onCompletion?()
            }
        }
    }


    func revealParentAndSiblingsOf(_ iZone: Zone, onCompletion: Closure?) {
        if let parent = iZone.parentZone, parent.zoneName != nil {
            parent.displayChildren()
            parent.maybeNeedProgeny()

            gOperationsManager.children(.restore) {
                onCompletion?()
            }
        } else {
            iZone.needParent()

            gOperationsManager.families {
                onCompletion?()
            }
        }
    }


    func recursivelyRevealSiblingsOf(_ descendent: Zone, untilReaching ancestor: Zone, onCompletion: ZoneClosure?) {
        if  descendent == ancestor {
            onCompletion?(ancestor)
        } else {
            revealParentAndSiblingsOf(descendent) {
                if let parent = descendent.parentZone {
                    self.recursivelyRevealSiblingsOf(parent, untilReaching: ancestor, onCompletion: onCompletion)
                } else {
                    onCompletion?(descendent)
                }
            }
        }
    }


    func revealSiblingsOf(_ descendent: Zone, untilReaching ancestor: Zone) {
        recursivelyRevealSiblingsOf(descendent, untilReaching: ancestor) { (iZone: Zone) in
            if iZone == ancestor {
                gHere = ancestor

                gHere.grab()
            }

            self.redrawAndSync()
        }
    }


    // MARK:- toggle dot
    // MARK:-


    func toggleDotUpdate(show: Bool, zone: Zone, to iGoal: Int? = nil) {
        toggleDotRecurse(show, zone, to: iGoal) {

            ///////////////////////////////////////////////////////////
            // delay executing this until the last time it is called //
            ///////////////////////////////////////////////////////////

            self.redrawAndSync()
        }
    }


    func toggleDotRecurse(_ show: Bool, _ zone: Zone, to iGoal: Int?, onCompletion: Closure?) {
        if !show && (zone.count == 0 || !zone.showChildren) && zone.isGrabbed {

            //////////////////////////
            // COLLAPSE INTO PARENT //
            //////////////////////////

            zone.hideChildren()

            revealParentAndSiblingsOf(zone) {
                if let  parent = zone.parentZone {
                    if  gHere == zone {
                        gHere  = parent
                    }

                    parent.grab()
                    self.toggleDotRecurse(false, parent, to: iGoal, onCompletion: onCompletion)
                }
            }
        } else {

            ////////////////////
            // ALTER CHILDREN //
            ////////////////////

            let  goal = iGoal ?? zone.level + (show ? 1 : -1)
            let apply = {
                zone.traverseAllProgeny { iZone in
                    if !show && iZone.level >= goal {
                        iZone.hideChildren()
                    } else if show && iZone.level < goal {
                        iZone.displayChildren()
                    }
                }

                onCompletion?()
            }

            if !show {
                gSelectionManager.deselectDragWithin(zone);
                apply()
            } else {
                zone.extendNeedForChildren(to: goal, [])
                
                gOperationsManager.children(.expand, iGoal) {
                    apply()
                }
            }
        }
    }


    func toggleDotActionOnZone(_ iZone: Zone?) {
        if let zone = iZone {
            let s = gSelectionManager

            for grabbed in s.currentGrabs {
                if zone.spawned(grabbed) {
                    s.ungrab(grabbed)
                }
            }

            if zone.isBookmark {
                travelThroughBookmark(zone)
            } else {
                if isEditing {
                    s.stopCurrentEdit()
                }

                let show = !zone.showChildren

                toggleDotUpdate(show: show, zone: zone)
            }
        }
    }


    // MARK:- create
    // MARK:-


    func addChild() {
        if let parentZone = gWidgetsManager.currentMovableWidget?.widgetZone, !parentZone.isBookmark {
            addChildTo(parentZone, at: willFollow ? nil : 0) { iChild in
                gControllersManager.signalFor(parentZone, regarding: .redraw) {
                    if let child = iChild {
                        gSelectionManager.edit(child)
                    }
                }
            }
        }
    }


    func addChildTo(_ iZone: Zone?, at iIndex: Int?, onCompletion: ZoneMaybeClosure?) {
        if  let               zone = iZone, zone.storageMode != .favorites {
            let       createAndAdd = {
                let         record = CKRecord(recordType: zoneTypeKey)
                let          child = Zone(record: record, storageMode: zone.storageMode)
                child.progenyCount = 1 // so add and reorder will correctly propagate count

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.deleteZone(child)
                    onCompletion?(nil)
                }

                zone.ungrab()
                child.needCreate()
                zone.addAndReorderChild(child, at: iIndex)
                onCompletion?(child)
            }

            zone.displayChildren()
            gSelectionManager.stopCurrentEdit()

            if zone.count > 0 || !zone.hasChildren {
                createAndAdd()
            } else {
                zone.needChildren()

                var     isFirstTime = true

                gOperationsManager.children(.restore) {
                    if  isFirstTime {
                        isFirstTime = false

                        createAndAdd()
                    }
                }
            }
        }
    }


    func addSibling(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
        let       zone = gSelectionManager.rootMostMoveable

        if  var parent = zone.parentZone {
            var  zones = gSelectionManager.currentGrabs

            if containing {
                if  zones.count < 2 {
                    zones  = zone.children
                    parent = zone
                }

                zones.sort { (a, b) -> Bool in
                    return a.order < b.order
                }

                undoManager.beginUndoGrouping()
            }

            gSelectionManager.stopCurrentEdit()

            if  zone  == gHere {
                gHere  = parent

                parent.displayChildren()
            }

            var index   = zone.siblingIndex

            if  index  != nil {
                index! += willFollow ? 1 : 0
            }

            addChildTo(parent, at: index) { iChild in
                if let child = iChild {
                    if name != nil {
                        child.zoneName = name
                    }

                    if !containing {
                        gControllersManager.signalFor(parent, regarding: .redraw) {
                            onCompletion?(child)
                        }
                    } else {
                        self.moveZones(zones, into: child, at: nil, orphan: true) {
                            self.undoManager.endUndoGrouping()
                            gControllersManager.syncToCloudAndSignalFor(parent, regarding: .redraw) {
                                onCompletion?(child)
                            }
                        }
                    }
                }
            }
        }
    }


    func createBookmark() {
        let zone = gSelectionManager.firstGrab

        if zone.storageMode != .favorites, !zone.isRoot {
            let closure = {
                var bookmark: Zone? = nil

                self.invokeWithMode(.mine) {
                    bookmark = gFavoritesManager.createBookmark(for: zone, isFavorite: false)
                }

                bookmark?.grab()
                self.signalFor(nil, regarding: .redraw)
                gOperationsManager.sync {}
            }

            if gHere != zone {
                closure()
            } else {
                self.revealParentAndSiblingsOf(zone) {
                    gHere = zone.parentZone ?? gHere

                    closure()
                }
            }
        }
    }
    

    // MARK:- copy and paste
    // MARK:-
    

    func paste() { pasteInto(gSelectionManager.firstGrab) }


    func copyToPaste() {
        let grabs = gSelectionManager.currentGrabs

        gSelectionManager.clearPaste()

        for zone in grabs {
            zone.needChildren()
        }

        gOperationsManager.children(.deep) {
            for zone in grabs {
                self.addToPasteCopyOf(zone)
            }
        }
    }
    

    func addToPasteCopyOf(_ zone: Zone, parent: Zone? = nil, at index: Int? = nil) {
        let        copy = zone.deepCopy()
        copy.parentZone = nil

        copy.traverseAllProgeny { iZone in
            iZone.isDeleted = true
        }

        gSelectionManager.pasteableZones[copy] = (parent, index)
    }


    // MARK:- destroy
    // MARK:-


    func delete(preserveChildren: Bool = false) {
        let candidate = gSelectionManager.rootMostMoveable
        let   closure = {
            if let parent = candidate.parentZone {
                let grabs = gSelectionManager.currentGrabs
                
                if preserveChildren {
                    var children = [Zone] ()
                    let    index = candidate.siblingIndex

                    gSelectionManager.deselectGrabs()
                    gSelectionManager.clearPaste()

                    for grab in grabs {
                        grab.isDeleted = true

                        for child in grab.children {
                            children.append(child)
                        }

                        gSelectionManager.pasteableZones[grab] = (grab.parentZone, grab.siblingIndex)
                        grab.orphan()
                    }

                    children.sort { (a, b) -> Bool in
                        return a.order > b.order      // reversed
                    }

                    for child in children {
                        parent.addAndReorderChild(child, at: index)
                        child.addToGrab()
                    }

                    self.UNDO(self) { iUndoSelf in
                        self.deleteZones(children, in: nil)
                        iUndoSelf.pasteInto(parent, ignoreFormerParents: false)
                    }
                } else if let index = candidate.siblingIndex {
                    self.prepareUndoForDelete()
                    self.deleteZones(grabs, in: nil)

                    if  parent.count == 0 {
                        parent.grab()
                    } else {
                        parent[index]?.grab()
                    }
                }
            }

            self.redrawAndSyncAndRedraw()
        }

        if candidate.count == candidate.fetchableCount {
            closure()
        } else {
            candidate.needProgeny()
            gOperationsManager.children(.deep) {
                closure()
            }
        }
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
                if zone == gHere { // this can only happen once during recursion (multiple places, below)
                    revealParentAndSiblingsOf(zone) {
                        gHere = grabThisZone!

                        self.deleteZone(zone) // recurse
                        self.signalFor(nil, regarding: .redraw)
                    }

                    return grabThisZone
                }

                let   siblings = grabThisZone!.children
                let      count = siblings.count

                if  var index  = siblings.index(of: zone), count > 1 {
                    if  index  < count - 1 && (willFollow || index == 0) {
                        index += 1
                    } else if index > 0 {
                        index -= 1
                    }

                    grabThisZone = siblings[index]
                }
            }

            let     bookmarks = gRemoteStoresManager.bookmarksFor(zone)
            zone   .isDeleted = true // will be saved, then ignored after next launch

            deleteZones(zone.children, in: zone) // recurse
            deleteZones(bookmarks,     in: zone) // recurse
            zone.orphan()
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


    func newmoveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool, extend: Bool) {
        let                  zone: Zone = gSelectionManager.firstGrab
        if  let              parentZone = zone.parentZone {
            let (next, index, newIndex) = nextUpward(moveUp, extreme: extreme, zone: parentZone)

            if selectionOnly {
                if next != nil {
                    next!.grab()
                }
            } else if zone.storageMode != .favorites {
                parentZone.children.remove(at: index)
                parentZone.children.insert(zone, at:newIndex)
            }

            signalFor(parentZone, regarding: .redraw)
        }
    }


    // MARK:- move
    // MARK:-


    func moveOut(selectionOnly: Bool, extreme: Bool) {
        let zone: Zone = gSelectionManager.firstGrab
        let     parent = zone.parentZone

        if selectionOnly {

            ///////////////
            // MOVE GRAB //
            ///////////////

            if zone.isRoot {
                gFavoritesManager.showFavoritesAndGrab(zone) { object, kind in
                    self.redrawAndSync()
                }
            } else if !extreme {
                if zone == gHere || parent == nil {
                    revealParentAndSiblingsOf(zone) {
                        if  let ancestor = gHere.parentZone {
                            ancestor.grab()
                            self.revealSiblingsOf(gHere, untilReaching: ancestor)
                        }
                    }
                } else if parent != nil {
                    parent!.grab()
                    signalFor(parent, regarding: .redraw)
                }
            } else if !gHere.isRoot {
                let here = gHere // revealRoot changes gHere, so nab it first

                zone.grab()

                revealRoot {
                    self.revealSiblingsOf(here, untilReaching: gRoot!)
                }
            } else if !zone.isRoot {
                gHere = zone

                self.redrawAndSync()
            }
        } else if zone.storageMode != .favorites {

            ///////////////
            // MOVE ZONE //
            ///////////////

            let grandparent = parent?.parentZone

            let moveIntoHere = { (iHere: Zone?) in
                if iHere != nil {
                    gHere = iHere!

                    self.moveOut(to: iHere!) {
                        self.redrawAndSync()
                    }
                }
            }

            if extreme {
                if gHere.isRoot {
                    moveIntoHere(grandparent)
                } else {
                    revealRoot {
                        moveIntoHere(gRoot)
                    }
                }
            } else if gHere != zone && gHere != parent && grandparent != nil {
                moveOut(to: grandparent!){
                    self.redrawAndSync(grandparent)
                }
            } else if parent != nil && parent!.isRoot {
                gFavoritesManager.showFavoritesAndGrab(nil) { object, kind in
                    zone.isFavorite = true

                    moveIntoHere(gFavoritesManager.rootZone)
                }
            } else {
                revealParentAndSiblingsOf(gHere) {
                    if let grandparent = parent?.parentZone {
                        moveIntoHere(grandparent)
                    }
                }
            }
        }
    }


    func moveInto(selectionOnly: Bool, extreme: Bool) {
        let zone: Zone = gSelectionManager.firstGrab

        if !selectionOnly {
            actuallyMoveZone(zone)
        } else if zone.isBookmark {
            travelThroughBookmark(zone)
        } else if zone.count > 0 {
            grabChild(of: zone)
        } else {
            zone.needChildren()

            gOperationsManager.children(.restore) {
                self.grabChild(of: zone)
            }
        }
    }


    func grabChild(of zone: Zone) {
        if  zone.count > 0, let child = willFollow ? zone.children.last : zone.children.first {
            zone.displayChildren()
            child.grab()
            signalFor(nil, regarding: .redraw)
        }
    }


    func moveZone(_ zone: Zone, to there: Zone) {
        if !there.isBookmark {
            moveZone(zone, into: there, at: willFollow ? nil : 0, orphan: true) {
                self.redrawAndSync(nil)
            }
        } else if !there.isABookmark(spawnedBy: zone) {

            //////////////////////////////////
            // MOVE ZONE THROUGH A BOOKMARK //
            //////////////////////////////////

            var         mover = zone
            let    targetLink = there.crossLink
            let     sameGraph = zone.storageMode == targetLink?.storageMode
            mover .isFavorite = false
            let grabAndTravel = {
                gTravelManager.travelThrough(there) { object, kind in
                    let there = object as! Zone

                    if !sameGraph {
                        self.applyModeRecursivelyTo(mover)
                    }

                    self.moveZone(mover, into: there, at: willFollow ? nil : 0, orphan: false) {
                        self.redrawAndSync()
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
        if  var           there = zone.parentZone {
            let        siblings = there.children

            if  let       index = siblings.index(of: zone) {
                let cousinIndex = index == 0 ? 1 : index - 1

                if cousinIndex >= 0 && cousinIndex < siblings.count {
                    there       = siblings[cousinIndex]

                    moveZone(zone, to: there)
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


    func moveZones(_ zones: [Zone], into: Zone, at iIndex: Int?, orphan: Bool, onCompletion: Closure?) {
        into.displayChildren()
        into.needChildren()

        gOperationsManager.children(.restore) {
            for zone in zones {
                if orphan {
                    zone.orphan()
                }

                into.addAndReorderChild(zone, at: iIndex)
            }

            onCompletion?()
        }
    }


    // MARK:- undoables
    // MARK:-


    func pasteInto(_ zone: Zone? = nil, ignoreFormerParents: Bool = true) {
        let         pastables = gSelectionManager.pasteableZones

        if pastables.count > 0, (zone == nil || !zone!.isBookmark) {
            var       forUndo = [Zone] ()

            gSelectionManager.deselectGrabs()

            for (pastable, (parent, index)) in pastables {
                let pasteThis = pastable.deepCopy()
                let        at = index  != nil ?  index  : willFollow ? nil : 0
                let      into = parent != nil ? !ignoreFormerParents ? parent! : zone : zone
                let      mode = into?.storageMode ?? gStorageMode

                pasteThis.traverseAllProgeny { iZone in
                    iZone.fetchableCount = iZone.count
                    iZone   .storageMode = mode
                    iZone     .isDeleted = false

                    iZone.needCreate()
                }

                into?.addAndReorderChild(pasteThis, at: at)
                into?.safeProgenyCountUpdate(.deep, [])
                forUndo.append(pasteThis)
                pasteThis.addToGrab()
            }

            redrawAndSync()

            UNDO(self) { iUndoSelf in
                iUndoSelf.prepareUndoForDelete()
                iUndoSelf.deleteZones(forUndo, in: nil)
                zone?.grab()
                iUndoSelf.redrawAndSync()
            }
        }
    }


    func prepareUndoForDelete() {
        let into = gSelectionManager.rootMostMoveable.parentZone

        gSelectionManager.clearPaste()

        for zone in gSelectionManager.currentGrabs {
            if let parent = zone.parentZone, let index = zone.siblingIndex {
                addToPasteCopyOf(zone, parent: parent, at: index)
            }
        }

        UNDO(self) { iUndoSelf in
            iUndoSelf.pasteInto(into)
        }
    }


    func moveOut(to: Zone, onCompletion: Closure?) {
        let         zone = gSelectionManager.firstGrab
        var completedYet = false

        recursivelyRevealSiblingsOf(zone, untilReaching: to) { (iRevealedZone: Zone) in
            if !completedYet && iRevealedZone == to {
                completedYet     = true
                var insert: Int? = zone.parentZone?.siblingIndex

                if to.storageMode == .favorites {
                    insert = gFavoritesManager.nextFavoritesIndex(forward: willFollow)
                } else if zone.parentZone?.parentZone == to {
                    if  insert != nil {
                        insert  = insert! + 1

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
                        iUndoSelf.moveZone(zone, into: from, at: index, orphan: true) { onCompletion?() }
                    }
                }

                zone.orphan()

                if  insert != nil && insert! > to.count {
                    insert  = nil
                }

                to.addAndReorderChild(zone, at: insert)
                onCompletion?()
            }
        }
    }


    func moveGrabbedZones(into iInto: Zone, at iIndex: Int?, onCompletion: Closure?) {
        let toBookmark = iInto.isBookmark
        let       into = !toBookmark ? iInto : iInto.bookmarkTarget!

        //////////////////////
        // prepare for UNDO //
        //////////////////////

        var  restore = [Zone: (Zone, Int?)] ()
        var newIndex = iIndex
        let    grabs = gSelectionManager.currentGrabs

        for zone in grabs.reversed() {
            if  let    parent = zone.parentZone {
                let     index = zone.siblingIndex
                restore[zone] = (parent, index)

                zone.orphan()

                if  newIndex  != nil, index != nil, parent == into && index! > 0 && index! <= newIndex! {
                    newIndex! -= 1
                }
            }
        }

        if toBookmark {
            undoManager.beginUndoGrouping()
        }

        UNDO(self) { iUndoSelf in
            for zone in restore.keys {
                zone.orphan()
            }

            for (zone, (parent, index)) in restore.reversed() {
                parent.addAndReorderChild(zone, at: index)
            }

            iUndoSelf.UNDO(self) { iUndoUndoSelf in
                iUndoUndoSelf.moveGrabbedZones(into: iInto, at: newIndex, onCompletion: onCompletion)
            }

            onCompletion?()
        }

        ///////////////////////////////////////////////////////////
        // assure children (of into) are present, then add grabs //
        ///////////////////////////////////////////////////////////

        into.displayChildren()
        into.maybeNeedChildren()

        gOperationsManager.children(.restore) {
            for zone in grabs.reversed() {
                into.addAndReorderChild(zone, at: newIndex)
            }

            if !toBookmark {
                onCompletion?()
            } else {
                gTravelManager.travelThrough(iInto, atArrival: { (iAny, iSignalKind) -> (Void) in
                    self.undoManager.endUndoGrouping()
                    onCompletion?()
                })
            }
        }
    }


    func moveZone(_ zone: Zone, into: Zone, at iIndex: Int?, orphan: Bool, onCompletion: Closure?) {
        if let parent = zone.parentZone {
            let  index = zone.siblingIndex

            UNDO(self) { iUndoSelf in
                iUndoSelf.moveZone(zone, into: parent, at: index, orphan: orphan) { onCompletion?() }
            }
        }

        into.displayChildren()
        into.maybeNeedProgeny()

        gOperationsManager.children(.restore) {
            zone.grab()
            
            if orphan {
                zone.orphan()
            }
            
            into.addAndReorderChild(zone, at: iIndex)
            onCompletion?()
        }
    }
    
    
    func moveUp(_ iMoveUp: Bool, selectionOnly: Bool, extreme: Bool, extend: Bool) {
        let            zone = iMoveUp ? gSelectionManager.firstGrab : gSelectionManager.lastGrab
        let          isHere = zone == gHere
        if  let       there = zone.parentZone, !isHere, let index = zone.siblingIndex {
            var    newIndex = index + (iMoveUp ? -1 : 1)
            var  allGrabbed = true
            var soloGrabbed = false
            var     hasGrab = false
            let    indexMax = there.count

            for child in there.children {
                if !child.isGrabbed {
                    allGrabbed   = false
                } else if hasGrab {
                    soloGrabbed  = false
                } else {
                    hasGrab      = true
                    soloGrabbed  = true
                }
            }

            if !extend {
                let    atTop = newIndex < 0
                let atBottom = newIndex >= indexMax

                //////////////////////////
                // vertical wrap around //
                //////////////////////////

                if        (!iMoveUp && (allGrabbed || extreme || (!allGrabbed && !soloGrabbed && atBottom))) || ( iMoveUp && soloGrabbed && atTop) {
                    newIndex = indexMax - 1 // bottom
                } else if ( iMoveUp && (allGrabbed || extreme || (!allGrabbed && !soloGrabbed && atTop)))    || (!iMoveUp && soloGrabbed && atBottom) {
                    newIndex = 0            // top
                }
            }

            if newIndex >= 0 && newIndex < indexMax {
                if  zone == gHere {
                    gHere = there
                }
                
                UNDO(self) { iUndoSelf in
                    iUndoSelf.moveUp(!iMoveUp, selectionOnly: selectionOnly, extreme: extreme, extend: extend)
                }
                
                if !selectionOnly {
                    if  there.move(child: index, to: newIndex) { // if move succeeds
                        there.children[newIndex].grab()
                        there.updateOrdering()
                        self.redrawAndSync(there)
                    }
                } else {
                    let  grabThis = there.children[newIndex]
                    var grabThese = [grabThis]

                    if !extend {
                        gSelectionManager.deselectGrabs(retaining: grabThese)
                    } else if !grabThis.isGrabbed || extreme {

                        if extreme {

                            ///////////////////
                            // expand to end //
                            ///////////////////

                            if iMoveUp {
                                for i in 0 ..< newIndex {
                                    grabThese.append(there.children[i])
                                }
                            } else {
                                for i in newIndex ..< indexMax {
                                    grabThese.append(there.children[i])
                                }
                            }
                        }

                        gSelectionManager.addMultipleToGrab(grabThese)
                    }

                    signalFor(nil, regarding: .data)
                }
            }
        } else if !zone.isRoot {

            //////////////////////////////////////////
            // parent is not yet fetched from cloud //
            //////////////////////////////////////////

            revealParentAndSiblingsOf(zone) {
                if let parent = zone.parentZone {
                    if isHere {
                        gHere = parent
                        
                        self.signalFor(nil, regarding: .redraw)
                    }
                    
                    if parent.count > 1 {
                        self.moveUp(iMoveUp, selectionOnly: selectionOnly, extreme: extreme, extend: extend)
                    }
                }
            }
        }
    }
}
