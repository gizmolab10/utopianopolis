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
			case .linearMode:     linearUpdateWidgetDrawnSize()
			case .circularMode: circularUpdateWidgetDrawnSize()
		}
	}

	func updateChildrenViewDrawnSize() {
		if  isLinearMode {
			linearUpdateChildrenViewDrawnSize()
		}
	}

	func updateLinesViewDrawnSize() {
		if  isLinearMode {
			linearUpdateLinesViewDrawnSize()
		}
	}

	func updateHighlightFrame() {
		switch mode {
		case .linearMode:   return   linearUpdateHighlightFrame()
		case .circularMode: return circularUpdateHighlightFrame()
		}
	}

	var selectionHighlightPath: ZBezierPath {
		switch mode {
		case .linearMode:   return   linearSelectionHighlightPath
		case .circularMode: return circularSelectionHighlightPath
		}
	}

	func grandUpdate() {
		switch mode {
			case .linearMode:     linearGrandUpdate()
			case .circularMode: circularGrandUpdate()
		}
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var absoluteDropDragDotRect: CGRect {
		switch mode {
			case .linearMode:   return   linearAbsoluteDropDragDotRect
			case .circularMode: return circularAbsoluteDropDragDotRect
		}
	}

	func straightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		switch mode {
			case .linearMode:   return   linearStraightLinePath(in: iRect, isDragLine)
			case .circularMode: return circularStraightLinePath(in: iRect, isDragLine)
		}
	}

	func lineKind(to dragRect: CGRect) -> ZLineCurve? {
		switch mode {
			case .linearMode:   return linearLineKind(to: dragRect)
			case .circularMode: return .straight
		}
	}

	func updateLineSize() {
		switch mode {
			case .linearMode:     linearUpdateLineSize()
			case .circularMode: circularUpdateLineSize()
		}
	}

}

// MARK: - dot
// MARK: -

extension ZoneDot {

	var isDragDrop : Bool {
		switch mode {
		case .linearMode:   return   linearIsDragDrop
		case .circularMode: return circularIsDragDrop
		}
	}

	func drawMainDot(in iDirtyRect: CGRect, using parameters: ZDotParameters) {
		switch mode {
			case .linearMode:     linearDrawMainDot(in: iDirtyRect, using: parameters)
			case .circularMode: circularDrawMainDot(in: iDirtyRect, using: parameters)
		}
	}

}

// MARK: - dragging
// MARK: -

extension ZDragging {

	func dropMaybeOntoWidget(_ iGesture: ZGestureRecognizer?, in controller: ZMapController) -> Bool { // true means successful drop
		if !draggedZones.containsARoot,
			draggedZones.userCanMoveAll {
			switch controller.mapLayoutMode {
			case .linearMode:   return   linearDropMaybeOntoWidget(iGesture, in: controller)
			case .circularMode: return circularDropMaybeOntoWidget(iGesture, in: controller)
			}
		}

		return false
	}

}
