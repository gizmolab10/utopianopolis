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

class ZRecordTooltip : NSObject {
	var zRecord: ZRecord?

	override var description: String {
		let prefix = "necklace dot"

		if  let  r = zRecord {
			return "\(prefix)\n\nchanges the focus to \"\(r.unwrappedName)\""
		}

		return prefix
	}

	convenience init(zRecord iZRecord: ZRecord) {
		self.init()

		zRecord = iZRecord
	}
}

extension ZRecord {

	var tooltipOwner: Any {
		if  _tooltipRecord == nil {
			_tooltipRecord  = ZRecordTooltip(zRecord: self)
		}

		return _tooltipRecord!
	}

}

extension ZNote {

	func tooltipString(grabbed: Bool) -> String? {
		if  gShowToolTips {
			let prefix = grabbed ? "This note is selected" : "\(kClickTo)select this note"

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
			let       focus = (gIsHere ? "creates a \(gCurrentSmallMapName) from" : (canTravel ? "travel to target of" : "focus on"))
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

	var revealTipText: String {
		if  count == 0, isTraveller {
			return hasNote      ? "edit note for"   :
				hasEmail        ? "send an email"   :
				isBookmark      ? "change focus to" :
				hasHyperlink    ? "invoke web link" : kEmpty
		}

		return gConcealmentString(for: expanded) + " list for"
	}

}

extension ZoneDot {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let zone = widgetZone,
			let name = zone.zoneName,
			(!isReveal || zone.isBookmark || zone.count > 0 || zone.hasNote) {
			toolTip  = "\(isReveal ? "Reveal" : "Drag") dot\n\n\(kClickTo)\(isReveal ? zone.revealTipText : zone.isGrabbed ? "drag" : "select or drag") \"\(name)\"\(zone.isBookmark && !isReveal ? " bookmark" : kEmpty)"
		}
	}

}

extension ZBannerButton {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let view = togglingView {
			toolTip  = "\(kClickTo)\(view.hideHideable ? "view" : "hide") \(view.toolTipText)"
		}
	}

}

extension ZoneTextWidget {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let name = widgetZone?.zoneName {
			toolTip  = "Idea text\n\n\(kClickTo)edit \"\(name)\""
		}
	}

}

extension ZMapControlsView {

	func updateTooltips() {
		for button in buttons {
			button.toolTip = nil

			if  gShowToolTips,
				let     type = button.modeButtonType {
				let browsing = "vertical browsing"

				switch type {
					case .tGrowth:  button.toolTip = "Growth direction\n\n\(kClickTo)grow lists \(gListsGrowDown ? "up" : "down")ward or browse (rightward) to the \(gListsGrowDown ? "top" : "bottom")"
					case .tConfine: button.toolTip = "Browsing confinement\n\n\(kClickTo)\(gBrowsingIsConfined ? "allow unconfined \(browsing)" : "confine \(browsing) within current list")"
				}
			}
		}
	}

}

extension ZTooltipButton {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let tagID = ZEssayButtonID(rawValue: tag) {
			toolTip   = "\(kClickTo)\(tagID.tooltipString)"
		}
	}

}

extension ZBreadcrumbButton {

	override func updateTooltips() {
		toolTip = nil

		if  gShowToolTips {
			let title = "Breadcrumb\n\n"
			let  name = zone.unwrappedName

			if  zone == gHereMaybe {
				toolTip = "\(title)current focus is \"\(name)\""
			} else if zone.isGrabbed {
				toolTip = "\(title)currently selected idea is \"\(name)\""
			} else {
				let shrink = zone.ancestralPath.contains(gHere)
				toolTip = "\(title)\(kClickTo)\(shrink ? "shrink" : "expand") focus to \"\(name)\""
			}
		}
	}

}
