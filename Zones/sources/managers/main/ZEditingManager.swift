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


let gEditingManager = ZEditingManager()


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


    var undoManager: UndoManager {
        if  let w = gEditedTextWidget,
            w.undoManager != nil {
            return w.undoManager!
        }

        return kUndoManager
    }


    // MARK:- events
    // MARK:-


    enum ZMenuType: Int {
        case Undo
        case Sort
        case Child
        case Alter
        case Cloud
        case Always
        case Parent
        case Travel
        case SelectAll

        case Redo
        case Paste
        case UseGrabs
        case Multiple
}


    func menuType(for key: String, _ flags: NSEventModifierFlags) -> ZMenuType {
        let isCommand = flags.isCommand

        switch key {
        case "a":                            return .SelectAll
        case "=":                            return .Travel
        case "z":                            return .Undo
        case "o", "r":                       return .Sort
        case "v", "x", kSpace:               return .Child
        case "d":                            return  isCommand ? .Alter : .Parent
        case "b", kTab, kDelete, kBackspace: return .Parent
        case ";", "'", "/", "?", ",", ".":   return .Cloud
        case "e", "h", "i", "l", "u", "w",
             "1", "-", "$", "!", "\r":       return .Alter
        default:                             return .Always
        }
    }


    func validateKey(_ key: String, _ flags: NSEventModifierFlags) -> Bool {
        if gWorkMode != .graphMode {
            return false
        }

        let type = menuType(for: key, flags)
        var valid = !gIsEditingText

        if  valid {
            let   undo = undoManager
            let      s = gSelectionManager
            let  mover = s.currentMoveable
            let wGrabs = s.writableGrabsCount
            let  paste = s.pasteableZones.count
            let  grabs = s.currentGrabs  .count
            let  shown = s.currentGrabsHaveVisibleChildren
            let  write = mover.isWritableByUseer
            let   sort = mover.isSortableByUser
            let parent = mover.isMovableByUser

            switch type {
            case .Parent:    valid =               parent
            case .Child:     valid =               sort
            case .Alter:     valid =               write
            case .Paste:     valid =  paste > 0 && write
            case .UseGrabs:  valid = wGrabs > 0 && write
            case .Multiple:  valid =  grabs > 1
            case .Sort:      valid = (shown     && sort) || (grabs > 1 && parent)
            case .SelectAll: valid =  shown
            case .Cloud: valid = gHasPrivateDatabase
            case .Undo:      valid = undo.canUndo
            case .Redo:      valid = undo.canRedo
            case .Travel:    valid = mover.canTravel
            case .Always:    valid = true
            }
        } else if key.arrow == nil {
            valid = type != .Travel
        }

        return valid
    }


    func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) {
        if  var       key = iKey, validateKey(key, flags) {
            let    widget = gWidgetsManager.currentMovableWidget
            let hasWidget = widget != nil
            let isControl = flags.isControl
            let isCommand = flags.isCommand
            let  isOption = flags.isOption
            var   isShift = flags.isShift

            if  key      != key.lowercased() {
                key       = key.lowercased()
                isShift   = true
            }

            if  gIsEditingText {
                switch key {
                case "a":      if isCommand { gEditedTextWidget?.selectAllText() }
                case "d":      if isCommand { addIdeaFromSelectedText() }
                case "f":      if isCommand { find() }
                case "?":      if isControl { gDetailsController?.displayViewFor(ids: [.Shortcuts]) }
                case ",", ".": gInsertionMode = key == "." ? .follow : .precede; signalFor(nil, regarding: .preferences)
                case kSpace:   if isControl { addIdea() }
                default:       break
                }
            } else if isWindow, let arrow = key.arrow {
                handleArrow(arrow, flags: flags)
            } else {
                switch key {
                case "a":      selectAll(progeny: isOption)
                case "b":      addBookmark()
                case "c":      recenter()
                case "d":      duplicate()
                case "e":      editEmail()
                case "f":      find()
                case "h":      editHyperlink()
                case "i":      toggleColorized()
                case "l", "u": alterCase(up: key == "u")
                case "n":      alphabetize(isOption)
                case "o":      orderByLength(isOption)
                case "p":      printHere()
                case "r":      reverse()
                case "s":      selectCurrentFavorite()
                case "w":      toggleWritable()
                case "$", "!": mark(with: key)
                case "1":      divideChildren()
                case "-":      addLine()
                case "`":      travelToOtherGraph()
                case "[":      gTravelManager.goBack()
                case "]":      gTravelManager.goForward()
                case ";":      doFavorites(true,    false)
                case "?":      openBrowserForFocusWebsite()
                case "'":      doFavorites(isShift, isOption)
                case "/":      focus(on: gSelectionManager.firstGrab, isCommand)
                case "=":      gTravelManager.maybeTravelThrough(gSelectionManager.firstGrab) { self.redrawSyncRedraw() }
                case kTab:     addNext(containing: isOption) { iChild in iChild.edit() }
                case ",", ".": gInsertionMode = key == "." ? .follow : .precede; signalFor(nil, regarding: .preferences)
                case "z":      if isCommand { if isShift { kUndoManager.redo() } else { kUndoManager.undo() } }
                case kSpace:   if isOption || isWindow || isControl { addIdea() }
                case kBackspace,
                     kDelete:  if isOption || isWindow { delete(permanently: isCommand && isControl && isOption && isWindow, preserveChildren: !isCommand && !isControl && isOption && isWindow) }
                case "\r":     if hasWidget { grabOrEdit(isCommand) }
                default:       break
                }
            }
        }
    }


    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        let isCommand = flags.isCommand
        let  isOption = flags.isOption
        let   isShift = flags.isShift

        if isOption && !gSelectionManager.currentMoveable.isMovableByUser {
            return
        }

        switch arrow {
        case .down:     moveUp(false, selectionOnly: !isOption, extreme: isCommand, extend: isShift)
        case .up:       moveUp(true,  selectionOnly: !isOption, extreme: isCommand, extend: isShift)
        default:
            if !isShift {
                switch arrow {
                case .right: moveInto(selectionOnly: !isOption, extreme: isCommand) { self.updateFavoritesRedrawAndSync() }
                case .left:  moveOut( selectionOnly: !isOption, extreme: isCommand) { self.updateFavoritesRedrawAndSync() }
                default: break
                }
            } else if !isOption {

                //////////////////
                // GENERATIONAL //
                //////////////////

                var show = true

                switch arrow {
                case .right: break
                case .left:  show = false
                default:     return
                }

                applyGenerationally(show, extreme: isCommand)
            }
        }
    }


    @discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> Bool {
        if !gIsEditingText, iEvent != previousEvent, gWorkMode == .graphMode {
            let     flags = iEvent.modifierFlags
            previousEvent = iEvent

            if let key = iEvent.key {
                handleKey(key, flags: flags, isWindow: isWindow)
            } else if let arrow = iEvent.arrow {
                handleArrow(arrow, flags: flags)
            }


            return true
        }

        return false
    }


    func handleMenuItem(_ iItem: ZMenuItem?) {
        #if os(OSX)
            if  gWorkMode == .graphMode,
                let   item = iItem {
                let  flags = item.keyEquivalentModifierMask
                let    key = item.keyEquivalent

                handleKey(key, flags: flags, isWindow: true)
            }
        #endif
    }


    // MARK:- miscellaneous features
    // MARK:-


    func travelToOtherGraph() {
        let here = gHere

        toggledatabaseiD()

        if        here.isRootOfFavorites {
            gHere = gFavoritesManager.rootZone!
        } else if here.isLostAndFound {
            gHere = gLostAndFound!
        } else if here.isTrash {
            gHere = gTrash!
        } else if here.isRoot {
            gHere = gRoot!
        }


        gHere.grab()
        gHere.revealChildren()
        gFavoritesManager.updateFavorites()
        signalFor(nil, regarding: .redraw)
    }


    func toggleColorized() {
        for zone in gSelectionManager.currentGrabs {
            zone.colorized = !zone.colorized
        }
    }


    func mark(with iMark: String) {
        let  zones = gSelectionManager.currentGrabs
        let prefix = "(" + iMark + ") "

        for zone in zones {
            if  let name = zone.zoneName {
                if !name.starts(with: prefix) {
                    zone .zoneName = prefix + name
                } else {
                    let components = name.components(separatedBy: prefix)
                    zone .zoneName = components[1]
                }

                zone.widget?.textWidget.updateText()
            }
        }

        signalFor(nil, regarding: .redraw)
    }


    func editEmail() {
        let       zone = gSelectionManager.firstGrab
        if  let widget = gWidgetsManager.widgetForZone(zone) {
            widget.textWidget.isEditingEmail = true
            zone.edit()
        }
    }


    func editHyperlink() {
        let       zone = gSelectionManager.firstGrab
        if  let widget = gWidgetsManager.widgetForZone(zone) {
            widget.textWidget.isEditingHyperlink = true
            zone.edit()
        }
    }


    func divideChildren() {
        let grabs = gSelectionManager.currentGrabs

        for zone in grabs {
            zone.needChildren()
        }

        gDBOperationsManager.children { iSame in
            for zone in grabs {
                zone.divideEvenly()
            }

            self.redrawSyncRedraw()
        }
    }


    func toggleWritable() {
        for zone in gSelectionManager.currentGrabs {
            zone.toggleWritable()
        }

        redrawSyncRedraw()
    }


    func applyGenerationally(_ show: Bool, extreme: Bool = false) {
        let       zone = gSelectionManager.rootMostMoveable
        var goal: Int? = nil

        if !show {
            goal = extreme ? zone.level - 1 : zone.highestExposed - 1
        } else if  extreme {
            goal = Int.max
        } else if let lowest = zone.lowestExposed {
            goal = lowest + 1
        }

        toggleDotUpdate(show: show, zone: zone, to: goal) {
            self.redrawSyncRedraw()
        }
    }


    func alphabetize(_ iBackwards: Bool = false) {
        alterOrdering { iZones -> ([Zone]) in
            return iZones.sorted { (a, b) -> Bool in
                let aName = a.unwrappedName
                let bName = b.unwrappedName

                return iBackwards ? (aName > bName) : (aName < bName)
            }
        }
    }


    func orderByLength(_ iBackwards: Bool = false) {
        let font = gWidgetFont

        alterOrdering { iZones -> ([Zone]) in
            return iZones.sorted { (a, b) -> Bool in
                let aLength = a.zoneName?.widthForFont(font) ?? 0
                let bLength = b.zoneName?.widthForFont(font) ?? 0

                return iBackwards ? (aLength > bLength) : (aLength < bLength)
            }
        }
    }


    func alterOrdering(_ iBackwards: Bool = false, with sortClosure: ZonesToZonesClosure) {
        var commonParent = gSelectionManager.firstGrab.parentZone ?? gSelectionManager.firstGrab
        var        zones = gSelectionManager.simplifiedGrabs

        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                // status bar -> not all of the grabbed zones share the same parent
                return
            }
        }

        if zones.count == 1 {
            commonParent = gSelectionManager.firstGrab
            zones        = commonParent.children
        }

        commonParent.children.updateOrder()

        if  zones.count > 1 {
            let (start, end) = zones.orderLimits()
            zones            = sortClosure(zones)

            zones.updateOrdering(start: start, end: end)
            commonParent.respectOrder()
            commonParent.children.updateOrder()
            redrawSyncRedraw()
        }
    }


    func recenter() {
        gScaling      = 1.0
        gScrollOffset = CGPoint.zero

        gEditorController?.layoutForCurrentScrollOffset()
    }


    func alterCase(up: Bool) {
        for grab in gSelectionManager.currentGrabs {
            if let text = grab.widget?.textWidget {
                text.alterCase(up: up)
            }
        }
    }


    func find() {
        if gDatabaseiD != .favoritesID {
            gWorkMode = gWorkMode == .searchMode ? .graphMode : .searchMode

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


    func selectAll(progeny: Bool = false) {
        let zone = gSelectionManager.currentMoveable

        if  zone.showChildren && zone.count != 0 {
            gSelectionManager.clearGrab()

            if progeny {
                zone.traverseAllProgeny { iChild in
                    iChild.addToGrab()
                }
            } else {
                for child in zone.children {
                    child.addToGrab()
                }
            }

            redrawSyncRedraw()
        }
    }


    func grabOrEdit(_ isCommand: Bool) {
        if  !gSelectionManager.hasGrab {
            gHere.grab()
        } else if isCommand {
            gSelectionManager.deselect()
        } else {
            gSelectionManager.editCurrent()
        }
    }


    // MARK:- focus and travel
    // MARK:-


    func selectCurrentFavorite() {
        if  let current = gFavoritesManager.currentFavorite {
            current.needRoot()
            gDBOperationsManager.families { iSame in
                if  let parent = current.parentZone {
                    parent.traverseAllAncestors { iAncestor in
                        iAncestor.revealChildren()
                    }

                    self.signalFor(nil, regarding: .redraw)
                }
            }

            if !current.isGrabbed {
                current.grab()
            } else {
                gHere.grab()
            }
        }
    }


    func doFavorites(_ isShift: Bool, _ isOption: Bool) {
        let backward = isShift || isOption

        gFavoritesManager.switchToNext(!backward) {
            self.redrawSyncRedraw()
        }
    }


    func focus(on iZone: Zone, _ isCommand: Bool = false) {
        let focusClosure = { (zone: Zone) in
            gHere = zone

            zone.grab()
            self.redrawSyncRedraw()
        }

        if isCommand {
            gFavoritesManager.refocus {
                self.redrawSyncRedraw()
            }
        } else if iZone.isBookmark {
            gTravelManager.travelThrough(iZone) { object, kind in
                gSelectionManager.deselect()
                focusClosure(object as! Zone)
            }
        } else if iZone == gHere {
            gFavoritesManager.toggleFavorite(for: iZone)
            redrawSyncRedraw()
        } else {
            focusClosure(iZone)
        }
    }


    // MARK:- async reveal
    // MARK:-


    func revealZonesToRoot(from zone: Zone, _ onCompletion: Closure?) {
        if zone.isRoot {
            onCompletion?()
        } else {
            var needOp = false

            zone.traverseAncestors { iZone -> ZTraverseStatus in
                if  let parentZone = iZone.parentZone, !parentZone.alreadyExists {
                    iZone.needRoot()

                    needOp = true

                    return .eStop
                }

                return .eContinue
            }

            if let root = gRoot, !needOp {
                gHere = root

                onCompletion?()
            } else {
                gDBOperationsManager.root { iSame in
                    onCompletion?()
                }
            }
        }
    }


    func revealParentAndSiblingsOf(_ iZone: Zone, onCompletion: BooleanClosure?) {
        if  let parent = iZone.parentZone {
            parent.revealChildren()

            if  parent.hasMissingChildren() {
                parent.needChildren()

                gDBOperationsManager.children(.restore) { iSame in
                    onCompletion?(true)
                }
            } else {

                ///////////////////////////////////////////////////////////////////////
                // passing false means: did not do a cloud operation ... avoids hang //
                ///////////////////////////////////////////////////////////////////////

                onCompletion?(false)
            }
        } else {
            iZone.needParent()

            gDBOperationsManager.families { iSame in
                onCompletion?(true)
            }
        }
    }


    func recursivelyRevealSiblings(_ descendent: Zone, untilReaching iAncestor: Zone, onCompletion: ZoneClosure?) {
        var needRoot = true

        descendent.traverseAllAncestors { iParent in
            iParent.revealChildren()

            if iParent.hasMissingChildren() {
                iParent.needChildren() // need this to show "minimal flesh" on graph
            }

            if iParent == iAncestor {
                needRoot = false
            }
        }

        if needRoot {
            descendent.needRoot()
        }

        gDBOperationsManager.families { iSame in
            FOREGROUND {
                descendent.traverseAncestors { iParent -> ZTraverseStatus in
                    let  gotThere = iParent == iAncestor || iParent.isRoot    // reached the ancestor or the root
                    let gotOrphan = iParent.parentZone == nil

                    if  gotThere || gotOrphan {
                        if !gotThere && !iParent.alreadyExists && iParent.parentZone != nil { // reached an orphan that has not yet been fetched
                            self.recursivelyRevealSiblings(iParent, untilReaching: iAncestor, onCompletion: onCompletion)
                        } else {
                            iAncestor.revealChildren()
                            FOREGROUND(after: 0.1) {
                                onCompletion?(iAncestor)
                            }
                        }

                        return .eStop
                    }

                    return .eContinue
                }
            }
        }
    }


    func revealSiblingsOf(_ descendent: Zone, untilReaching iAncestor: Zone) {
        recursivelyRevealSiblings(descendent, untilReaching: iAncestor) { iZone in
            if iZone == iAncestor {
                gHere = iAncestor

                gHere.grab()
            }

            self.redrawSyncRedraw()
        }
    }


    // MARK:- toggle dot
    // MARK:-


    func toggleDotUpdate(show: Bool, zone: Zone, to iGoal: Int? = nil, onCompletion: Closure?) {
        toggleDotRecurse(show, zone, to: iGoal) {

            ///////////////////////////////////////////////////////////
            // delay executing this until the last time it is called //
            ///////////////////////////////////////////////////////////

            onCompletion?()
        }
    }


    func toggleDotRecurse(_ show: Bool, _ zone: Zone, to iGoal: Int?, onCompletion: Closure?) {
        if !show && zone.isGrabbed && (zone.count == 0 || !zone.showChildren) {

            //////////////////////////////////
            // COLLAPSE OUTWARD INTO PARENT //
            //////////////////////////////////

            zone.concealChildren()

            revealParentAndSiblingsOf(zone) { iCloudCalled in
                if let  parent = zone.parentZone, parent != zone {
                    if  gHere == zone {
                        gHere  = parent
                    }

                    parent.grab()
                    
                    self.toggleDotRecurse(show, parent, to: iGoal, onCompletion: onCompletion)
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
                    if           !iChild.isBookmark {
                        if        iChild.level >= goal && !show {
                                  iChild.concealChildren()
                        } else if iChild.level  < goal && show {
                                  iChild.revealChildren()
                        }
                    }
                }

                if zone.isInFavorites && show {
                    gFavoritesManager.updateFavorites()
                }

                onCompletion?()
            }

            if !show {
                gSelectionManager.deselectDragWithin(zone);
                apply()
            } else {
                zone.needProgeny()
                gDBOperationsManager.children(.all, goal) { iSame in
                    apply()
                }
            }
        }
    }


    func toggleDotActionOnZone(_ iZone: Zone?) {
        if  let zone = iZone, !zone.onlyShowToggleDot {
            let    s = gSelectionManager

            if gIsEditingText {
                s.stopCurrentEdit()
            }

            for     grabbed in s.currentGrabs {
                if  grabbed != zone && grabbed.spawnedBy(zone) {
                    grabbed.ungrab()
                }
            }

            if  zone.fetchableCount == 0 && zone.count == 0 {
                gTravelManager.maybeTravelThrough(zone) {
                    self.redrawSyncRedraw()
                }
            } else if zone.showChildren && zone.hasMissingChildren() {
                zone.needChildren()
                gDBOperationsManager.children { iSame in
                    self.signalFor(nil, regarding: .redraw)
                }
            } else {
                let show = !zone.showChildren

                toggleDotUpdate(show: show, zone: zone) {
                    self.redrawSyncRedraw()
                }
            }
        }
    }


    // MARK:- add
    // MARK:-


    func addIdea() {
        let parentZone = gSelectionManager.currentMoveable
        if !parentZone.isBookmark {
            addIdeaIn(parentZone, at: gInsertionsFollow ? nil : 0) { iChild in
                gControllersManager.signalFor(parentZone, regarding: .redraw) {
                    iChild?.edit()
                }
            }
        }
    }


    func addNext(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
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

                parent.revealChildren()
            }

            var index   = zone.siblingIndex

            if  index  != nil {
                index! += gInsertionsFollow ? 1 : 0
            }

            addIdeaIn(parent, at: index, with: name) { iChild in
                if let child = iChild {
                    if !containing {
                        gControllersManager.signalFor(nil, regarding: .redraw) {
                            onCompletion?(child)
                        }
                    } else {
                        self.moveZones(zones, into: child, at: nil, orphan: true) {
                            gControllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {
                                onCompletion?(child)
                            }
                        }
                    }
                }
            }
        }
    }


    func addLine() {
        let   grab = gSelectionManager.currentMoveable

        let assign = { (iText: String) in
            grab .zoneName = iText
            grab.colorized = true

            grab.widget?.textWidget.updateText()
        }

        if  grab.zoneName?.contains(kHalfLineOfDashes + " ") ?? false {
            assign(kLineOfDashes)
        } else if grab.zoneName?.contains(kLineOfDashes) ?? false {
            assign(kLineWithStubTitle)
            grab.editAndSelect(in: NSMakeRange(12, 1))
        } else {
            addNext(with: kLineOfDashes) { iChild in
                iChild.colorized = true

                iChild.grab()
            }
        }
    }


    func addIdeaFromSelectedText() {
        if  let w = gEditedTextWidget, let t = w.text, let e = w.currentEditor(), let z = w.widgetZone {
            let     range = e.selectedRange
            let childName = t.substring(with: range)
            w.text        = t.stringBySmartReplacing(range, with: "")

            gSelectionManager.clearEdit()
            gSelectionManager.fullResign()
            z.revealChildren()
            z.needChildren()

            gDBOperationsManager.children { iSame in
                self.addIdeaIn(z, at: gInsertionsFollow ? nil : 0, with: childName) { iChild in
                    self.redrawAndSync()
                    iChild?.edit()
                }
            }
        }
    }


    func addBookmark() {
        let zone = gSelectionManager.firstGrab

        if zone.databaseiD != .favoritesID, !zone.isRoot {
            let closure = {
                var bookmark: Zone? = nil

                self.invokeUnderdatabaseiD(.mineID) {
                    bookmark = gFavoritesManager.createBookmark(for: zone, style: .normal)
                }

                bookmark?.grab()
                self.signalFor(nil, regarding: .redraw)
                gDBOperationsManager.sync { iSame in
                }
            }

            if gHere != zone {
                closure()
            } else {
                self.revealParentAndSiblingsOf(zone) { iCloudCalled in
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


    // MARK:- delete
    // MARK:-


    func delete(permanently: Bool = false, preserveChildren: Bool = false) {
        if  preserveChildren {
            preserveChildrenOfGrabbedZones {
                self.updateFavoritesRedrawAndSync()
            }
        } else {
            prepareUndoForDelete()

            deleteZones(gSelectionManager.simplifiedGrabs, permanently: permanently) {
                self.updateFavoritesRedrawAndSync()     // delete alters the list
            }
        }
    }


    func updateFavoritesRedrawAndSync() {
        gFavoritesManager.updateFavorites()
        redrawSyncRedraw()
    }


    private func deleteZones(_ iZones: [Zone], permanently: Bool = false, in iParent: Zone? = nil, iShouldGrab: Bool = true, onCompletion: Closure?) {
        let zones = iZones.sortedByReverseOrdering()
        let  grab = !iShouldGrab ? nil : self.grabAppropriate(zones)
        var  done = false

        for zone in iZones {
            zone.needProgeny()
        }

        gDBOperationsManager.children(.all) { iSame in // to make sure all progeny are acted upon
            if !done {
                done      = true
                var count = zones.count

                if  count == 0 {
                    onCompletion?()
                } else {
                    let maybefinish: Closure = {
                        count -= 1

                        if  count == 0 {
                            if  iShouldGrab {
                                grab?.grab()
                            }

                            gDBOperationsManager.bookmarks { iSame in
                                var bookmarks = [Zone] ()

                                for zone in zones {
                                    bookmarks += zone.fetchedBookmarks
                                }

                                if  bookmarks.count == 0 {
                                    onCompletion?()
                                } else {

                                    ////////////////////////////////////////////
                                    // remove a bookmark whose target is zone //
                                    ////////////////////////////////////////////

                                    self.deleteZones(bookmarks, permanently: permanently, iShouldGrab: false) { iZone in // recurse
                                        onCompletion?()
                                    }
                                }
                            }
                        }
                    }

                    for zone in zones {
                        if  zone == iParent { // detect and avoid infinite recursion
                            maybefinish()
                        } else {
                            self.deleteZone(zone, permanently: permanently) {
                                maybefinish()
                            }
                        }
                    }
                }
            }
        }
    }


    private func deleteZone(_ zone: Zone, permanently: Bool = false, onCompletion: Closure?) {
        if  zone.isRoot {
            onCompletion?()
        } else {
            let parent        = zone.parentZone
            if  zone         == gHere {                         // this can only happen once during recursion (multiple places, below)
                if  let     p = parent, p != zone {
                    gHere     = p

                    revealParentAndSiblingsOf(zone) { iCloudCalled in
                        self.deleteZone(zone, permanently: permanently, onCompletion: onCompletion)   // recurse
                    }
                } else {                                        // delete here but here has no parent ... so, go somewhere useful and familiar:
                    gFavoritesManager.refocus {                 // travel to current favorite
                        self.deleteZone(zone, permanently: permanently, onCompletion: onCompletion)   // then, recurse
                    }
                }
            } else {
                if  zone.isInTrash || permanently {
                    zone.traverseAllProgeny { iZone in
                        iZone.concealChildren()                 // remove from list
                        iZone.needDestroy()
                    }
                } else {
                    zone.addToPaste()
                    moveToTrash(zone)
                }

                zone.orphan()

                if  let            p = parent, p != zone {
                    p.fetchableCount = p.count                  // delete alters the count
                }

                /////////////////////////////////////////////////////////
                // remove all bookmarks for which their target is zone //
                /////////////////////////////////////////////////////////

                zone.maybeNeedBookmarks()
                gDBOperationsManager.bookmarks { iSame in
                    self.deleteZones(zone.fetchedBookmarks, permanently: permanently) {
                        onCompletion?()
                    }
                }
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    func grabAppropriate(_ zones: [Zone]) -> Zone? {
        if  let       grab = gInsertionsFollow ? zones.first : zones.last,
            let     parent = grab.parentZone {
            let   siblings = parent.children
            var      count = siblings.count
            let        max = count - 1

            if siblings.count == zones.count {
                for zone in zones {
                    if siblings.contains(zone) {
                        count -= 1
                    }
                }
            }

            if  var           index  = grab.siblingIndex, max > 0, count > 0 {
                if !grab.isGrabbed {
                    if        index == max &&   gInsertionsFollow {
                        index        = 0
                    } else if index == 0   &&  !gInsertionsFollow {
                        index        = max
                    }
                } else if     index  < max &&  (gInsertionsFollow || index == 0) {
                    index           += 1
                } else if     index  > 0    && (!gInsertionsFollow || index == max) {
                    index           -= 1
                }

                return siblings[index]
            } else {
                return parent
            }
        }

        return nil
    }


    func moveToTrash(_ iZone: Zone, onCompletion: Closure? = nil) {
        if  let trash = iZone.trashZone {
            moveZone(iZone, to: trash, onCompletion: onCompletion)
        }
    }



    // MARK:- move
    // MARK:-


    func moveOut(selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
        let zone: Zone = gSelectionManager.firstGrab
        let parentZone = zone.parentZone

        if zone.isRoot || zone.isTrash || parentZone == gFavoritesManager.rootZone {
            onCompletion?() // avoid disasters
        } else if selectionOnly {

            ////////////////////
            // MOVE SELECTION //
            ////////////////////

            if extreme {
                if  gHere.isRoot {
                    gHere = zone // reverse what the last move out extreme did

                    onCompletion?()
                } else {
                    let here = gHere // revealPathToRoot (below) changes gHere, so nab it first

                    zone.grab()
                    revealZonesToRoot(from: zone) {
                        self.revealSiblingsOf(here, untilReaching: gRoot!)
                    }
                }
            } else if let p = parentZone {
                p.grab()

                if  zone == gHere {
                    revealParentAndSiblingsOf(zone) { iCloudCalled in
                        self.revealSiblingsOf(zone, untilReaching: p)
                    }
                } else {
                    p.revealChildren()
                    p.needChildren()

                    gDBOperationsManager.children(.restore) { iSame in
                        onCompletion?()
                    }
                }
            } else {
                // zone is an orphan
                // change focus to bookmark of zone

                zone.maybeNeedBookmarks()
                gDBOperationsManager.bookmarks { iSame in
                    if  let bookmark = zone.fetchedBookmark {
                        gHere        = bookmark
                    }

                    onCompletion?()
                }
            }
        } else if let p = parentZone, !p.isRoot {

            ///////////////
            // MOVE ZONE //
            ///////////////

            let grandParentZone = p.parentZone

            let moveOutToHere = { (iHere: Zone?) in
                if  let here = iHere {
                    gHere = here
                }

                self.moveOut(to: gHere, onCompletion: onCompletion)
            }

            if extreme {
                if gHere.isRoot {
                    moveOut(to: gHere, onCompletion: onCompletion)
                } else {
                    revealZonesToRoot(from: zone) {
                        moveOutToHere(gRoot)
                    }
                }
            } else if grandParentZone != nil {
                revealParentAndSiblingsOf(p) { iCloudCalled in
                    if  grandParentZone!.spawnedBy(gHere) {
                        self.moveOut(to: grandParentZone!, onCompletion: onCompletion)
                    } else {
                        moveOutToHere(grandParentZone!)
                    }
                }
            } // else no available move
        }
    }


    func moveInto(selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
        let zone: Zone = gSelectionManager.firstGrab

        if !selectionOnly {
            actuallyMoveZone(zone, onCompletion: onCompletion)
        } else if zone.canTravel && zone.fetchableCount == 0 && zone.count == 0 {
            gTravelManager.maybeTravelThrough(zone, onCompletion: onCompletion)
        } else {
            zone.needChildren()
            zone.revealChildren()
            grabChild(of: zone)
            signalFor(nil, regarding: .data)

            gDBOperationsManager.children(.restore) { iSame in
                if  iSame {
                    self.grabChild(of: zone)
                }

                self.updateFavoritesRedrawAndSync()
            }
        }
    }


    func grabChild(of zone: Zone) {
        if  zone.count > 0, let child = gInsertionsFollow ? zone.children.last : zone.children.first {
            child.grab()
        }
    }


    func moveZone(_ zone: Zone, to there: Zone, onCompletion: Closure?) {
        if !there.isBookmark {
            moveZone(zone, into: there, at: gInsertionsFollow ? nil : 0, orphan: true) {
                onCompletion?()
            }
        } else if !there.isABookmark(spawnedBy: zone) {

            //////////////////////////////////
            // MOVE ZONE THROUGH A BOOKMARK //
            //////////////////////////////////

            var         mover = zone
            let    targetLink = there.crossLink
            let     sameGraph = zone.databaseiD == targetLink?.databaseiD
            let grabAndTravel = {
                gTravelManager.travelThrough(there) { object, kind in
                    let there = object as! Zone

                    self.moveZone(mover, into: there, at: gInsertionsFollow ? nil : 0, orphan: false) {
                        mover.recursivelyApplyDatabaseID(targetLink?.databaseiD)
                        mover.grab()
                        onCompletion?()
                    }
                }
            }

            mover.orphan()

            if sameGraph {
                grabAndTravel()
            } else {
                mover.needDestroy()

                mover = mover.deepCopy()

                gDBOperationsManager.sync { iSame in
                    grabAndTravel()
                }
            }
        }
    }


    func actuallyMoveZone(_ zone: Zone, onCompletion: Closure?) {
        if  var           there = zone.parentZone {
            let        siblings = there.children

            if  let       index = zone.siblingIndex {
                let cousinIndex = index == 0 ? 1 : index - 1 // always insert into sibling above, except at top

                if cousinIndex >= 0 && cousinIndex < siblings.count {
                    there       = siblings[cousinIndex]

                    moveZone(zone, to: there, onCompletion: onCompletion)
                }
            }
        }
    }


    func moveZones(_ zones: [Zone], into: Zone, at iIndex: Int?, orphan: Bool, onCompletion: Closure?) {
        into.revealChildren()
        into.needChildren()

        gDBOperationsManager.children(.restore) { iSame in
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
    

    func addIdeaIn(_ iParent: Zone?, at iIndex: Int?, with name: String? = nil, onCompletion: ZoneMaybeClosure?) {
        if  let       parent = iParent, parent.databaseiD != .favoritesID {
            let createAndAdd = {
                let    child = Zone(databaseiD: parent.databaseiD)

                if name != nil {
                    child.zoneName = name
                }

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.deleteZones([child]) {
                        onCompletion?(nil)
                    }
                }

                parent.ungrab()
                parent.addAndReorderChild(child, at: iIndex)
                onCompletion?(child)
            }

            parent.revealChildren()
            gSelectionManager.stopCurrentEdit()

            if parent.count > 0 || parent.fetchableCount == 0 {
                createAndAdd()
            } else {
                parent.needChildren()

                var     isFirstTime = true

                gDBOperationsManager.children(.restore) { iSame in
                    if  isFirstTime {
                        isFirstTime = false

                        createAndAdd()
                    }
                }
            }
        }
    }


    func duplicate() {
        let commonParent = gSelectionManager.firstGrab.parentZone ?? gSelectionManager.firstGrab
        var        zones = gSelectionManager.simplifiedGrabs
        var   duplicates = [Zone] ()
        var      indices = [Int] ()

        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                return
            }
        }

        zones.sort { (a, b) -> Bool in
            return a.order < b.order
        }

        for zone in zones {
            if  let index = zone.siblingIndex {
                duplicates.append(zone.deepCopy())
                indices.append(index)
            }
        }

        while   var index = indices.last, let duplicate = duplicates.last, let zone = zones.last {
            if  let     p = zone.parentZone {
                index    += (gInsertionsFollow ? 1 : 0)

                duplicate.grab()
                p.addAndReorderChild(duplicate, at: index)
            }

            duplicates.removeLast()
            indices   .removeLast()
            zones     .removeLast()
        }

        updateFavoritesRedrawAndSync()
    }


    func reverse() {
        var commonParent = gSelectionManager.firstGrab.parentZone ?? gSelectionManager.firstGrab
        var        zones = gSelectionManager.simplifiedGrabs
        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                return
            }
        }

        if zones.count == 1 {
            commonParent = gSelectionManager.firstGrab
            zones        = commonParent.children
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

                a.maybeNeedSave()
            }

            commonParent.respectOrder()
            redrawSyncRedraw()
        }
    }


    func undoDelete() {
        gSelectionManager.deselectGrabs()

        for (child, (parent, index)) in gSelectionManager.pasteableZones {
            child.orphan()
            parent?.addAndReorderChild(child, at: index)
            child.addToGrab()
        }

        gSelectionManager.clearPaste()

        UNDO(self) { iUndoSelf in
            iUndoSelf.delete()
        }

        redrawSyncRedraw()
    }


    func pasteInto(_ iZone: Zone? = nil, honorFormerParents: Bool = false) {
        let      pastables = gSelectionManager.pasteableZones

        if pastables.count > 0, let zone = iZone {
            let isBookmark = zone.isBookmark
            let action = {
                var forUndo = [Zone] ()

                gSelectionManager.deselectGrabs()

                for (pastable, (parent, index)) in pastables {
                    let pasteMe = pastable.isInTrash ? pastable : pastable.deepCopy() // for zones not in trash, paste a deep copy
                    let      at = index  != nil ? index : gInsertionsFollow ? nil : 0
                    let    into = parent != nil ? honorFormerParents ? parent! : zone : zone

                    pasteMe.orphan()
                    into.revealChildren()
                    into.addAndReorderChild(pasteMe, at: at)
                    pasteMe.recursivelyApplyDatabaseID(into.databaseiD)
                    forUndo.append(pasteMe)
                    pasteMe.addToGrab()
                }

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.prepareUndoForDelete()
                    iUndoSelf.deleteZones(forUndo, iShouldGrab: false) { iZone in }
                    zone.grab()
                    iUndoSelf.redrawSyncRedraw()
                }

                if isBookmark {
                    self.undoManager.endUndoGrouping()
                }

                self.updateFavoritesRedrawAndSync()
            }

            let prepare = {
                var childrenAreMissing = false

                for child in pastables.keys {
                    if !child.isInTrash {
                        child.needProgeny()

                        childrenAreMissing = true
                    }
                }

                if !childrenAreMissing {
                    action()
                } else {
                    var once = true

                    gDBOperationsManager.children(.all) { iSame in
                        if  once {
                            once = false

                            action()
                        }
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


    func preserveChildrenOfGrabbedZones(onCompletion: Closure?) {
        let grabs = gSelectionManager.simplifiedGrabs

        for zone in grabs {
            zone.needChildren()
            zone.revealChildren()
        }

        gDBOperationsManager.children(.all) { iSame in // to make sure all progeny are acted upon
            let    candidate = gSelectionManager.rootMostMoveable
            if  let   parent = candidate.parentZone {
                let    index = candidate.siblingIndex
                var children = [Zone] ()

                gSelectionManager.deselectGrabs()
                gSelectionManager.clearPaste()

                for grab in grabs {
                    for child in grab.children {
                        children.append(child)
                    }

                    grab.addToPaste()
                    self.moveToTrash(grab)
                }

                children.sort { (a, b) -> Bool in
                    return a.order > b.order      // reversed ordering
                }

                for child in children {
                    child.orphan()
                    child.addToGrab()
                    parent.addAndReorderChild(child, at: index)
                }

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.prepareUndoForDelete()
                    iUndoSelf.deleteZones(children, iShouldGrab: false) {}
                    iUndoSelf.pasteInto(parent, honorFormerParents: true)
                }
            }

            onCompletion?()
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

        recursivelyRevealSiblings(zone, untilReaching: to) { iRevealedZone in
            if !completedYet && iRevealedZone == to {
                completedYet     = true
                var insert: Int? = zone.parentZone?.siblingIndex

                if to.databaseiD == .favoritesID {
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


    func moveGrabbedZones(into iInto: Zone, at iIndex: Int?, isCommand: Bool, onCompletion: Closure?) {

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // 1. move a normal zone into another normal zone                                                           //
        // 2. move a normal zone through a bookmark                                                                 //
        // 3. move a normal zone into favorites -- create a favorite pointing at normal zone, then add the favorite //
        // 4. move a favorite into a normal zone -- convert favorite to a bookmark, then move the bookmark          //
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////

        let  toBookmark = iInto.isBookmark                      // type 2
        let toFavorites = iInto.isInFavorites && !toBookmark    // type 3
        var       grabs = gSelectionManager.currentGrabs
        var     restore = [Zone: (Zone, Int?)] ()
        var   cyclicals = IndexSet()

        for (index, zone) in grabs.enumerated() {
            if iInto.spawnedBy(zone) {
                cyclicals.insert(index)
            } else if let parent = zone.parentZone {
                let siblingIndex = zone.siblingIndex
                restore[zone]    = (parent, siblingIndex)

                zone.needProgeny()
            }
        }

        while let index = cyclicals.last {
            cyclicals.remove(index)
            grabs.remove(at: index)
        }

        if  let dragged = gDraggedZone, dragged.isFavorite, !toFavorites {
            dragged.maybeNeedSave()                             // type 4
        }

        grabs.sort { (a, b) -> Bool in
            if  a.isFavorite {
                a.maybeNeedSave()                               // type 4
            }

            return a.order < b.order
        }

        //////////////////////
        // prepare for UNDO //
        //////////////////////

        if toBookmark {
            undoManager.beginUndoGrouping()
        }

        UNDO(self) { iUndoSelf in
            for (child, (parent, index)) in restore {
                child.orphan()
                parent.addAndReorderChild(child, at: index)
            }

            iUndoSelf.UNDO(self) { iUndoUndoSelf in
                iUndoUndoSelf.moveGrabbedZones(into: iInto, at: iIndex, isCommand: isCommand, onCompletion: onCompletion)
            }

            onCompletion?()
        }

        ////////////////
        // move logic //
        ////////////////

        let finish = {
            var    done = false
            let    into = iInto.bookmarkTarget ?? iInto         // grab bookmark AFTER travel
            let toTrash = into.isInTrash || into.isTrash

            if !isCommand {
                into.revealChildren()
            }

            into.maybeNeedChildren()

            gDBOperationsManager.children(.all) { iSame in
                if !done {
                    done = true

                    for grab in grabs {
                        var      movable = grab
                        let    fromTrash = movable.isInTrash
                        let fromFavorite = movable.isInFavorites

                        if  toFavorites, !fromFavorite, !fromTrash {
                            movable = gFavoritesManager.createBookmark(for: grab, style: .favorite)

                            movable.maybeNeedSave()
                        } else {
                            movable.orphan()

                            if into.databaseiD != movable.databaseiD {
                                movable.needDestroy()
                            }

                            if  fromFavorite, !toFavorites, !toTrash, !fromTrash {
                                movable = movable.deepCopy()
                            }
                        }

                        if !isCommand {
                            movable.grab()
                        }

                        into.addAndReorderChild(movable, at: iIndex)
                        movable.recursivelyApplyDatabaseID(into.databaseiD)
                    }

                    if  toBookmark && self.undoManager.groupingLevel > 0 {
                        self.undoManager.endUndoGrouping()
                    }

                    onCompletion?()
                }
            }
        }

        ///////////////////////////////////////
        // deal with target being a bookmark //
        ///////////////////////////////////////

        if !toBookmark || isCommand {
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

        into.revealChildren()
        into.needChildren()

        gDBOperationsManager.children(.restore) { iSame in
            if orphan {
                zone.orphan()
            }

            if !into.isInTrash && !into.isTrash { // so grab won't disappear
                zone.grab()
            }

            into.addAndReorderChild(zone, at: iIndex)
            into.maybeNeedSave()
            zone.maybeNeedSave()
            onCompletion?()
        }
    }
    
    
    func moveUp(_ iMoveUp: Bool = true, selectionOnly: Bool = true, extreme: Bool = false, extend: Bool = false) {
        let            zone = iMoveUp ? gSelectionManager.firstGrab : gSelectionManager.lastGrab
        let          isHere = zone == gHere
        let          parent = zone.parentZone
        if  let     newHere = parent, !isHere,
            let       index = zone.siblingIndex {
            var    newIndex = index + (iMoveUp ? -1 : 1)
            var  allGrabbed = true
            var soloGrabbed = false
            var     hasGrab = false
            let    indexMax = newHere.count

            for child in newHere.children {
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
                if  isHere {
                    gHere = newHere
                }
                
                UNDO(self) { iUndoSelf in
                    iUndoSelf.moveUp(!iMoveUp, selectionOnly: selectionOnly, extreme: extreme, extend: extend)
                }
                
                if !selectionOnly {
                    if  newHere.moveChildIndex(from: index, to: newIndex) { // if move succeeds
                        let grab = newHere.children[newIndex]
                        
                        grab.grab()
                        newHere.children.updateOrder()
                        redrawSyncRedraw(newHere.widget)
                    }
                } else {
                    let  grabThis = newHere.children[newIndex]
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
                                    grabThese.append(newHere.children[i])
                                }
                            } else {
                                for i in newIndex ..< indexMax {
                                    grabThese.append(newHere.children[i])
                                }
                            }
                        }

                        gSelectionManager.addMultipleToGrab(grabThese)
                    }

                    signalFor(nil, regarding: .data)
                }
            }
        } else if !zone.isRoot {

            ///////////////////////////
            // parent is not visible //
            ///////////////////////////

            let snapshot = gSelectionManager.snapshot

            revealParentAndSiblingsOf(zone) { iCalledCloud in
                let same    = (snapshot == gSelectionManager.snapshot)
                let setHere = parent != nil && isHere
                if  setHere {
                    gHere   = parent!

                    self.signalFor(nil, regarding: .redraw)
                }

                if  same && (parent?.count ?? 0) > 1 && (setHere || iCalledCloud) {
                    self.moveUp(iMoveUp, selectionOnly: selectionOnly, extreme: extreme, extend: extend)
                } else if !setHere {
                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }
}
