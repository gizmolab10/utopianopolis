//
//  ZLinear.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK:- widget
// MARK:-

extension ZoneWidget {

	func updateChildrenViewDrawnSize() {
		switch gMapLayoutMode {
			case .linear:     linearUpdateChildrenViewDrawnSize()
			case .circular: circularUpdateChildrenViewDrawnSize()
		}
	}

	func updateSize() {
		switch gMapLayoutMode {
			case .linear:     linearUpdateSize()
			case .circular: circularUpdateSize()
		}
	}

	func updateChildrenFrames(_ absolute: Bool = false) {
		switch gMapLayoutMode {
			case .linear:     linearUpdateChildrenFrames(absolute)
			case .circular: circularUpdateChildrenFrames(absolute)
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
		switch gMapLayoutMode {
			case .linear:     linearUpdateTextViewFrame(absolute)
			case .circular: circularUpdateTextViewFrame(absolute)
		}
	}

	func updateChildrenViewFrame(_ absolute: Bool = false) {
		switch gMapLayoutMode {
			case .linear:     linearUpdateChildrenViewFrame(absolute)
			case .circular: circularUpdateChildrenViewFrame(absolute)
		}
	}

	func updateHighlightRect(_ absolute: Bool = false) {
		if  gMapLayoutMode == .linear,
			childrenLines.count > 0 {
			childrenLines[0].updateHighlightRect(absolute)
		}
	}

	func drawSelectionHighlight(_ dashes: Bool, _ thin: Bool) {
		switch gMapLayoutMode {
			case .linear:     linearDrawSelectionHighlight(dashes, thin)
			case .circular: circularDrawSelectionHighlight(dashes, thin)
		}
	}

}

// MARK:- dot
// MARK:-

extension ZoneDot {

	func updateFrame(relativeTo textFrame: CGRect) {
		switch gMapLayoutMode {
			case .linear:     linearUpdateFrame(relativeTo: textFrame)
			case .circular: circularUpdateFrame(relativeTo: textFrame)
		}
	}

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		switch gMapLayoutMode {
			case .linear:     linearDrawMainDot(in: iDirtyRect, using: parameters)
			case .circular: circularDrawMainDot(in: iDirtyRect, using: parameters)
		}
	}

}

// MARK:- line
// MARK:-

extension ZoneLine {

	var absoluteDropDotRect: CGRect {
		switch gMapLayoutMode {
			case .linear:   return   linearAbsoluteDropDotRect
			case .circular: return circularAbsoluteDropDotRect
		}
	}

	var lineRect : CGRect {
		switch gMapLayoutMode {
			case .linear:   return   linearLineRect
			case .circular: return circularLineRect
		}
	}

	func lineKind(for delta: CGFloat) -> ZLineKind {
		switch gMapLayoutMode {
			case .linear:   return   linearLineKind(for: delta)
			case .circular: return circularLineKind(for: delta)
		}
	}

	func lineKind(to dragRect: CGRect) -> ZLineKind? {
		switch gMapLayoutMode {
			case .linear:   return   linearLineKind(to: dragRect)
			case .circular: return circularLineKind(to: dragRect)
		}
	}

}
