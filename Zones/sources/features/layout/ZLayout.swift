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

	func updateSize() {
		switch mode {
			case .linearMode:     linearModeUpdateSize()
			case .circularMode: circularModeUpdateSize()
		}
	}

	func updateChildrenViewDrawnSize() {
		switch mode {
			case .linearMode:     linearModeUpdateChildrenViewDrawnSize()
			case .circularMode: circularModeUpdateChildrenViewDrawnSize()
		}
	}

	func updateChildrenLinesDrawnSize() {
		switch mode {
			case .linearMode:     linearModeUpdateChildrenLinesDrawnSize()
			case .circularMode: circularModeUpdateChildrenLinesDrawnSize()
		}
	}

	func updateChildrenVectors(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:   break
			case .circularMode: circularModeUpdateChildrenVectors(absolute)
		}
	}

	func updateChildrenWidgetFrames(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:     linearModeUpdateChildrenWidgetFrames(absolute)
			case .circularMode: circularModeUpdateChildrenWidgetFrames(absolute)
		}
	}

	func updateTextViewFrame(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:     linearModeUpdateTextViewFrame(absolute)
			case .circularMode: circularModeUpdateTextViewFrame(absolute)
		}
	}

	func updateChildrenViewFrame(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:     linearModeUpdateChildrenViewFrame(absolute)
			case .circularMode: circularModeUpdateChildrenViewFrame(absolute)
		}
	}

	func updateLinesViewFrame(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:     linearModeUpdateLinesViewFrame(absolute)
			case .circularMode: circularModeUpdateLinesViewFrame(absolute)
		}
	}

	func updateDotFrames(_ absolute: Bool) {
		switch mode {
			case .linearMode:     linearModeUpdateDotFrames(absolute)
			case .circularMode: circularModeUpdateDotFrames(absolute)
		}
}

	func updateHighlightFrame(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:     linearModeUpdateHighlightFrame(absolute)
			case .circularMode: circularModeUpdateHighlightFrame(absolute)
		}
	}

	var selectionHighlightPath: ZBezierPath {
		switch mode {
			case .linearMode:   return   linearModeSelectionHighlightPath
			case .circularMode: return circularModeSelectionHighlightPath
		}
	}

}

// MARK:- dot
// MARK:-

extension ZoneDot {

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		switch mode {
			case .linearMode:     linearModeDrawMainDot(in: iDirtyRect, using: parameters)
			case .circularMode: circularModeDrawMainDot(in: iDirtyRect, using: parameters)
		}
	}

}

// MARK:- line
// MARK:-

extension ZoneLine {

	var absoluteDropDotRect: CGRect {
		switch mode {
			case .linearMode:   return   linearModeAbsoluteDropDotRect
			case .circularMode: return circularModeAbsoluteDropDotRect
		}
	}

	var lineRect : CGRect {
		switch mode {
			case .linearMode:   return   linearModeLineRect
			case .circularMode: return circularModeLineRect
		}
	}

	func straightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		switch mode {
			case .linearMode:   return   linearModeStraightLinePath(in: iRect, isDragLine)
			case .circularMode: return circularModeStraightLinePath(in: iRect, isDragLine)
		}
	}

	func lineKind(to dragRect: CGRect) -> ZLineKind? {
		switch mode {
			case .linearMode:   return linearModeLineKind(to: dragRect)
			case .circularMode: return .straight
		}
	}

	func updateSize() {
		switch mode {
			case .linearMode:     linearModeUpdateSize()
			case .circularMode: circularModeUpdateSize()
		}
	}

}
