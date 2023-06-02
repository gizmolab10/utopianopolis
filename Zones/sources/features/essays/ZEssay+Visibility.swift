//
//  ZEssay+Visibility.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/13/23.
//  Copyright © 2023 Zones. All rights reserved.
//

import Foundation

typealias ZNoteVisibilityArray = [ZNoteVisibility]

enum ZNoteVisibilityIconType: Int {

	case tSelf
	case tChildren
	case tHidden

	static var all : [ZNoteVisibilityIconType] { return [.tSelf, .tChildren, .tHidden] }
	var forEssayOnly : Bool { return self != .tSelf }

	var offset : CGFloat {
		switch self {
			case .tSelf:     return 35.0
			case .tChildren: return 60.0
			case .tHidden:   return 85.0
		}
	}

	func iconForVisibilityState(_ on: Bool) -> ZImage? {
		switch self {
			case .tChildren: return on ? kStackImage     : kSingleImage
			case .tSelf:     return on ? kEyeImage       : kEyebrowImage
			case .tHidden:   return on ? kLightbulbImage : kAntiLightbulbImage
		}
	}

}

struct ZNoteVisibility {
	var       eyeRect = CGRect .zero
	var     stackRect = CGRect .zero
	var lightbulbRect = CGRect .zero
	var          zone : Zone

	func stateFor(_ type: ZNoteVisibilityIconType) -> Bool? { return zone.maybeNoteOrEssayTrait?.stateFor(type) }

	mutating func setRect(_ rect: CGRect, for type: ZNoteVisibilityIconType) {
		switch type {
			case .tSelf:         eyeRect = rect
			case .tChildren:   stackRect = rect
			case .tHidden: lightbulbRect = rect
		}
	}

	func rectFor(_ type: ZNoteVisibilityIconType) -> CGRect {
		switch type {
			case .tSelf:     return       eyeRect
			case .tChildren: return     stackRect
			case .tHidden:   return lightbulbRect
		}
	}

}

extension ZEssayView {

	func resetVisibilities() {
		visibilities.removeAll()

		if  let essay = gCurrentEssay,
			let  zone = essay.zone {
			if  !zone.hasChildNotes {
				visibilities.append(ZNoteVisibility(zone: zone))
			} else {
				for child in zone.zonesWithVisibleNotes {
					visibilities.append(ZNoteVisibility(zone: child))
				}
			}
		}
	}

	func drawVisibilityIcons(for index: Int, y: CGFloat, isANote: Bool) {
		if  gEssayTitleMode   != .sEmpty, !gHideNoteVisibility {
			var              v = visibilities[index]
			for type in ZNoteVisibilityIconType.all {
				if  !(type.forEssayOnly && isANote),
					let     on = v.stateFor(type),
					let   icon = type.iconForVisibilityState(on) {
					let origin = CGPoint(x: bounds.maxX, y: y).offsetBy(-type.offset, .zero)
					let   rect = CGRect(origin: origin, size: .zero).expandedBy(icon.size.dividedInHalf)

					v.setRect(rect, for: type)
					icon.draw(in: rect)
				}
			}

			visibilities[index] = v
		}
	}

	func hitTestForVisibilityIcon(at rect: CGRect) -> (Zone, ZNoteVisibilityIconType)? {
		if !gHideNoteVisibility {
			for visibility in visibilities {
				for type in ZNoteVisibilityIconType.all {
					if  visibility.rectFor(type).intersects(rect) {
						return (visibility.zone, type)
					}
				}
			}
		}

		return nil
	}

}
