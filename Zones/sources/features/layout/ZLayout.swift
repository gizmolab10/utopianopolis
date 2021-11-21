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

	var mode: ZMapLayoutMode { return controller?.mapLayoutMode ?? .linear }

	func updateSize() {
		switch mode {
			case .linear:     linearUpdateSize()
			case .circular: circularUpdateSize()
		}
	}

	func updateChildrenViewDrawnSize() {
		switch mode {
			case .linear:     linearUpdateChildrenViewDrawnSize()
			case .circular: circularUpdateChildrenViewDrawnSize()
		}
	}

	func updateChildrenLinesDrawnSize() {
		switch mode {
			case .linear:     linearUpdateChildrenLinesDrawnSize()
			case .circular: circularUpdateChildrenLinesDrawnSize()
		}
	}

	func updateChildrenVectors(_ absolute: Bool = false) {
		switch mode {
			case .linear:   break
			case .circular: circularUpdateChildrenVectors(absolute)
		}
	}

	func updateChildrenWidgetFrames(_ absolute: Bool = false) {
		switch mode {
			case .linear:     linearUpdateChildrenWidgetFrames(absolute)
			case .circular: circularUpdateChildrenWidgetFrames(absolute)
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
		switch mode {
			case .linear:     linearUpdateTextViewFrame(absolute)
			case .circular: circularUpdateTextViewFrame(absolute)
		}
	}

	func updateChildrenViewFrame(_ absolute: Bool = false) {
		switch mode {
			case .linear:     linearUpdateChildrenViewFrame(absolute)
			case .circular: circularUpdateChildrenViewFrame(absolute)
		}
	}

	func updateHighlightFrame(_ absolute: Bool = false) {
		switch mode {
			case .linear:     linearUpdateHighlightFrame(absolute)
			case .circular: circularUpdateHighlightFrame(absolute)
		}
	}

	func drawSelectionHighlight(_ dashes: Bool, _ thin: Bool) {
		switch mode {
			case .linear:     linearDrawSelectionHighlight(dashes, thin)
			case .circular: circularDrawSelectionHighlight(dashes, thin)
		}
	}

}

// MARK:- dot
// MARK:-

extension ZoneDot {

	var mode: ZMapLayoutMode { return controller?.mapLayoutMode ?? .linear }

	func updateAbsoluteFrame(relativeTo absoluteTextFrame: CGRect) {
		switch mode {
			case .linear:     linearUpdateAbsoluteFrame(relativeTo: absoluteTextFrame)
			case .circular: circularUpdateAbsoluteFrame(relativeTo: absoluteTextFrame)
		}

		updateTooltips()
	}

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		switch mode {
			case .linear:     linearDrawMainDot(in: iDirtyRect, using: parameters)
			case .circular: circularDrawMainDot(in: iDirtyRect, using: parameters)
		}
	}

}

// MARK:- line
// MARK:-

extension ZoneLine {

	var mode: ZMapLayoutMode { return controller?.mapLayoutMode ?? .linear }

	var absoluteDropDotRect: CGRect {
		switch mode {
			case .linear:   return   linearAbsoluteDropDotRect
			case .circular: return circularAbsoluteDropDotRect
		}
	}

	var lineRect : CGRect {
		switch mode {
			case .linear:   return   linearLineRect
			case .circular: return circularLineRect
		}
	}

	func straightPath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		switch mode {
			case .linear:   return   linearStraightPath(in: iRect, isDragLine)
			case .circular: return circularStraightPath(in: iRect, isDragLine)
		}
	}

	func lineKind(to dragRect: CGRect) -> ZLineKind? {
		switch mode {
			case .linear:   return linearLineKind(to: dragRect)
			case .circular: return .straight
		}
	}

	func updateSize() {
		switch mode {
			case .linear:     linearUpdateSize()
			case .circular: circularUpdateSize()
		}
	}

}
