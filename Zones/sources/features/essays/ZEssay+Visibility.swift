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

enum ZEssayTitleMode: Int {
	case sEmpty // do not change the order, storyboard and code dependencies
	case sTitle
	case sFull
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
