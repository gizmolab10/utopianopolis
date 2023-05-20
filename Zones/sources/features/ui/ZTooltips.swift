//
//  ZToolTips.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/14/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZControlType {
	case eInsertion
	case eConfined
	case eToolTips
}

@objc protocol ZToolTipper {

	@objc func updateToolTips(_ flags: ZEventFlags)
	@objc func clearToolTips()

}

protocol ZIdentifiable {

	var recordName: String? { get }
	func identifier() -> String?
	static func object(for id: String, isExpanded: Bool) -> NSObject?

}

protocol ZToolable {

	func toolName()  -> String?
	func toolColor() -> ZColor?

}

extension ZDirection {

	var toolTipString : String? {        return gShowToolTips ? "Resize image\r\rClick and drag to resize \(description)" : nil }

	var description   : String {
		switch self {
			case .top, .bottom:          return "vertically"
			case .left, .right:          return "horizontally"
			case .topLeft, .bottomRight: return "vertically and horizontally, retaining aspect ratio"
			default:                     return "vertically and horizontally"
		}
	}

}

extension ZNote {

	func toolTipString(grabbed: Bool) -> String? {
		if  gShowToolTips {
			let prefix = grabbed ? "This note is selected" : "select this note"

			return "\(prefix)\r\rTo move it, hold down the OPTION key and tap a vertical arrow key"
		}

		return nil
	}

}

extension ZKickoffToolButton {

	var toolTipString : String? {
		if  gShowToolTips,
			let    buttonID = kickoffToolID {
			let   canTravel = gIsMapMode && gGrabbedCanTravel
			let       flags = gKickoffToolsController?.flags
			let    	 OPTION = flags?.hasOption  ?? false
			let    	CONTROL = flags?.hasControl ?? false
			let     addANew = "adds a new idea as "
			let     editing = (!gIsEditing ? "edits" : "stops editing and save to")
			let notMultiple = gSelecting.currentMapGrabs.count < 2
			let   adjective = notMultiple ? kEmpty : "\(gListsGrowDown ? "bottom" : "top")- or left-most "
			let currentIdea = " the \(adjective)currently selected idea"
			let     unfocus = "from favorites, remove bookmark targeting"
			let       focus = (gSelecting.movableIsHere ? "creates a favorite from" : (canTravel ? "travel to target of" : "focus on"))
			let    forFocus = CONTROL ? unfocus  : focus
			let  forSibling = OPTION  ? "parent" : "sibling"

			switch buttonID {
				case .tSibling: return addANew  + forSibling + " to" + currentIdea
				case .tChild:   return addANew  + "child to"         + currentIdea
				case .tNote:    return editing  + " the note of"     + currentIdea
				case .tIdea:    return editing                       + currentIdea
				case .tFocus:   return forFocus                      + currentIdea
				case .tUp,
					 .tDown:    break
				case .tLeft,
					 .tRight:   break
				default:        break
			}
		}

		return nil
	}

}

extension ZBox {

	var toolTipString : String? {
		if  gShowToolTips,
			let  boxID = kickoffToolID {
			let  flags = gKickoffToolsController?.flags
			let  SHIFT = flags?.hasShift  ?? false
			let OPTION = flags?.hasOption ?? false

			switch boxID {
				case .tMove: return SHIFT && !OPTION ? "horizontal arrows conceal and reveal, vertical arrows expand selection" : (OPTION ? "relocate" : "browse to next") + " selected idea"
				default:    break
			}
		}

		return nil
	}

}

extension ZKickoffToolsController {

	func updateToolTips(_ flags: ZEventFlags) {
		view.applyToAllSubviews { subview in
			if  let     button = subview as? ZKickoffToolButton {
				button.toolTip = button.toolTipString
			} else if  let box = subview as? ZBox {
				box   .toolTip = box   .toolTipString
			}
		}
	}

	func clearToolTips() {
		view.applyToAllSubviews { subview in
			if  let     button = subview as? ZKickoffToolButton {
				button.clearToolTips()
			} else if  let box = subview as? ZBox {
				box   .toolTip = nil
			}
		}
	}

}

extension Zone {

	func updateToolTips(_ flags: ZEventFlags) { widget?.updateToolTips(flags) }
	func clearToolTips()                      { widget?.clearToolTips() }

	func dotToolTipText(_ isReveal: Bool, _ flags: ZEventFlags) -> String {
		let COMMAND = flags.hasCommand
		let  prefix = "This is a"
		let noChild = count      == 0
		let special =  COMMAND   || noChild
		let  oneGen = !COMMAND   || isExpanded || isTraveller
		let   title = (isReveal   ? "Reveal"    : "Drag")       + " dot\n\n"
		let    list = oneGen      ? "list for"  : "entire hierarchy of"
		let    drag = (isSelected ? kEmpty      : "select or ") + "drag"
		var  action = noChild     ? kEmpty      : gConcealmentString(hide: isExpanded) + " \(list) "
		var    name = zoneName   ?? kEmptyIdea

		if  !isReveal {
			action     = drag
		} else if     isTraveller, special {
			if        hasEmail {
				action = "send an email to"
				name   = email     ?? name
			} else if hasHyperlink {
				action = "visit website at"
				name   = hyperLink ?? name
			} else if hasNote, (COMMAND || !isBookmark) {
				action = "edit note of"
				if    isBookmark {
					action += " target of"
				}
			} else if isBookmark {
				action = "change focus to"
			}
		}

		return prefix + title + action + kSpace + kDoubleQuote + name + kDoubleQuote
	}

}

extension ZoneWidget {

	func updateToolTips(_ flags: ZEventFlags) {
		parentLine?.dragDot?.updateToolTips(flags)

		for child in childrenLines {
			child.revealDot?.updateToolTips(flags)
		}
	}

	func clearToolTips() {
		parentLine?.dragDot?.clearToolTips()

		for child in childrenLines {
			child.revealDot?.clearToolTips()
		}
	}

}

extension ZoneDot {

	var toolTipIsVisible: Bool { return gShowToolTips && dotIsVisible }
	func clearToolTips() { toolTip = nil }

	func updateToolTips(_ flags: ZEventFlags) {
		clearToolTips()

		if  toolTipIsVisible {
			toolTip = widgetZone?.dotToolTipText(isReveal, flags)
		}
	}

}

extension ZBannerButton {

	func clearToolTips() { toolTip = nil }

	func updateToolTips(_ flags: ZEventFlags) {
		clearToolTips()

		if  gShowToolTips,
			let view = togglingView {
			toolTip  = "\(view.hideHideable ? "view" : "hide") \(view.toolTipText)"
		}
	}

}

extension ZoneTextWidget {

	func clearToolTips() { toolTip = nil }

	func updateToolTips(_ flags: ZEventFlags) {
		clearToolTips()

		if  gShowToolTips,
			let name = widgetZone?.zoneName {
			toolTip  = "This is an Idea\n\nedit \"\(name)\""
		}

		updateTracking() // needed because text field is a subview of the map, not the text widget
	}

}

extension WidgetHashDictionary {

	mutating func clear() {
		clearAllToolTips()
		removeAll()
	}

	func clearAllToolTips() {
		for widget in values {
			widget.clearToolTips()
		}
	}

}

extension ZWidgets {

	func updateAllToolTips(_ flags: ZEventFlags) {
		if  let widgets = allWidgets(forExemplar: false) {
			for widget in widgets {
				widget.updateToolTips(flags)
			}
		}
	}

	func clearAllToolTips(for type: ZRelayoutMapType = .both) {
		if  let widgets = allWidgets(forExemplar: false) {
			for widget in widgets {
				widget.clearToolTips()
			}
		}
	}

	func removeToolTipsFromAllWidgets(for controller: ZMapController) {
		clearAllToolTips(for: controller.mapType)
	}

	func clearAllToolTips(for type: ZMapType) {
		let registry = getZoneWidgetRegistry(for: type)

		registry?.clearAllToolTips()
	}

}

extension ZMapControlsView {

	func updateToolTips(_ flags: ZEventFlags) {
		for button in buttons {
			button.toolTip = nil

			if  gShowToolTips,
				let     type = button.modeButtonType {
				var      tip : String?

				switch type {
					case .tBack:    break
					case .tForward: break
					case .tGrowth:  tip = "Growth direction\n\nCurrently new child ideas are added at (and browsing to the right goes to) the \(gListsGrowDown ? "bottom" : "top"). Click to change."
					case .tConfine: tip = "Browsing confinement\n\nCurrently vertical browsing is \(gBrowsingIsConfined ? "confined within the list" : "unconfined"). Click to change."
				}

				if  let t = tip {
					button.toolTip = t
					button.updateTrackingAreas()
				}
			}
		}
	}

	func clearToolTips() {
		for button in buttons {
			button.toolTip = nil
		}
	}

}

extension ZHoverableButton {

	func updateToolTips(_ flags: ZEventFlags) { toolTip = "Arrangement\n\narrange ideas as a \(gMapLayoutMode == .circularMode ? "tree" : "starburst")"}
	func clearToolTips()                      { toolTip = nil }

}

extension ZBreadcrumbButton {

	override func clearToolTips() { toolTip = nil }

	override func updateToolTips(_ flags: ZEventFlags) {
		clearToolTips()

		if  gShowToolTips {
			var  body : String?
			let title = "This is a Breadcrumb\n\n"
			let  name = "\"\(zone.unwrappedName)\""
			let alter = zone.ancestralPath.contains(gHere) ? "shrink" : "expand"

			if  gIsEssayMode {
				body = "show map, focused on "
			} else if  zone == gHereMaybe {
				body = "current focus is "
			} else if zone.isGrabbed {
				body = "currently selected idea is "
			} else {
				body = alter + " focus to "
			}

			if  let b = body {
				toolTip = title + b + name
			}
		}
	}

}
