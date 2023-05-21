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

@objc (ZoneContextualMenu)
class ZoneContextualMenu: ZContextualMenu {

	var textWidget: ZoneTextWidget?
	var zone: Zone? { return textWidget?.widgetZone }

	@IBAction override func genericMenuHandler(_ iItem: ZMenuItem?) {
		if  let item = iItem,
			let w = textWidget,
			w.validateMenuItem(item) {
			let key = item.keyEquivalent

			handleKey(key)
		}
	}

	override func handleKey(_ key: String) {
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

			handleKey(key)
		}
	}

	func handleKey(_ key: String) {
		switch key {
			case kEquals,
			kHyphen: gUpdateBaseFontSize(up: key == kEquals)
			case "c":     gMapController?.recenter()
			case "e":     gToggleShowExplanations()
			case "k":     gColorfulMode = !gColorfulMode; gSignal([.sDatum])
			case "y":     gToggleShowToolTips()
			default:  break
		}
	}

}

extension ZMenu {

	static func handleMenu() {}

	static func specialCharactersPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "add a special character")

		for type in gActiveSpecialCharacters {
			menu.addItem(specialsItem(type: type, target: target, action: action))
		}

		menu.addItem(ZMenuItem.separator())
		menu.addItem(specialsItem(type: .eCancel, target: target, action: action))

		return menu
	}

	static func specialsItem(type: ZSpecialCharactersMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
		let  	  item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
		item.isEnabled = true
		item.target    = target

		if  type != .eCancel {
			item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)
		}

		return item
	}

	static func mutateTextPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "change text")

		for type in ZMutateTextMenuType.allTypes {
			menu.addItem(mutateTextItem(type: type, target: target, action: action))
		}

		return menu
	}

	static func mutateTextItem(type: ZMutateTextMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
		let  	  item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
		item.isEnabled = true
		item.target    = target
		item.keyEquivalentModifierMask = ZEventFlags(rawValue: 0)

		return item
	}

	static func reorderPopup(target: AnyObject, action: Selector) -> ZMenu {
		let menu = ZMenu(title: "reorder")

		for type in gActiveReorderTypes {
			menu.addItem(reorderingItem(type: type, target: target, action: action))

			if  type != .eReversed {
				menu.addItem(reorderingItem(type: type, target: target, action: action, flagged: true))
			}

			menu.addItem(.separator())
		}

		return menu
	}

	static func reorderingItem(type: ZReorderMenuType, target: AnyObject, action: Selector, flagged: Bool = false) -> ZMenuItem {
		let                      title = flagged ? "\(type.title) reversed" : type.title
		let                       item = ZMenuItem(title: title, action: action, keyEquivalent: type.rawValue)
		item.keyEquivalentModifierMask = flagged ? ZEventFlags.shift : ZEventFlags(rawValue: 0)
		item                   .target = target
		item                .isEnabled = true

		return item
	}

	enum ZRefetchMenuType: String {
		case eList    = "l"
		case eIdeas   = "g"
		case eAdopt   = "a"
		case eTraits  = "t"
		case eProgeny = "p"

		var title: String {
			switch self {
				case .eList:    return "list"
				case .eAdopt:   return "adopt"
				case .eIdeas:   return "all ideas"
				case .eTraits:  return "all traits"
				case .eProgeny: return "all progeny"
			}
		}
	}

	static func refetchPopup(target: AnyObject, action: Selector) -> ZMenu {
		let types: [ZRefetchMenuType] = [.eIdeas, .eTraits, .eProgeny, .eList, .eAdopt]
		let menu = ZMenu(title: "refetch")

		for type in types {
			menu.addItem(refetchingItem(type: type, target: target, action: action))
		}

		return menu
	}

	static func refetchingItem(type: ZRefetchMenuType, target: AnyObject, action: Selector) -> ZMenuItem {
		let                       item = ZMenuItem(title: type.title, action: action, keyEquivalent: type.rawValue)
		item.keyEquivalentModifierMask = ZEvent.ModifierFlags(rawValue: 0)
		item                   .target = target
		item                .isEnabled = true

		return item
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

			handleKey(key, flags: flags, isWindow: true)
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
		let  menu = ZMenu.specialCharactersPopup(target: self, action: #selector(handleSpecialsPopupMenu(_:)))
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
		let  menu = ZMenu.specialCharactersPopup(target: self, action: #selector(handleSymbolsPopupMenu(_:)))
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
