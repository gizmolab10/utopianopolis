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

extension ZRingView {

	@discardableResult override func addToolTip(_ rect: NSRect, owner: Any, userData data: UnsafeMutableRawPointer?) -> NSView.ToolTipTag {
		if  gShowToolTips,
			let         tool = owner as? ZToolable,
			let         name = tool.toolName() {
			let         font = gFavoritesFont
			var     nameRect = name.rectWithFont(font, options: .usesFontLeading).insetBy(dx: -10.0, dy: 0.0)
			nameRect.center  = rect.offsetBy(dx: 10.0, dy: 1.0).center
			var   attributes : [NSAttributedString.Key : Any] = [.font : font]

			if  let    color = tool.toolColor() {
				attributes[.foregroundColor] = color
			}

			name.draw(in: nameRect, withAttributes: attributes)
		}

		let o = (owner as? Zone)?.tooltipOwner ?? owner

		return super.addToolTip(rect, owner: o, userData: data)
	}

	func updateTooltips() {
		let controls = ZControlButton.controls
		let  objects = necklaceObjects 				// expensive computation: do once
		let    count = objects.count

		removeAllToolTips()

		for (index, tinyRect) in necklaceDotRects {
			if  index < count { 							// avoid crash
				var      owner = objects[index]
				let       rect = self.convert(tinyRect, to: self)

				if  let owners = owner as? [NSObject] {
					owner      = owners[0]
				}

				addToolTip(rect, owner: owner, userData: nil)
			}
		}

		for (index, controlRect) in controlRects.enumerated() {
			let  rect = self.convert(controlRect, to: self).offsetBy(dx: 0.0, dy: -5.0)
			let owner = controls[index]

			addToolTip(rect, owner: owner, userData: nil)
		}
	}

}

extension ZIntroductionController {

	func updateTooltips() {
		view.applyToAllSubviews {     subview in
			if  let        button   = subview as? ZIntroductionButton {
				button     .toolTip = nil
				if  gShowToolTips,
					let    buttonID = button.introductionID {
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

		return (showingChildren ? "hide" : "reveal") + " children of"
	}

}

extension ZoneDot {

	func updateTooltips() {
		toolTip = nil

		if  gShowToolTips,
			let zone = widgetZone,
			let name = widgetZone?.zoneName,
			( isReveal ||  !zone.isGrabbed),
			(!isReveal || !(zone.bookmarkTarget?.isGrabbed ?? false)) {
			toolTip  = "\(isReveal ? "Reveal" : "Drag") dot\n\n\(kClickTo)\(isReveal ? zone.revealTipText : "select or drag") \"\(name)\"\(zone.isBookmark && !isReveal ? " bookmark" : "")"
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

extension ZControlButton {

	var labelText: String {
		switch type {
			case .eInsertion: return gListsGrowDown      ? "down" : "up"
			case .eConfined:  return gBrowsingIsConfined ? "list" : "all"
			case .eToolTips:  return gShowToolTips       ? "hide" : "show" + "tool tips"
		}
	}

	override var description: String {
		switch type {
			case .eInsertion: return kClickTo + "toggle insertion direction"
			case .eConfined:  return kClickTo + "toggle browsing confinement (between list and all)"
			case .eToolTips:  return kClickTo + "toggle tool tips visibility"
		}
	}

}

extension ZModeControlsView {

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
