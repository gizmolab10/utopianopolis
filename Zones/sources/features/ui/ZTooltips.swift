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

	@objc func updateToolTips()
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
			let    	 OPTION = flags?.isOption  ?? false
			let    	CONTROL = flags?.isControl ?? false
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
				case .sibling: return addANew  + forSibling + " to" + currentIdea
				case .child:   return addANew  + "child to"         + currentIdea
				case .note:    return editing  + " the note of"     + currentIdea
				case .idea:    return editing                       + currentIdea
				case .focus:   return forFocus                      + currentIdea
				case .up,
					 .down:    break
				case .left,
					 .right:   break
				default:       break
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
			let  SHIFT = flags?.isShift  ?? false
			let OPTION = flags?.isOption ?? false

			switch boxID {
				case .move: return SHIFT && !OPTION ? "horizontal arrows conceal and reveal, vertical arrows expand selection" : (OPTION ? "relocate" : "browse to next") + " selected idea"
				default:    break
			}
		}

		return nil
	}

}

extension ZKickoffToolsController {

	func updateToolTips() {
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

	var revealTipSuffix: String {
		var string = kEmpty

		if  count == 0, isTraveller {
			string = count == 0 ? kEmpty : "\n\nor with COMMAND key down, "

			if  hasNote {
				string += "begin editing note"
			} else if hasEmail {
				string += "send an email"
			} else if hasHyperlink {
				string += "invoke web link"
			}
		}

		return string
	}

	func dotToolTipText(_ isReveal: Bool) -> String? {
		if  let    name = zoneName {
			let plainRe =  isReveal  && !isBookmark
			let  noName = count == 0 && isTraveller && plainRe
			let   plain = count == 0  ? kEmpty   : gConcealmentString(for: isExpanded) + " list for "
			let  target = noName      ? kEmpty   : "\"\(name)\""
			let    drag = (isSelected ? kEmpty   : "select or ") + "drag "
			let  reveal = !isBookmark ? plain    : "change focus to "
			let  action =  isReveal   ? reveal   : drag
			let   title = (isReveal   ? "Reveal" : "Drag") + " dot\n\n"
			let  suffix = !plainRe    ? kEmpty   : revealTipSuffix
			let   extra =  plainRe    ? kEmpty   : "target of "
			let    text = title + action + extra + target + suffix

			return text
		}

		return nil
	}

	func updateToolTips() { widget?.updateToolTips() }
	func clearToolTips()  { widget?.clearToolTips() }

}

extension ZoneWidget {

	func updateToolTips() {
		parentLine?.dragDot?.updateToolTips()

		for child in childrenLines {
			child.revealDot?.updateToolTips()
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

	func updateToolTips() {
		clearToolTips()

		if  toolTipIsVisible {
			toolTip = widgetZone?.dotToolTipText(isReveal)
		}
	}

}

extension ZBannerButton {

	func clearToolTips() { toolTip = nil }

	func updateToolTips() {
		clearToolTips()

		if  gShowToolTips,
			let view = togglingView {
			toolTip  = "\(view.hideHideable ? "view" : "hide") \(view.toolTipText)"
		}
	}

}

extension ZoneTextWidget {

	func clearToolTips() { toolTip = nil }

	func updateToolTips() {
		clearToolTips()

		if  gShowToolTips,
			let name = widgetZone?.zoneName {
			toolTip  = "Idea\n\nedit \"\(name)\""
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

	func updateAllToolTips() {
		if  let widgets = allWidgets(for: .tIdea) {
			for widget in widgets {
				widget.updateToolTips()
			}
		}
	}

	func clearAllToolTips() {
		if  let widgets = allWidgets(for: .tIdea) {
			for widget in widgets {
				widget.clearToolTips()
			}
		}
	}

	func removeToolTipsFromAllWidgets(for controller: ZMapController) {
		if  let type = controller.hereZone?.widgetType {
			clearAllToolTips(for: type)
		}
	}

	func clearAllToolTips(for type: ZWidgetType) {
		let registry = getZoneWidgetRegistry(for: type)

		registry?.clearAllToolTips()
	}

}

extension ZMapControlsView {

	func updateToolTips() {
		for button in buttons {
			button.toolTip = nil

			if  gShowToolTips,
				let     type = button.modeButtonType {
				let browsing = "vertical browsing"
				var      tip : String?

				switch type {
				case .tLayout:  tip = "Arrangement\n\narrange ideas as a \(gMapLayoutMode == .circularMode ? "tree" : "starburst")"
				case .tGrowth:  tip = "Growth direction\n\ngrow lists \(gListsGrowDown ? "up" : "down")ward or browse (rightward) to the \(gListsGrowDown ? "top" : "bottom")"
				case .tConfine: tip = "Browsing confinement\n\n\(gBrowsingIsConfined ? "allow unconfined \(browsing)" : "confine \(browsing) within current list")"
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

extension ZToolTipButton {

	@objc func updateToolTips() {}
	@objc func clearToolTips() {}

}

extension ZBreadcrumbButton {

	override func clearToolTips() { toolTip = nil }

	override func updateToolTips() {
		clearToolTips()

		if  gShowToolTips {
			var  body : String?
			let title = "Breadcrumb\n\n"
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
