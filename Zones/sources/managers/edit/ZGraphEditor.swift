 //
//  ZGraphEditor.swift
//  Thoughtful
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


let gGraphEditor = ZGraphEditor()


// mix of zone mutations and web services requestss


class ZGraphEditor: NSObject {


    class ZStalledEvent: NSObject {
        var event: ZEvent?
        var isWindow: Bool = true

        convenience init(_ iEvent: ZEvent, iIsWindow: Bool) {
            self.init()

            isWindow = iIsWindow
            event    = iEvent
        }
    }


    var previousEvent: ZEvent?
    var shortcutsController: NSWindowController?


    var undoManager: UndoManager {
        if  let w = gEditedTextWidget,
            w.undoManager != nil {
            return w.undoManager!
        }

        return kUndoManager
    }

    
    var currentLevel = 0
    

    // MARK:- events
    // MARK:-


    enum ZMenuType: Int {
        case eUndo
        case eHelp
        case eSort
        case eFind
        case eChild
        case eAlter
        case eFiles
        case eCloud
        case eAlways
        case eParent
        case eTravel

        case eRedo
        case ePaste
        case eUseGrabs
        case eMultiple
    }


    @discardableResult func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool { // true means handled
        if  var     key = iKey {
            let CONTROL = flags.isControl
            let COMMAND = flags.isCommand
            let  OPTION = flags.isOption
            var   SHIFT = flags.isShift
            let   arrow = key.arrow
            
            if  key    != key.lowercased() {
                key     = key.lowercased()
                SHIFT   = true
            }

            if  gIsEditingText {
                let editedZone = gEditedTextWidget?.widgetZone
                if  let      a = arrow {
                    gTextEditor.handleArrow(a, flags: flags)
                } else if COMMAND || CONTROL || OPTION {
                    switch key {
                    case "a":      gEditedTextWidget?.selectAllText()
                    case "d":      if SHIFT { addParentFromSelectedText(inside: editedZone) } else { addIdeaFromSelectedText(inside: editedZone) }
                    case "f":      search()
                    case "i":      toggleColorized()
                    case "?":      showHideKeyboardShortcuts()
                    case "-":      return convertToLine(editedZone)
                    case "/":      gFocusing.focus(kind: .eEdited, false) { self.redrawSyncRedraw() }
                    case ",", ".": commaAndPeriod(COMMAND, OPTION, with: key == ".")
                    case kSpace:   addIdea()
                    default:       return false
                    }
                } else {
                    switch key {
                    case "-":      return convertToLine(editedZone)
                    case kEscape:  gTextEditor.cancel()
                    default:       return false
                    }
                }
            } else if  validateKey(key, flags) {
                let    widget = gWidgets.currentMovableWidget
                let hasWidget = widget != nil
                let   FLAGGED = CONTROL || COMMAND || OPTION
                
                widget?.widgetZone?.deferWrite()
                
                if  let a = arrow, isWindow {
                    handleArrow(a, flags: flags)
                } else if kMarkingCharacters.contains(key), !COMMAND {
                    prefix(with: key)
                } else {
                    switch key {
                    case "a":      selectAll(progeny: OPTION)
                    case "b":      addBookmark()
                    case "c":      recenter()
                    case "d":      if FLAGGED { combineIntoParent(widget?.widgetZone) } else { duplicate() }
                    case "e":      editTrait(for: .eEmail)
                    case "f":      search()
                    case "h":      editTrait(for: .eHyperlink)
                    case "i":      toggleColorized()
                    case "l", "u": alterCase(up: key == "u")
                    case "j":      gFiles.importFromFile(asOutline: OPTION, insertInto: gSelecting.currentMoveable) { self.redrawSyncRedraw() }
                    case "k":      gFiles  .exportToFile(asOutline: OPTION,        for: gSelecting.currentMoveable)
                    case "m":      refetch()
                    case "n":      alphabetize(OPTION)
                    case "o":      if COMMAND { if OPTION { gFiles.showInFinder() } else { gFiles.open() } } else { orderByLength(OPTION) }
                    case "p":      printHere()
                    case "q":      ZApplication.shared.terminate(self)
                    case "r":      reverse()
                    case "s":      if COMMAND { gFiles.saveAs() } else { selectCurrentFavorite() }
                    case "t":      swapWithParent()
                    case "w":      rotateWritable()
                    case "1":      if COMMAND && SHIFT { sendEmailBugReport() }
                    case "+":      divideChildren()
                    case "-":      addLine()
                    case "`":      travelToOtherGraph()
                    case "[":      gFocusing.goBack(   extreme: FLAGGED)
                    case "]":      gFocusing.goForward(extreme: FLAGGED)
                    case ";":      doFavorites(true,    false)
                    case "?":      CONTROL ? openBrowserForFocusWebsite() : showHideKeyboardShortcuts()
                    case "'":      doFavorites(SHIFT, OPTION)
                    case "/":      SHIFT && OPTION ? showHideKeyboardShortcuts() : gFocusing.focus(kind: .eSelected, COMMAND) { self.redrawSyncRedraw() }
                    case "=":      gFocusing.maybeTravelThrough(gSelecting.firstGrab) { self.redrawSyncRedraw() }
                    case kTab:     addNext(containing: OPTION) { iChild in iChild.edit() }
                    case ",", ".": commaAndPeriod(COMMAND, OPTION, with: key == ".")
                    case "z":      if COMMAND { if SHIFT { kUndoManager.redo() } else { kUndoManager.undo() } }
                    case kSpace:   if OPTION || isWindow || CONTROL { addIdea() }
                    case kBackspace,
                         kDelete:  if OPTION || isWindow || COMMAND { delete(permanently: COMMAND && OPTION && isWindow, preserveChildren: FLAGGED && isWindow) }
                    case "\r":     if hasWidget { grabOrEdit(COMMAND) }
                    default:       return false
                    }
                }
            }
        }
        
        return true
    }
    

    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        if  gIsEditingText {
            gTextEditor.handleArrow(arrow, flags: flags)
            
            return
        }
        
        let COMMAND = flags.isCommand
        let  OPTION = flags.isOption
        let   SHIFT = flags.isShift

        if OPTION && !gSelecting.currentMoveable.userCanMove {
            return
        }

        switch arrow {
        case .down:     moveUp(false, selectionOnly: !OPTION, extreme: COMMAND, extend: SHIFT)
        case .up:       moveUp(true,  selectionOnly: !OPTION, extreme: COMMAND, extend: SHIFT)
        default:
            if !SHIFT {
                switch arrow {
                case .right: moveInto(selectionOnly: !OPTION, extreme: COMMAND) { self.updateFavoritesRedrawSyncRedraw() } // relayout graph when travelling through a bookmark
                case .left:  moveOut( selectionOnly: !OPTION, extreme: COMMAND) { self.updateFavoritesRedrawSyncRedraw() }
                default: break
                }
            } else if !OPTION {

                //////////////////
                // GENERATIONAL //
                //////////////////

                var show = true

                switch arrow {
                case .right: break
                case .left:  show = false
                default:     return
                }

                applyGenerationally(show, extreme: COMMAND)
            }
        }
    }


    @discardableResult func handleEvent(_ iEvent: ZEvent, isWindow: Bool) -> ZEvent? {
        if  gWorkMode    == .graphMode,
            iEvent       != previousEvent {
            let     flags = iEvent.modifierFlags
            previousEvent = iEvent
            
            if  handleKey(iEvent.key, flags: flags, isWindow: isWindow) {
                return nil
            }
        }

        return iEvent
    }


    func handleMenuItem(_ iItem: ZMenuItem?) {
        #if os(OSX)
            if !isDuplicate(item: iItem),
                gWorkMode == .graphMode,
                let   item = iItem {
                let  flags = item.keyEquivalentModifierMask
                let    key = item.keyEquivalent

                handleKey(key, flags: flags, isWindow: true)
            }
        #endif
    }


    func menuType(for key: String, _ flags: NSEvent.ModifierFlags) -> ZMenuType {
        let alterers = "ehiluw\r" + kMarkingCharacters
        let  COMMAND = flags.isCommand

        if  alterers.contains(key) {             return .eAlter
        } else {
            switch key {
            case "=":                            return .eTravel
            case "?":                            return .eHelp
            case "f":                            return .eFind
            case "m":                            return .eCloud
            case "t":                            return .eAlter
            case "z":                            return .eUndo
            case "o", "r":                       return  COMMAND ? .eFiles : .eSort
            case "v", "x", kSpace:               return .eChild
            case "b", kTab, kDelete, kBackspace: return .eParent
            case "j", "k":                       return .eFiles
            case "d":                            return  COMMAND ? .eAlter : .eParent
            default: break
            }

            return .eAlways
        }
    }


    func validateKey(_ key: String, _ flags: NSEvent.ModifierFlags) -> Bool {
        if gWorkMode != .graphMode {
            return false
        }

        let type = menuType(for: key, flags)
        let arrow = key.arrow
        var valid = !gIsEditingText

        if  valid {
            let   undo = undoManager
            let      s = gSelecting
            let  mover = s.currentMoveable
            let wGrabs = s.writableGrabsCount
            let  paste = s.pasteableZones.count
            let  grabs = s.currentGrabs  .count
            let  shown = s.currentGrabsHaveVisibleChildren
            let  write = mover.userCanWrite
            let   sort = mover.userCanMutateProgeny
            let parent = mover.userCanMove

            switch type {
            case .eParent:    valid =               parent
            case .eChild:     valid =               sort
            case .eAlter:     valid =               write
            case .ePaste:     valid =  paste > 0 && write
            case .eUseGrabs:  valid = wGrabs > 0 && write
            case .eMultiple:  valid =  grabs > 1
            case .eSort:      valid = (shown     && sort) || (grabs > 1 && parent)
            case .eUndo:      valid = undo.canUndo
            case .eRedo:      valid = undo.canRedo
            case .eTravel:    valid = mover.canTravel
            case .eCloud:     valid = gHasInternet && gCloudAccountIsActive
            case .eFiles:     valid = flags.contains(.command)
            default:          break
            }
        } else if arrow == nil {
            valid = type != .eTravel
        } else {
            valid = true
        }

        return valid
    }


    // MARK:- miscellaneous features
    // MARK:-

    
    func combineIntoParent(_ iChild: Zone?) {
        if  let       child = iChild,
            let      parent = child.parentZone,
            let    original = parent.zoneName {
            let   childName = child.zoneName ?? ""
            let childLength = childName.length
            let    combined = original.stringBySmartly(appending: childName)
            let       range = NSMakeRange(combined.length - childLength, childLength)
            parent.zoneName = combined
            moveZone(child, to: gTrash)
            redrawSyncRedraw(child)
            parent.editAndSelect(in: range)
        }
    }

 
    
    func swapWithParent() {
        let child = gSelecting.firstGrab

        if  gSelecting.currentGrabs.count == 1,
            let  cIndex = child.siblingIndex,
            let  parent = child.parentZone,
            let  pIndex = parent.siblingIndex,
            let gParent = parent.parentZone {
            moveZone(child, into: gParent, at: pIndex, orphan: true) {
                self.moveZones(parent.children, into: child, at: nil, orphan: true) {
                    self.moveZone(parent, into: child, at: cIndex, orphan: true) {
                        parent.needCount()

                        self.redrawSyncRedraw(child)
                    }
                }
            }
        }
    }
    
    
    func commaAndPeriod(_ COMMAND: Bool, _ OPTION: Bool, with PERIOD: Bool) {
        if     !COMMAND {
            if  OPTION {
                gBrowsingMode  = PERIOD ? .extend : .confine
            } else {
                gInsertionMode = PERIOD ? .follow : .precede
            }
            
            gControllers.signalFor(nil, regarding: .ePreferences)
        } else if !PERIOD {
            gDetailsController?.toggleViewsFor(ids: [.Preferences])
        } else if gIsEditingText {
            gTextEditor.cancel()
        }
    }

    
    func showHideKeyboardShortcuts() {
        if  shortcutsController == nil {
            let      storyboard  = NSStoryboard(name: "Shortcuts", bundle: nil)
            shortcutsController  = storyboard.instantiateInitialController() as? NSWindowController
        }

        if  shortcutsController?.window?.isVisible ?? false {
            shortcutsController?.window?.orderOut(self)
        } else {
            shortcutsController?.showWindow(nil)
        }
    }


    func travelToOtherGraph() {
        let here = gHere

        toggleDatabaseID()

        if    !here.isRootOfFavorites {
            if here.isRootOfLostAndFound {
                gHere = gLostAndFound!
            } else if here.isTrash {
                gHere = gTrash!
            } else if here.isRoot {
                gHere = gRoot!
            }
        }

        gHere.grab()
        gHere.revealChildren()
        gFavorites.updateFavorites()
        gControllers.signalFor(nil, regarding: .eRelayout)
    }


    func toggleColorized() {
        for zone in gSelecting.currentGrabs {
            zone.toggleColorized()
        }

        redrawAndSync()
    }


    func prefix(with iMark: String) {
        let before = "("
        let  after = ") "
        let  zones = gSelecting.currentGrabs
        var  digit = 0
        let  count = iMark == "#"

        for zone in zones {
            if  var name                  = zone.zoneName {
                var prefix                = before + iMark + after
                var add                   = true
                digit                    += 1
                if  name.starts(with: prefix) {
                    let         nameParts = name.components(separatedBy: prefix)
                    name                  = nameParts[1]                // remove prefix
                } else {
                    if  name.starts(with: before) {
                        var     nameParts = name.components(separatedBy: after)
                        var         index = 0

                        while nameParts.count > index + 1 {
                            let      mark = nameParts[index]            // found: "(x"
                            let markParts = mark.components(separatedBy: before) // markParts[1] == x

                            if  markParts.count > 1 && markParts[0].count == 0 && markParts[1].count <= 2 {
                                index    += 1

                                if  markParts[1].isDigit {
                                    add   = false
                                    break
                                }
                            }
                        }

                        name              = nameParts[index]            // remove all (x) where x is any character
                    }

                    if  add {
                        if  count {
                            prefix        = before + "\(digit)" + after  // increment prefix
                        }

                        name              = prefix + name               // replace or prepend with prefix
                    }
                }

                zone.zoneName             = name

                gTextEditor.updateText(inZone: zone)
            }
        }

        redrawAndSync()
    }


    func editTrait(for iType: ZTraitType) {
        let  zone = gSelecting.firstGrab
        let trait = zone.trait(for: iType)

        gTextEditor.edit(trait)
    }


    func divideChildren() {
        let grabs = gSelecting.currentGrabs

        for zone in grabs {
            zone.needChildren()
        }

        gBatches.children { iSame in
            for zone in grabs {
                zone.divideEvenly()
            }

            self.redrawSyncRedraw()
        }
    }


    func rotateWritable() {
        for zone in gSelecting.currentGrabs {
            zone.rotateWritable()
        }

        redrawSyncRedraw()
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
        var commonParent = gSelecting.firstGrab.parentZone ?? gSelecting.firstGrab
        var        zones = gSelecting.simplifiedGrabs

        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                // status bar -> not all of the grabbed zones share the same parent
                return
            }
        }

        if  zones.count == 1 {
            commonParent = gSelecting.firstGrab
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

        gSelecting.hasNewGrab = gSelecting.currentMoveable
    }


    func recenter() {
        gScaling      = 1.0
        gScrollOffset = CGPoint.zero

        gEditorController?.layoutForCurrentScrollOffset()
    }


    func alterCase(up: Bool) {
        for grab in gSelecting.currentGrabs {
            if let text = grab.widget?.textWidget {
                text.alterCase(up: up)
            }
        }
    }


    func search() {
        if  gDatabaseID != .favoritesID {
            gWorkMode = gWorkMode == .searchMode ? .graphMode : .searchMode

            gControllers.signalFor(nil, regarding: .eSearch)
        }
    }


    func printHere() {
        #if os(OSX)

            if  let         view = gHere.widget {
                let    printInfo = NSPrintInfo.shared
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
        var zone = gSelecting.currentMoveable

        if progeny {
            gSelecting.clearGrab()

            zone.traverseAllProgeny { iChild in
                iChild.addToGrab()
            }
        } else {
            if  zone.count == 0 {
                if  let parent = zone.parentZone {
                    zone       = parent
                } else {
                    return // selection has not changed
                }
            }

            if  zone.showingChildren {
                gSelecting.clearGrab()

                for child in zone.children {
                    child.addToGrab()
                }
            } else {
                return // selection does not show its children
            }
        }

        gControllers.signalFor(nil, regarding: .eRelayout)
    }


    func grabOrEdit(_ isCommand: Bool) {
        if  !gSelecting.hasGrab {
            gHere.grab()
        } else if isCommand {
            gSelecting.deselect()
        } else {
            gTextEditor.edit(gSelecting.currentMoveable)
        }
    }


    func refetch() {
        gBatches.refetch { iSame in
            gControllers.signalFor(nil, regarding: .eRelayout)
        }
    }


    // MARK:- focus and travel
    // MARK:-


    func selectCurrentFavorite() {
        if  let current = gFavorites.currentFavorite {
            current.needRoot()
            gBatches.families { iSame in
                if  let parent = current.parentZone {
                    parent.traverseAllAncestors { iAncestor in
                        iAncestor.revealChildren()
                    }

                    gControllers.signalFor(nil, regarding: .eRelayout)
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

        gFavorites.switchToNext(!backward) {
            self.redrawSyncRedraw()
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
                if  let parentZone = iZone.parentZone, !parentZone.isFetched {
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
                gBatches.root { iSame in
                    onCompletion?()
                }
            }
        }
    }


    func revealParentAndSiblingsOf(_ iZone: Zone, onCompletion: BooleanClosure?) {
        if  let parent = iZone.parentZone {
            parent.revealChildren()
            parent.needChildren()
        } else {
            iZone.needParent()
        }

        gBatches.families { iSame in
            onCompletion?(true)
        }
    }


    func recursivelyRevealSiblings(_ descendent: Zone, untilReaching iAncestor: Zone, onCompletion: ZoneClosure?) {
        if  descendent == iAncestor {
            onCompletion?(iAncestor)
            
            return
        }

        var needRoot = true

        descendent.traverseAllAncestors { iParent in
            if  iParent != descendent {
                iParent.revealChildren()
                iParent.needChildren() // need this to show "minimal flesh" on graph
            }

            if  iParent == iAncestor {
                needRoot = false
            }
        }

        if  needRoot { // true means ideas graph in memory does not include root, so fetch it from iCloud
            descendent.needRoot()
        }

        gBatches.families { iSame in
            FOREGROUND {
                descendent.traverseAncestors { iParent -> ZTraverseStatus in
                    let  gotThere = iParent == iAncestor || iParent.isRoot    // reached the ancestor or the root
                    let gotOrphan = iParent.parentZone == nil

                    if  gotThere || gotOrphan {
                        if !gotThere && !iParent.isFetched && iParent.parentZone != nil { // reached an orphan that has not yet been fetched
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
            if     iZone != descendent {
                if iZone == iAncestor {
                    gHere = iAncestor
                    
                    gHere.grab()
                }
                
                gFavorites.updateCurrentFavorite()
                self.redrawSyncRedraw()
            }
        }
    }


    // MARK:- reveal dot
    // MARK:-


    func applyGenerationally(_ show: Bool, extreme: Bool = false) {
        let        zone = gSelecting.rootMostMoveable
        var level: Int?

        if !show {
            level = extreme ? zone.level - 1 : zone.highestExposed - 1
        } else if  extreme {
            level = Int.max
        } else if let lowest = zone.lowestExposed {
            level = lowest + 1
        }

        generationalUpdate(show: show, zone: zone, to: level) {
            self.redrawSyncRedraw()
        }
    }


    func generationalUpdate(show: Bool, zone: Zone, to iLevel: Int? = nil, onCompletion: Closure?) {
        recursiveUpdate(show, zone, to: iLevel) {

            ///////////////////////////////////////////////////////////
            // delay executing this until the last time it is called //
            ///////////////////////////////////////////////////////////

            onCompletion?()
        }
    }


    func recursiveUpdate(_ show: Bool, _ zone: Zone, to iLevel: Int?, onCompletion: Closure?) {
        if !show && zone.isGrabbed && (zone.count == 0 || !zone.showingChildren) {

            //////////////////////////////////
            // COLLAPSE OUTWARD INTO PARENT //
            //////////////////////////////////

            zone.concealAllProgeny()

            revealParentAndSiblingsOf(zone) { iCloudCalled in
                if let  parent = zone.parentZone, parent != zone {
                    if  gHere == zone {
                        gHere  = parent
                    }
                    
                    self.recursiveUpdate(show, parent, to: iLevel) {
                        parent.grab()
                        onCompletion?()
                    }
                } else {
                    onCompletion?()
                }
            }
        } else {

            ////////////////////
            // ALTER CHILDREN //
            ////////////////////

            let level = iLevel ?? zone.level + (show ? 1 : -1)
            let apply = {
                zone.traverseAllProgeny { iChild in
                    if           !iChild.isBookmark {
                        if        iChild.level >= level && !show {
                                  iChild.concealChildren()
                        } else if iChild.level  < level && show {
                                  iChild.revealChildren()
                        }
                    }
                }

                if zone.isInFavorites && show {
                    gFavorites.updateFavorites()
                }

                onCompletion?()
            }

            if !show {
                gSelecting.deselectDragWithin(zone);
            }

            apply()
        }
    }


    func clickActionOnRevealDot(for iZone: Zone?, isCommand: Bool) {
        if  let zone = iZone {
            gTextEditor.stopCurrentEdit()

            for     grabbed in gSelecting.currentGrabs {
                if  grabbed != zone && grabbed.spawnedBy(zone) {
                    grabbed.ungrab()
                }
            }

            if  zone.canTravel && (isCommand || (zone.fetchableCount == 0 && zone.count == 0)) {
                gFocusing.maybeTravelThrough(zone) { // email, hyperlink, bookmark
                    self.redrawSyncRedraw()
                }
            } else {
                let show = !zone.showingChildren

                if !zone.isRootOfFavorites {
                    self.generationalUpdate(show: show, zone: zone) {
                        self.redrawSyncRedraw()
                    }
                } else {

                    //////////////////////////////////////////////////////////////////
                    // avoid annoying user by treating favorites non-generationally //
                    //////////////////////////////////////////////////////////////////

                    zone.toggleChildrenVisibility()

                    self.redrawSyncRedraw()
                }
            }
        }
    }


    // MARK:- add
    // MARK:-


    func addIdea() {
        let parent = gSelecting.currentMoveable
        if !parent.isBookmark,
            parent.userCanMutateProgeny {
            addIdeaIn(parent, at: gInsertionsFollow ? nil : 0) { iChild in
                gControllers.signalFor(parent, regarding: .eRelayout) {
                    iChild?.edit()
                }
            }
        }
    }


    func addNext(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
        let       zone = gSelecting.rootMostMoveable

        if  var parent = zone.parentZone, parent.userCanMutateProgeny {
            var  zones = gSelecting.currentGrabs

            if containing {
                if  zones.count < 2 {
                    zones  = zone.children
                    parent = zone
                }

                zones.sort { (a, b) -> Bool in
                    return a.order < b.order
                }
            }

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
                        gControllers.signalFor(nil, regarding: .eRelayout) {
                            onCompletion?(child)
                        }
                    } else {
                        self.moveZones(zones, into: child, at: nil, orphan: true) {
                            self.redrawAndSync() {
                                onCompletion?(child)
                            }
                        }
                    }
                }
            }
        }
    }


    func addLine() {
        let zone = gSelecting.currentMoveable
        
        if  let name = zone.zoneName {
            if  name.isLineTitle {
                zone.assignAndColorize(kLineOfDashes)
                
                return
            } else if name.contains(kLineOfDashes) {
                zone.assignAndColorize(kLineWithStubTitle)
                zone.editAndSelect(in: NSMakeRange(12, 1))
                
                return
            }
        }
        
        addNext(with: kLineOfDashes) { iChild in
            iChild.colorized = true
            
            iChild.grab()
        }
    }
    
    
    func convertToLine(_ iZone: Zone?) -> Bool {
        if  let      zone = iZone,
            let childName = extractSelectedText(from: zone.widget?.textWidget, requiresAllOrTitleSelected: true) {
            
            if  zone.zoneName != childName {
                zone.zoneName  = childName
                zone.colorized = false

                zone.editAndSelect(in: NSMakeRange(0,  childName.length))
            } else {
                zone.zoneName  = kHalfLineOfDashes + " " + childName + " " + kHalfLineOfDashes
                zone.colorized = true

                zone.editAndSelect(in: NSMakeRange(12, childName.length))
            }
            
            return true
        }
        
        return false
    }

    
    func addParentFromSelectedText(inside iZone: Zone?) {
        if  let     child = iZone,
            let     index = child.siblingIndex,
            let    parent = child.parentZone,
            let childName = extractSelectedText(from: child.widget?.textWidget) {

            self.addIdeaIn(parent, at: index, with: childName) { iChild in
                self.moveZone(child, to: iChild) {
                    self.redrawAndSync()
                    iChild?.edit()
                }
            }
        }
    }
    

    func addIdeaFromSelectedText(inside iZone: Zone?) {
        if  let      zone  = iZone,
            let childName  = extractSelectedText(from: zone.widget?.textWidget) {

            if  childName == zone.zoneName {
                combineIntoParent(zone)
            } else {
                zone.revealChildren()
                zone.needChildren()
                
                gBatches.children { iSame in
                    self.addIdeaIn(zone, at: gInsertionsFollow ? nil : 0, with: childName) { iChild in
                        self.redrawAndSync()
                        iChild?.edit()
                    }
                }
            }
        }
    }

    
    func extractSelectedText(from iTextWidget: ZoneTextWidget?, requiresAllOrTitleSelected: Bool = false) -> String? {
        var extract: String?
        
        if  let   widget = iTextWidget,
            let original = widget.text,
            let   editor = widget.currentEditor() {
            let    range = editor.selectedRange
            extract      = original.substring(with: range)

            if  range.length < original.length {
                if  !requiresAllOrTitleSelected {
                    widget.text = original.stringBySmartReplacing(range, with: "")
                    
                    gSelecting.deselectGrabs()
                } else if !original.isLineTitle(within: range) {
                    return nil
                }
            }

            gTextEditor.stopCurrentEdit()
        }
        
        return extract
    }


    func addBookmark() {
        let zone = gSelecting.firstGrab

        if zone.databaseID != .favoritesID, !zone.isRoot {
            let closure = {
                var bookmark: Zone?

                self.invokeUsingDatabaseID(.mineID) {
                    bookmark = gFavorites.createBookmark(for: zone, style: .normal)
                }

                bookmark?.grab()
                bookmark?.markNotFetched()
                gControllers.signalFor(nil, regarding: .eRelayout)
                gBatches.sync { iSame in
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
    

    func paste() { pasteInto(gSelecting.firstGrab) }


    func copyToPaste() {
        let grabs = gSelecting.simplifiedGrabs

        gSelecting.clearPaste()

        for grab in grabs {
            grab.addToPaste()
        }
    }


    // MARK:- delete
    // MARK:-


    func delete(permanently: Bool = false, preserveChildren: Bool = false) {
        if  preserveChildren && !permanently {
            preserveChildrenOfGrabbedZones {
                self.updateFavoritesRedrawSyncRedraw()
            }
        } else {
            prepareUndoForDelete()

            deleteZones(gSelecting.simplifiedGrabs, permanently: permanently) {
                self.updateFavoritesRedrawSyncRedraw()     // delete alters the list
            }
        }
    }


    func updateFavoritesRedrawSyncRedraw(avoidRedraw: Bool = false) {
        if  gFavorites.updateFavorites() || !avoidRedraw {
            redrawSyncRedraw()
        }
    }


    private func deleteZones(_ iZones: [Zone], permanently: Bool = false, in iParent: Zone? = nil, iShouldGrab: Bool = true, onCompletion: Closure?) {
        let    zones = iZones.sortedByReverseOrdering()
        let     grab = !iShouldGrab ? nil : self.grabAppropriate(zones)
        var doneOnce = false

        for zone in iZones {
            zone.needProgeny()
        }

        gBatches.children(.all) { iSame in // to make sure all progeny are acted upon
            if !doneOnce {
                doneOnce  = true
                var count = zones.count

                if  count == 0 {
                    grab?.grab()
                    onCompletion?()
                    
                    return
                }
                
                let maybefinish: Closure = {
                    count -= 1
                    
                    if  count == 0 {
                        gBatches.bookmarks { iSame in
                            var bookmarks = [Zone] ()
                            
                            for zone in zones {
                                bookmarks += zone.fetchedBookmarks
                            }
                            
                            if  bookmarks.count == 0 {
                                grab?.grab()
                                onCompletion?()
                            } else {
                                
                                ////////////////////////////////////////////
                                // remove a bookmark whose target is zone //
                                ////////////////////////////////////////////
                                
                                self.deleteZones(bookmarks, permanently: permanently, iShouldGrab: false) { // recurse
                                    grab?.grab()
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


    private func deleteZone(_ zone: Zone, permanently: Bool = false, onCompletion: Closure?) {
        if  zone.isRoot {
            onCompletion?()
        } else {
            let parent        = zone.parentZone
            if  zone         == gHere {                         // this can only happen ONCE during recursion (multiple places, below)
                if  let     p = parent, p != zone {
                    gHere     = p

                    revealParentAndSiblingsOf(zone) { iCloudCalled in

                        /////////////
                        // RECURSE //
                        /////////////

                        self.deleteZone(zone, permanently: permanently, onCompletion: onCompletion)
                    }
                } else {

                    ///////////////////////////////////////////////////////////////////////////////////////////////
                    // SPECIAL CASE: delete here but here has no parent ... so, go somewhere useful and familiar //
                    ///////////////////////////////////////////////////////////////////////////////////////////////

                    gFavorites.refocus {                 // travel through current favorite, then ...

                        /////////////
                        // RECURSE //
                        /////////////

                        if  gHere != zone {
                            self.deleteZone(zone, permanently: permanently, onCompletion: onCompletion)
                        }
                    }
                }
            } else {
                let destructionIsAllowed = gCloudAccountIsActive || zone.databaseID != .mineID // allowed
                let    eventuallyDestroy = permanently           || zone.isInTrash
                let           destroyNow = destructionIsAllowed && eventuallyDestroy && gHasInternet

                zone.addToPaste()


                if !destroyNow && !eventuallyDestroy {
                    moveZone(zone, to: zone.trashZone)
                } else {
                    zone.traverseAllProgeny { iZone in
                        iZone.needDestroy()                     // gets written in file
                        iZone.concealAllProgeny()               // prevent gExpandedZones list from getting clogged with stale references
                        iZone.orphan()
                    }

                    if !destroyNow {
                        moveZone(zone, to: zone.destroyZone)
                    }
                }

                if  let            p = parent, p != zone {
                    p.fetchableCount = p.count                  // delete alters the count
                }

                /////////////
                // RECURSE //
                /////////////

                self.deleteZones(zone.fetchedBookmarks, permanently: permanently) {
                    onCompletion?()
                }
            }
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



    // MARK:- move
    // MARK:-


    func moveOut(selectionOnly: Bool = true, extreme: Bool = false, force: Bool = false, onCompletion: Closure?) {
        let zone: Zone = gSelecting.firstGrab
        let parentZone = zone.parentZone

        if zone.isRoot || zone.isTrash || parentZone == gFavoritesRoot {
            onCompletion?() // avoid the ridiculous
        } else if selectionOnly {

            ////////////////////
            // MOVE SELECTION //
            ////////////////////

            if extreme {
                if  gHere.isRoot {
                    gHere = zone // reverse what the last move out extreme did

                    onCompletion?()
                } else {
                    let here = gHere // revealZonesToRoot (below) changes gHere, so nab it first

                    zone.grab()
                    revealZonesToRoot(from: zone) {
                        self.revealSiblingsOf(here, untilReaching: gRoot!)
                        onCompletion?()
                    }
                }
            } else if let p = parentZone {
                if  zone == gHere {
                    revealParentAndSiblingsOf(zone) { iCloudCalled in
                        self.revealSiblingsOf(zone, untilReaching: p)
                        onCompletion?()
                    }
                } else {
                    p.revealChildren()
                    p.needChildren()
                    p.grab()
                    
                    gBatches.children(.restore) { iSame in
                        onCompletion?()
                    }
                }
            } else {
                // zone is an orphan
                // change focus to bookmark of zone

                if  let bookmark = zone.fetchedBookmark {
                    gHere        = bookmark
                }

                onCompletion?()
            }
        } else if let p = parentZone, !p.isRoot {

            ///////////////
            // MOVE ZONE //
            ///////////////

            let grandParentZone = p.parentZone

            if zone == gHere && !force {
                let grandParentName = grandParentZone?.zoneName
                let   parenthetical = grandParentName == nil ? "" : " (\(grandParentName!))"

                ////////////////////////////////////////////////////////////////////////
                // present an alert asking if user really wants to move here leftward //
                ////////////////////////////////////////////////////////////////////////

                gAlerts.showAlert("WARNING", "This will relocate \"\(zone.zoneName ?? "")\" to its parent's parent\(parenthetical)", "Relocate", "Cancel") { iStatus in
                    if iStatus == .eStatusYes {
                        self.moveOut(selectionOnly: selectionOnly, extreme: extreme, force: true, onCompletion: onCompletion)
                    }
                }
            } else {

                let moveOutToHere = { (iHere: Zone?) in
                    if  let here = iHere {
                        gHere = here
                    }

                    self.moveOut(to: gHere, onCompletion: onCompletion)
                }

                if extreme {
                    if  gHere.isRoot {
                        moveOut(to: gHere, onCompletion: onCompletion)
                    } else {
                        revealZonesToRoot(from: zone) {
                            moveOutToHere(gRoot)
                            onCompletion?()
                        }
                    }
                } else if   grandParentZone != nil {
                    revealParentAndSiblingsOf(p) { iCloudCalled in
                        if  grandParentZone!.spawnedBy(gHere) {
                            self.moveOut(to: grandParentZone!, onCompletion: onCompletion)
                        } else {
                            moveOutToHere(grandParentZone!)
                            onCompletion?()
                        }
                    }
                } else { // no available move
                    onCompletion?()
                }
            }
        }
    }


    func moveInto(selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
        let zone: Zone = gSelecting.firstGrab

        if !selectionOnly {
            actuallyMove(zone, onCompletion: onCompletion)
        } else if zone.canTravel && zone.fetchableCount == 0 && zone.count == 0 {
            gFocusing.maybeTravelThrough(zone, onCompletion: onCompletion)
        } else {
            zone.needChildren()
            zone.revealChildren()
            gControllers.signalFor(nil, regarding: .eData)

            gBatches.children(.restore) { iSame in
                if  zone.count > 0,
                    let child = gInsertionsFollow ? zone.children.last : zone.children.first {
                    child.grab()
                }

                self.updateFavoritesRedrawSyncRedraw()

                onCompletion?()
            }
        }
    }


    func actuallyMove(_ zone: Zone, onCompletion: Closure?) {
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


    func moveZone(_ zone: Zone, to iThere: Zone?, onCompletion: Closure? = nil) {
        if  let there = iThere {
            if !there.isBookmark {
                moveZone(zone, into: there, at: gInsertionsFollow ? nil : 0, orphan: true) {
                    onCompletion?()
                }
            } else if !there.isABookmark(spawnedBy: zone) {

                //////////////////////////////////
                // MOVE ZONE THROUGH A BOOKMARK //
                //////////////////////////////////

                var     movedZone = zone
                let    targetLink = there.crossLink
                let     sameGraph = zone.databaseID == targetLink?.databaseID
                let grabAndTravel = {
                    gFocusing.travelThrough(there) { object, kind in
                        let there = object as! Zone

                        self.moveZone(movedZone, into: there, at: gInsertionsFollow ? nil : 0, orphan: false) {
                            movedZone.recursivelyApplyDatabaseID(targetLink?.databaseID)
                            movedZone.grab()
                            onCompletion?()
                        }
                    }
                }

                movedZone.orphan()

                if sameGraph {
                    grabAndTravel()
                } else {
                    movedZone.needDestroy()

                    movedZone = movedZone.deepCopy

                    gBatches.sync { iSame in
                        grabAndTravel()
                    }
                }
            }
        } else {
            onCompletion?()
        }
    }


    func moveZones(_ zones: [Zone], into: Zone, at iIndex: Int?, orphan: Bool, onCompletion: Closure?) {
        into.revealChildren()
        into.needChildren()

        gBatches.children(.restore) { iSame in
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
        if  let       parent = iParent,
            let         dbID = parent.databaseID,
            dbID            != .favoritesID {
            let createAndAdd = {
                let    child = Zone(databaseID: dbID)

                if  name != nil {
                    child.zoneName   = name
                }

                if !gIsMasterAuthor,
                    dbID            == .everyoneID,
                    let     identity = gAuthorID {
                    child.zoneAuthor = identity
                }

                child.markNotFetched()

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
            gTextEditor.stopCurrentEdit()

            if parent.count > 0 || parent.fetchableCount == 0 {
                createAndAdd()
            } else {
                parent.needChildren()

                var     isFirstTime = true

                gBatches.children(.restore) { iSame in
                    if  isFirstTime {
                        isFirstTime = false

                        createAndAdd()
                    }
                }
            }
        }
    }


    func duplicate() {
        let commonParent = gSelecting.firstGrab.parentZone ?? gSelecting.firstGrab
        var        zones = gSelecting.simplifiedGrabs
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
                let duplicate = zone.deepCopy

                duplicates.append(duplicate)
                indices.append(index)
            }
        }

        while   var index = indices.last, let duplicate = duplicates.last, let zone = zones.last {
            if  let     p = zone.parentZone {
                index    += (gInsertionsFollow ? 1 : 0)

                p.addAndReorderChild(duplicate, at: index)
                duplicate.grab()
            }

            duplicates.removeLast()
            indices   .removeLast()
            zones     .removeLast()
        }

        updateFavoritesRedrawSyncRedraw()
    }


    func reverse() {
        var commonParent = gSelecting.firstGrab.parentZone ?? gSelecting.firstGrab
        var        zones = gSelecting.simplifiedGrabs
        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                return
            }
        }

        if zones.count == 1 {
            commonParent = gSelecting.firstGrab
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

            gSelecting.hasNewGrab = gSelecting.currentMoveable

            commonParent.respectOrder()
            redrawSyncRedraw()
        }
    }


    func undoDelete() {
        gSelecting.deselectGrabs()

        for (child, (parent, index)) in gSelecting.pasteableZones {
            child.orphan()
            parent?.addAndReorderChild(child, at: index)
            child.addToGrab()
        }

        gSelecting.clearPaste()

        UNDO(self) { iUndoSelf in
            iUndoSelf.delete()
        }

        redrawSyncRedraw()
    }


    func pasteInto(_ iZone: Zone? = nil, honorFormerParents: Bool = false) {
        let      pastables = gSelecting.pasteableZones

        if pastables.count > 0, let zone = iZone {
            let isBookmark = zone.isBookmark
            let action = {
                var forUndo = [Zone] ()

                gSelecting.deselectGrabs()

                for (pastable, (parent, index)) in pastables {
                    let  pasteMe = pastable.isInTrash ? pastable : pastable.deepCopy // for zones not in trash, paste a deep copy
                    let insertAt = index  != nil ? index : gInsertionsFollow ? nil : 0
                    let     into = parent != nil ? honorFormerParents ? parent! : zone : zone

                    pasteMe.orphan()
                    into.revealChildren()
                    into.addAndReorderChild(pasteMe, at: insertAt)
                    pasteMe.recursivelyApplyDatabaseID(into.databaseID)
                    forUndo.append(pasteMe)
                    pasteMe.addToGrab()
                }

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.prepareUndoForDelete()
                    iUndoSelf.deleteZones(forUndo, iShouldGrab: false, onCompletion: nil)
                    zone.grab()
                    iUndoSelf.redrawSyncRedraw()
                }

                if isBookmark {
                    self.undoManager.endUndoGrouping()
                }

                self.updateFavoritesRedrawSyncRedraw()
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

                    gBatches.children(.all) { iSame in
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
                gFocusing.travelThrough(zone) { (iAny, iSignalKind) in
                    prepare()
                }
            }
        }
    }


    func preserveChildrenOfGrabbedZones(onCompletion: Closure?) {
        let grabs = gSelecting.simplifiedGrabs

        for zone in grabs {
            zone.needChildren()
            zone.revealChildren()
        }

        gBatches.children(.all) { iSame in // to make sure all progeny are acted upon
            let    candidate = gSelecting.rootMostMoveable
            if  let   parent = candidate.parentZone {
                let    index = candidate.siblingIndex
                var children = [Zone] ()

                gSelecting.deselectGrabs()
                gSelecting.clearPaste()

                for grab in grabs {
                    for child in grab.children {
                        children.append(child)
                    }

                    grab.addToPaste()
                    self.moveZone(grab, to: grab.trashZone)
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
        gSelecting.clearPaste()

        self.UNDO(self) { iUndoSelf in
            iUndoSelf.undoDelete()
        }
    }


    func moveOut(to: Zone, onCompletion: Closure?) {
        let         zone = gSelecting.firstGrab
        var completedYet = false

        recursivelyRevealSiblings(zone, untilReaching: to) { iRevealedZone in
            if !completedYet && iRevealedZone == to {
                completedYet     = true
                var insert: Int? = zone.parentZone?.siblingIndex

                if  zone.parentZone?.parentZone == to,
                    let  i = insert {
                    insert = i + 1
                    
                    if  insert! >= to.count {
                        insert   = nil // append at end
                    }
                }

                if  let  from = zone.parentZone {
                    let index = zone.siblingIndex

                    self.UNDO(self) { iUndoSelf in
                        iUndoSelf.moveZone(zone, into: from, at: index, orphan: true) { onCompletion?() }
                    }
                }

                zone.orphan()

                to.addAndReorderChild(zone, at: insert)
                onCompletion?()
            }
        }
    }


    func moveGrabbedZones(into iInto: Zone, at iIndex: Int?, _ COMMAND: Bool, onCompletion: Closure?) {

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // 1. move a normal zone into another normal zone                                                           //
        // 2. move a normal zone through a bookmark                                                                 //
        // 3. move a normal zone into favorites -- create a favorite pointing at normal zone, then add the favorite //
        // 4. move a favorite into a normal zone -- convert favorite to a bookmark, then move the bookmark          //
        //////////////////////////////////////////////////////////////////////////////////////////////////////////////

        let   toBookmark = iInto.isBookmark                      // type 2
        let  toFavorites = iInto.isInFavorites && !toBookmark    // type 3
        let         into = iInto.bookmarkTarget ?? iInto         // grab bookmark AFTER travel
        var        grabs = gSelecting.currentGrabs
        var      restore = [Zone: (Zone, Int?)] ()
        var    cyclicals = IndexSet()

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
                iUndoUndoSelf.moveGrabbedZones(into: iInto, at: iIndex, COMMAND, onCompletion: onCompletion)
            }

            onCompletion?()
        }

        ////////////////
        // move logic //
        ////////////////

        let finish = {
            var done = false

            if !COMMAND {
                into.revealChildren()
            }

            into.maybeNeedChildren()

            gBatches.children(.all) { iSame in
                if !done {
                    done = true
                    if  let firstGrab = grabs.first,
                        let fromIndex = firstGrab.siblingIndex,
                        (firstGrab.parentZone != into || fromIndex > (iIndex ?? 1000)) {
                        grabs = grabs.reversed()
                    }
                    
                    gSelecting.deselectGrabs()

                    for grab in grabs {
                        var beingMoved = grab

                        if  toFavorites && !beingMoved.isInFavorites && !beingMoved.isBookmark && !beingMoved.isInTrash {
                            beingMoved = gFavorites.createBookmark(for: beingMoved, style: .favorite)

                            beingMoved.maybeNeedSave()
                        } else {
                            beingMoved.orphan()

                            if  beingMoved.databaseID != into.databaseID {
                                beingMoved.traverseAllProgeny { iChild in
                                    iChild.needDestroy()
                                }

                                beingMoved = beingMoved.deepCopy
                            }
                        }

                        if !COMMAND {
                            beingMoved.addToGrab()
                        }

                        into.addAndReorderChild(beingMoved, at: iIndex)
                        beingMoved.recursivelyApplyDatabaseID(into.databaseID)
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

        if !toBookmark || COMMAND {
            finish()
        } else {
            gFocusing.travelThrough(iInto) { (iAny, iSignalKind) in
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

        gBatches.children(.restore) { iSame in
            let doGrab = !(into.isInTrash || into.isTrash)
            
            if orphan {
                zone.orphan()
            }

            into.addAndReorderChild(zone, at: iIndex)
            into.maybeNeedSave()
            zone.maybeNeedSave()

            if  doGrab { // so grab won't disappear
                zone.grab()
            }

            onCompletion?()
        }
    }
    
    
    fileprivate func findChildMatching(_ grabThis: inout Zone, _ iMoveUp: Bool, _ iOffset: CGFloat?) {
        guard let offset = iOffset else { return }
        
        //////////////////////////////////////////////////
        //         text is being edited by user         //
        // grab another zone whose text contains offset //
        //////////////////////////////////////////////////
        
        while grabThis.showingChildren, grabThis.count > 0,
            let length = grabThis.zoneName?.length {
                let range = NSRange(location: length, length: 0)
                
                if  let anOffset = grabThis.widget?.textWidget.offset(for: range, iMoveUp),
                    offset > anOffset + 25.0 { // half the distance from end of parent's text field to beginning of child's text field
                    grabThis = grabThis.children[iMoveUp ? grabThis.count - 1 : 0]
                } else {
                    break // done
                }
        }
    }
    
    func moveUp(_ iMoveUp: Bool = true, selectionOnly: Bool = true, extreme: Bool = false, extend: Bool = false, targeting iOffset: CGFloat? = nil) {
        let         zone = iMoveUp ? gSelecting.firstGrab : gSelecting.lastGrab
        let   isConfined = gBrowsingMode == .confine
        let hereIsMoving = zone == gHere
        let       parent = zone.parentZone

        if  parent == nil || hereIsMoving {
            if !zone.isRoot {
                
                ///////////////////////////
                // parent is not visible //
                ///////////////////////////
                
                let snapshot = gSelecting.snapshot
                
                revealParentAndSiblingsOf(zone) { iCalledCloud in
                    let same    = gSelecting.snapshotEquals(snapshot)
                    let setHere = parent != nil && hereIsMoving

                    if  setHere {
                        gHere   = parent!
                        
                        self.updateFavoritesRedrawSyncRedraw()
                    }
                    
                    if  same && (parent?.count ?? 0) > 1 && (setHere || iCalledCloud) {
                        self.moveUp(iMoveUp, selectionOnly: selectionOnly, extreme: extreme, extend: extend)
                    } else {
                        gControllers.signalFor(nil, regarding: .eRelayout)
                    }
                }
            }
        } else if  let originalParent = parent {
            let     targetZones = isConfined ? originalParent.children : gSelecting.cousinList
            let     targetCount = targetZones.count
            let       targetMax = targetCount - 1

            if  let       index = targetZones.index(of: zone) {
                var    newIndex = index + (iMoveUp ? -1 : 1)
                var  allGrabbed = true
                var soloGrabbed = false
                var     hasGrab = false
                
                let moveClosure: ZoneClosure = { iZone in
                    if  let newParent = iZone.parentZone {
                        var toIndex   = iZone.siblingIndex
                        
                        if  toIndex     != nil {
                            if  parent  != newParent {
                                toIndex  = toIndex! + (iMoveUp ? 1 : 0)
                            }

                            if  toIndex == newParent.count - 1 {
                                toIndex  = nil
                            }
                        }
                        
                        self.moveZone(zone, into: newParent, at: toIndex, orphan: true) {
                            zone.grab()
                            newParent.children.updateOrder()
                            self.redrawSyncRedraw(newParent)
                        }
                    }
                }
                
                /////////////////////////////////////
                // detect grab for extend behavior //
                /////////////////////////////////////
                
                for child in targetZones {
                    if !child.isGrabbed {
                        allGrabbed  = false
                    } else if hasGrab {
                        soloGrabbed = false
                    } else {
                        hasGrab     = true
                        soloGrabbed = true
                    }
                }
                
                //////////////////////////
                // vertical wrap around //
                //////////////////////////
                
                if !extend {
                    let    atTop = newIndex < 0
                    let atBottom = newIndex >= targetCount
                    
                    //////////////////////////
                    // vertical wrap around //
                    //////////////////////////
                    
                    if        (!iMoveUp && (allGrabbed || extreme || (!allGrabbed && !soloGrabbed && atBottom))) || ( iMoveUp && soloGrabbed && atTop) {
                        newIndex = targetMax // bottom
                    } else if ( iMoveUp && (allGrabbed || extreme || (!allGrabbed && !soloGrabbed && atTop)))    || (!iMoveUp && soloGrabbed && atBottom) {
                        newIndex = 0         // top
                    }
                }
                
                if  newIndex >= 0 && newIndex < targetCount {
                    var grabThis = targetZones[newIndex]
                    
                    ////////////////////////////
                    // wrapping is not needed //
                    ////////////////////////////

                    if  hereIsMoving {
                        gHere = originalParent
                    }
                    
                    UNDO(self) { iUndoSelf in
                        iUndoSelf.moveUp(!iMoveUp, selectionOnly: selectionOnly, extreme: extreme, extend: extend)
                    }
                    
                    if !selectionOnly {
                        moveClosure(grabThis)
                    } else {
                        if !extend {
                            findChildMatching(&grabThis, iMoveUp, iOffset)
                            gSelecting.deselectGrabs(retaining: [grabThis])
                        } else if !grabThis.isGrabbed || extreme {
                            var grabThese = [grabThis]
                            
                            if extreme {
                                
                                ///////////////////
                                // expand to end //
                                ///////////////////
                                
                                if iMoveUp {
                                    for i in 0 ..< newIndex {
                                        grabThese.append(targetZones[i])
                                    }
                                } else {
                                    for i in newIndex ..< targetCount {
                                        grabThese.append(targetZones[i])
                                    }
                                }
                            }
                            
                            gSelecting.addMultipleToGrab(grabThese)
                        }
                        
                        gControllers.signalFor(nil, regarding: .eData)
                    }
                } else if !isConfined,
                    var index  = targetZones.index(of: zone) {

                    /////////////////
                    // cousin jump //
                    /////////////////
                    
                    index     += (iMoveUp ? -1 : 1)

                    if  index >= targetCount {
                        index  = extend ? targetMax : 0
                    } else if index < 0 {
                        index  = extend ? 0 : targetMax
                    }
                    
                    var grab = targetZones[index]
                    
                    findChildMatching(&grab, iMoveUp, iOffset)
                    
                    if !selectionOnly {
                        moveClosure(grab)
                    } else if extend {
                        grab.addToGrab()
                    } else {
                        grab.grab()
                    }
                }
            }
        }
    }
}
