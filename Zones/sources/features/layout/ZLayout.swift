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
			case .linearMode:     linesUpdateWidgetDrawnSize()
			case .circularMode: circlesUpdateWidgetDrawnSize()
		}
	}

	func updateChildrenViewDrawnSize() {
		if  isLinearMode {
			linesUpdateChildrenViewDrawnSize()
		}
	}

	func updateChildrenLinesDrawnSize() {
		if  isLinearMode {
			linesUpdateChildrenLinesDrawnSize()
		}
	}

	var selectionHighlightPath: ZBezierPath {
		switch mode {
			case .linearMode:   return   linesSelectionHighlightPath
			case .circularMode: return circlesSelectionHighlightPath
		}
	}

	var highlightFrame : CGRect {
		switch mode {
			case .linearMode:   return   linesHighlightFrame
			case .circularMode: return circlesHighlightFrame
		}
	}

	func grandUpdate() {
		switch mode {
			case .linearMode:     linesGrandUpdate()
			case .circularMode: circlesGrandUpdate()
		}
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var absoluteDropDotRect: CGRect {
		switch mode {
			case .linearMode:   return   linesAbsoluteDropDotRect
			case .circularMode: return circlesAbsoluteDropDotRect
		}
	}

	var lineRect : CGRect {
		switch mode {
			case .linearMode:   return   linesLineRect
			case .circularMode: return circlesLineRect
		}
	}

	func straightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		switch mode {
			case .linearMode:   return   linesStraightLinePath(in: iRect, isDragLine)
			case .circularMode: return circlesStraightLinePath(in: iRect, isDragLine)
		}
	}

	func lineKind(to dragRect: CGRect) -> ZLineCurve? {
		switch mode {
			case .linearMode:   return   linesLineKind(to: dragRect)
			case .circularMode: return .straight
		}
	}

	func updateLineSize() {
		switch mode {
			case .linearMode:     linesUpdateLineSize()
			case .circularMode: circlesUpdateLineSize()
		}
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		switch mode {
			case .linearMode:     linesDrawMainDot(in: iDirtyRect, using: parameters)
			case .circularMode: circlesDrawMainDot(in: iDirtyRect, using: parameters)
		}
	}

}

extension ZMapController {
	
	func detectWidget(at location: CGPoint) -> ZoneWidget? {
		switch mode {
		case .linearMode:   return   linesDetectWidget(at: location)
		case .circularMode: return circlesDetectWidget(at: location)
		}
	}
	
	func handleDetection(for gesture: ZKeyClickGestureRecognizer) -> Bool {
		switch mode {
		case .linearMode:   return   linesHandleDetection(for: gesture)
		case .circularMode: return circlesHandleDetection(for: gesture)
		}
	}

	func detectDot(_ gesture: ZGestureRecognizer) -> ZoneDot? {
		switch mode {
		case .linearMode:   return   linesDetectDot(gesture)
		case .circularMode: return circlesDetectDot(gesture)
		}
	}

}
