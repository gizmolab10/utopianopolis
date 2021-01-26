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

protocol ZTooltips {

	func updateTooltips()

}

protocol ZIdentifiable {

	func recordName() -> String?
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

extension ZStartHereController {

	func updateTooltips() {
		view.applyToAllSubviews {     subview in
			if  let        button   = subview as? ZStartHereButton {
				button     .toolTip = nil
				if  gShowToolTips,
					let    buttonID = button.startHereID {
					let     addANew = "adds a new idea as "
					let     editing = (!isEditing ? "edits" : "stops editing and save to")
					let notMultiple = gSelecting.currentGrabs.count < 2
					let   adjective = notMultiple ? "" : "\(gListsGrowDown ? "bottom" : "top")- or left-most "
					let currentIdea = " the \(adjective)currently selected idea"

					switch buttonID {
						case .focus:   button.toolTip = (isHere ? "creates favorite from" : (canTravel ? "travel to target of" : "focus on")) + currentIdea
						case .sibling: button.toolTip = addANew  + "\(flags.isOption ? "parent" : "sibling") to"                                        + currentIdea
						case .child:   button.toolTip = addANew  + "child to"                                                                           + currentIdea
						case .note:    button.toolTip = editing  + " the note of"                                                                       + currentIdea
						case .idea:    button.toolTip = editing                                                                                        + currentIdea
						default:       break
					}
				}
			}
		}
	}

}

extension Zone {

	var revealTipText: String {
		if  count == 0, canTravel {
			return hasNote      ? "edit note for"   :
				hasEmail        ? "send an email"   :
				isBookmark      ? "change focus to" :
				hasHyperlink    ? "invoke web link" : ""
		}

		return (expanded ? "hide" : "reveal") + " list for"
	}

}

extension ZoneDot {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let zone = widgetZone,
			let name = zone.zoneName,
			(!isReveal || zone.isBookmark || zone.count > 0) {
			toolTip  = "\(isReveal ? "Reveal" : "Drag") dot\n\n\(kClickTo)\(isReveal ? zone.revealTipText : zone.isGrabbed ? "drag" : "select or drag") \"\(name)\"\(zone.isBookmark && !isReveal ? " bookmark" : "")"
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

extension ZSmallMapControlsView {

	func updateTooltips() {
		for button in buttons {
			button.toolTip = nil

			if  gShowToolTips,
				let     type = button.modeButtonType {
				let browsing = "vertical browsing"
				let isRecent = gIsRecentlyMode

				switch type {
					case .tAdd:     button.toolTip = "Add\n\n\(kClickTo)add a new category"
					case .tMode:    button.toolTip = "Showing \(isRecent ? "recents" : "favorites")\n\n\(kClickTo)show \(isRecent ? "favorites" : "recents")"
					case .tGrow:    button.toolTip = "Growth direction\n\n\(kClickTo)grow lists \(gListsGrowDown ? "up" : "down")ward or browse (rightward) to the \(gListsGrowDown ? "top" : "bottom")"
					case .tConfine: button.toolTip = "Browsing confinement\n\n\(kClickTo)\(gBrowsingIsConfined ? "allow unconfined \(browsing)" : "confine \(browsing) within current list")"
				}
			}
		}
	}

}

extension ZBreadcrumbButton {

	func updateTooltips() {
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
