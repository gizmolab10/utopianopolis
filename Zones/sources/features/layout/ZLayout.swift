//
//  ZLayout.swift
//  Seriously
//
//  Created by Jonathan Sand on 11/11/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZMapLayoutMode: Int { // do not change the order, they are persisted
	case linearMode
	case circularMode

	var next: ZMapLayoutMode {
		switch self {
			case .linearMode: return .circularMode
			default:          return .linearMode
		}
	}

	var title: String {
		switch self {
			case .linearMode: return "Tree"
			default:          return "Star"
		}
	}
}

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

	func updateHighlightRect() {
		switch mode {
		case .linearMode:   return   linearRelayoutHighlightRect()
		case .circularMode: return circularUpdateHighlightRect()
		}
	}

	var selectionHighlightPath: ZBezierPath {
		switch mode {
		case .linearMode:   return   linearSelectionHighlightPath
		case .circularMode: return circularSelectionHighlightPath
		}
	}

	func grandRelayout() {
		switch mode {
			case .linearMode:     linearGrandRelayout()
			case .circularMode: circularGrandRelayout()
		}
	}

}

// MARK: - line
// MARK: -

extension ZoneLine {

	var draggingDotAbsoluteFrame: CGRect {
		switch mode {
			case .linearMode:   return   linearDraggingDotAbsoluteFrame
			case .circularMode: return circularDraggingDotAbsoluteFrame
		}
	}

	func straightLinePath(in iRect: CGRect, _ isDragLine: Bool) -> ZBezierPath {
		switch mode {
			case .linearMode:   return   linearStraightLinePath(in: iRect, isDragLine)
			case .circularMode: return circularStraightLinePath(in: iRect, isDragLine)
		}
	}

	func lineKind(to dragRect: CGRect) -> ZLineCurveKind? {
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

	@discardableResult func updateDotDrawnSize() -> CGSize {
		switch mode {
			case .linearMode:   return   linearUpdateDotDrawnSize()
			case .circularMode: return circularUpdateDotDrawnSize()
		}
	}

	func drawMainDot(_ iDirtyRect: CGRect, _ parameters: ZDotParameters) {
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
