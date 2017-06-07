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
            let     spaceDo = {
                if let zone = widget?.widgetZone, !zone.isBookmark {
                    self.addNewChildTo(zone)
                }
            }

            if  isEditing {
                switch key {
                case "a":         if isCommand { gSelectionManager.currentlyEditingZone?.widget?.textWidget.selectAllText() }
                case gSpaceKey:   if isControl { spaceDo() }
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
                case "/", "?":    onZone(gSelectionManager.firstGrab, toggleFavorite: hasFlags)
                case "-":         addSibling(containing: false, with: "-------------------------") { iChild in iChild.grab() }
                case "z":         if isCommand { if isShift { gUndoManager.redo() } else { gUndoManager.undo() } }
                case gTabKey:     if hasWidget { addSibling(containing: isOption) }
                case gSpaceKey:   if force { spaceDo() }
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

        if !isShift {
            switch arrow {
            case .right: moveInto(     selectionOnly: !isOption, extreme: isCommand)
            case .left:  moveOut(      selectionOnly: !isOption, extreme: isCommand)
            case .down:  moveUp(false, selectionOnly: !isOption, extreme: isCommand)
            case .up:    moveUp(true,  selectionOnly: !isOption, extreme: isCommand)
            }
        } else {

            //////////////////
            // GENERATIONAL //
            //////////////////

            let zone = gSelectionManager.firstGrab
            var show = true

            switch arrow {
            case .left:  show = false
            case .right: break
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


    // MARK:- API
    // MARK:-


    func syncAndRedraw() { gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw, onCompletion: nil) }
    func         paste() { pasteInto(gSelectionManager.firstGrab) }


    func copyToPaste() {
        gSelectionManager.clearPaste()

        for zone in gSelectionManager.currentGrabs {
            zone.needChildren()
        }

        gOperationsManager.children(.deep) {
            for zone in gSelectionManager.currentGrabs {
                self.addToPasteCopyOf(zone)
            }
        }
    }


    func find() {
        if gStorageMode != .favorites {
            gShowsSearching = !gShowsSearching

            signalFor(nil, regarding: .search)
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
                syncAndRedraw()
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
        if isCommand {
            gFavoritesManager.refocus() {
                self.syncAndRedraw()
            }
        } else if         !isShift || !isOption {
            let backward = isShift ||  isOption

            gFavoritesManager.switchToNext(!backward) {
                self.syncAndRedraw()
            }
        } else {
            gFavoritesManager.showFavoritesAndGrab(gSelectionManager.firstGrab) { object, kind in
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


    func onZone(_ iZone: Zone, toggleFavorite: Bool) {
        let focusOn = { (zone: Zone) in
            gHere = zone

            zone.grab()
            gControllersManager.syncToCloudAndSignalFor(zone, regarding: .redraw) {}
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

            self.syncAndRedraw()
        }
    }


    // MARK:- toggle dot
    // MARK:-


    func toggleDotUpdate(show: Bool, zone: Zone, to iGoal: Int? = nil) {
        toggleDotRecurse(show, zone, to: iGoal) {

            ///////////////////////////////////////////////////////////
            // delay executing this until the last time it is called //
            ///////////////////////////////////////////////////////////

            self.syncAndRedraw()
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
                zone.traverseApply() { iZone in
                    if !show && iZone.level >= goal {
                        iZone.hideChildren()
                    } else if show && iZone.level < goal {
                        iZone.displayChildren()
                    }

                    return .eContinue
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

            for grabbed: Zone in s.currentGrabs {
                if zone.spawned(grabbed) {
                    s.ungrab(grabbed)
                }
            }

            if zone.isBookmark {
                travelThroughBookmark(zone)
            } else {
                let show = !zone.showChildren

                toggleDotUpdate(show: show, zone: zone)
            }
        }
    }


    // MARK:- create
    // MARK:-


    func addNewChildTo(_ parentZone: Zone?) {
        addNewChildTo(parentZone, at: asTask ? 0 : nil) { iChild in
            gControllersManager.signalFor(parentZone, regarding: .redraw) {
                gSelectionManager.edit(iChild)
            }
        }
    }


    func addSibling(containing: Bool) {
        addSibling(containing: containing) { iChild in
            gSelectionManager.edit(iChild)
        }
    }


    func addSibling(containing: Bool, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
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
                index! += asTask ? 0 : 1
            }

            addNewChildTo(parent, at: index) { iChild in
                if name != nil {
                    iChild.zoneName = name
                }

                if !containing {
                    gControllersManager.signalFor(parent, regarding: .redraw) {
                        onCompletion?(iChild)
                    }
                } else {
                    self.moveZones(zones, into: iChild, at: nil, orphan: true) {
                        gControllersManager.syncToCloudAndSignalFor(parent, regarding: .redraw) {
                            onCompletion?(iChild)
                        }
                    }
                }
            }
        }
    }


    func addNewChildTo(_ iZone: Zone?, at iIndex: Int?, onCompletion: ZoneClosure?) {
        if  let               zone = iZone, zone.storageMode != .favorites {
            let       createAndAdd = {
                let         record = CKRecord(recordType: zoneTypeKey)
                let          child = Zone(record: record, storageMode: zone.storageMode)
                child.progenyCount = 1 // so add and reorder will correctly propagate count

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


    func addToPasteCopyOf(_ zone: Zone) {
        let        copy = zone.deepCopy()
        copy.parentZone = nil

        copy.recursivelyMarkAsDeleted(true)
        gSelectionManager.pasteableZones.append(copy)
    }


    // MARK:- destroy
    // MARK:-


    func delete(preserveChildren: Bool = false) {
        prepareUndoForDelete()

        let candidate = gSelectionManager.rootMostMoveable
        let     zones = gSelectionManager.currentGrabs
        let    action = {
            let last = self.deleteZones(zones, preserveChildren: preserveChildren, in: nil)

            last?.grab()
        }

        if !preserveChildren {
            action()

            gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {
                self.signalFor(nil, regarding: .redraw)
            }
        } else if let parent = candidate.parentZone,
            var        index = parent.children.index(of: candidate) {
            let     preserve = {
                var children = [Zone]()

                for zone in zones {
                    for child in zone.children {
                        let copy = child.deepCopy()

                        copy.traverseApply() { (iZone) -> (ZTraverseStatus) in
                            iZone.isDeleted = false

                            return .eContinue
                        }

                        children.append(copy)
                    }
                }

                action()

                for child in children {
                    parent.addChild(child, at: index)

                    index += 1
                }

                gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {
                    self.signalFor(nil, regarding: .redraw)
                }
            }

            if !candidate.hasChildren || candidate.count > 0 {
                preserve()
            } else {
                candidate.needChildren()
                gOperationsManager.children(.deep) {
                    preserve()
                }
            }
        }
    }


    @discardableResult private func deleteZones(_ zones: [Zone], preserveChildren: Bool = false, in parent: Zone?) -> Zone? {
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


    func newmoveUp(_ moveUp: Bool, selectionOnly: Bool, extreme: Bool) {
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
                    self.syncAndRedraw()
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

                gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
            }
        } else if zone.storageMode != .favorites {

            ///////////////
            // MOVE ZONE //
            ///////////////

            let grandparent = parent?.parentZone

            let moveIntoHere = { (iHere: Zone?) in
                if iHere != nil {
                    gHere = iHere!

                    self.moveZone(zone, outTo: iHere!, orphan: true) {
                        self.syncAndRedraw()
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
                moveZone(zone, outTo: grandparent!, orphan: true){
                    gControllersManager.syncToCloudAndSignalFor(grandparent!, regarding: .redraw) {}
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
        } else if zone.hasChildren {
            zone.needChildren()

            gOperationsManager.children(.restore) {
                self.grabChild(of: zone)
            }
        }
    }


    func grabChild(of zone: Zone) {
        if  zone.count > 0, let child = asTask ? zone.children.first : zone.children.last {
            zone.displayChildren()
            child.grab()
            signalFor(nil, regarding: .redraw)
        }
    }


    func moveZone(_ zone: Zone, _ toThere: Zone) {
        if !toThere.isBookmark {
            let parent = zone.parentZone

            moveZone(zone, into: toThere, at: asTask ? 0 : nil, orphan: true){
                gControllersManager.syncToCloudAndSignalFor(parent, regarding: .redraw) {}
            }
        } else if !gTravelManager.isZone(zone, ancestorOf: toThere) {

            //////////////////////////////////
            // MOVE ZONE THROUGH A BOOKMARK //
            //////////////////////////////////

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

                    self.moveZone(mover, into: there, at: asTask ? 0 : nil, orphan: false) {
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


    func pasteInto(_ zone: Zone) {
        let pastables = gSelectionManager.pasteableZones
        var     count = pastables.count

        if count > 0, !zone.isBookmark {
            var originals = [Zone] ()

            for pastable in pastables {
                let pasteThis = pastable.deepCopy()

                originals.append(pasteThis)
                pasteThis.orphan() // disable undo inside moveZone
                pasteThis.recursivelyMarkAsDeleted(false)
                moveZone(pasteThis, into: zone, at: asTask ? 0 : nil, orphan: false) {
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

        for zone in gSelectionManager.currentGrabs {
            if let parent = zone.parentZone {
                addToPasteCopyOf(zone)

                UNDO(self) { iUndoSelf in
                    iUndoSelf.pasteInto(parent)
                }
            }
        }
    }


    func moveZone(_ zone: Zone, outTo: Zone, orphan: Bool, onCompletion: Closure?) {
        var completedYet = false

        recursivelyRevealSiblingsOf(zone, untilReaching: outTo) { (iRevealedZone: Zone) in
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
    
    
    func moveUp(_ iMoveUp: Bool, selectionOnly: Bool, extreme: Bool) {
        let         zone = gSelectionManager.firstGrab
        let       isHere = zone == gHere
        if  let    there = zone.parentZone, !isHere, let index = zone.siblingIndex {
            var newIndex = index + (iMoveUp ? -1 : 1)
            
            if extreme {
                newIndex = iMoveUp ? 0 : there.count - 1
            }
            
            if newIndex >= 0 && newIndex < there.count {
                if  zone == gHere {
                    gHere = there
                }
                
                UNDO(self) { iUndoSelf in
                    iUndoSelf.moveUp(!iMoveUp, selectionOnly: selectionOnly, extreme: extreme)
                }
                
                if selectionOnly {
                    there.children[newIndex].grab()
                    signalFor(there, regarding: .redraw)
                } else {
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
                        gHere = parent
                        
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
