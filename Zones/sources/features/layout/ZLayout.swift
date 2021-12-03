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

	func updateWidgetSize() {
		switch mode {
			case .linearMode:     linearModeUpdateWidgetSize()
			case .circularMode: circularModeUpdateWidgetSize()
		}
	}

	func updateChildrenViewDrawnSize() {
		if  isLinearMode {
			linearModeUpdateChildrenViewDrawnSize()
		}
	}

	func updateChildrenLinesDrawnSize() {
		if  isLinearMode {
			linearModeUpdateChildrenLinesDrawnSize()
		}
	}

	var selectionHighlightPath: ZBezierPath {
		switch mode {
			case .linearMode:   return   linearModeSelectionHighlightPath
			case .circularMode: return circularModeSelectionHighlightPath
		}
	}

	var highlightFrame : CGRect {
		switch mode {
			case .linearMode:   return   linearModeHighlightFrame
			case .circularMode: return circularModeHighlightFrame
		}
	}

	func updateAllChildrenVectors(_ absolute: Bool = false) {
		if  isCircularMode {
			traverseAllWidgetProgeny { widget in
				widget.circularModeUpdateChildrenVectors(absolute)
			}
		}
	}

	func updateChildrenVectors(_ absolute: Bool = false) {
		if  isCircularMode {
			circularModeUpdateChildrenVectors(absolute)
		}
	}

	func updateAllFrames(_ absolute: Bool = false) {
		switch mode {
			case .linearMode:     linearModeUpdateAllFrames(absolute)
			case .circularMode: circularModeUpdateAllFrames(absolute)
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

	func updateLineSize() {
		switch mode {
			case .linearMode:     linearModeUpdateLineSize()
			case .circularMode: circularModeUpdateLineSize()
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
