//
//  ZTooltips.swift
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

@objc protocol ZTooltips {

	@objc func updateTooltips()

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

	func tooltipString(grabbed: Bool) -> String? {
		if  gShowToolTips {
			let prefix = grabbed ? "This note is selected" : "select this note"

			return "\(prefix)\r\rTo move it, hold down the OPTION key and tap a vertical arrow key"
		}

		return nil
	}

}

extension ZSimpleToolButton {

	var tooltipString : String? {
		if  gShowToolTips,
			let    buttonID = simpleToolID {
			let   canTravel = gIsMapMode && gGrabbedCanTravel
			let       flags = gSimpleToolsController?.flags
			let    	 OPTION = flags?.isOption  ?? false
			let    	CONTROL = flags?.isControl ?? false
			let     addANew = "adds a new idea as "
			let     editing = (!gIsEditing ? "edits" : "stops editing and save to")
			let notMultiple = gSelecting.currentMapGrabs.count < 2
			let   adjective = notMultiple ? kEmpty : "\(gListsGrowDown ? "bottom" : "top")- or left-most "
			let currentIdea = " the \(adjective)currently selected idea"
			let     unfocus = "from \(gCurrentSmallMapName)s, remove bookmark targeting"
			let       focus = (gSelecting.movableIsHere ? "creates a \(gCurrentSmallMapName) from" : (canTravel ? "travel to target of" : "focus on"))
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

	var tooltipString : String? {
		if  gShowToolTips,
			let  boxID = simpleToolID {
			let  flags = gSimpleToolsController?.flags
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

extension ZSimpleToolsController {

	func updateTooltips() {
		view.applyToAllSubviews { subview in
			if  let     button = subview as? ZSimpleToolButton {
				button.toolTip = button.tooltipString
			} else if  let box = subview as? ZBox {
				box   .toolTip = box   .tooltipString
			}
		}
	}

}

func gConcealmentString(for hide: Bool) -> String {
	return (hide ? "hide" : "reveal")
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

	func dotTooltip(_ isReveal: Bool) -> String? {
		if  let   name = zoneName {
			let target = (count == 0 && isTraveller && isReveal) ? kEmpty : "\"\(name)\""
			let  plain =  count == 0 ? kEmpty : gConcealmentString(for: isExpanded) + " list for "
			let  extra = isBookmark  && !isReveal ? " bookmark of " : kEmpty
			let reveal = isBookmark  ? "change focus to " : plain
			let   drag = isGrabbed   ? "drag " : "select or drag "
			let  title = (isReveal   ? "Reveal" : "Drag") + " dot\n\n"
			let action = isReveal    ? reveal : drag
			let suffix = isReveal    ? revealTipSuffix : kEmpty
			let   text = title + action + extra + target + suffix

			return text
		}

		return nil
	}

	func updateToolTips() { widget?.updateToolTips() }

}

extension ZoneWidget {

	func updateToolTips() {
		textWidget?.updateTooltips()
		parentLine?.dragDot?.updateTooltips()

		for child in childrenLines {
			child.revealDot?.updateTooltips()
		}
	}

}

extension ZoneDot {

	func updateTooltips() {
		toolTip = !gShowToolTips ? nil : widgetZone?.dotTooltip(isReveal)
	}

}

extension ZBannerButton {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let view = togglingView {
			toolTip  = "\(view.hideHideable ? "view" : "hide") \(view.toolTipText)"
		}
	}

}

extension ZoneTextWidget {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let name = widgetZone?.zoneName {
			toolTip  = "Idea text\n\nedit \"\(name)\""
		}

		updateTracking()
	}

}

extension WidgetHashDictionary {

	mutating func clear() {
		removeTooltips()
		removeAll()
	}

	func removeTooltips() {
		for widget in values {
			widget.toolTip = nil
			widget.parentLine?.revealDot?.toolTip = nil
			for line in widget.childrenLines {
				line.dragDot?.toolTip = nil
			}
		}
	}

}

extension ZWidgets {

	func removeTooltipsFromAllWidgets(for controller: ZMapController) {
		if  let type = controller.hereZone?.widgetType {
			removeTooltips(for: type)
		}
	}

	func removeTooltips(for type: ZWidgetType) {
		let registry = getZoneWidgetRegistry(for: type)

		registry?.removeTooltips()
	}

}

extension ZMapControlsView {

	func updateTooltips() {
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

}

extension ZTooltipButton {

	func updateTooltips() {}

}

extension ZBreadcrumbButton {

	override func updateTooltips() {
		toolTip = nil

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
