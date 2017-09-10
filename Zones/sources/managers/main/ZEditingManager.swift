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


    var    previousEvent:         ZEvent?
    var editedTextWidget: ZoneTextWidget? { return gSelectionManager.currentlyEditingZone?.widget?.textWidget }
    var        isEditing:           Bool  { return editedTextWidget == nil ? false : editedTextWidget!.isTextEditing }


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
        if  var       key = iKey {
            let    widget = gWidgetsManager.currentMovableWidget
            let isControl = flags.isControl
            let isCommand = flags.isCommand
            let  isOption = flags.isOption
            var   isShift = flags.isShift
            let hasWidget = widget != nil
            let     force = isOption || isWindow

            if  key      != key.lowercased() {
                key       = key.lowercased()
                isShift   = true
            }

            if  isEditing {
                switch key {
                case "a":         if isCommand { gSelectionManager.currentlyEditingZone?.widget?.textWidget.selectAllText() }
                case gSpaceKey:   if isControl { createIdea() }
                default:          break
                }
            } else if isWindow, let arrow = key.arrow {
                handleArrow(arrow, flags: flags)
            } else {
                switch key {
                case "f":         find()
                case "r":         reverse()
                case "c":         recenter()
                case "p":         printHere()
                case "b":         createBookmark()
                case "u", "l":    alterCase(up: key == "u")
                case "s":         selectCurrentFavorite()
                case ";":         doFavorites(true,    false)
                case "'":         doFavorites(isShift, isOption)
                case ",", ".":    gInsertionMode = key == "." ? .follow : .precede; signalFor(nil, regarding: .preferences)
                case "/":         focus(on: gSelectionManager.firstGrab, isCommand)
                // case "?":         gSettingsController?.displayViewFor(id: .Help)
                case "-":         createSiblingIdea  (with: "-------------------------") { iChild in iChild.grab() }
                case "=":         createSiblingIdea  (with: "----------- | -----------") { iChild in iChild.editAndSelect(in: NSMakeRange(12, 1)) }
                case gTabKey:     if hasWidget { createSiblingIdea(containing: isOption) { iChild in iChild.edit() } }
                case "z":         if isCommand { if isShift { gUndoManager.redo() } else { gUndoManager.undo() } }
                case gSpaceKey:   if force { createIdea() }
                case gBackspaceKey,
                     gDeleteKey:  if force { delete(permanently: isCommand && isControl && isOption && isWindow, preserveChildren: !isCommand && !isControl && isOption && isWindow) }
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

                let zone = gSelectionManager.rootMostMoveable
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
            let flags = iEvent.modifierFlags
            let   key = iEvent.key

            handleKey(key, flags: flags, isWindow: isWindow)

            return true
        }

        return false
    }


    func handleMenuItem(_ iItem: ZMenuItem?) {
        #if os(OSX)
            let   key = (iItem?.keyEquivalent)!
            let flags = (iItem?.keyEquivalentModifierMask)!

            handleKey(key, flags: flags, isWindow: true)
        #endif
    }


    // MARK:- miscellaneous features
    // MARK:-


    func recenter() {
        gScaling      = 1.0
        gScrollOffset = CGPoint.zero

        gEditorController?.layoutForCurrentScrollOffset()
        gEditorView?.setNeedsDisplay()
    }
    

    func alterCase(up: Bool) {
        for grab in gSelectionManager.currentGrabs {
            if let text = grab.widget?.textWidget {
                text.alterCase(up: up)
            }
        }
    }


    func find() {
        if gStorageMode != .favorites {
            gShowsSearching = !gShowsSearching

            signalFor(nil, regarding: .search)
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


    func selectCurrentFavorite() {
        if let current = gFavoritesManager.favorite(for: gHere) {
            current.grab()
            signalFor(current, regarding: .datum)
        }
    }


    func doFavorites(_ isShift: Bool, _ isOption: Bool) {
        let backward = isShift || isOption

        gFavoritesManager.switchToNext(!backward) {
            self.redrawAndSync() {
                self.signalFor(nil, regarding: .redraw)
            }
        }
    }


    func travelThroughBookmark(_ bookmark: Zone) {
        gTravelManager.travelThrough(bookmark) { object, kind in
            self.redrawAndSync()
        }
    }


    func focus(on iZone: Zone, _ isCommand: Bool = false) {
        let focusClosure = { (zone: Zone) in
            gHere = zone

            zone.grab()
            self.redrawAndSync(nil)
        }

        if isCommand{
            gFavoritesManager.refocus() {
                self.redrawAndSync()
            }
        } else if iZone.isBookmark {
            gTravelManager.travelThrough(iZone) { object, kind in
                gSelectionManager.deselect()
                focusClosure(object as! Zone)
            }
        } else if iZone == gHere {
            gFavoritesManager.toggleFavorite(for: iZone)
            redrawAndSync(nil)
        } else {
            focusClosure(iZone)
        }
    }


    // MARK:- async reveal
    // MARK:-


    func revealRoot(_ onCompletion: Closure?) {
        if gRoot?.record != nil {
            onCompletion?()
        } else {
            gOperationsManager.roots {
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
        descendent.traverseAncestors { iAncestor -> ZTraverseStatus in
            if  iAncestor == ancestor || iAncestor.isRoot {
                onCompletion?(ancestor)

                return .eStop
            } else {
                revealParentAndSiblingsOf(iAncestor) {}

                return .eContinue
            }
        }
    }


    func revealSiblingsOf(_ descendent: Zone, untilReaching ancestor: Zone) {
        recursivelyRevealSiblingsOf(descendent, untilReaching: ancestor) { iZone in
            if iZone == ancestor {
                gHere = ancestor

//                gFavoritesManager.updateGrabAndIndexFor(gHere)
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
                } else {
                    onCompletion?()
                }
            }
        } else {

            ////////////////////
            // ALTER CHILDREN //
            ////////////////////

            let  goal = iGoal ?? zone.level + (show ? 1 : -1)
            let apply = {
                zone.traverseAllProgeny { iChild in
                    if !show && iChild.level >= goal {
                        iChild.hideChildren()
                    } else if show && iChild.level < goal {
                        iChild.displayChildren()
                    }
                }

                onCompletion?()
            }

            if !show {
                gSelectionManager.deselectDragWithin(zone);
                apply()
            } else {
                zone.extendNeedForChildren(to: goal)
                
                gOperationsManager.children(.expand, goal) {
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


    func createIdea() {
        if let parentZone = gWidgetsManager.currentMovableWidget?.widgetZone, !parentZone.isBookmark {
            createIdeaIn(parentZone, at: gInsertionsFollow ? nil : 0) { iChild in
                gControllersManager.signalFor(parentZone, regarding: .redraw) {
                    iChild?.edit()
                }
            }
        }
    }


    func createSiblingIdea(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
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
            }

            gSelectionManager.stopCurrentEdit()

            if  zone  == gHere {
                gHere  = parent

                parent.displayChildren()
            }

            var index   = zone.siblingIndex

            if  index  != nil {
                index! += gInsertionsFollow ? 1 : 0
            }

            createIdeaIn(parent, at: index) { iChild in
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
        let grabs = gSelectionManager.simplifiedGrabs

        gSelectionManager.clearPaste()

        for grab in grabs {
            grab.addToPaste()
        }
    }


    // MARK:- destroy
    // MARK:-


    func delete(permanently: Bool = false, preserveChildren: Bool = false) {
        let candidate = gSelectionManager.rootMostMoveable
        let   closure = {
            if  candidate.parentZone != nil {
                if preserveChildren {
                    self.preserveChildrenOfGrabbedZones()
                    gFavoritesManager.updateChildren()
                    self.redrawAndSyncAndRedraw()
                } else {
                    self.prepareUndoForDelete()
                    self.deleteZones(gSelectionManager.simplifiedGrabs, permanently: permanently) { iZone in
                        iZone?.grab()

                        if iZone?.isFavorite ?? false {
                            gFavoritesManager.updateChildren()
                        }

                        self.redrawAndSyncAndRedraw()
                    }
                }
            }
        }

        if candidate.count == candidate.fetchableCount {
            closure()
        } else {
            candidate.needProgeny()
            gOperationsManager.children(.all) {
                closure()
            }
        }
    }


    private func deleteZones(_ zones: [Zone], permanently: Bool = false, in parent: Zone? = nil, onCompletion: ZoneMaybeClosure?) {
        var count = zones.count

        if count == 0 {
            onCompletion?(nil)

            return
        }

        let finished: ZoneMaybeClosure = { iZone in
            count -= 1

            if count == 0 {
                onCompletion?(iZone)
            }
        }

        for zone in zones {
            if  zone == parent { // detect and avoid infinite recursion
                finished(nil)
            } else {
                deleteZone(zone, permanently: permanently || zone.isFavorite) { iZone in
                    finished(iZone)
                }
            }
        }
    }


    private func deleteZone(_ zone: Zone, permanently: Bool = false, onCompletion: ZoneMaybeClosure?) {
        var grabThisZone = zone.parentZone
        var     deleteMe = !zone.isRoot && grabThisZone?.record != nil

        if !deleteMe && zone.isBookmark, let name = zone.crossLink?.record.recordID.recordName {
            deleteMe = ![rootNameKey, trashNameKey, favoritesRootNameKey].contains(name)
        }

        if !deleteMe {
            onCompletion?(grabThisZone)
        } else {
            if grabThisZone != nil {
                if zone == gHere { // this can only happen once during recursion (multiple places, below)
                    revealParentAndSiblingsOf(zone) {
                        gHere = grabThisZone!

                        self.deleteZone(zone, onCompletion: onCompletion) // recurse
                    }

                    return
                }

                let   siblings = grabThisZone!.children
                let        max = siblings.count - 1

                if  var index  = zone.siblingIndex, max > 0 {
                    if  index  < max    &&  (gInsertionsFollow || index == 0) {
                        index += 1
                    } else if index > 0 && (!gInsertionsFollow || index == max) {
                        index -= 1
                    }

                    grabThisZone = siblings[index]
                }
            }

            if !permanently && !zone.isDeleted {
                zone.addToPaste()
                moveToTrash(zone)
            } else {
                zone.orphan()

                zone.traverseAllProgeny() { iZone in
                    iZone.needDestroy()
                }
            }

            if let             grab = grabThisZone {
                grab.fetchableCount = grab.count
            }

            zone.needBookmarks()

            gOperationsManager.bookmarks {
                let bookmarks = gRemoteStoresManager.bookmarksFor(zone)

                if bookmarks.count == 0 {
                    onCompletion?(grabThisZone)
                } else {
                    self.deleteZones(bookmarks, permanently: permanently) { iZone in // recurse
                        onCompletion?(grabThisZone)
                    }
                }
            }
        }
    }


    func moveToTrash(_ zone: Zone) {
        if let trash = gTrash {
            moveZone(zone, to: trash)
        }
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

            if !(parent?.isRootOfFavorites ?? false) {
                if zone.isRoot {
                    self.redrawAndSync()
                } else if !extreme {
                    if zone == gHere || parent == nil {
                        revealParentAndSiblingsOf(zone) {
                            if  let ancestor = gHere.parentZone {
                                ancestor.grab()
                                self.revealSiblingsOf(gHere, untilReaching: ancestor)
                            }
                        }
                    } else if let p = parent {
                        p.displayChildren()
                        p.needChildren()

                        gOperationsManager.children(.restore) {
                            p.grab()
                            self.signalFor(p, regarding: .redraw)
                        }
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
                zone.isFavorite = true

                moveIntoHere(gFavoritesManager.rootZone)
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
        } else {
            zone.needChildren()
            zone.displayChildren()

            gOperationsManager.children(.restore) {
                self.grabChild(of: zone)
            }
        }
    }


    func grabChild(of zone: Zone) {
        if  zone.count > 0, let child = gInsertionsFollow ? zone.children.last : zone.children.first {
            child.grab()
            redrawAndSync()
        }
    }


    func moveZone(_ zone: Zone, to there: Zone) {
        if !there.isBookmark {
            moveZone(zone, into: there, at: gInsertionsFollow ? nil : 0, orphan: true) {
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

                    self.moveZone(mover, into: there, at: gInsertionsFollow ? nil : 0, orphan: false) {
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


    func applyModeRecursivelyTo(_ iZone: Zone?) {
        iZone?.traverseAllProgeny() { iChild in
            iChild.record      = CKRecord(recordType: zoneTypeKey)
            iChild.storageMode = gStorageMode

            iChild.needFlush()
            iChild.updateCloudProperties()
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
    

    func createIdeaIn(_ iZone: Zone?, at iIndex: Int?, onCompletion: ZoneMaybeClosure?) {
        if  let         zone = iZone, zone.storageMode != .favorites {
            let createAndAdd = {
                let   record = CKRecord(recordType: zoneTypeKey)
                let    child = Zone(record: record, storageMode: zone.storageMode)

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.deleteZone(child, onCompletion: onCompletion)
                    onCompletion?(nil)
                }

                zone.ungrab()
                zone.addAndReorderChild(child, at: iIndex)
                onCompletion?(child)
            }

            zone.displayChildren()
            gSelectionManager.stopCurrentEdit()

            if zone.count > 0 || zone.fetchableCount == 0 {
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


    func reverse() {
        if  var commonParent = gSelectionManager.firstGrab.parentZone {
            var        zones = gSelectionManager.simplifiedGrabs
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


    func undoDelete() {
        gSelectionManager.deselectGrabs()

        for (child, (parent, index)) in gSelectionManager.pasteableZones {
            parent?.addAndReorderChild(child, at: index)
            child.addToGrab()
        }

        gSelectionManager.clearPaste()

        UNDO(self) { iUndoSelf in
            iUndoSelf.delete()
        }

        redrawAndSync()
    }


    func pasteInto(_ iZone: Zone? = nil, honorFormerParents: Bool = false) {
        let      pastables = gSelectionManager.pasteableZones

        if pastables.count > 0, let zone = iZone {
            let isBookmark = zone.isBookmark
            let action = {
                var forUndo = [Zone] ()

                gSelectionManager.deselectGrabs()

                for (child, (parent, index)) in pastables {
                    let pastable = child.isDeleted ? child : child.deepCopy()
                    let       at = index  != nil ? index : gInsertionsFollow ? nil : 0
                    let     into = parent != nil ? honorFormerParents ? parent! : zone : zone
                    let     mode = into.storageMode ?? gStorageMode

                    pastable.traverseAllProgeny { iChild in
                        iChild.fetchableCount = iChild.count
                        iChild   .storageMode = mode

                        iChild.needFlush()
                    }

                    pastable.orphan()
                    into.displayChildren()
                    into.addAndReorderChild(pastable, at: at)
                    forUndo.append(pastable)
                    pastable.addToGrab()
                }

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.prepareUndoForDelete()
                    iUndoSelf.deleteZones(forUndo, in: nil) { iZone in }
                    zone.grab()
                    iUndoSelf.redrawAndSync()
                }

                if isBookmark {
                    self.undoManager.endUndoGrouping()
                }

                self.redrawAndSync()
            }

            let prepare = {
                var need = false

                for child in pastables.keys {
                    if !child.isDeleted {
                        child.needProgeny()

                        need = true
                    }
                }

                if !need {
                    action()
                } else {
                    gOperationsManager.children(.all) {
                        action()
                    }
                }
            }

            if !isBookmark {
                prepare()
            } else {
                undoManager.beginUndoGrouping()
                gTravelManager.travelThrough(zone) { (iAny, iSignalKind) in
                    prepare()
                }
            }
        }
    }


    func preserveChildrenOfGrabbedZones() {
        let     candidate = gSelectionManager.rootMostMoveable
        if  let    parent = candidate.parentZone {
            var  children = [Zone] ()
            let     index = candidate.siblingIndex
            let     grabs = gSelectionManager.simplifiedGrabs

            gSelectionManager.deselectGrabs()
            gSelectionManager.clearPaste()

            for grab in grabs {
                for child in grab.children {
                    children.append(child)
                }

                grab.addToPaste()
                moveToTrash(grab)
            }

            children.sort { (a, b) -> Bool in
                return a.order > b.order      // reversed ordering
            }

            for child in children {
                parent.addAndReorderChild(child, at: index)
                child.addToGrab()
            }

            self.UNDO(self) { iUndoSelf in
                iUndoSelf.prepareUndoForDelete()
                iUndoSelf.deleteZones(children) { iZone in iZone?.grab() }
                iUndoSelf.pasteInto(parent, honorFormerParents: true)
            }
        }
    }

    
    func prepareUndoForDelete() {
        gSelectionManager.clearPaste()

        self.UNDO(self) { iUndoSelf in
            iUndoSelf.undoDelete()
        }
    }


    func moveOut(to: Zone, onCompletion: Closure?) {
        let         zone = gSelectionManager.firstGrab
        var completedYet = false

        recursivelyRevealSiblingsOf(zone, untilReaching: to) { iRevealedZone in
            if !completedYet && iRevealedZone == to {
                completedYet     = true
                var insert: Int? = zone.parentZone?.siblingIndex

                if to.storageMode == .favorites {
                    insert = gFavoritesManager.nextFavoritesIndex(forward: gInsertionsFollow)
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

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // 1. move a normal zone into another normal zone                                                           //
        // 2. move a normal zone through a bookmark                                                                 //
        // 3. move a normal zone into favorites -- create a favorite pointing at normal zone, then add the favorite //
        // 4. move a favorite into a normal zone -- convert favorite to a bookmark, then move the bookmark          //
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////

        let toFavorites = iInto.isRootOfFavorites   // type 3
        let  toBookmark = iInto.isBookmark          // type 2
        var     restore = [Zone: (Zone, Int?)] ()
        var       grabs = gSelectionManager.currentGrabs

        if  let dragged = gDraggedZone, dragged.isFavorite {
            dragged.isFavorite = false              // type 4
            dragged.needFlush()
        }

        grabs.sort { (a, b) -> Bool in
            if  a.isFavorite {
                a.isFavorite = false                // type 4
                a.needFlush()
            }

            return a.order < b.order
        }

        //////////////////////
        // prepare for UNDO //
        //////////////////////

        for zone in grabs {
            if  let    parent = zone.parentZone {
                let     index = zone.siblingIndex
                restore[zone] = (parent, index)
            }
        }

        if toBookmark {
            undoManager.beginUndoGrouping()
        }

        UNDO(self) { iUndoSelf in
            for (child, (parent, index)) in restore {
                child.orphan()
                parent.addAndReorderChild(child, at: index)
            }

            iUndoSelf.UNDO(self) { iUndoUndoSelf in
                iUndoUndoSelf.moveGrabbedZones(into: iInto, at: iIndex, onCompletion: onCompletion)
            }

            onCompletion?()
        }

        let finish = {
            let     into = !toBookmark ? iInto : iInto.bookmarkTarget! // grab bookmark AFTER travel
            let addGrabs = {
                for zone in grabs {
                    var movable = zone

                    if !toFavorites {
                        movable.orphan()
                    } else {
                        movable = gFavoritesManager.createBookmark(for: zone, isFavorite: true)

                        movable.needFlush()
                    }

                    into.addAndReorderChild(movable, at: iIndex)
                }

                if toBookmark {
                    self.undoManager.endUndoGrouping()
                }

                onCompletion?()
            }

            ///////////////////////////////////////////////////////////
            // assure children (of into) are present, then add grabs //
            ///////////////////////////////////////////////////////////

            into.displayChildren()

            if !into.hasMissingChildren {
                addGrabs()
            } else {
                into.maybeNeedChildren()

                gOperationsManager.children(.restore) {
                    addGrabs()
                }
            }
        }

        ///////////////////////////////////////
        // deal with target being a bookmark //
        ///////////////////////////////////////

        if !toBookmark {
            finish()
        } else {
            gTravelManager.travelThrough(iInto) { (iAny, iSignalKind) in
                finish()
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

        into.displayChildren()
        into.needChildren()

        gOperationsManager.children(.restore) {
            if orphan {
                zone.orphan()
            }

            into.addAndReorderChild(zone, at: iIndex)
            into.needFlush()
            zone.needFlush()
            zone.grab()
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
                    if  there.moveChildIndex(from: index, to: newIndex) { // if move succeeds
                        let grab = there.children[newIndex]
                        
                        grab.grab()
                        there.updateOrdering()
                        redrawAndSync(there)
//                        gFavoritesManager.updateForZone(there) { iZone in
//                            self.redrawAndSync(there)
//                        }
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
