//
//  ZMapEditor.swift
//  Seriously
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

let gMapEditor = ZMapEditor()

// mix of zone mutations and web services requestss

class ZMapEditor: ZBaseEditor {
	override var canHandleKey: Bool { return gIsMapOrEditIdeaMode }
	var             priorHere: Zone?

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

    @discardableResult override func handleKey(_ iKey: String?, flags: ZEventFlags, isWindow: Bool) -> Bool {   // false means key not handled
		if !gIsEditingStateChanging,
			var     key = iKey {
            let CONTROL = flags.isControl
            let COMMAND = flags.isCommand
            let  OPTION = flags.isOption
            var   SHIFT = flags.isShift
			let SPECIAL = flags.isSpecial
			let     ALL = COMMAND && OPTION && CONTROL
			let IGNORED = 			 OPTION && CONTROL
			let    HARD = COMMAND &&           CONTROL
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
							case "d":      gCurrentlyEditingWidget?.widgetZone?.tearApartCombine(ALL, HARD)
							case "f":      gSearching.showSearch(OPTION)
							case "g":      refetch(COMMAND, OPTION)
							case "n":      grabOrEdit(true, OPTION)
							case "p":      printCurrentFocus()
							case "/":      if IGNORED { return false } else { popAndUpdate(CONTROL, kind: .eEdited) }
							case ",", ".": commaAndPeriod(COMMAND, OPTION, with: key == ",")
							case kTab:     addSibling(OPTION)
							case kSpace:   gSelecting.currentMoveable.addIdea()
							case kReturn:  if COMMAND { grabOrEdit(COMMAND, OPTION) }
							case kEscape:               grabOrEdit(   true, OPTION, true)
							case kBackspace,
								 kDelete:  if CONTROL { focusOnTrash() }
							default:       return false // false means key not handled
						}
					}
				}
            } else if isValid(key, flags) {
                let widget = gWidgets.currentMovableWidget

                widget?.widgetZone?.needWrite()
                
                if  let a = arrow, isWindow {
                    handleArrow(a, flags: flags)
                } else if kMarkingCharacters.contains(key), !COMMAND, !CONTROL {
                    prefix(with: key)
                } else if !super.handleKey(iKey, flags: flags, isWindow: isWindow) {
					gCurrentKeyPressed = key

                    switch key {
					case "a":      if COMMAND { gSelecting.currentMoveable.selectAll(progeny: OPTION) } else { gSelecting.simplifiedGrabs.alphabetize(OPTION); gRedrawMaps() }
                    case "b":      gSelecting.firstSortedGrab?.addBookmark()
					case "c":      if COMMAND && !OPTION { copyToPaste() } else { gMapController?.recenter(SPECIAL) }
					case "d":      if FLAGGED { widget?.widgetZone?.combineIntoParent() } else { duplicate() }
					case "e":      gSelecting.firstSortedGrab?.editTrait(for: .tEmail)
                    case "f":      gSearching.showSearch(OPTION)
					case "g":      refetch(COMMAND, OPTION)
                    case "h":      gSelecting.firstSortedGrab?.editTrait(for: .tHyperlink)
                    case "l":      alterCase(up: false)
					case "k":      toggleColorized()
					case "m":      gSelecting.simplifiedGrabs.sortByLength(OPTION); gRedrawMaps()
                    case "n":      grabOrEdit(true, OPTION)
                    case "o":      gSelecting.currentMoveable.importFromFile(OPTION ? .eOutline : .eSeriously) { gRedrawMaps() }
                    case "p":      printCurrentFocus()
                    case "r":      reverse()
					case "s":      gHere.exportToFile(OPTION ? .eOutline : .eSeriously)
					case "t":      if SPECIAL { gControllers.showEssay(forGuide: false) } else { swapWithParent() }
					case "u":      if SPECIAL { gControllers.showEssay(forGuide:  true) } else { alterCase(up: true) }
					case "v":      if COMMAND { paste() }
					case "w":      rotateWritable()
					case "x":      if COMMAND { delete(permanently: SPECIAL && isWindow) } else { gCurrentKeyPressed = nil; return false }
                    case "z":      if !SHIFT  { gUndoManager.undo() } else { gUndoManager.redo() }
					case "+":      divideChildren()
					case "-":      return handleHyphen(COMMAND, OPTION)
					case "'":      swapSmallMapMode(OPTION)
                    case "/":      if IGNORED { gCurrentKeyPressed = nil; return false } else { popAndUpdate(CONTROL, COMMAND, kind: .eSelected) }
					case "\\":     gMapController?.toggleMaps(); gRedrawMaps()
					case "]", "[": gCurrentSmallMapRecords?.go(down: key == "]") { gRedrawMaps() }
                    case "?":      if CONTROL { openBrowserForFocusWebsite() } else { gCurrentKeyPressed = nil; return false }
					case kEquals:  if COMMAND { updateSize(up: true) } else { gSelecting.firstSortedGrab?.invokeTravel() { gRedrawMaps() } }
                    case ",", ".": commaAndPeriod(COMMAND, OPTION, with: key == ",")
                    case kTab:     addSibling(OPTION)
					case kSpace:   if OPTION || CONTROL || isWindow { gSelecting.currentMoveable.addIdea() } else { gCurrentKeyPressed = nil; return false }
                    case kBackspace,
                         kDelete:  if CONTROL { focusOnTrash() } else if OPTION || isWindow || COMMAND { delete(permanently: SPECIAL && isWindow, preserveChildren: FLAGGED && isWindow, convertToTitledLine: SPECIAL) } else { gCurrentKeyPressed = nil; return false }
                    case kReturn:  grabOrEdit(COMMAND, OPTION)
					case kEscape:  grabOrEdit(true,    OPTION, true)
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

        if (OPTION && !gSelecting.currentMoveable.userCanMove) || gIsHelpFrontmost {
            return
        }

        switch arrow {
        case .up, .down:     move(up: arrow == .up, selectionOnly: !OPTION, extreme: COMMAND, growSelection: SHIFT)
        default:
			if  let moveable = gSelecting.rootMostMoveable {
				if !SHIFT || moveable.isInSmallMap {
					switch arrow {
						case .left,
							 .right: move(out: arrow == .left, selectionOnly: !OPTION, extreme: COMMAND) {
								gSelecting.updateAfterMove()  // relayout map when travelling through a bookmark
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
						moveable.applyGenerationally(show, extreme: COMMAND)
					}
				}
			}
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
            case "k":                   return .eColor
            case "m":                   return .eCloud
            case "z":                   return .eUndo
			case "o", "s":              return .eFiles
            case "r", "#":              return .eSort
			case "t", "u", "?", "/":    return .eHelp
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
        if !gIsMapOrEditIdeaMode {
            return false
        }
		
		if  key.arrow != nil {
			return true
		}

        let  type = menuType(for: key, flags)
        var valid = !gIsEditIdeaMode

        if  valid,
			type  	    != .eAlways {
            let     undo = undoManager
            let   select = gSelecting
            let   wGrabs = select.writableGrabsCount
            let    paste = select.pasteableZones.count
            let    grabs = select.currentGrabs  .count
            let    shown = select.currentGrabsHaveVisibleChildren
            let    mover = select.currentMoveable
            let canColor = mover.isReadOnlyRoot || mover.bookmarkTarget?.isReadOnlyRoot ?? false
            let    write = mover.userCanWrite
            let     sort = mover.userCanMutateProgeny
            let   parent = mover.userCanMove

            switch type {
            case .eParent:    valid =               parent
            case .eChild:     valid =               sort
            case .eAlter:     valid =               write
            case .eColor:     valid =  canColor  || write
            case .ePaste:     valid =  paste > 0 && write
            case .eUseGrabs:  valid = wGrabs > 0 && write
            case .eMultiple:  valid =  grabs > 1
            case .eSort:      valid = (shown     && sort) || (grabs > 1 && parent)
            case .eUndo:      valid = undo.canUndo
            case .eRedo:      valid = undo.canRedo
            case .eTravel:    valid = mover.canTravel
            case .eCloud:     valid = gHasInternet && gCloudStatusIsActive
            default:          break
            }
        }

        return valid
    }

	// MARK:- features
	// MARK:-

	func swapSmallMapMode(_ OPTION: Bool) {
		let currentID : ZDatabaseID = gIsRecentlyMode ? .recentsID   : .favoritesID
		let newID     : ZDatabaseID = gIsRecentlyMode ? .favoritesID : .recentsID

		gSmallMapMode = gIsRecentlyMode ? .favorites : .recent

		if  OPTION {			// if any grabs are in current small map, move them to other map
			gSelecting.swapGrabsFrom(currentID, toID: newID)
		}

		gCurrentSmallMapRecords?.revealBookmark(of: gHere)

		gSignal([.sDetails])
	}

	func addSibling(_ OPTION: Bool) {
		gTextEditor.stopCurrentEdit()
		gSelecting.currentMoveable.addNextAndRedraw(containing: OPTION)
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
			gRedrawMaps(for: here)
		}
	}

	func duplicate() {
		var grabs = gSelecting.simplifiedGrabs

		grabs.duplicate()
	}

	func popAndUpdate(_ CONTROL: Bool, _ COMMAND: Bool = false, kind: ZFocusKind) {
		if  !CONTROL {
			gRecords?.maybeRefocus(kind, COMMAND, shouldGrab: true) { // complex grab logic
				gRedrawMaps()
			}
		} else {
			gRecents.popAndUpdateRecents()

			if  let here = gRecents.currentBookmark?.bookmarkTarget {
				gHere    = here
			}

			gRedrawMaps()
		}
	}

	func updateSize(up: Bool) {
		let      delta = CGFloat(up ? 1 : -1)
		var       size = gGenericOffset.offsetBy(0, delta)
		size           = size.force(horizotal: false, into: NSRange(location: 2, length: 7))
		gGenericOffset = size

		gRedrawMaps()
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

					gRedrawMaps {
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

		gSelecting.rootMostMoveable?.addNext(with: kLineOfDashes) { iChild in
			iChild.colorized = true

			iChild.grab()

			onCompletion?()
		}
	}

    func focusOnTrash() {
		gTrash?.focusOn() {
			gRedrawMaps()
		}
    }

	func refetch(_ COMMAND: Bool = false, _ OPTION: Bool = false) {

		// plain is fetch children
		// COMMAND alone is fetch all
		// OPTION is all progeny
		// both is force adoption of selected

		if         COMMAND &&  OPTION {
			gSelecting.simplifiedGrabs.assureAdoption()   // finish what fetch has done
		} else if  COMMAND && !OPTION {                   // COMMAND alone
			gBatches.refetch { iSame in
				gRedrawMaps()
			}
		} else {
			for grab in gSelecting.currentGrabs {
				if !OPTION {                              // plain
					grab.reallyNeedChildren()
				} else {                                  // OPTION alone or both
					grab.reallyNeedProgeny()
				}
			}

			gBatches.children { iSame in
				gRedrawMaps()
			}
		}
	}

    func commaAndPeriod(_ COMMAND: Bool, _ OPTION: Bool, with COMMA: Bool) {
        if     !COMMAND || (OPTION && COMMA) {
            toggleGrowthAndConfinementModes(changesDirection:  COMMA)
            
            if  gIsEditIdeaMode    && COMMA {
                swapAndResumeEdit()
            }

			gSignal([.sMap, .sMain, .sDetails, .sPreferences])
        } else if COMMA {
			gShowDetailsView = true

			gMainController?.update()
			gDetailsController?.toggleViewsFor(ids: [.Preferences])
        } else if gIsEditIdeaMode {
            gTextEditor.cancel()
        }
    }


    func toggleColorized() {
        for zone in gSelecting.currentGrabs {
            zone.toggleColorized()
        }

        gRedrawMaps()
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

        gRedrawMaps()
    }

	func grabOrEdit(_ COMMAND: Bool, _  OPTION: Bool, _ ESCAPE: Bool = false) {
        if !COMMAND {											// switch to essay edit mode
			gSelecting.currentMoveable.edit()

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

			gControllers.swapMapAndEssay()
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

		gRedrawMaps()
    }

    func rotateWritable() {
        for zone in gSelecting.currentGrabs {
            zone.rotateWritable()
        }

        gRedrawMaps()
    }

    func alterCase(up: Bool) {
        for grab in gSelecting.currentGrabs {
            if  let tWidget = grab.widget?.textWidget {
                tWidget.alterCase(up: up)
            }
        }
    }

    // MARK:- lines
    // MARK:-
    
    func convertToTitledLineAndRearrangeChildren() {
        delete(preserveChildren: true, convertToTitledLine: true)
    }
	
	func swapWithParent() {
		if  gSelecting.currentGrabs.count == 1 {
			gSelecting.firstSortedGrab?.swapWithParent()
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
                gRedrawMaps() {
                    t.edit(zone)
                    t.setCursor(at: offset)
                }
            }
        }
    }
    
    // MARK:- copy and paste
    // MARK:-

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
        gDeferRedraw {
            if  preserveChildren && !permanently {
                self.preserveChildrenOfGrabbedZones(convertToTitledLine: convertToTitledLine) {
                    gFavorites.updateFavoritesAndRedraw {
                        gDeferringRedraw = false
                        
                        gRedrawMaps()
                    }
                }
            } else {
				let grab = gSelecting.rootMostMoveable

				prepareUndoForDelete()
                
				gSelecting.simplifiedGrabs.deleteZones(permanently: permanently) {
					gDeferringRedraw = false

					if  let g = grab {
						if  g.isInSmallMap,      // if already grabbed and in small map
							g.count == 0 {       // mark g as current
							gCurrentSmallMapRecords?.setAsCurrent(g, alterHere: true)
						}

						gRedrawMaps(for: g)
					}
                }
            }
        }
    }

    // MARK:- move
    // MARK:-

    func moveOut(selectionOnly: Bool = true, extreme: Bool = false, force: Bool = false, onCompletion: Closure?) {
        if  let zone: Zone = gSelecting.firstSortedGrab {
            let parentZone = zone.parentZone

            if  zone.isARoot || parentZone == gFavoritesRoot {
                return // cannot move out from a root or move into favorites root
			} else if selectionOnly {

				// /////////////////
				// MOVE SELECTION //
				// /////////////////

				zone.moveSelectionOut(extreme: extreme, onCompletion: onCompletion)
			} else if let p = parentZone, !p.isARoot {
                
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

							self.moveOut(to: gHere, onCompletion: onCompletion)
						}
                    }
                    
                    if extreme {
                        if  gHere.isARoot {
                            moveOut(to: gHere, onCompletion: onCompletion)
                        } else {
							zone.revealZonesToRoot() {
                                moveOutToHere(gRoot)
                                onCompletion?()
                            }
                        }
                    } else if let gp = grandParentZone {
						let inSmallMap = p.isInSmallMap

						if  inSmallMap {
							p.concealChildren()
						}

						p.revealParentAndSiblings()

						if  gp.spawnedBy(gHere) {
							self.moveOut(to: gp, onCompletion: onCompletion)
						} else if inSmallMap {
							gCurrentSmallMapRecords?.setAsCurrent(p)
						} else {
							moveOutToHere(gp)
						}
                    }
                }
            }
        }

		onCompletion?()
    }
    
    func move(out: Bool, selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
        if  out {
            moveOut (selectionOnly: selectionOnly, extreme: extreme, onCompletion: onCompletion)
        } else {
            moveInto(selectionOnly: selectionOnly, extreme: extreme, onCompletion: onCompletion)
        }
    }

    func moveInto(selectionOnly: Bool = true, extreme: Bool = false, onCompletion: Closure?) {
		if  let zone  = gSelecting.firstSortedGrab {
            if !selectionOnly {
                actuallyMoveInto(gSelecting.sortedGrabs, onCompletion: onCompletion)
            } else if zone.canTravel && zone.fetchableCount == 0 && zone.count == 0 {
				zone.invokeTravel(onCompletion: onCompletion)
            } else {
				zone.moveSelectionInto(extreme: extreme, onCompletion: onCompletion)
			}
        }
    }

    func actuallyMoveInto(_ zones: ZoneArray, onCompletion: Closure?) {
		if  !gIsRecentlyMode || !zones.anyInRecently,
			zones.count > 0,
			var    there = zones[0].parentZone {
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

	func moveZones(_ zones: ZoneArray, into: Zone, at iIndex: Int? = nil, orphan: Bool = true, onCompletion: Closure?) {
		into.revealChildren()
		into.needChildren()

		for     zone in zones {
			if  zone != into {
				if  orphan {
					zone.orphan()
				}

				into.addAndReorderChild(zone, at: iIndex)
			}
		}

		onCompletion?()
	}

    // MARK:- undoables
    // MARK:-

    func reverse() {
		UNDO(self) { iUndoSelf in
			iUndoSelf.reverse()
		}

		var        zones  = gSelecting.simplifiedGrabs
		let commonParent  = zones.commonParent

		if  commonParent == nil {
			return
		}

        if  zones.count  == 1 {
            zones         = commonParent?.children ?? []
        }

		zones.reverse()

		commonParent?.respectOrder()
		gRedrawMaps()
	}

    func undoDelete() {
        gSelecting.ungrabAll()

        for (child, (parent, index)) in gSelecting.pasteableZones {
            child.orphan()
            parent?.addAndReorderChild(child, at: index)
            child.addToGrabs()
        }

        gSelecting.clearPaste()

        UNDO(self) { iUndoSelf in
            iUndoSelf.delete()
        }

        gRedrawMaps()
    }

	func paste() { pasteInto(gSelecting.firstSortedGrab) }

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
                    pasteMe.addToGrabs()
                }

                self.UNDO(self) { iUndoSelf in
                    iUndoSelf.prepareUndoForDelete()
                    forUndo.deleteZones(iShouldGrab: false, onCompletion: nil)
                    zone.grab()
                    gRedrawMaps()
                }

                if isBookmark {
                    self.undoManager.endUndoGrouping()
                }

                gFavorites.updateFavoritesAndRedraw()
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
				zone.travelThrough() { (iAny, iSignalKind) in
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
					grab.moveZone(to: grab.trashZone)
				} else {                        // convert to titled line and insert above
					grab.convertToTitledLine()
					children.append(grab)
					grab.addToGrabs()
				}

				for child in grab.children {
					children.append(child)
					child.addToGrabs()
				}
			}

			children.reverse()

			for child in children {
				child.orphan()
				parent.addAndReorderChild(child, at: siblingIndex)
			}

			self.UNDO(self) { iUndoSelf in
				iUndoSelf.prepareUndoForDelete()
				children .deleteZones(iShouldGrab: false) {}
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

		zones.recursivelyRevealSiblings(untilReaching: to) { iRevealedZone in
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
                            zone.moveZone(into: from, at: index, orphan: true) { onCompletion?() }
                        }
                    }
                    
                    zone.orphan()
                    
                    to.addAndReorderChild(zone, at: insert)
                }

                onCompletion?()
            }
        }
    }

    func moveGrabbedZones(into iInto: Zone, at iIndex: Int?, _ SPECIAL: Bool, onCompletion: Closure?) {

        // ////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // 1. move a normal zone into another normal zone                                                            //
        // 2. move a normal zone through a bookmark                                                                  //
        // 3. move a normal zone into small map -- create a bookmark pointing at normal zone, then add it to the map //
        // 4. move from small map into a normal zone -- convert to a bookmark, then move the bookmark                //
        // ////////////////////////////////////////////////////////////////////////////////////////////////////////////

        let   toBookmark = iInto.isBookmark                    // type 2
        let   toSmallMap = iInto.isInSmallMap && !toBookmark   // type 3
        let         into = iInto.bookmarkTarget ?? iInto       // grab bookmark AFTER travel
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

        if  let dragged = gDraggedZone, dragged.isInSmallMap, !toSmallMap {
            dragged.maybeNeedSave()                            // type 4
        }

        grabs.sort { (a, b) -> Bool in
            if  a.isInSmallMap {
                a.maybeNeedSave()                              // type 4
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
                iUndoUndoSelf.moveGrabbedZones(into: iInto, at: iIndex, SPECIAL, onCompletion: onCompletion)
            }

            onCompletion?()
        }

        // /////////////
        // move logic //
        // /////////////

        let finish = {
            var done = false

            if !SPECIAL {
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

					if  toSmallMap && beingMoved.isInBigMap && !beingMoved.isBookmark && !beingMoved.isInTrash && !SPECIAL {
						if  let bookmark = gFavorites.createFavorite(for: beingMoved, action: .aNotABookmark) {	// type 3
							beingMoved   = bookmark

							beingMoved.maybeNeedSave()
						}
					} else {
						beingMoved.orphan()

						if  beingMoved.databaseID != into.databaseID {
							beingMoved.traverseAllProgeny { iChild in
								iChild.needDestroy()
							}

							beingMoved = beingMoved.deepCopy
						}
					}

					if !SPECIAL {
						beingMoved.addToGrabs()
					}

					if  toSmallMap {
						into.expandInSmallMap(true)
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

        if !toBookmark || SPECIAL {
            finish()
        } else {
			iInto.travelThrough() { (iAny, iSignalKind) in
                finish()
            }
        }
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
		priorHere = gHere

		moveUp(iMoveUp, gSelecting.sortedGrabs, selectionOnly: selectionOnly, extreme: extreme, growSelection: growSelection, targeting: iOffset) { iKind in
            gSignal([iKind])
        }
    }
    
    func moveUp(_ iMoveUp: Bool = true, _ originalGrabs: ZoneArray, selectionOnly: Bool = true, extreme: Bool = false, growSelection: Bool = false, targeting iOffset: CGFloat? = nil, onCompletion: SignalKindClosure? = nil) {
        let   doCousinJump = !gBrowsingIsConfined
		let      hereMaybe = gHereMaybe
        let         isHere = hereMaybe != nil && originalGrabs.contains(hereMaybe!)
        guard let rootMost = originalGrabs.rootMost(goingUp: iMoveUp) else {
			onCompletion?(.sData)
            
            return
        }

        let rootMostParent = rootMost.parentZone
        
        if  isHere {
            if  rootMost.isARoot {
				onCompletion?(.sData)
            } else {

                // ////////////////////////
                // parent is not visible //
                // ////////////////////////
                
                let    snapshot = gSelecting.snapshot
                let hasSiblings = rootMost.hasSiblings
                
				rootMost.revealParentAndSiblings()

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
                        grab.addToGrabs()
                    } else {
                        grab.grab(updateBrowsingLevel: false)
                    }
                }

				onCompletion?(.sRelayout)
            }
        }
    }

}
