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


class ZGraphEditor: ZBaseEditor {
	override func canHandleKey() -> Bool { return gIsGraphOrEditIdeaMode }

	// MARK:- events
	// MARK:-

    class ZStalledEvent: NSObject {
        var event: ZEvent?
        var isWindow: Bool = true

        convenience init(_ iEvent: ZEvent, iIsWindow: Bool) {
            self.init()

            isWindow = iIsWindow
            event    = iEvent
        }
    }

    var undoManager: UndoManager {
        if  let w = gCurrentlyEditingWidget,
            w.undoManager != nil {
            return w.undoManager!
        }

        return gUndoManager
    }

    enum ZMenuType: Int {
        case eUndo
        case eHelp
        case eSort
        case eFind
        case eTint
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
    
    @discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if  var     key = iKey {
            let CONTROL = flags.isControl
            let COMMAND = flags.isCommand
            let  OPTION = flags.isOption
            var   SHIFT = flags.isShift
            let SPECIAL = COMMAND && OPTION
			let     ALL = COMMAND && OPTION && CONTROL
			let IGNORED = 			 OPTION && CONTROL
			let FLAGGED = COMMAND || OPTION || CONTROL
            let   arrow = key.arrow
            
            if  key    != key.lowercased() {
                key     = key.lowercased()
                SHIFT   = true
            }

			gCurrentKeyPressed = key

            if  gIsEditIdeaMode {
				if !gTextEditor.handleKey(iKey, flags: flags) {
					if !FLAGGED {
						return false
					} else {
						gCurrentKeyPressed = key

						switch key {
							case "a":      gCurrentlyEditingWidget?.selectAllText()
							case "d":      tearApartCombine(ALL, gCurrentlyEditingWidget?.widgetZone)
							case "f":      gControllers.showSearch(OPTION)
							case "n":      grabOrEdit(true, OPTION)
							case "p":      printCurrentFocus()
							case "/":      if IGNORED { return false } else if CONTROL { popAndUpdate() } else { gFocusRing.focus(kind: .eEdited, false) { self.redrawGraph() } }
							case ",", ".": commaAndPeriod(COMMAND, OPTION, with: key == ".")
							case kTab:     if OPTION { gTextEditor.stopCurrentEdit(); addNextAndRedraw(containing: true) }
							case kSpace:   addIdea()
							case kReturn:  if COMMAND { grabOrEdit(COMMAND, OPTION) }
							case kEscape:               grabOrEdit(   true, OPTION, true)
							case kBackspace,
								 kDelete:  if CONTROL { focusOnTrash() }
							default:       return false // false means key not handled
						}
					}
				}
            } else if isValid(key, flags) {
                let    widget = gWidgets.currentMovableWidget
                let hasWidget = widget != nil

                widget?.widgetZone?.needWrite()
                
                if  let a = arrow, isWindow {
                    handleArrow(a, flags: flags)
                } else if kMarkingCharacters.contains(key), !COMMAND, !CONTROL {
                    prefix(with: key)
                } else if !super.handleKey(iKey, flags: flags, isWindow: isWindow) {
					gCurrentKeyPressed = key

                    switch key {
					case "a":      if COMMAND { selectAll(progeny: OPTION) } else { alphabetize(OPTION) }
                    case "b":      addBookmark()
					case "c":      if COMMAND { copyToPaste() } else { gGraphController?.recenter() }
                    case "d":      if FLAGGED { combineIntoParent(widget?.widgetZone) } else { duplicate() }
                    case "e":      editTrait(for: .tEmail)
                    case "f":      gControllers.showSearch(OPTION)
                    case "h":      editTrait(for: .tHyperlink)
                    case "l":      alterCase(up: false)
					case "j":      gControllers.updateRingState(SPECIAL)
					case "k":      toggleColorized()
                    case "m":      orderByLength(OPTION)
                    case "n":      grabOrEdit(true, OPTION)
                    case "o":      gFiles.importFromFile(OPTION ? .eOutline : .eSeriously, insertInto: gSelecting.currentMoveable) { self.redrawAndSync() }
                    case "p":      printCurrentFocus()
                    case "r":      if SPECIAL { sendEmailBugReport() } else { reverse() }
					case "s":      gFiles.exportToFile(OPTION ? .eOutline : .eSeriously, for: gHere)
					case "t":      if SPECIAL { gControllers.showEssay(forGuide: false) } else { swapWithParent() }
					case "u":      if SPECIAL { gControllers.showEssay(forGuide:  true) } else { alterCase(up: true) }
					case "v":      if COMMAND { paste() }
					case "w":      rotateWritable()
					case "x":      if COMMAND { delete(permanently: SPECIAL && isWindow) } else { gCurrentKeyPressed = nil; return false }
					case "y":      gBreadcrumbs.toggleBreadcrumbExtent()
                    case "z":      if !SHIFT { gUndoManager.undo() } else { gUndoManager.redo() }
					case "+":      divideChildren()
					case "-":      return handleHyphen(COMMAND, OPTION)
                    case "/":      if IGNORED { gCurrentKeyPressed = nil; return false } else if CONTROL { popAndUpdate() } else { gFocusRing.focus(kind: .eSelected, COMMAND) { self.redrawGraph() } }
					case "\\":     gGraphController?.toggleGraphs(); redrawGraph()
                    case "[":      gFocusRing.goBack(   extreme: FLAGGED)
                    case "]":      gFocusRing.goForward(extreme: FLAGGED)
                    case "?":      if CONTROL { openBrowserForFocusWebsite() } else { gCurrentKeyPressed = nil; return false }
					case kEquals:  if COMMAND { updateSize(up: true) } else { gFocusRing.invokeTravel(gSelecting.firstSortedGrab) { self.redrawGraph() } }
                    case ";", "'": gFavorites.switchToNext(key == "'") { self.redrawGraph() }
                    case ",", ".": commaAndPeriod(COMMAND, OPTION, with: key == ".")
                    case kTab:     addNextAndRedraw(containing: OPTION)
					case kSpace:   if OPTION || isWindow || CONTROL { addIdea() } else { gCurrentKeyPressed = nil; return false }
                    case kBackspace,
                         kDelete:  if CONTROL { focusOnTrash() } else if OPTION || isWindow || COMMAND { delete(permanently: SPECIAL && isWindow, preserveChildren: FLAGGED && isWindow, convertToTitledLine: SPECIAL) } else { gCurrentKeyPressed = nil; return false }
                    case kReturn:  if hasWidget { grabOrEdit(COMMAND, OPTION) } else { gCurrentKeyPressed = nil; return false }
					case kEscape:                 grabOrEdit(true,    OPTION, true)
                    default:       return false // indicate key was not handled
                    }
                }
            }
        }

        gCurrentKeyPressed = nil

		return true // indicate key was handled
    }

    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        if  gIsEditIdeaMode || gArrowsDoNotBrowse {
            gTextEditor.handleArrow(arrow, flags: flags)
            
            return
        }
        
        let COMMAND = flags.isCommand
        let  OPTION = flags.isOption
        let   SHIFT = flags.isShift

        if (OPTION && !gSelecting.currentMoveable.userCanMove) || gIsShortcutsFrontmost {
            return
        }

        switch arrow {
        case .up, .down:     move(up: arrow == .up, selectionOnly: !OPTION, extreme: COMMAND, growSelection: SHIFT)
        default:
            if !SHIFT {
                switch arrow {
                case .left,
                     .right: move(out: arrow == .left, selectionOnly: !OPTION, extreme: COMMAND) {
                        gSelecting.updateAfterMove()  // relayout graph when travelling through a bookmark
                    }
                default: break
                }
            } else {

                // ///////////////
                // GENERATIONAL //
                // ///////////////

                var show = true

                switch arrow {
                case .right: break
                case .left:  show = false
                default:     return
                }

				if  OPTION {
					browseBreadcrumbs(arrow == .left)
				} else {
					applyGenerationally(show, extreme: COMMAND)
				}
            }
        }
    }

	func browseBreadcrumbs(_ out: Bool) {
		if  let here = out ? gHere.parentZone : gBreadcrumbs.nextCrumb(false) {
			let last = gSelecting.currentGrabs
			gHere    = here

			here.traverseAllProgeny { child in
				child.concealChildren()
			}

			gSelecting.grab(last)
			gSelecting.firstGrab?.asssureIsVisible()
			gControllers.signalFor(here, regarding: .sRelayout)
		}
	}
	
    func menuType(for key: String, _ flags: ZEventFlags) -> ZMenuType {
        let alterers = "ehltuw\r" + kMarkingCharacters
		let  ALTERER = alterers.contains(key)
        let  COMMAND = flags.isCommand
        let  CONTROL = flags.isControl
		let  FLAGGED = COMMAND || CONTROL

        if  !FLAGGED && ALTERER {       return .eAlter
        } else {
            switch key {
            case "f":                   return .eFind
            case "k":                   return .eTint
            case "m":                   return .eCloud
            case "z":                   return .eUndo
			case "o", "s":              return .eFiles
            case "r", "#":              return .eSort
			case "t", "u", "?":         return .eHelp
            case "x", kSpace:           return .eChild
            case "b", kTab, kBackspace: return .eParent
            case kDelete:               return  CONTROL ? .eAlways : .eParent
			case kEquals:               return  COMMAND ? .eAlways : .eTravel
            case "d":                   return  COMMAND ? .eAlter  : .eParent
            default:                    return .eAlways
            }
        }
    }


    override func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool {
        if !gIsGraphOrEditIdeaMode {
            return false
        }
		
		if  key.arrow != nil {
			return true
		}

        let  type = menuType(for: key, flags)
        var valid = !gIsEditIdeaMode

        if  valid,
			type 	   != .eAlways {
            let    undo = undoManager
            let  select = gSelecting
            let  wGrabs = select.writableGrabsCount
            let   paste = select.pasteableZones.count
            let   grabs = select.currentGrabs  .count
            let   shown = select.currentGrabsHaveVisibleChildren
            let   mover = select.currentMoveable
            let canTint = mover.isReadOnlyRoot || mover.bookmarkTarget?.isReadOnlyRoot ?? false
            let   write = mover.userCanWrite
            let    sort = mover.userCanMutateProgeny
            let  parent = mover.userCanMove

            switch type {
            case .eParent:    valid =               parent
            case .eChild:     valid =               sort
            case .eAlter:     valid =               write
            case .eTint:      valid =  canTint   || write
            case .ePaste:     valid =  paste > 0 && write
            case .eUseGrabs:  valid = wGrabs > 0 && write
            case .eMultiple:  valid =  grabs > 1
            case .eSort:      valid = (shown     && sort) || (grabs > 1 && parent)
            case .eUndo:      valid = undo.canUndo
            case .eRedo:      valid = undo.canRedo
            case .eTravel:    valid = mover.canTravel
            case .eCloud:     valid = gHasInternet && gCanAccessMyCloudDatabase
            default:          break
            }
        }

        return valid
    }

    // MARK:- features
    // MARK:-

	func popAndUpdate() {
		gFocusRing.popAndRemoveEmpties()
		redrawGraph()

	}

	func updateSize(up: Bool) {
		let      delta = CGFloat(up ? 1 : -1)
		var       size = gGenericOffset.offsetBy(0, delta)
		size           = size.force(horizotal: false, into: NSRange(location: 2, length: 7))
		gGenericOffset = size

		redrawGraph()
	}

	func handleHyphen(_ COMMAND: Bool = false, _ OPTION: Bool = false) -> Bool {
		let SPECIAL = COMMAND && OPTION

		if  SPECIAL {
			convertToTitledLineAndRearrangeChildren()
		} else if OPTION {
			return gSelecting.currentMoveable.convertToFromLine()
		} else if COMMAND {
			updateSize(up: false)
		} else {
			addDashedLine()
		}

		return true
	}

    func focusOnTrash() {
        if  let trash = gTrash {
            gFocusRing.focusOn(trash) {
                self.redrawGraph()
            }
        }
    }
    
    
    func commaAndPeriod(_ COMMAND: Bool, _ OPTION: Bool, with PERIOD: Bool) {
        if     !COMMAND || (OPTION && PERIOD) {
            toggleRingControlModes(isDirection:  PERIOD)
            
            if  gIsEditIdeaMode     && PERIOD {
                swapAndResumeEdit()
            }

            signal([.sMain, .sGraph, .sPreferences])
        } else if !PERIOD {
            gDetailsController?.toggleViewsFor(ids: [.Preferences])
        } else if gIsEditIdeaMode {
            gTextEditor.cancel()
        }
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
                        let     nameParts = name.components(separatedBy: after)
                        var         index = 0

                        while nameParts.count > index + 1 {
                            let      mark = nameParts[index]            // found: "(x"
                            let markParts = mark.components(separatedBy: before) // markParts[1] == x

                            if  markParts.count > 1 && markParts[0].count == 0 {
                                let  part = markParts[1]
                                index    += 1

                                if  part.count <= 2 && part.isDigit {
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

                gTextEditor.updateText(inZone: zone)?.updateBookmarkAssociates()
            }
        }

        redrawAndSync()
    }

    func editTrait(for iType: ZTraitType) {
        if  let  zone = gSelecting.firstSortedGrab {
            let trait = zone.traitFor(iType)
            
            gTextEditor.edit(trait)
        }
    }

	func grabOrEdit(_ COMMAND: Bool, _  OPTION: Bool, _ ESCAPE: Bool = false) {
        if !COMMAND {											// switch to essay edit mode
			let zone = gSelecting.currentMoveable

			gTemporarilySetMouseZone(zone)
			gTextEditor.edit(zone)

            if  OPTION {
                gTextEditor.placeCursorAtEnd()
            }
		} else {												// switch to idea edit mode
			if !gIsNoteMode {
				gCreateCombinedEssay     = !OPTION				// default is multiple, option drives it to single

				if  gCurrentEssay == nil || OPTION || !ESCAPE {	// restore prior essay or create one fresh (OPTION forces the latter)
					gCurrentEssay        =  gSelecting.firstGrab?.note
				}
			}

			gControllers.swapGraphAndEssay()
		}
    }

    func divideChildren() {
        let grabs = gSelecting.currentGrabs

        for zone in grabs {
            zone.needChildren()
        }

		for zone in grabs {
			zone.divideEvenly()
		}

		redrawAndSync()
    }


    func rotateWritable() {
        for zone in gSelecting.currentGrabs {
            zone.rotateWritable()
        }

        redrawAndSync()
    }


    func alphabetize(_ iBackwards: Bool = false) {
        alterOrdering { iZones -> (ZoneArray) in
            return iZones.sorted { (a, b) -> Bool in
                let aName = a.unwrappedName
                let bName = b.unwrappedName

                return iBackwards ? (aName > bName) : (aName < bName)
            }
        }
    }


    func orderByLength(_ iBackwards: Bool = false) {
        let font = gWidgetFont

        alterOrdering { iZones -> (ZoneArray) in
            return iZones.sorted { (a, b) -> Bool in
                let aLength = a.zoneName?.widthForFont(font) ?? 0
                let bLength = b.zoneName?.widthForFont(font) ?? 0

                return iBackwards ? (aLength > bLength) : (aLength < bLength)
            }
        }
    }


    func alterOrdering(_ iBackwards: Bool = false, with sortClosure: ZonesToZonesClosure) {
        var commonParent = gSelecting.firstSortedGrab?.parentZone ?? gSelecting.firstSortedGrab
        var        zones = gSelecting.simplifiedGrabs

        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                // status bar -> not all of the grabbed zones share the same parent
                return
            }
        }

        if  zones.count == 1 {
            commonParent = gSelecting.firstSortedGrab
            zones        = commonParent?.children ?? []
        }

        commonParent?.children.updateOrder()

        if  zones.count > 1 {
            let (start, end) = zones.orderLimits()
            zones            = sortClosure(zones)

            zones.updateOrdering(start: start, end: end)
            commonParent?.respectOrder()
            commonParent?.children.updateOrder()
            redrawAndSync()
        }

        gSelecting.hasNewGrab = gSelecting.currentMoveable
    }


    func alterCase(up: Bool) {
        for grab in gSelecting.currentGrabs {
            if  let tWidget = grab.widget?.textWidget {
                tWidget.alterCase(up: up)
            }
        }
    }

    func selectAll(progeny: Bool = false) {
        var zone = gSelecting.currentMoveable

        if progeny {
            gSelecting.ungrabAll()

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
                gSelecting.ungrabAll(retaining: zone.children)
            } else {
                return // selection does not show its children
            }
        }

        redrawGraph()
    }

    // MARK:- focus and travel
    // MARK:-


    func selectCurrentFavorite() {
        if  let current = gFavorites.currentFavorite {
            current.needRoot()

			if !current.isGrabbed {
				current.grab()
			} else {
				gHere.grab()
			}

			if  let parent = current.parentZone {
				parent.asssureIsVisible()

				self.redrawGraph()
			}
        }
    }


    func doFavorites(_ isShift: Bool, _ isOption: Bool) {
        let backward = isShift || isOption

        gFavorites.switchToNext(!backward) {
            self.redrawGraph()
        }
    }


    // MARK:- async
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


    func revealParentAndSiblingsOf(_ iZone: Zone) {
        if  let parent = iZone.parentZone {
            parent.revealChildren()
            parent.needChildren()
        } else {
            iZone.needParent()
        }
    }


    func recursivelyRevealSiblings(_ descendents: ZoneArray, untilReaching iAncestor: Zone, onCompletion: ZoneClosure?) {
        if  descendents.contains(iAncestor) {
            onCompletion?(iAncestor)
            
            return
        }

        var needRoot = true

        descendents.traverseAllAncestors { iParent in
            if  !descendents.contains(iParent) {
                iParent.revealChildren()
                iParent.needChildren()
            }

            if  iParent == iAncestor {
                needRoot = false
            }
        }

        if  needRoot { // true means graph in memory does not include root, so fetch it from iCloud
            for descendent in descendents {
                descendent.needRoot()
            }
        }

		descendents.traverseAncestors { iParent -> ZTraverseStatus in
			let  gotThere = iParent == iAncestor || iParent.isRoot    // reached the ancestor or the root
			let gotOrphan = iParent.parentZone == nil

			if  gotThere || gotOrphan {
				if !gotThere && !iParent.isFetched && iParent.parentZone != nil { // reached an orphan that has not yet been fetched
					self.recursivelyRevealSiblings([iParent], untilReaching: iAncestor, onCompletion: onCompletion)
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


    func revealSiblingsOf(_ descendent: Zone, untilReaching iAncestor: Zone) {
        recursivelyRevealSiblings([descendent], untilReaching: iAncestor) { iZone in
            if     iZone != descendent {
                if iZone == iAncestor {
                    gHere = iAncestor
                    
                    gHere.grab()
                }
                
                gFavorites.updateCurrentFavorite()
                self.redrawGraph()
            }
        }
    }
    
    
    func deferRedraw(_ closure: Closure) {
        gDeferRedraw     = true
        
        closure()
        
        FOREGROUND(after: 0.4) {
            gDeferRedraw = false   // in case closure doesn't set it
        }
    }


    // MARK:- reveal dot
    // MARK:-


    func applyGenerationally(_ show: Bool, extreme: Bool = false) {
		if  let zone = gSelecting.rootMostMoveable {
			var level: Int?

			if !show {
				level = extreme ? zone.level - 1 : zone.highestExposed - 1
			} else if  extreme {
				level = Int.max
			} else if let lowest = zone.lowestExposed {
				level = lowest + 1
			}

			generationalUpdate(show: show, zone: zone, to: level) {
				self.redrawGraph()
			}
		}
	}

	
	func expand(_ show: Bool) {
		generationalUpdate(show: show, zone: gSelecting.currentMoveable) {
			self.redrawGraph()
		}
	}
	

    func generationalUpdate(show: Bool, zone: Zone, to iLevel: Int? = nil, onCompletion: Closure?) {
        recursiveUpdate(show, zone, to: iLevel) {

            // ////////////////////////////////////////////////////////
            // delay executing this until the last time it is called //
            // ////////////////////////////////////////////////////////

            onCompletion?()
        }
    }


    func recursiveUpdate(_ show: Bool, _ zone: Zone, to iLevel: Int?, onCompletion: Closure?) {
        if !show && zone.isGrabbed && (zone.count == 0 || !zone.showingChildren) {

            // ///////////////////////////////
            // COLLAPSE OUTWARD INTO PARENT //
            // ///////////////////////////////

            zone.concealAllProgeny()

            revealParentAndSiblingsOf(zone)

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
        } else {

            // /////////////////
            // ALTER CHILDREN //
            // /////////////////

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
                    gFavorites.updateAllFavorites()
                }

                onCompletion?()
            }

            if !show {
                gSelecting.deselectGrabsWithin(zone);
            }

            apply()
        }
    }


	func clickActionOnRevealDot(for iZone: Zone?, COMMAND: Bool, OPTION: Bool) {
        if  let zone = iZone {
            gTextEditor.stopCurrentEdit()

            for     grabbed in gSelecting.currentGrabs {
                if  grabbed != zone && grabbed.spawnedBy(zone) {
                    grabbed.ungrab()
                }
            }

            if  zone.canTravel && (COMMAND || (zone.fetchableCount == 0 && zone.count == 0)) {
                gFocusRing.invokeTravel(zone) { // email, hyperlink, bookmark, essay
                    self.redrawGraph()
                }
            } else {
                let show = !zone.showingChildren

                if  zone.isRootOfFavorites {
                    // ///////////////////////////////////////////////////////////////
                    // avoid annoying user by treating favorites non-generationally //
                    // ///////////////////////////////////////////////////////////////

                    zone.toggleChildrenVisibility()

                    self.redrawGraph()
				} else {
					self.generationalUpdate(show: show, zone: zone) {
						self.redrawGraph()
					}
                }
            }
        }
    }

    
    // MARK:- lines
    // MARK:-

    
    func convertToTitledLineAndRearrangeChildren() {
        delete(preserveChildren: true, convertToTitledLine: true)
    }
    
    
    func combineIntoParent(_ iChild: Zone?) {
        if  let       child = iChild,
            let      parent = child.parentZone,
            let    original = parent.zoneName {
            let   childName = child.zoneName ?? ""
            let childLength = childName.length
            let    combined = original.stringBySmartly(appending: childName)
            let       range = NSMakeRange(combined.length - childLength, childLength)
            parent.zoneName = combined
            parent.extractTraits(from: child)
            parent.extractChildren(from: child)
            
            self.deferRedraw {
                moveZone(child, to: gTrash)
                redrawAndSync(child) {
                    gDeferRedraw = false
                    
                    gDragView?.setAllSubviewsNeedDisplay()
                    parent.editAndSelect(range: range)
                }
            }
        }
    }
    
    
	func swapWithParent() {
		let scratchZone = Zone()

        // swap places with parent

		if  gSelecting.currentGrabs.count == 1,
            let  grabbed = gSelecting.firstSortedGrab,
            let grabbedI = grabbed.siblingIndex,
            let   parent = grabbed.parentZone,
            let  parentI = parent.siblingIndex,
			let   grandP = parent.parentZone {
			
			self.moveZones(grabbed.children, into: scratchZone) {
				self.moveZone(grabbed, into: grandP, at: parentI, orphan: true) {
					self.moveZones(parent.children, into: grabbed) {
						self.moveZone(parent, into: grabbed, at: grabbedI, orphan: true) {
							self.moveZones(scratchZone.children, into: parent) {
								parent.needCount()
								parent.grab()

								if  gHere == parent {
									gHere  = grabbed
								}

								self.redrawAndSync(grabbed)
							}
						}
					}
				}
			}
		}
    }
    
    
    func swapAndResumeEdit() {
        let t = gTextEditor
        
        // //////////////////////////////////////////////////////////
        // swap currently editing zone with sibling, resuming edit //
        // //////////////////////////////////////////////////////////
        
        if  let    zone = t.currentlyEditingZone, zone.hasSiblings {
            let atStart = gListGrowthMode == .up
            let  offset = t.editingOffset(atStart)
            
            t.stopCurrentEdit(forceCapture: true)
            zone.ungrab()
            
            gCurrentBrowseLevel = zone.level // so cousin list will not be empty
            
            moveUp(atStart, [zone], selectionOnly: false, extreme: false, growSelection: false, targeting: nil) { iKind in
                self.redrawGraph() {
                    t.edit(zone)
                    t.setCursor(at: offset)
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
            addIdea(in: parent, at: gListsGrowDown ? nil : 0) { iChild in
                gControllers.signalFor(parent, regarding: .sRelayout) {
                    iChild?.edit()
                }
            }
        }
    }


    func addNext(containing: Bool = false, with name: String? = nil, _ onCompletion: ZoneClosure? = nil) {
        let       zone = gSelecting.rootMostMoveable

        if  let parent = zone?.parentZone, parent.userCanMutateProgeny {
            var  zones = gSelecting.currentGrabs

            if containing {
                zones.sort { (a, b) -> Bool in
                    return a.order < b.order
                }
            }

            if  zone  == gHere {
                gHere  = parent

                parent.revealChildren()
            }

            var index   = zone?.siblingIndex

            if  index  != nil {
                index! += gListsGrowDown ? 1 : 0
            }

            addIdea(in: parent, at: index, with: name) { iChild in
                if let child = iChild {
                    if !containing {
                        self.redrawGraph() {
                            onCompletion?(child)
                        }
                    } else {
                        self.moveZones(zones, into: child) {
							self.redrawGraph() {
								onCompletion?(child)
								gControllers.sync()
							}
                        }
                    }
                }
            }
        }
    }

    
    func addNextAndRedraw(containing: Bool = false) {
        deferRedraw {
            addNext(containing: containing) { iChild in
                gDeferRedraw = false

                self.redrawGraph {
                    iChild.edit()
                }
            }
        }
    }
    

    func addDashedLine(onCompletion: Closure? = nil) {
        
        // three states:
        // 1) plain line -> insert and edit stub title
        // 2) titled line selected only -> convert back to plain line
        // 3) titled line is first of multiple -> convert titled line to plain title, selected, as parent of others

        let grabs        = gSelecting.currentGrabs
        let isMultiple   = grabs.count > 1
        if  let original = gSelecting.currentMoveableLine,
            let name     = original.zoneName {
            let promoteToParent: ClosureClosure = { innerClosure in
                original.convertFromLineWithTitle()
                
                self.moveZones(grabs, into: original) {
                    original.grab()

                    self.redrawAndSync() {
                        innerClosure()
                        onCompletion?()
                    }
                }
            }
            
            if  name.contains(kLineOfDashes) {
                
                // //////////
                // state 1 //
                // //////////

                original.assignAndColorize(kLineWithStubTitle)   // convert into a stub title

                if !isMultiple {
                    original.editAndSelect(range: NSMakeRange(12, 1))   // edit selecting stub
                } else {
                    promoteToParent {
                        original.edit()
                    }
                }
                
                return
            } else if name.isLineWithTitle {
                if !isMultiple {
                    
                    // //////////
                    // state 2 //
                    // //////////

                    original.assignAndColorize(kLineOfDashes)
                } else {
                    
                    // //////////
                    // state 3 //
                    // //////////

                    promoteToParent {}
                }
                
                return
            }
        }
        
        addNext(with: kLineOfDashes) { iChild in
            iChild.colorized = true
            
            iChild.grab()
            
            onCompletion?()
        }
    }
    
    
    func tearApartCombine(_ intoParent: Bool, _ iZone: Zone?) {
        if  intoParent {
            addParentFromSelectedText(inside: iZone)
        } else {
            createChildIdeaFromSelectedText  (inside: iZone)
        }
    }
    

    func addParentFromSelectedText(inside iZone: Zone?) {
        if  let     child = iZone,
            let     index = child.siblingIndex,
            let    parent = child.parentZone,
            let childName = child.widget?.textWidget.extractTitleOrSelectedText() {

            gTextEditor.stopCurrentEdit()

            deferRedraw {
                self.addIdea(in: parent, at: index, with: childName) { iChild in
                    self.moveZone(child, to: iChild) {
                        self.redrawAndSync()

                        gDeferRedraw = false

                        iChild?.edit()
                    }
                }
            }
        }
    }
    

    func createChildIdeaFromSelectedText(inside iZone: Zone?) {
        if  let      zone  = iZone,
            let childName  = zone.widget?.textWidget.extractTitleOrSelectedText() {
            
            gTextEditor.stopCurrentEdit()

            if  childName == zone.zoneName {
                combineIntoParent(zone)
            } else {
                self.deferRedraw {
                    self.addIdea(in: zone, at: gListsGrowDown ? nil : 0, with: childName) { iChild in
                        gDeferRedraw = false
                        
						self.redrawAndSync {
							let e = iChild?.edit()

							FOREGROUND(after: 0.2) {
								e?.selectAllText()
							}
						}
                    }
                }
            }
        }
    }


    func addBookmark() {
        if  let zone = gSelecting.firstSortedGrab,
            zone.databaseID != .favoritesID, !zone.isRoot {
            let closure = {
                var bookmark: Zone?

                self.invokeUsingDatabaseID(.mineID) {
                    bookmark = gFavorites.createBookmark(for: zone, style: .normal)
                }

                bookmark?.grab()
                bookmark?.markNotFetched()
                gControllers.redrawAndSync()
            }

            if gHere != zone {
                closure()
            } else {
                self.revealParentAndSiblingsOf(zone)

				gHere = zone.parentZone ?? gHere

				closure()
            }
        }
    }


    // MARK:- copy and paste
    // MARK:-
    

    func paste() { pasteInto(gSelecting.firstSortedGrab) }


    func copyToPaste() {
        let grabs = gSelecting.simplifiedGrabs

        gSelecting.clearPaste()

        for grab in grabs {
            grab.addToPaste()
        }
    }

    // MARK:- delete
    // MARK:-

    func delete(permanently: Bool = false, preserveChildren: Bool = false, convertToTitledLine: Bool = false) {
        deferRedraw {
            if  preserveChildren && !permanently {
                self.preserveChildrenOfGrabbedZones(convertToTitledLine: convertToTitledLine) {
                    gFavorites.updateFavoritesRedrawAndSync {
                        gDeferRedraw = false
                        
                        self.redrawGraph()
                    }
                }
            } else {
                prepareUndoForDelete()
                
                deleteZones(gSelecting.simplifiedGrabs, permanently: permanently) {
                    gFavorites.updateFavoritesRedrawAndSync {    // delete alters the list
                        gDeferRedraw = false
                        
                        self.redrawGraph()
                    }
                }
            }
        }
    }

	func deleteZones(_ iZones: ZoneArray, permanently: Bool = false, in iParent: Zone? = nil, iShouldGrab: Bool = true, onCompletion: Closure?) {
        if  iZones.count == 0 {
            onCompletion?()
            
            return
        }

        let    zones = iZones.sortedByReverseOrdering()
        let     grab = !iShouldGrab ? nil : self.grabAppropriate(zones)
        var doneOnce = false

        for zone in iZones {
            zone.needProgeny()
        }

		if !doneOnce {
			doneOnce  = true
			var count = zones.count

			let finish: Closure = {
				grab?.grab()
				onCompletion?()
			}

			if  count == 0 {
				finish()
			} else {
				let deleteBookmarks: Closure = {
					count -= 1

					if  count == 0 {
						gBatches.bookmarks { iSame in
							var bookmarks = ZoneArray ()

							for zone in zones {
								bookmarks += zone.fetchedBookmarks
							}

							if  bookmarks.count == 0 {
								finish()
							} else {

								// ///////////////////////////////////////////////////////////
								// remove any bookmarks the target of which is one of zones //
								// ///////////////////////////////////////////////////////////

								self.deleteZones(bookmarks, permanently: permanently, iShouldGrab: false) { // recurse
									finish()
								}
							}
						}
					}
				}

				for zone in zones {
					if  zone == iParent { // detect and avoid infinite recursion
						deleteBookmarks()
					} else {
						self.deleteZone(zone, permanently: permanently) {
							deleteBookmarks()
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
            let parent = zone.parentZone
            if  zone == gHere {                         // this can only happen ONCE during recursion (multiple places, below)
                let recurse: Closure = {
                    
                    // //////////
                    // RECURSE //
                    // //////////
                    
                    self.deleteZone(zone, permanently: permanently, onCompletion: onCompletion)
                }
                
                if  let p = parent, p != zone {
                    gHere = p

                    revealParentAndSiblingsOf(zone)
					recurse()
                } else {

                    // ////////////////////////////////////////////////////////////////////////////////////////////
                    // SPECIAL CASE: delete here but here has no parent ... so, go somewhere useful and familiar //
                    // ////////////////////////////////////////////////////////////////////////////////////////////

                    gFavorites.refocus {                 // travel through current favorite, then ...
                        if  gHere != zone {
                            recurse()
                        }
                    }
                }
            } else {
                let deleteBookmarksClosure: Closure = {
                    if  let            p = parent, p != zone {
                        p.fetchableCount = p.count                  // delete alters the count
                    }
                    
                    // //////////
                    // RECURSE //
                    // //////////
                    
                    self.deleteZones(zone.fetchedBookmarks, permanently: permanently) {
                        onCompletion?()
                    }
                }
                
                zone.addToPaste()

                if  !permanently && !zone.isInTrash {
                    moveZone(zone, to: zone.trashZone) {
                        deleteBookmarksClosure()
                    }
                } else {
                    zone.traverseAllProgeny { iZone in
                        iZone.needDestroy()                     // gets written in file
                        iZone.concealAllProgeny()               // prevent gExpandedZones list from getting clogged with stale references
                        iZone.orphan()
                        gManifest?.smartAppend(iZone)
						gFocusRing.removeFromStack(iZone)		// prevent focus stack from containing a zombie and thus getting stuck
						gEssayRing.removeFromStack(iZone.noteMaybe)
                    }

                    if  zone.cloud?.cloudUnavailable ?? true {
                        moveZone(zone, to: zone.destroyZone) {
                            deleteBookmarksClosure()
                        }
                    } else {
                        deleteBookmarksClosure()
                    }
                }
            }
        }
    }


    func grabAppropriate(_ zones: ZoneArray) -> Zone? {
        if  let       grab = gListsGrowDown ? zones.first : zones.last,
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
                    if        index == max &&   gListsGrowDown {
                        index        = 0
                    } else if index == 0   &&  !gListsGrowDown {
                        index        = max
                    }
                } else if     index  < max &&  (gListsGrowDown || index == 0) {
                    index           += 1
                } else if     index  > 0    && (!gListsGrowDown || index == max) {
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
        if  let zone: Zone = gSelecting.firstSortedGrab {
            let parentZone = zone.parentZone
            let complete: Closure = {
                onCompletion?()
            }
            
            if zone.isRoot || zone.isRootOfTrash || parentZone == gFavoritesRoot {
                complete() // avoid the ridiculous
            } else if selectionOnly {
                
                // /////////////////
                // MOVE SELECTION //
                // /////////////////
                
                if extreme {
                    if  gHere.isRoot {
                        gHere = zone // reverse what the last move out extreme did

                        complete()
                    } else {
                        let here = gHere // revealZonesToRoot (below) changes gHere, so nab it first
                        
                        zone.grab()
                        revealZonesToRoot(from: zone) {
                            self.revealSiblingsOf(here, untilReaching: gRoot!)
                            complete()
                        }
                    }
                } else if let p = parentZone {
                    if  zone == gHere {
                        revealParentAndSiblingsOf(zone)
						self.revealSiblingsOf(zone, untilReaching: p)
						complete()
                    } else {
                        p.revealChildren()
                        p.needChildren()
                        p.grab()
						complete()
                    }
                } else {
                    // zone is an orphan
                    // change focus to bookmark of zone
                    
                    if  let bookmark = zone.fetchedBookmark {
                        gHere        = bookmark
                    }
                    
                    complete()
                }
            } else if let p = parentZone, !p.isRoot {
                
                // ////////////
                // MOVE ZONE //
                // ////////////
                
                let grandParentZone = p.parentZone
                
                if zone == gHere && !force {
                    let grandParentName = grandParentZone?.zoneName
                    let   parenthetical = grandParentName == nil ? "" : " (\(grandParentName!))"
                    
                    // /////////////////////////////////////////////////////////////////////
                    // present an alert asking if user really wants to move here leftward //
                    // /////////////////////////////////////////////////////////////////////
                    
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
                                complete()
                            }
                        }
                    } else if   grandParentZone != nil {
                        revealParentAndSiblingsOf(p)

						if  grandParentZone!.spawnedBy(gHere) {
							self.moveOut(to: grandParentZone!, onCompletion: onCompletion)
						} else {
							moveOutToHere(grandParentZone!)
							complete()
						}
                    } else { // no available move
                        complete()
                    }
                }
            }
        }
    }

    
    func move(out: Bool, selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
        if out {
            moveOut (selectionOnly: selectionOnly, extreme: extreme, onCompletion: onCompletion)
        } else {
            moveInto(selectionOnly: selectionOnly, extreme: extreme, onCompletion: onCompletion)
        }
    }
    

    func moveInto(selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
        if  let zone  = gSelecting.firstSortedGrab {
            let zones = gSelecting.sortedGrabs
            
            if !selectionOnly {
                actuallyMoveInto(zones, onCompletion: onCompletion)
            } else if zone.canTravel && zone.fetchableCount == 0 && zone.count == 0 {
                gFocusRing.invokeTravel(zone, onCompletion: onCompletion)
            } else {
				var needReveal = false
				var      child = zone
				var     invoke = {}

				invoke = {
					needReveal = needReveal || !child.showingChildren

					child.revealChildren()

					if  child.count > 0,
						let grandchild = gListsGrowDown ? child.children.last : child.children.first {
						grandchild.grab()

						if  extreme {
							child = grandchild

							invoke()
						}
					}
				}

				invoke()

				if  needReveal {
					gControllers.signalFor(zone, regarding: .sRelayout)
				}

				gFavorites.updateAllFavorites()

				onCompletion?()
            }
        }
    }


    func actuallyMoveInto(_ zones: ZoneArray, onCompletion: Closure?) {
        if  var    there = zones[0].parentZone {
            let siblings = Array(there.children)
            
            for zone in zones {
                if  let       index  = zone.siblingIndex {
                    var cousinIndex  = index == 0 ? 1 : index - 1 // ALWAYS INSERT INTO SIBLING ABOVE, EXCEPT AT TOP
                    
                    if  cousinIndex >= 0 && cousinIndex < siblings.count {
                        var newThere = siblings[cousinIndex]
                        
                        if !zones.contains(newThere) {
                            there    = newThere
                            
                            break
                        } else {
                            cousinIndex += 1
                            newThere = siblings[cousinIndex]

                            if !zones.contains(newThere) {
                                there    = newThere
                                
                                break
                            }
                        }
                    }
                }
            }
            
            moveZones(zones, into: there, onCompletion: onCompletion)
        } else {
            onCompletion?()
        }
    }


    func moveZone(_ zone: Zone, to iThere: Zone?, onCompletion: Closure? = nil) {
        if  let there = iThere {
            if !there.isBookmark {
                moveZone(zone, into: there, at: gListsGrowDown ? nil : 0, orphan: true) {
                    onCompletion?()
                }
            } else if !there.isABookmark(spawnedBy: zone) {

                // ///////////////////////////////
                // MOVE ZONE THROUGH A BOOKMARK //
                // ///////////////////////////////

                var     movedZone = zone
                let    targetLink = there.crossLink
                let     sameGraph = zone.databaseID == targetLink?.databaseID
                let grabAndTravel = {
                    gFocusRing.travelThrough(there) { object, kind in
                        let there = object as! Zone

                        self.moveZone(movedZone, into: there, at: gListsGrowDown ? nil : 0, orphan: false) {
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

                    gControllers.redrawAndSync {
                        grabAndTravel()
                    }
                }
            }
        } else {
            onCompletion?()
        }
    }


    func moveZones(_ zones: ZoneArray, into: Zone, at iIndex: Int? = nil, orphan: Bool = true, onCompletion: Closure?) {
        into.revealChildren()
        into.needChildren()

		for     zone in zones {
			if  zone != into {
				if orphan {
					zone.orphan()
				}

				into.addAndReorderChild(zone, at: iIndex)
			}
		}

		onCompletion?()
    }


    // MARK:- undoables
    // MARK:-
    

    func addIdea(in  iParent: Zone?, at iIndex: Int?, with name: String? = nil, onCompletion: ZoneMaybeClosure?) {
        if  let parent = iParent,
            let   dbID = parent.databaseID,
            dbID      != .favoritesID {

            func createAndAdd() {
                let child = Zone(databaseID: dbID)

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
				createAndAdd()
            }
        }
    }


    func duplicate() {
        let commonParent = gSelecting.firstSortedGrab?.parentZone ?? gSelecting.firstSortedGrab
        var        zones = gSelecting.simplifiedGrabs
        var   duplicates = ZoneArray ()
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
                index    += (gListsGrowDown ? 1 : 0)

                p.addAndReorderChild(duplicate, at: index)
                duplicate.grab()
            }

            duplicates.removeLast()
            indices   .removeLast()
            zones     .removeLast()
        }

        gFavorites.updateFavoritesRedrawAndSync()
    }


    func reverse() {
        var commonParent = gSelecting.firstSortedGrab?.parentZone ?? gSelecting.firstSortedGrab
        var        zones = gSelecting.simplifiedGrabs
        for zone in zones {
            if let parent = zone.parentZone, parent != commonParent {
                return
            }
        }

        if zones.count == 1 {
            commonParent = gSelecting.firstSortedGrab
            zones        = commonParent?.children ?? []
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

            commonParent?.respectOrder()
            redrawAndSync()
        }
    }


    func undoDelete() {
        gSelecting.ungrabAll()

        for (child, (parent, index)) in gSelecting.pasteableZones {
            child.orphan()
            parent?.addAndReorderChild(child, at: index)
            child.addToGrab()
        }

        gSelecting.clearPaste()

        UNDO(self) { iUndoSelf in
            iUndoSelf.delete()
        }

        redrawAndSync()
    }


    func pasteInto(_ iZone: Zone? = nil, honorFormerParents: Bool = false) {
        let      pastables = gSelecting.pasteableZones

        if pastables.count > 0, let zone = iZone {
            let isBookmark = zone.isBookmark
            let action = {
                var forUndo = ZoneArray ()

                gSelecting.ungrabAll()

                for (pastable, (parent, index)) in pastables {
                    let  pasteMe = pastable.isInTrash ? pastable : pastable.deepCopy // for zones not in trash, paste a deep copy
                    let insertAt = index  != nil ? index : gListsGrowDown ? nil : 0
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
                    iUndoSelf.redrawAndSync()
                }

                if isBookmark {
                    self.undoManager.endUndoGrouping()
                }

                gFavorites.updateFavoritesRedrawAndSync()
            }

            let prepare = {
                for child in pastables.keys {
                    if !child.isInTrash {
                        child.needProgeny()
                    }
                }

				action()
            }

            if !isBookmark {
                prepare()
            } else {
                undoManager.beginUndoGrouping()
                gFocusRing.travelThrough(zone) { (iAny, iSignalKind) in
                    prepare()
                }
            }
        }
    }


    func preserveChildrenOfGrabbedZones(convertToTitledLine: Bool = false, onCompletion: Closure?) {
        let     grabs = gSelecting.simplifiedGrabs
		let candidate = gSelecting.rootMostMoveable

        if  grabs.count > 1 && convertToTitledLine {
            addDashedLine {
                onCompletion?()
            }
         
            return
        }

        for grab in grabs {
            grab.needChildren()
            grab.revealChildren()
        }

		if  let       parent = candidate?.parentZone {
			let siblingIndex = candidate?.siblingIndex
			var     children = ZoneArray ()

			gSelecting.clearPaste()
			gSelecting.currentGrabs = []

			for grab in grabs {
				if !convertToTitledLine {       // delete, add to paste
					grab.addToPaste()
					self.moveZone(grab, to: grab.trashZone)
				} else {                        // convert to titled line and insert above
					grab.convertToTitledLine()
					children.append(grab)
					grab.addToGrab()
				}

				for child in grab.children {
					children.append(child)
					child.addToGrab()
				}
			}

			children.reverse()

			for child in children {
				child.orphan()
				parent.addAndReorderChild(child, at: siblingIndex)
			}

			self.UNDO(self) { iUndoSelf in
				iUndoSelf.prepareUndoForDelete()
				iUndoSelf.deleteZones(children, iShouldGrab: false) {}
				iUndoSelf.pasteInto(parent, honorFormerParents: true)
			}
		}

		onCompletion?()
    }

    
    func prepareUndoForDelete() {
        gSelecting.clearPaste()

        self.UNDO(self) { iUndoSelf in
            iUndoSelf.undoDelete()
        }
    }


    func moveOut(to: Zone, onCompletion: Closure?) {
        let        zones = gSelecting.sortedGrabs.reversed() as ZoneArray
        var completedYet = false

        recursivelyRevealSiblings(zones, untilReaching: to) { iRevealedZone in
            if !completedYet && iRevealedZone == to {
                completedYet     = true
                
                for zone in zones {
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
                }

                onCompletion?()
            }
        }
    }


    func moveGrabbedZones(into iInto: Zone, at iIndex: Int?, _ CONTROL: Bool, onCompletion: Closure?) {

        // ///////////////////////////////////////////////////////////////////////////////////////////////////////////
        // 1. move a normal zone into another normal zone                                                           //
        // 2. move a normal zone through a bookmark                                                                 //
        // 3. move a normal zone into favorites -- create a favorite pointing at normal zone, then add the favorite //
        // 4. move a favorite into a normal zone -- convert favorite to a bookmark, then move the bookmark          //
        // ///////////////////////////////////////////////////////////////////////////////////////////////////////////

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

        if  let dragged = gDraggedZone, dragged.isInFavorites, !toFavorites {
            dragged.maybeNeedSave()                             // type 4
        }

        grabs.sort { (a, b) -> Bool in
            if  a.isInFavorites {
                a.maybeNeedSave()                               // type 4
            }

            return a.order < b.order
        }

        // ///////////////////
        // prepare for UNDO //
        // ///////////////////

        if  toBookmark {
            undoManager.beginUndoGrouping()
        }

        UNDO(self) { iUndoSelf in
            for (child, (parent, index)) in restore {
                child.orphan()
                parent.addAndReorderChild(child, at: index)
            }

            iUndoSelf.UNDO(self) { iUndoUndoSelf in
                iUndoUndoSelf.moveGrabbedZones(into: iInto, at: iIndex, CONTROL, onCompletion: onCompletion)
            }

            onCompletion?()
        }

        // /////////////
        // move logic //
        // /////////////

        let finish = {
            var done = false

            if !CONTROL {
                into.revealChildren()
            }

            into.maybeNeedChildren()

			if !done {
				done = true
				if  let firstGrab = grabs.first,
					let fromIndex = firstGrab.siblingIndex,
					(firstGrab.parentZone != into || fromIndex > (iIndex ?? 1000)) {
					grabs = grabs.reversed()
				}

				gSelecting.ungrabAll()

				for grab in grabs {
					var beingMoved = grab

					if  toFavorites && !beingMoved.isInFavorites && !beingMoved.isBookmark && !beingMoved.isInTrash && !CONTROL {
						beingMoved = gFavorites.createBookmark(for: beingMoved, style: .favorite)	// type 3

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

					if !CONTROL {
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

        // ////////////////////////////////////
        // deal with target being a bookmark //
        // ////////////////////////////////////

        if !toBookmark || CONTROL {
            finish()
        } else {
            gFocusRing.travelThrough(iInto) { (iAny, iSignalKind) in
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

		if  orphan {
			zone.orphan()
		}

		into.addAndReorderChild(zone, at: iIndex)
		into.maybeNeedSave()
		zone.maybeNeedSave()

		if  !into.isInTrash { // so grab won't disappear
			zone.grab()
		}

		onCompletion?()
    }
    
    
    fileprivate func findChildMatching(_ grabThis: inout Zone, _ iMoveUp: Bool, _ iOffset: CGFloat?) {

        // ///////////////////////////////////////////////////////////
        // IF text is being edited by user, grab another zone whose //
        //                  text contains offset                    //
        //                       else whose                         //
        //           level equals gCurrentBrowsingLevel             //
        // ///////////////////////////////////////////////////////////
        
        while grabThis.showingChildren, grabThis.count > 0,
            let length = grabThis.zoneName?.length {
                let range = NSRange(location: length, length: 0)
                let index = iMoveUp ? grabThis.count - 1 : 0
                let child = grabThis.children[index]
                
                if  let   offset = iOffset,
                    let anOffset = grabThis.widget?.textWidget.offset(for: range, iMoveUp),
                    offset       > anOffset + 25.0 { // half the distance from end of parent's text field to beginning of child's text field
                    grabThis     = child
                } else if let level = gCurrentBrowseLevel,
                    child.level == level {
                    grabThis     = child
                } else {
                    break // done
                }
        }
    }
    
    
    func move(up iMoveUp: Bool = true, selectionOnly: Bool = true, extreme: Bool = false, growSelection: Bool = false, targeting iOffset: CGFloat? = nil) {
		moveUp(iMoveUp, gSelecting.sortedGrabs, selectionOnly: selectionOnly, extreme: extreme, growSelection: growSelection, targeting: iOffset) { iKind in
            gControllers.signalAndSync(nil, regarding: iKind) {
                self.signal([iKind])
            }
        }
    }

    
    func moveUp(_ iMoveUp: Bool = true, _ originalGrabs: ZoneArray, selectionOnly: Bool = true, extreme: Bool = false, growSelection: Bool = false, targeting iOffset: CGFloat? = nil, onCompletion: SignalKindClosure? = nil) {
        let doCousinJump = !gBrowsingIsConfined
		let    hereMaybe = gHereMaybe
        let       isHere = hereMaybe != nil && originalGrabs.contains(hereMaybe!)
        
        guard let rootMost = originalGrabs.rootMost(goingUp: iMoveUp) else {
            onCompletion?(.sData)
            
            return
        }

        let rootMostParent = rootMost.parentZone
        
        if  isHere {
            if  rootMost.isRoot {
                onCompletion?(.sData)
            } else {

                // ////////////////////////
                // parent is not visible //
                // ////////////////////////
                
                let    snapshot = gSelecting.snapshot
                let hasSiblings = rootMost.hasSiblings
                
                revealParentAndSiblingsOf(rootMost)

				let recurse = hasSiblings && snapshot.isSame && (rootMostParent != nil)

				if  let parent = rootMostParent {
					gHere = parent

					if  recurse {
						gSelecting.updateCousinList()
						self.moveUp(iMoveUp, originalGrabs, selectionOnly: selectionOnly, extreme: extreme, growSelection: growSelection, targeting: iOffset, onCompletion: onCompletion)
					} else {
						gFavorites.updateAllFavorites()

						onCompletion?(.sRelayout)
					}
				}
			}
        } else if let    parent = rootMostParent {
            let     targetZones = doCousinJump ? gSelecting.cousinList : parent.children
            let     targetCount = targetZones.count
            let       targetMax = targetCount - 1
            
            // ////////////////////
            // parent is visible //
            // ////////////////////
            
            if  let       index = targetZones.firstIndex(of: rootMost) {
                var     toIndex = index + (iMoveUp ? -1 : 1)
                var  allGrabbed = true
                var soloGrabbed = false
                var     hasGrab = false
                
                let moveClosure: ZonesClosure = { iZones in
                    if  extreme {
                        toIndex = iMoveUp ? 0 : targetMax
                    }

                    var  moveUp = iMoveUp
                    
                    if  !extreme {
                        
                        // ///////////////////////
                        // vertical wrap around //
                        // ///////////////////////
                        
                        if  toIndex > targetMax {
                            toIndex = 0
                            moveUp  = !moveUp
                        } else if toIndex < 0 {
                            toIndex = targetMax
                            moveUp  = !moveUp
                        }
                    }

                    let        indexer = targetZones[toIndex]
                    
                    if  let intoParent = indexer.parentZone {
                        let   newIndex = indexer.siblingIndex
                        let  moveThese = moveUp ? iZones.reversed() : iZones
                        
                        self.moveZones(moveThese, into: intoParent, at: newIndex, orphan: true) {
                            gSelecting.grab(moveThese)
                            intoParent.children.updateOrder()
                            onCompletion?(.sRelayout)
                        }
                    }
                }
                
                // //////////////////////////////////
                // detect grab for extend behavior //
                // //////////////////////////////////
                
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
                
                // ///////////////////////
                // vertical wrap around //
                // ///////////////////////
                
                if !growSelection {
                    let    aboveTop = toIndex < 0
                    let belowBottom = toIndex >= targetCount
                    
                    // ///////////////////////
                    // vertical wrap around //
                    // ///////////////////////
                    
                    if        (!iMoveUp && (allGrabbed || extreme || (!allGrabbed && !soloGrabbed && belowBottom))) || ( iMoveUp && soloGrabbed && aboveTop) {
                        toIndex = targetMax // bottom
                    } else if ( iMoveUp && (allGrabbed || extreme || (!allGrabbed && !soloGrabbed && aboveTop)))    || (!iMoveUp && soloGrabbed && belowBottom) {
                        toIndex = 0         // top
                    }
                }
                
                if  toIndex >= 0 && toIndex < targetCount {
                    var grabThis = targetZones[toIndex]
                    
                    // //////////////////////////
                    // no vertical wrap around //
                    // //////////////////////////
                    
                    UNDO(self) { iUndoSelf in
                        iUndoSelf.move(up: !iMoveUp, selectionOnly: selectionOnly, extreme: extreme, growSelection: growSelection)
                    }
                    
                    if !selectionOnly {
                        moveClosure(originalGrabs)
                    } else if !growSelection {
                        findChildMatching(&grabThis, iMoveUp, iOffset) // should look at siblings, not children
                        grabThis.grab(updateBrowsingLevel: false)
                    } else if !grabThis.isGrabbed || extreme {
                        var grabThese = [grabThis]
                        
                        if extreme {
                            
                            // ////////////////
                            // expand to end //
                            // ////////////////
                            
                            if iMoveUp {
                                for i in 0 ..< toIndex {
                                    grabThese.append(targetZones[i])
                                }
                            } else {
                                for i in toIndex ..< targetCount {
                                    grabThese.append(targetZones[i])
                                }
                            }
                        }
                        
                        gSelecting.addMultipleGrabs(grabThese)
                    }
                } else if doCousinJump,
                    var index  = targetZones.firstIndex(of: rootMost) {
                    
                    // //////////////
                    // cousin jump //
                    // //////////////
                    
                    index     += (iMoveUp ? -1 : 1)
                    
                    if  index >= targetCount {
                        index  = growSelection ? targetMax : 0
                    } else if index < 0 {
                        index  = growSelection ? 0 : targetMax
                    }
                    
                    var grab = targetZones[index]
                    
                    findChildMatching(&grab, iMoveUp, iOffset)
                    
                    if !selectionOnly {
                        moveClosure(originalGrabs)
                    } else if growSelection {
                        grab.addToGrab()
                    } else {
                        grab.grab(updateBrowsingLevel: false)
                    }
                }
                
                onCompletion?(.sRelayout)
            }
        }
    }

}
