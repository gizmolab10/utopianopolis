//
//  ZLinear.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

// MARK: - widget
// MARK: -

extension ZoneWidget {

	func updateWidgetDrawnSize() {
		switch mode {
			case .linearMode:     linearModeUpdateWidgetDrawnSize()
			case .circularMode: circularModeUpdateWidgetDrawnSize()
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

	func grandUpdate() {
		switch mode {
			case .linearMode:     linearModeGrandUpdate()
			case .circularMode: circularModeGrandUpdate()
		}
	}

}

// MARK: - line
// MARK: -

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

	func lineKind(to dragRect: CGRect) -> ZLineCurve? {
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

// MARK: - dot
// MARK: -

extension ZoneDot {

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		switch mode {
			case .linearMode:     linearModeDrawMainDot(in: iDirtyRect, using: parameters)
			case .circularMode: circularModeDrawMainDot(in: iDirtyRect, using: parameters)
		}
	}

}
