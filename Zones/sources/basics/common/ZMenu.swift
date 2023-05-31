//
//  ZMenu.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/20/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZReorderMenuType: String {
	case eAlphabetical = "a"
	case eByLength     = "l"
	case eByDate       = "d"
	case eByKind       = "k"
	case eReversed     = "r"
	case eBySizeOfList = "s"

	var title: String {
		switch self {
			case .eAlphabetical: return "alphabetically"
			case .eReversed:     return "reverse order"
			case .eByLength:     return "by length of idea"
			case .eBySizeOfList: return "by size of list"
			case .eByKind:       return "by kind of idea"
			case .eByDate:       return "by date of idea"
		}
	}

}

enum ZSpecialCharactersMenuType: String {
	case eCommand   = "c"
	case eOption    = "o"
	case eShift     = "s"
	case eControl   = "n"
	case eCopyright = "g"
	case eReturn    = "r"
	case eArrow     = "i"
	case eBack      = "k"
	case eCancel    = "\r"

	var both: (String, String) {
		switch self {
			case .eCopyright: return ("©",  "Copyright")
			case .eControl:   return ("^",  "Control")
			case .eCommand:   return ("⌘",  "Command")
			case .eOption:    return ("⌥",  "Option")
			case .eReturn:    return ("􀅇", "Return")
			case .eCancel:    return ("",   "Cancel")
			case .eShift:     return ("⇧",  "Shift")
			case .eArrow:     return ("⇨",  "⇨")
			case .eBack:      return ("⇦",  "⇦")
		}
	}

	var text: String {
		let (insert, _) = both

		return insert
	}

	var title: String {
		let (_, title) = both
		return title
	}

}

enum ZEssayLinkType: String {
	case hWeb   = "h"
	case hFile  = "u"
	case hIdea  = "i"
	case hNote  = "n"
	case hEssay = "e"
	case hEmail = "m"
	case hClear = "c"

	var title: String {
		switch self {
			case .hWeb:   return "Internet"
			case .hFile:  return "Upload"
			case .hIdea:  return "Idea"
			case .hNote:  return "Note"
			case .hEssay: return "Essay"
			case .hEmail: return "Email"
			case .hClear: return "Clear"
		}
	}

	var linkDialogLabel: String {
		switch self {
			case .hWeb:   return "Text of link"
			case .hEmail: return "Email address"
			default:      return "Name of file"
		}
	}

	var linkType: String {
		switch self {
			case .hWeb:   return "http"
			case .hEmail: return "mailto"
			default:      return title.lowercased()
		}
	}

	static var all: [ZEssayLinkType] { return [.hWeb, .hIdea, .hEmail, .hNote, .hEssay, .hFile, .hClear] }

}

func gIsDuplicate(event: ZEvent? = nil, item: ZMenuItem? = nil) -> Bool {
	if  let e  = event {
		if  e == gCurrentEvent {
			return true
		} else {
			gCurrentEvent = e
		}
	}

	if  item != nil {
		return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4)
	}

	return false
}

func gSpecialCharactersPopup(target: AnyObject, action: Selector) -> ZMenu {
	let menu = ZMenu(title: "add a special character")

	for type in gActiveSpecialCharacters {
		menu.addItem(gSpecialsItem(type: type, target: target, action: action))
	}

	menu.addItem(ZMenuItem.separator())
	menu.addItem(gSpecialsItem(type: .eCancel, target: target, action: action))

	return menu
}

func gSpecialsItem(type: ZSpecialCharactersMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
	let  	  item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
	item.isEnabled = true
	item.target    = target

	if  type != .eCancel {
		item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)
	}

	return item
}

func gMutateTextPopup(target: AnyObject, action: Selector) -> ZMenu {
	let menu = ZMenu(title: "change text")

	for type in ZMutateTextMenuType.allTypes {
		menu.addItem(gMutateTextItem(type: type, target: target, action: action))
	}

	return menu
}

func gMutateTextItem(type: ZMutateTextMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
	let  	  item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
	item.isEnabled = true
	item.target    = target
	item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)

	return item
}

func gReorderPopup(target: AnyObject, action: Selector) -> ZMenu {
	let menu = ZMenu(title: "reorder")

	for type in gActiveReorderTypes {
		menu.addItem(gReorderingItem(type: type, target: target, action: action))

		if  type != .eReversed {
			menu.addItem(gReorderingItem(type: type, target: target, action: action, flagged: true))
		}

		menu.addItem(.separator())
	}

	return menu
}

func gReorderingItem(type: ZReorderMenuType, target: AnyObject, action: Selector, flagged: Bool = false) -> ZMenuItem {
	let                      title = flagged ? "\(type.title) reversed" : type.title
	let                       item = ZMenuItem(title: title, action: action, keyEquivalent: type.rawValue)
	item.keyEquivalentModifierMask = flagged ? ZEventFlags.shift : ZEventFlags(rawValue: 0)
	item                   .target = target
	item                .isEnabled = true

	return item
}

@objc (ZoneContextualMenu)
class ZoneContextualMenu: ZContextualMenu {

	var textWidget: ZoneTextWidget?
	var zone: Zone? { return textWidget?.widgetZone }

	@IBAction override func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let item = iItem,
			let w = textWidget,
			w.validateMenuItem(item) {
			let key = item.keyEquivalent

			handleKeyInContextMenu(key)
		}
	}

	override func handleKeyInContextMenu(_ key: String) {
		if  ["l", "u"].contains(key) {
			textWidget?.alterCase(up: key == "u")
		} else {
			zone?.handleContextualMenuKey(key)
		}
	}

}

class ZContextualMenu: ZMenu {

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let item = iItem {
			let  key = item.keyEquivalent

			handleKeyInContextMenu(key)
		}
	}

	func handleKeyInContextMenu(_ key: String) {
		switch key {
			case kEquals,
			kHyphen: gUpdateBaseFontSize(up: key == kEquals)
			case "c":     gMapController?.recenter()
			case "e":     gToggleShowExplanations()
			case "k":     gColorfulMode = !gColorfulMode; gDispatchSignals([.sDatum])
			case "y":     gToggleShowToolTips()
			default:  break
		}
	}

}

extension ZBaseEditor {

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gAppDelegate?.genericMenuHandler(iItem) }
	@objc func invalidMenuItemAlert(_ menuItem: ZMenuItem) -> ZAlert? { return nil }

	func handleMenuItem(_ iItem: ZMenuItem?) {
		if  canHandleKey,
			let   item = iItem {
			let  flags = item.keyEquivalentModifierMask
			let    key = item.keyEquivalent

			handleKeyInMapEditor(key, flags: flags, isWindow: true)
		}
	}

	public func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
		return isValid(menuItem.keyEquivalent, menuItem.keyEquivalentModifierMask)
	}

}

extension ZTraitType {

	func traitsItem(target: AnyObject, action: Selector) -> ZMenuItem {
		let                      title = title ?? ""
		let                       item = ZMenuItem(title: title, action: action, keyEquivalent: rawValue)
		item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)
		item                   .target = target
		item                .isEnabled = true

		return item
	}

}

extension ZTraitTypesArray {

	func traitsPopup(target: AnyObject, action: Selector, zone: Zone) -> ZMenu {
		let menu = ZMenu(title: "traits")

		for type in self {
			let item = type.traitsItem(target: target, action: action)

			if  zone.hasTrait(for: type) {
				item.state = .on
			}

			menu.addItem(item)
		}

		return menu
	}

}

extension ZApplication {

	override func validateMenuItem(_ iItem: ZMenuItem?) -> Bool {
		if  let   item = iItem,
			let editor = gAppDelegate?.workingEditor {
			return editor.validateMenuItem(item)
		}

		return false
	}

}

extension ZDesktopAppDelegate {

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let   item = iItem,
			let editor = workingEditor {
			if  editor.validateMenuItem(item) {
				editor.handleMenuItem(item)
			} else if let alert = editor.invalidMenuItemAlert(item) {
				alert.runModal()
			}
		}
	}

}

extension ZTextEditor {

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) {
		gAppDelegate?.genericMenuHandler(iItem)
	}

	func showSpecialCharactersPopup() {
		let  menu = gSpecialCharactersPopup(target: self, action: #selector(handleSpecialsPopupMenu(_:)))
		let point = CGPoint(x: -165.0, y: -60.0)

		menu.popUp(positioning: nil, at: point, in: gTextEditor.currentTextWidget)
	}

	@objc func handleSpecialsPopupMenu(_ iItem: ZMenuItem) {
		if  let  type = ZSpecialCharactersMenuType(rawValue: iItem.keyEquivalent),
			let range = selectedRanges[0] as? NSRange,
			type     != .eCancel {
			let  text = type.text

			insertText(text, replacementRange: range)
		}
	}

}

extension ZEssayView {

	// MARK: - special characters
	// MARK: -

	func showSpecialCharactersPopup() {
		let  menu = gSpecialCharactersPopup(target: self, action: #selector(handleSymbolsPopupMenu(_:)))
		let point = selectionRect.origin.offsetBy(-165.0, -60.0)

		menu.popUp(positioning: nil, at: point, in: self)
	}

	@objc func handleSymbolsPopupMenu(_ iItem: ZMenuItem) {
		if  let type = ZSpecialCharactersMenuType(rawValue: iItem.keyEquivalent),
			type    != .eCancel {
			let text = type.text

			insertText(text, replacementRange: selectedRange)
		}
	}

	// MARK: - images
	// MARK: -

	func showImagesPopupMenu(for zone: Zone) {

	}

	func imagesPopup(target: AnyObject, action: Selector) -> ZMenu {
		return ZMenu()
	}

	// MARK: - hyperlinks
	// MARK: -

	func showLinkPopup() {
		let menu = ZMenu(title: "create a link")
		menu.autoenablesItems = false

		for type in ZEssayLinkType.all {
			menu.addItem(item(type: type))
		}

		menu.popUp(positioning: nil, at: selectionRect.origin, in: self)
	}

	func item(type: ZEssayLinkType) -> ZMenuItem {
		let  	  item = ZMenuItem(title: type.title, action: #selector(handleLinkPopupMenu(_:)), keyEquivalent: type.rawValue)
		item   .target = self
		item.isEnabled = true

		item.keyEquivalentModifierMask = ZEvent.ModifierFlags(rawValue: 0)

		return item
	}

	@objc func handleLinkPopupMenu(_ iItem: ZMenuItem) {
		if  let   type = ZEssayLinkType(rawValue: iItem.keyEquivalent) {
			let  range = selectedRange
			let showAs = textStorage?.string.substring(with: range)
			var   link : String? = type.linkType + kColon

			func setLink(to appendToLink: String?, replacement: String? = nil) {
				if  let a = appendToLink, !a.isEmpty {
					link?.append(a)
				} else {
					link  = nil  // remove existing hyperlink
				}

				if  link == nil {
					textStorage?.removeAttribute(.link,               range: range)
				} else {
					textStorage?   .addAttribute(.link, value: link!, range: range)
				}

				if  let r = replacement {
					textStorage?.replaceCharacters(in: range, with: r)
				}

				selectAndScrollTo(range)
			}

			func displayUploadDialog() {
				gPresentOpenPanel() {  iAny in
					if  let      url = iAny as? URL {
						let    asset = CKAsset(fileURL: url)
						if  let file = gDatabaseID.uniqueFile(asset),
							let name = file.recordName {

							setLink(to: name, replacement: showAs)
						}
					} else if let panel = iAny as? NSPanel {
						panel.title = "Import"
					}
				}
			}

			func displayLinkDialog() {
				gEssayController?.modalForLink(type: type, showAs) { path, replacement in
					setLink(to: path, replacement: replacement)
				}
			}

			switch type {
				case .hEmail,
						.hWeb:   displayLinkDialog()
				case .hFile:  displayUploadDialog()
				case .hClear: setLink(to: nil)
				default:      setLink(to: gSelecting.pastableRecordName)
			}
		}
	}

}

extension ZMapEditor {

	enum ZMenuType: Int {
		case eUndo
		case eHelp
		case eSort
		case eFind
		case eColor
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

	func menuType(for key: String, _ flags: ZEventFlags) -> ZMenuType {
		let alterers = "hluw#" + kMarkingCharacters + kReturn
		let  ALTERER = alterers.contains(key)
		let  COMMAND = flags.hasCommand
		let  CONTROL = flags.hasControl
		let      ANY = COMMAND || CONTROL

		if  !ANY && ALTERER {    return .eAlter
		} else {
			switch key {
				case "f":               return .eFind
				case "z":               return .eUndo
				case "k":               return .eColor
				case "g":               return .eCloud
				case "o", "s":          return .eFiles
				case kQuestion, kSlash: return .eHelp
				case "x", kSpace:       return .eChild
				case "b", "t", kTab:    return .eParent
				case "d":               return  COMMAND ? .eAlter  : .eParent
				case kDelete:           return  CONTROL ? .eAlways : .eParent
				case kEquals:           return  COMMAND ? .eAlways : .eTravel
				default:                return .eAlways
			}
		}
	}

	override func invalidMenuItemAlert(_ menuItem: ZMenuItem) -> ZAlert? {
		let     type = menuType(for: menuItem.keyEquivalent, menuItem.keyEquivalentModifierMask)
		let subtitle = type != .eTravel ? "is not editable" : "cannot be activated"
		let   prefix = type != .eParent ? kEmpty : "parent of "
		let selected = "selected item "

		return gAlerts.alert("Menu item disabled", prefix + selected + subtitle, "OK", nil, nil, nil)
	}

}

extension ZMapView {

	override func menu(for event : ZEvent) -> ZMenu? {
		return controller?.mapContextualMenu
	}

}

extension ZoneTextWidget {

	public func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
		return true
	}

	override func menu(for event: ZEvent) -> ZMenu? {
		let         contextualMenu = controller?.ideaContextualMenu
		contextualMenu?.textWidget = self

		return contextualMenu
	}

}
