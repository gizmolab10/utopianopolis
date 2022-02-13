//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZMapID: String {
	case mLinesAndDots      = "d"
	case mTextAndHighlights = "t"

	var title      : String { return "\(self)".lowercased().substring(fromInclusive: 1) }
	var identifier : NSUserInterfaceItemIdentifier { return NSUserInterfaceItemIdentifier(title) }
}

class ZMapView: ZView {

	var          okayToDetectHover = false
	var                      mapID : ZMapID?
	var                   hovering : ZHovering?
	var                 controller : ZMapController?
	@IBOutlet var linesAndDotsView : ZMapView?
	override func   menu(for event : ZEvent) -> ZMenu? { return gMapController?.mapContextualMenu }

	var ignoreHovering : Bool {
		return !okayToDetectHover
		|| gDragging.isDragging
		|| gRubberband.showRubberband    // not blink rubberband or drag
		|| !(controller?.isExemplar ?? false)
	}

	// MARK: - initialize
	// MARK: -

	func setup(_ id: ZMapID = .mTextAndHighlights, with iController: ZMapController) {
		if  controller == nil {
			controller  = iController
			identifier  = id.identifier
			mapID       = id

			switch id {
				case .mTextAndHighlights:
					hovering = ZHovering()

					updateTracking()
					linesAndDotsView?.setup(.mLinesAndDots, with: iController)
					fallthrough
				default:
					zlayer.backgroundColor = CGColor.clear

					if  let s = superview, (!iController.isExemplar || id != .mTextAndHighlights) { // not do this for help dots exemplar
						frame = s.bounds
					}
			}
		}
	}

	func resize() {
		if  let view = gMapView {
			frame    = view.bounds

			setNeedsDisplay()
		}
	}

	func removeAllTextViews(ofType: ZMapController.ZRelayoutMapType = .both) {
		for subview in subviews {
			if  let textView = subview as? ZoneTextWidget,
				let   widget = textView.widget {
				if widget.isBigMap ? (ofType != .small) : (ofType != .big) {
					textView.removeFromSuperview()
				}
			}
		}
	}

	// MARK: - mouse
	// MARK: -

	func updateTracking() { addTracking(for: frame) }

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		addTracking(for: bounds)
	}

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)

		if  let view = gMainWindow?.contentView, !view.frame.contains(event.locationInWindow) {
			gRubberband.rubberbandRect = nil
			gDragging      .dropWidget = nil
		}
	}

	// MARK: - draw
	// MARK: -

	func debugDraw() {
		bounds                 .insetEquallyBy(1.5).drawColoredRect(.blue)
		linesAndDotsView?.frame.insetEquallyBy(3.0).drawColoredRect(.red)
		superview?.drawBox(in: self, with:                          .orange)
	}

	override func draw(_ iDirtyRect: CGRect) {
		if  iDirtyRect.hasZeroSize {
			return
		}

		switch mapID {
		case .mTextAndHighlights:
			drawDrag       (iDirtyRect)
			super.draw     (iDirtyRect) // text fields are drawn by OS
			drawWidgets(in: iDirtyRect, for: .pHighlights)
		case .mLinesAndDots:
			drawWidgets(in: iDirtyRect, for: .pLines)
			drawWidgets(in: iDirtyRect, for: .pDots)   // draw dots last so they can "cover" the ends of lines
		default: break
		}
	}

	func drawWidgets(in iDirtyRect: CGRect, for phase: ZDrawPhase) {
		ZBezierPath.setClip(to: iDirtyRect)
		gSmallMapController?.drawWidgets(for: phase)

		if  !gIsEssayMode {
			gMapController? .drawWidgets(for: phase)
		}
	}

	func drawDrag(_ iDirtyRect: CGRect) {
		ZBezierPath.fillWithColor(gBackgroundColor, in: iDirtyRect) // remove old rubberband and drag line/dot
		gRubberband.draw()
		gDragging.dragLine?.drawDragLineAndDot()
	}
//
//	@objc override func printView() {
//		gDetailsController?.temporarilyHideView(for: .vSmallMap) {
//			super.printView()
//		}
//		
//		gRelayoutMaps()
//	}

}
