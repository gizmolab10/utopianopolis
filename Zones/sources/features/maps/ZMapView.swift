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

	var mapID                      : ZMapID?
	@IBOutlet var linesAndDotsView : ZMapView?
	override func menu(for event   : ZEvent) -> ZMenu? { return gMapController?.mapContextualMenu }

	// MARK: - mouse
	// MARK: -

	func updateTracking() { addTracking(for: frame) }

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		addTracking(for: bounds)
	}

	override func mouseExited(with event: ZEvent) {
		super.mouseExited(with: event)

		if  !(event.window?.contentView?.frame.contains(event.locationInWindow) ?? false) {

			if  gRubberband.rubberbandRect != nil {
				gRubberband.rubberbandRect  = nil
			}

			if  gDragging.dropWidget != nil {
				gDragging.dropWidget  = nil
			}

//			gMapController?.setNeedsDisplay()
		}
	}

	// MARK: - initialize
	// MARK: -

	func setup(_ id: ZMapID = .mTextAndHighlights) {
		identifier = id.identifier
		mapID      = id

		switch id {
			case .mTextAndHighlights:
				updateTracking()
				linesAndDotsView?.setup(.mLinesAndDots)
				fallthrough
			default:
				zlayer.backgroundColor = CGColor.clear
				
				if  let s = superview {
					frame = s.bounds
				}
		}
	}

	func resize() {
		if  let   view = gMapController?.view {
			frame      = view.bounds
//			if  mapID == .mTextAndHighlights {
//				linesAndDotsView?.resize()
//			}
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
		gMapController?     .drawWidgets(for: phase)
	}

	func drawDrag(_ iDirtyRect: CGRect) {
		ZBezierPath.fillWithColor(gBackgroundColor, in: iDirtyRect) // remove old rubberband and drag line/dot
		gRubberband.draw()
		gDragging.dragLine?.drawDragLineAndDot()
	}

	@objc override func printView() {
		gDetailsController?.temporarilyHideView(for: .vSmallMap) {
			super.printView()
		}
		
		gRelayoutMaps()
	}

}
