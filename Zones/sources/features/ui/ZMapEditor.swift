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

// mix of zone mutations and web services requests

class ZMapEditor: ZBaseEditor {
	var             priorHere : Zone?
	override var canHandleKey : Bool       { return gIsMapOrEditIdeaMode }
	var             moveables : ZoneArray? { return (gIsEssayMode && !gMapIsResponder) ? gEssayView?.grabbedZones : gSelecting.sortedGrabs }
	func          forceRedraw()            { gMapView?.setNeedsDisplay() }

	// MARK: - events
	// MARK: -

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
			let   arrow = key.arrow
			let CONTROL = flags.isControl
			let SPECIAL = flags.exactlySpecial
			let SPLAYED = flags.exactlySplayed
			let COMMAND = flags.isCommand
			let  OPTION = flags.isOption
			var   SHIFT = flags.isShift
			let     ANY = flags.isAny
			let     ALL = flags.exactlyAll

            if  key    != key.lowercased() {
                key     = key.lowercased()
                SHIFT   = true
            }

			if  "{}".contains(key) {
				key     = (key == "{") ? "[" : "]"
				SHIFT   = true
			}

			gTemporarilySetKey(key)

            if  gIsEditIdeaMode {
				if !gTextEditor.handleKey(iKey, flags: flags) {
					if !ANY { return false } // ignore key events which have no modifier keys

					switch key {
						case "a":      gCurrentlyEditingWidget?.selectAllText()
						case "d":      gCurrentlyEditingWidget?.widgetZone?.tearApartCombine(ALL, SPLAYED)
						case "f":      gSearching.showSearch(OPTION)
						case "k":      toggleColorized()
						case "n":      editNote(OPTION)
						case "p":      printCurrentFocus()
						case "t":      if COMMAND, let string = gCurrentlySelectedText { showThesaurus(for: string) }
						case "/":      return handleSlash(flags)
						case kCommaSeparator,
							 kDotSeparator: commaAndPeriod(COMMAND, OPTION, with: key == kCommaSeparator)
						case kTab:     addSibling(OPTION)
						case kSpace:   gSelecting.currentMoveable.addIdea()
						case kReturn:  if COMMAND { editNote(OPTION) }
						case kEscape:               editNote(OPTION, useGrabbed: false)
						case kBackspace,
							 kDelete:  if CONTROL { focusOnTrash() }
						default:       return false // false means key not handled
					}
				}
            } else if isValid(key, flags) {
                let widget = gWidgets.widgetForZone(gSelecting.currentMoveableMaybe)
                
                if  let a = arrow, isWindow {
                    handleArrow(a, flags: flags)
				} else if kMarkingCharacters.contains(key), !COMMAND, !CONTROL, !OPTION {
                    prefix(with: key)
                } else if !super.handleKey(iKey, flags: flags, isWindow: isWindow) {
					let moveable = gSelecting.currentMoveable

					switch key {
						case "a":        if COMMAND { moveable.selectAll(progeny: OPTION) }
						case "b":        gSelecting.firstSortedGrab?.addBookmark()
						case "c":        if  OPTION { divideChildren() } else if COMMAND { gSelecting.simplifiedGrabs.copyToPaste() } else { gMapController?.recenter(SPECIAL) }
						case "d":        if     ALL { gRemoteStorage.removeAllDuplicates() } else if ANY { widget?.widgetZone?.combineIntoParent() } else { duplicate() }
						case "h":        showTraitsPopup()
						case "f":        gSearching.showSearch(OPTION)
						case "i":        grabDuplicatesAndRedraw()
						case "j":        if SPECIAL { gRemoteStorage.recount(); gSignal([.spData]) } else { gSelecting.handleDuplicates(COMMAND) }
						case "k":        toggleColorized()
						case "l":        alterCase(up: false)
						case "n":        editNote(OPTION)
						case "o":        moveable.importFromFile(OPTION ? .eOutline : SPLAYED ? .eCSV : .eSeriously) { gRelayoutMaps() }
						case "p":        printCurrentFocus()
						case "r":        if     ANY { gNeedsRecount = true } else { showReorderPopup() }
						case "s":        gFiles.export(moveable, toFileAs: OPTION ? .eOutline : .eSeriously)
						case "t":        if COMMAND { showThesaurus() } else if SPECIAL { gControllers.showEssay(forGuide: false) } else { swapWithParent() }
						case "u":        if SPECIAL { gControllers.showEssay(forGuide:  true) } else { alterCase(up: true) }
						case "v":        if COMMAND { paste() }
						case "w":        rotateWritable()
						case "x":        return handleX(flags)
						case "z":        if  !SHIFT { gUndoManager.undo() } else { gUndoManager.redo() }
						case "8":        if  OPTION { prefix(with: kSoftArrow, withParentheses: false) } // option-8 is a dot
						case "#":        if gSelecting.hasMultipleGrab { prefix(with: key) } else { debugAnalyze() }
						case "+":        gSelecting.currentMapGrabs.toggleGroupOwnership()
						case "-":        return handleHyphen(COMMAND, OPTION)
						case "'":        gToggleSmallMapMode(OPTION)
						case "/":        return handleSlash(flags)
						case "?":        if CONTROL { openBrowserForFocusWebsite() } else { gCurrentKeyPressed = nil; return false }
						case "[", "]":   go(down: key == "]", SHIFT: SHIFT, OPTION: OPTION, moveCurrent: SPECIAL) { gRelayoutMaps() }
						case kCommaSeparator,
							 kDotSeparator: commaAndPeriod(COMMAND, OPTION, with: key == kCommaSeparator)
						case kTab:       addSibling(OPTION)
						case kSpace:     if CONTROL || OPTION || isWindow { moveable.addIdea() } else { gCurrentKeyPressed = nil; return false }
						case kEquals:    if COMMAND { updateFontSize(up: true) } else { gSelecting.firstSortedGrab?.invokeTravel() { reveal in gRelayoutMaps() } }
						case kBackSlash: mapControl(OPTION)
						case kBackspace,
							 kDelete:    handleDelete(flags, isWindow)
						case kReturn:    if COMMAND { editNote(OPTION) } else { editIdea(OPTION) }
						case kEscape:    editNote(OPTION, useGrabbed: false)
						default:         return false // indicate key was not handled
					}
                }
            }
        }

        gCurrentKeyPressed = nil

		return true // indicate key was handled
    }

    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags, onCompletion: Closure? = nil) {
		if !gIsExportingToAFile {
			if  gTextEditorHandlesArrows || gIsEditIdeaMode {
				gTextEditor.handleArrow(arrow, flags: flags)
			} else if !((flags.isOption && !gSelecting.currentMoveable.userCanMove) || gIsHelpFrontmost) || gIsEssayMode {
				switch arrow {
					case .down,    .up: moveUp  (arrow == .up, flags: flags);                               forceRedraw()
					case .left, .right: moveLeft(arrow == .left, flags: flags, onCompletion: onCompletion); forceRedraw(); return
				}
			}
		}

		onCompletion?()
    }

    func menuType(for key: String, _ flags: ZEventFlags) -> ZMenuType {
        let alterers = "ehlnuw#" + kMarkingCharacters + kReturn
		let  ALTERER = alterers.contains(key)
        let  COMMAND = flags.isCommand
        let  CONTROL = flags.isControl
		let      ANY = COMMAND || CONTROL

        if  !ANY && ALTERER {    return .eAlter
        } else {
			switch key {
				case "f":            return .eFind
				case "z":            return .eUndo
				case "k":            return .eColor
				case "g":            return .eCloud
				case "?", "/":       return .eHelp
				case "o", "s":       return .eFiles
				case "x", kSpace:    return .eChild
				case "b", "t", kTab: return .eParent
				case "d":            return  COMMAND ? .eAlter  : .eParent
				case kDelete:        return  CONTROL ? .eAlways : .eParent
				case kEquals:        return  COMMAND ? .eAlways : .eTravel
				default:             return .eAlways
			}
        }
    }

    override func isValid(_ key: String, _ flags: ZEventFlags, inWindow: Bool = true) -> Bool {
        if !gIsMapOrEditIdeaMode && !gIsEssayMode {
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
            let    paste = select.pasteableZones .count
            let    grabs = select.currentMapGrabs.count
            let    shown = select.currentMapGrabsHaveVisibleChildren
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
            case .eSort:      valid = (grabs > 1 && parent) || (shown && sort)
            case .eUndo:      valid = undo.canUndo
            case .eRedo:      valid = undo.canRedo
            case .eTravel:    valid = mover.isTraveller
            case .eCloud:     valid = gHasInternet && (gCloudStatusIsActive || gCloudStatusIsAvailable)
            default:          break // .eAlways goes here
            }
        }

        return valid
    }

	// MARK: - handlers
	// MARK: -

	@objc func handleTraitsPopupMenu(_ iItem: ZMenuItem) {
		handleTraitsKey(iItem.keyEquivalent)
	}

	@objc func handleTraitsKey(_ key: String) {
		if  let type = ZTraitType(rawValue: key) {
			UNDO(self) { iUndoSelf in
				iUndoSelf.handleTraitsKey(key)
			}

			gTemporarilySetKey(key)
			editTraitForType(type)
		}
	}

	@objc func handleReorderPopupMenu(_ iItem: ZMenuItem) {
		handleReorderKey(iItem.keyEquivalent, iItem.keyEquivalentModifierMask == .shift)
	}

	@objc func handleReorderKey(_ key: String, _ reversed: Bool) {
		if  let type  = ZReorderMenuType(rawValue: key) {
			UNDO(self) { iUndoSelf in
				iUndoSelf.handleReorderKey(key, !reversed)
			}

			gSelecting.simplifiedGrabs.sortBy(type, reversed)
			gRelayoutMaps()
		}
	}

	func handleHyphen(_ COMMAND: Bool = false, _ OPTION: Bool = false) -> Bool {
		if  COMMAND && OPTION {
			convertToTitledLineAndRearrangeChildren()
		} else if OPTION {
			return gSelecting.currentMoveable.convertToFromLine()
		} else if COMMAND {
			updateFontSize(up: false)
		} else {
			addDashedLine()
		}

		return true
	}

	func handleX(_ flags: ZEventFlags) -> Bool {
		if  flags.isCommand {
			delete(permanently: flags.isOption)

			return true
		}

		return moveToDone()
	}

	func handleSlash(_ flags: ZEventFlags) -> Bool {                                // false means not handled here
		if !flags.isAnyMultiple {
			focusOrPopSmallMap(flags, kind: .eSelected)

			return true
		} else if let controller = gHelpController {                                 // should always succeed
			controller.show(flags: flags)

			return true
		}

		return false
	}

	func handleDelete(_ flags: ZEventFlags, _ isWindow: Bool) {
		let CONTROL = flags.isControl
		let SPECIAL = flags.exactlySpecial
		let COMMAND = flags.isCommand
		let  OPTION = flags.isOption
		let     ANY = flags.isAny

		if  CONTROL {
			focusOnTrash()
		} else if OPTION || isWindow || COMMAND {
			delete(permanently: SPECIAL && isWindow, preserveChildren: ANY && isWindow, convertToTitledLine: SPECIAL)
		}
	}

	// MARK: - focus
	// MARK: -

	func focusOnTrash() {
		gTrash?.focusOn() {
			gRelayoutMaps()
		}
	}

	func focusOrPopSmallMap(_ flags: ZEventFlags, kind: ZFocusKind) {
		if  flags.isControl {
			gCurrentSmallMapRecords?.popAndUpdateCurrent()
		} else {
			gRecords?.focusOnGrab(kind, flags.isCommand, shouldGrab: true) { // complex grab logic
				gRelayoutMaps()
			}
		}
	}

	// MARK: - features
	// MARK: -

	func mapControl(_ OPTION: Bool) {
		if !OPTION {
			gMapController?.toggleMaps()
		} else if let root = gRecords?.rootZone {
			gHere = root

			gHere.grab()
		}

		gRelayoutMaps()
	}

	func addSibling(_ OPTION: Bool) {
		gTextEditor.stopCurrentEdit()
		gSelecting.currentMoveable.addNextAndRedraw(containing: OPTION)
	}

	func browseBreadcrumbs(_ out: Bool) {
		if  let here = out ? gHere.parentZone : gBreadcrumbs.nextCrumb(false) {
			let last = gSelecting.currentMapGrabs
			gHere    = here

			here.traverseAllProgeny { child in
				child.collapse()
			}

			gSelecting.grab(last)
			gSelecting.firstGrab?.asssureIsVisible()
			gRelayoutMaps(for: here)
		}
	}

	func duplicate() {
		var grabs = gSelecting.simplifiedGrabs // convert to mutable, otherwise can't invoke duplicate

		grabs.duplicate()
	}

	func updateFontSize(up: Bool) {
		let     delta = CGFloat(up ? 1 : -1)
		var      size = gBaseFontSize + delta
		size          = size.confineBetween(low: 0.0, high: 15.0)
		gBaseFontSize = size

		gRelayoutMaps()
	}

	func addDashedLine(onCompletion: Closure? = nil) {

		// three states:
		// 1) plain line -> insert and edit stub title
		// 2) titled line selected only -> convert back to plain line
		// 3) titled line is first of multiple -> convert titled line to plain title, selected, as parent of others

		let grabs        = gSelecting.currentMapGrabs
		let isMultiple   = grabs.count > 1
		if  let original = gSelecting.currentMoveableLine,
			let name     = original.zoneName {
			let promoteToParent: ClosureClosure = { innerClosure in
				original.convertFromLineWithTitle()

				grabs.moveIntoAndGrab(original) { reveal in
					original.grab()

					gRelayoutMaps {
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
			iChild.grab()
			onCompletion?()
		}
	}

	func showTraitsPopup() {
		applyToMenu { return ZMenu .traitsPopup(target: self, action: #selector(handleTraitsPopupMenu(_:))) }
	}

	func showReorderPopup() {
		applyToMenu { return ZMenu.reorderPopup(target: self, action: #selector(handleReorderPopupMenu(_:))) }
	}

	func applyToMenu(_ createMenu: ToMenuClosure) {
		if  let widget = gSelecting.lastGrab.widget?.textWidget {
			var  point = widget.bounds.bottomRight
			point      = widget.convert(point, to: gMapView).offsetBy(-160.0, -20.0)

			createMenu().popUp(positioning: nil, at: point, in: gMapView)
		}
	}

    func commaAndPeriod(_ COMMAND: Bool, _ OPTION: Bool, with COMMA: Bool) {
        if !COMMAND || (OPTION && COMMA) {
            toggleGrowthAndConfinementModes(changesDirection:  COMMA)
            
            if  gIsEditIdeaMode    && COMMA {
                swapAndResumeEdit()
            }

			gSignal([.spMain, .sDetails, .spBigMap])
        } else if COMMA {
			if !gShowDetailsView {
				gShowDetailsView = true
			} else {
				gDetailsController?.toggleViewsFor(ids: [.vPreferences])
			}

			gSignal([.spMain, .sDetails])
        } else if gIsEditIdeaMode {
            gTextEditor.cancel()
        }
    }

    func toggleColorized() {
        for zone in gSelecting.currentMapGrabs {
            zone.toggleColorized()
        }

        gRelayoutMaps()
    }

	func grabDuplicatesAndRedraw() {
		if  let zones = gSelecting.currentMapGrabs.forDetectingDuplicates {
			gSelecting.ungrabAll()

			if  zones.grabDuplicates() {
				gRelayoutMaps()
			}
		}
	}

	func prefix(with iMark: String, withParentheses: Bool = true) {
		let before = withParentheses ? "("  : kEmpty
		let  after = withParentheses ? ") " : kSpace
        let  zones = gSelecting.currentMapGrabs
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
                    if  withParentheses,
						name.starts(with: before) {
                        let     nameParts = name.components(separatedBy: after)
                        var         index = 0
                        while       index < nameParts.count - 1 {
                            let      mark = nameParts[index]                        // found: "(m"
                            let markParts = mark.components(separatedBy: before)    // markParts[1] == m
							index        += 1

                            if  markParts.count > 1 && markParts[0].count == 0 {
                                let  part = markParts[1]

                                if  part.count <= 2 && part.isDigit {
                                    add   = false
                                    break
                                }
                            }
                        }

                        name              = nameParts[index]            // remove all (m) where m is any character
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

        gRelayoutMaps()
    }

    func divideChildren() {
        let grabs = gSelecting.currentMapGrabs

		for zone in grabs {
			zone.divideEvenly()
		}

		gRelayoutMaps()
    }

    func rotateWritable() {
        for zone in gSelecting.currentMapGrabs {
            zone.rotateWritable()
        }

        gRelayoutMaps()
    }

    func alterCase(up: Bool) {
        for grab in gSelecting.currentMapGrabs {
			if  let tWidget = grab.widget?.textWidget {
                tWidget.alterCase(up: up)
            }
        }
    }

	func go(down: Bool, SHIFT: Bool, OPTION: Bool, moveCurrent: Bool = false, amongNotes: Bool = false, atArrival: Closure? = nil) {
		if  SHIFT || (gHere.isInAGroup && gIsFavoritesMode) {
			gSelecting.currentMoveable.cycleToNextInGroup(!down)
		} else {
			let smallMap = OPTION ? gCurrentSmallMapRecords : gRecents

			smallMap?.go(down: down, amongNotes: amongNotes, moveCurrent: moveCurrent, atArrival: atArrival)
		}
	}

	func debugAnalyze() {
		var count = 0

		for cloud in gRemoteStorage.allClouds {
			cloud.applyToAllOrphans { zone in
				print("orphan: \(zone)")
				count += 1
			}
		}

		print(" total: \(count)")
	}

	// MARK: - edit text
	// MARK: -

	func editIdea(_  OPTION: Bool) {
		gSelecting.currentMoveable.edit()

		if  OPTION {
			gTextEditor.placeCursorAtEnd()
		}
	}

	func editTraitForType(_ type: ZTraitType) {
		gSelecting.firstSortedGrab?.editTraitForType(type)
	}

	func editNote(_  OPTION: Bool, useGrabbed: Bool = true) {
		if !gIsEssayMode {
			gCreateCombinedEssay = !OPTION				             // default is multiple, OPTION drives it to single

			if  gCurrentEssay   == nil || OPTION || useGrabbed {     // restore prior essay or create one fresh (OPTION forces the latter)
				gCurrentEssay    = gSelecting.firstGrab?.note
			}
		}

		gControllers.swapMapAndEssay()
	}

    // MARK: - lines
    // MARK: -
    
    func convertToTitledLineAndRearrangeChildren() {
        delete(preserveChildren: true, convertToTitledLine: true)
    }
	
	func swapWithParent() {
		if  gSelecting.currentMapGrabs.count == 1,
			let zone = gSelecting.firstSortedGrab {
			zone.swapWithParent { gRelayoutMaps(for: zone) }
		}
    }

    func swapAndResumeEdit() {
        let t = gTextEditor
        
        // //////////////////////////////////////////////////////////
        // swap currently editing zone with sibling, resuming edit //
        // //////////////////////////////////////////////////////////
        
        if  let   zone = t.currentlyEditedZone, zone.hasSiblings {
            let upward = gListGrowthMode == .up
            let offset = t.editingOffset(upward)
            
            t.stopCurrentEdit(forceCapture: true)
            zone.ungrab()
            
            gCurrentBrowseLevel = zone.level // so cousin list will not be empty
            
            moveUp(upward, [zone], selectionOnly: false, extreme: false, growSelection: false, targeting: nil) { kind in
                gRelayoutMaps() {
                    t.edit(zone)
                    t.setCursor(at: offset)
                }
            }
        }
    }
    
    // MARK: - cut and paste
    // MARK: -

	func prepareUndoForDelete() {
		gSelecting.clearPaste()

		self.UNDO(self) { iUndoSelf in
			iUndoSelf.undoDelete()
		}
	}

	func undoDelete() {
		gSelecting.ungrabAll()

		for (child, (parent, index)) in gSelecting.pasteableZones {
			child.orphan()
			parent?.addChildAndReorder(child, at: index)
			child.addToGrabs()
		}

		gSelecting.clearPaste()

		UNDO(self) { iUndoSelf in
			iUndoSelf.delete()
		}

		gRelayoutMaps()
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
			grab.expand()
		}

		if  let       parent = candidate?.parentZone {
			let siblingIndex = candidate?.siblingIndex
			var     children = ZoneArray ()

			gSelecting.clearPaste()
			gSelecting.currentMapGrabs = []

			for grab in grabs.reversed() {
				if !convertToTitledLine {       // delete, add to paste
					grab.addToPaste()
					grab.moveZone(to: grab.trashZone)
				} else {                        // convert to titled line and insert above
					grab.convertToTitledLine()
					children.append(grab)
					grab.addToGrabs()
				}

				for child in grab.children.reversed() {
					children.append(child)
					child.addToGrabs()
				}
			}

			for child in children {
				child.orphan()
				parent.addChildAndReorder(child, at: siblingIndex)
			}

			self.UNDO(self) { iUndoSelf in
				iUndoSelf.prepareUndoForDelete()
				children .deleteZones(iShouldGrab: false) {}
				iUndoSelf.pasteInto(parent, honorFormerParents: true)
			}
		}

		onCompletion?()
	}

    func delete(permanently: Bool = false, preserveChildren: Bool = false, convertToTitledLine: Bool = false) {
        gDeferRedraw {
            if  preserveChildren && !permanently {
                self.preserveChildrenOfGrabbedZones(convertToTitledLine: convertToTitledLine) {
                    gFavorites.updateFavoritesAndRedraw {
                        gDeferringRedraw = false
                        
                        gRelayoutMaps()
                    }
                }
            } else if let grab = gSelecting.rootMostMoveable {
				let    inSmall = grab.isInSmallMap  // these three values
				let     parent = grab.parentZone    // are out of date
				let      index = grab.siblingIndex  // after delete zones, below

				prepareUndoForDelete()
                
				gSelecting.simplifiedGrabs.deleteZones(permanently: permanently) {
					gDeferringRedraw = false

					if  inSmall,
						let i  = index,
						let p  = parent {
						let c  = p.count
						if  c == 0 || c <= i {   // no more siblings
							if  p.isInFavorites {
								gFavorites.updateAllFavorites()
							} else if c == 0 {
								gNewOrExistingBookmark(targeting: gHere, addTo: gRecentsHere)  // assure at least one bookmark in recents (targeting here)
							}

							gHere.grab()                                 // as though user clicked on background
						} else {
							let z = p.children[i]

							z.grab()
						}
					}

					gDeferringRedraw = false
					gRelayoutMaps(for: grab)
                }
            }
        }
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
					let  pasteMe = pastable.isInTrash ? pastable : pastable.deepCopy(dbID: nil) // for zones not in trash, paste a deep copy
					let insertAt = index  != nil ? index : gListsGrowDown ? nil : 0
					let     into = parent != nil ? honorFormerParents ? parent! : zone : zone

					pasteMe.orphan()
					into.expand()
					into.addChildAndReorder(pasteMe, at: insertAt)
					pasteMe.recursivelyApplyDatabaseID(into.databaseID)
					forUndo.append(pasteMe)
					pasteMe.addToGrabs()
				}

				self.UNDO(self) { iUndoSelf in
					iUndoSelf.prepareUndoForDelete()
					forUndo.deleteZones(iShouldGrab: false, onCompletion: nil)
					zone.grab()
					gRelayoutMaps()
				}

				if isBookmark {
					self.undoManager.endUndoGrouping()
				}

				gFavorites.updateFavoritesAndRedraw()
			}

			if !isBookmark {
				action()
			} else {
				undoManager.beginUndoGrouping()
				zone.focusOnBookmarkTarget() { (iAny, iSignalKind) in
					action()
				}
			}
		}
	}

    // MARK: - move vertically
    // MARK: -

	func moveToDone() -> Bool {
		if  let   zone = gSelecting.rootMostMoveable,
			let parent = zone.parentZone {
			let  grabs = gSelecting.currentMapGrabs
			var   done = zone.visibleDoneZone

			if  done == nil {
				done  = Zone.uniqueZone(recordName: nil, in: parent.databaseID)
				done?.zoneName = kDone

				done?.moveZone(to: parent)
			}

			for zone in grabs {
				zone.orphan()
			}

			grabs.moveIntoAndGrab(done!) { good in
				done?.grab()
				gRelayoutMaps()
			}

			return true
		}

		return false
	}

	func moveUp(_ iMoveUp: Bool, flags: ZEventFlags) {
		let COMMAND = flags.isCommand
		let  OPTION = flags.isOption
		let   SHIFT = flags.isShift

		move(up: iMoveUp, selectionOnly: !OPTION, extreme: COMMAND, growSelection: SHIFT)
	}

	func move(up iMoveUp: Bool = true, selectionOnly: Bool = true, extreme: Bool = false, growSelection: Bool = false, targeting iOffset: CGFloat? = nil) {
		priorHere     = gHere

		if  let grabs = moveables {
			moveUp(iMoveUp, grabs.reversed(), selectionOnly: selectionOnly, extreme: extreme, growSelection: growSelection, targeting: iOffset) { kinds in
				gSignal(kinds)
			}
		}
	}

	func moveUp(_ iMoveUp: Bool = true, _ originalGrabs: ZoneArray, selectionOnly: Bool = true, extreme: Bool = false, growSelection: Bool = false, targeting iOffset: CGFloat? = nil, forcedResponse: ZSignalKindArray? = nil, onCompletion: SignalArrayClosure? = nil) {
		var       response = forcedResponse ?? [ZSignalKind.spRelayout]
		let   doCousinJump = !gBrowsingIsConfined
		let      hereMaybe = gHereMaybe
		let         isHere = hereMaybe != nil && originalGrabs.contains(hereMaybe!)
		guard let rootMost = originalGrabs.rootMost(goingUp: iMoveUp) else {
			onCompletion?([.sData])

			return
		}

		let rootMostParent = rootMost.parentZone

		if  isHere {
			if  rootMost.isARoot {
				onCompletion?([.sData])
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
						if !isHere {
							response = [.spData, .spCrumbs]
						}

						gSelecting.updateCousinList()
						self.moveUp(iMoveUp, originalGrabs, selectionOnly: selectionOnly, extreme: extreme, growSelection: growSelection, targeting: iOffset, forcedResponse: response, onCompletion: onCompletion)
					} else {
						gFavorites.updateAllFavorites()
						onCompletion?([.spRelayout])
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

						moveThese.moveIntoAndGrab(intoParent, at: newIndex, orphan: true) { reveal in
							gSelecting.grab(moveThese)
							intoParent.children.updateOrder()
							onCompletion?([.spRelayout])
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
						findChildMatching(&grabThis, iMoveUp, iOffset) // TODO: should look at siblings, not children
						grabThis.grab(updateBrowsingLevel: false)

						if !isHere && forcedResponse == nil {
							response = [.spData, .spCrumbs]
						}
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

						if !isHere && forcedResponse == nil {
							response = [.spData, .spCrumbs]
						}
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

				onCompletion?(response)
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

		while grabThis.hasVisibleChildren,
			  let length = grabThis.zoneName?.length {
			let range = NSRange(location: length, length: 0)
			let index = iMoveUp ? grabThis.count - 1 : 0
			let child = grabThis.children[index]

			if  let   offset = iOffset,
				let anOffset = grabThis.widget?.textWidget?.offset(for: range, iMoveUp),
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

	// MARK: - move horizontally
	// MARK: -

	func moveLeft(_ isLeft: Bool, flags: ZEventFlags, onCompletion: Closure? = nil) {
		if  let moveable = gSelecting.rootMostMoveable {
			let  COMMAND = flags.isCommand
			let   OPTION = flags.isOption
			let    SHIFT = flags.isShift

			if !SHIFT || moveable.isInSmallMap {
				move(out: isLeft, selectionOnly: !OPTION, extreme: COMMAND) { neededReveal in
					gSelecting.updateAfterMove(!OPTION, needsRedraw: neededReveal)  // relayout map when travelling through a bookmark
					onCompletion?() // invoke closure from essay editor
				}
			} else {

				// ///////////////
				// GENERATIONAL //
				// ///////////////

				if  OPTION {
					browseBreadcrumbs(isLeft)
				} else {
					moveable.applyGenerationally(!isLeft, extreme: COMMAND)
				}
			}
		}
	}

    func moveOut(selectionOnly: Bool = true, extreme: Bool = false, force: Bool = false, onCompletion: BoolClosure?) {
		if  let zone: Zone = moveables?.first, !zone.isARoot {
			if  selectionOnly {

				// /////////////////
				// MOVE SELECTION //
				// /////////////////

				zone.moveSelectionOut(extreme: extreme, onCompletion: onCompletion)

				return
			} else if let p = zone.parentZone, !p.isARoot {

				// ////////////
				// MOVE ZONE //
				// ////////////

				let grandParentZone = p.parentZone

				if  zone == gHere && !force {
					let grandParentName = grandParentZone?.zoneName
					let   parenthetical = grandParentName == nil ? kEmpty : " (\(grandParentName!))"

					// /////////////////////////////////////////////////////////////////////
					// present an alert asking if user really wants to move here leftward //
					// /////////////////////////////////////////////////////////////////////

					gAlerts.showAlert("WARNING", "This will relocate \"\(zone.zoneName ?? kEmpty)\" to its parent's parent\(parenthetical)", "Relocate", "Cancel") { iStatus in
						if  iStatus == .sYes {
							self.moveOut(selectionOnly: selectionOnly, extreme: extreme, force: true, onCompletion: onCompletion)
						}
					}
				} else {
					let moveOutToHere = { (iHere: Zone?) in
						if  let here = iHere {
							gHere = here

							self.moveOut(to: here, onCompletion: onCompletion)
						}
					}

					if extreme {
						if  gHere.isARoot {
							moveOut(to: gHere, onCompletion: onCompletion)
						} else {
							zone.revealZonesToRoot() {
								moveOutToHere(gRoot)
								onCompletion?(true)
							}

							return
						}
					} else if let gp = grandParentZone {
						let inSmallMap = p.isInSmallMap

						if  inSmallMap {
							p.collapse()
						}

						if  !gIsEssayMode {
							p.revealParentAndSiblings()
						}

						if  gp.spawnedBy(gHere) || gp == gHere {
							moveOut(to: gp, onCompletion: onCompletion)

							return
						} else if inSmallMap {
							moveOut(to: gp) { reveal in
								zone.grab()
								gCurrentSmallMapRecords?.setHere(to: gp)
								onCompletion?(reveal)
							}

							return
						} else {
							moveOutToHere(gp)
						}
					}
				}
			}

			onCompletion?(true)
		}

		onCompletion?(false)
    }
    
    func move(out: Bool, selectionOnly: Bool = true, extreme: Bool = false, onCompletion: BoolClosure?) {
        if  out {
            moveOut (selectionOnly: selectionOnly, extreme: extreme, onCompletion: onCompletion)
        } else {
            moveInto(selectionOnly: selectionOnly, extreme: extreme, onCompletion: onCompletion)
        }
    }

	func moveInto(selectionOnly: Bool = true, extreme: Bool = false, onCompletion: BoolClosure?) {
		if !selectionOnly {
			moveables?.actuallyMoveInto(onCompletion: onCompletion)
		} else if let zone = moveables?.first {
			if  zone.isBookmark {
				zone.invokeBookmark(onCompletion: onCompletion)
			} else if zone.isTraveller && zone.fetchableCount == 0 && zone.count == 0 {
				zone.invokeTravel(onCompletion: onCompletion)
			} else {
				zone.addAGrab(extreme: extreme, onCompletion: onCompletion)
			}
		}
	}

	func moveOut(to into: Zone, onCompletion: BoolClosure?) {
		if  let        zones = moveables?.reversed() as ZoneArray? {
			var completedYet = false

			zones.recursivelyRevealSiblings(untilReaching: into) { iRevealedZone in
				if !completedYet && iRevealedZone == into {
					completedYet = true

					for zone in zones {
						var insert: Int? = zone.parentZone?.siblingIndex // first compute insertion index

						if  zone.parentZone?.parentZone == into,
							let  i = insert {
							insert = i + 1

							if  insert! >= into.count {
								insert   = nil // append at end
							}
						}

						if  let  from = zone.parentZone {
							let index = zone.siblingIndex

							self.UNDO(self) { iUndoSelf in
								zone.moveZone(into: from, at: index, orphan: true) { onCompletion?(true) }
							}
						}

						zone.orphan()

						into.addChildAndReorder(zone, at: insert)
					}

					onCompletion?(true)
				}
			}
		}
	}

}
