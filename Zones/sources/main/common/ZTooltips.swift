//
//  ZTooltips.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/14/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

protocol ZTooltips {

	func updateTooltips()

}

class ZTooltipOwner : NSObject {
	var zRecord: ZRecord?

	override var description: String {
		let prefix = "[necklace dot]"

		if  let  r = zRecord {
			return "\(prefix) click here to change focus to \"\(r.unwrappedName)\""
		}

		return prefix
	}

	convenience init(zRecord iZRecord: ZRecord) {
		self.init()

		zRecord = iZRecord
	}
}

extension ZIntroductionController {

	func updateTooltips() {
		view.applyToAllSubviews { subview in
			if  let    button   = subview as? ZIntroductionButton,
				let    buttonID = button.introductionID {
				let     addANew = "add a new idea as "
				let     editing = !isEditing ? "edit" : "stop editing and save to"
				let notMultiple = gSelecting.currentGrabs.count < 2
				let   adjective = notMultiple ? "" : "\(gListsGrowDown ? "bottom" : "top")- or left-most "
				let currentIdea = " the \(adjective)currently selected idea"

				switch buttonID {
					case .focus:   button.toolTip = (isHere ? "create favorite from" : (canTravel ? "travel to target of" : "focus on")) + currentIdea
					case .sibling: button.toolTip = addANew + "\(flags.isOption ? "parent" : "sibling") to"                              + currentIdea
					case .child:   button.toolTip = addANew + "child to"                                                                 + currentIdea
					case .note:    button.toolTip = editing + " the note of"                                                             + currentIdea
					case .idea:    button.toolTip = editing                                                                              + currentIdea
					default:       break
				}
			}
		}
	}

}

extension ZoneDot {

	func updateTooltips() {
		toolTip = nil

		if  let zone = widgetZone,
			let name = widgetZone?.zoneName,
			(!zone.isGrabbed || isReveal) {
			toolTip  = "[\(isReveal ? "reveal" : "drag") dot] click here to \(isReveal ? zone.revealTipText : "select or drag") \"\(name)\""
		}
	}

}

extension ZoneTextWidget {

	func updateTooltips() {
		toolTip = nil

		if  let name = widgetZone?.zoneName {
			toolTip  = "click here to edit \"\(name)\""
		}
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
