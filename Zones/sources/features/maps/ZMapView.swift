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
	case mText        = "t"
	case mDecorations = "d"

	var title      : String { return "\(self)".lowercased().substring(fromInclusive: 1) }
	var identifier : NSUserInterfaceItemIdentifier { return NSUserInterfaceItemIdentifier(title) }
}

class ZMapView: ZView {

	var                     mapID : ZMapID?
	var                  hovering : ZHovering?
	var                controller : ZMapController?
	@IBOutlet var decorationsView : ZMapView?
	override var        debugName : String            { return controller?.zClassName ?? kUnknown }

	// MARK: - initialize
	// MARK: -

	func clear() {
		ZBezierPath.fillWithColor(gBackgroundColor, in: bounds)
		setNeedsDisplay()
	}

	func setup(_ id: ZMapID = .mText, with iController: ZMapController) {
		if  controller == nil {
			controller  = iController
			identifier  = id.identifier
			mapID       = id

			switch id {
				case .mText:
					hovering = ZHovering()

					updateTracking()
					decorationsView?.setup(.mDecorations, with: iController)
					fallthrough
				default:
					zlayer.backgroundColor = CGColor.clear

					if  let s = superview, (!iController.isExemplar || id != .mText) { // not do this for help dots exemplar
						frame = s.bounds
					}
			}
		}
	}

	func resize() {
		if  let view = gMapView {
			frame    = view.bounds

			if  gIsEssayMode,
				let view = gEssayView {
				view.updateResizeDragRect()
			}

			setNeedsDisplay()
		}
	}

	func removeAllTextViews(ofType: ZRelayoutMapType = .both) {
		for subview in subviews {
			if  let textView = subview as? ZoneTextWidget,
				let   widget = textView.widget {
				if widget.isMainMap ? (ofType != .favorites) : (ofType != .main) {
					textView.removeFromSuperview()
				}
			}
		}
	}

	// MARK: - draw
	// MARK: -

	func debugDraw() {
		bounds                .insetEquallyBy(1.5).drawColoredRect(.blue)
		decorationsView?.frame.insetEquallyBy(3.0).drawColoredRect(.red)
		superview?.drawBox(in: self, with:                         .orange)
	}

	override func draw(_ iDirtyRect: CGRect) {
		if  iDirtyRect.hasZeroSize || !gIsReadyToShowUI {
			return
		}

		switch mapID {
			case .mText:
				super.draw(iDirtyRect)    // text fields are drawn by OS
			case .mDecorations:
				clear()                   // remove old rubberband and drag line/dot

				for phase in gAllDrawPhases {
					drawWidgets(in: iDirtyRect, for: phase)
				}

				drawDrag(iDirtyRect)
			default: break
		}
	}

	func drawWidgets(in iDirtyRect: CGRect, for phase: ZDrawPhase) {
		ZBezierPath.setClip(to: iDirtyRect)

		if  let c = controller {
			if  c.isExemplar {
				c.drawWidgets(for: phase)
			} else {
				if !gIsEssayMode {
					c.drawWidgets(for: phase)
				}

				gFavoritesMapController.drawWidgets(for: phase)
			}
		}
	}

	func drawDrag(_ iDirtyRect: CGRect) {
		gRubberband.draw()
		gDragging.dragLine?.drawDraggedLineAndDot()
		gDragging.drawRotator()    // for rotating around here in star view
	}

}
