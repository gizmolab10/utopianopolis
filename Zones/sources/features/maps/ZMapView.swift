//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZMapID: String {
	case mHighlight    = "h"
	case mText         = "t"
	case mDotsAndLines = "m"
}

class ZMapView: ZView {

	var mapID            : ZMapID?
	var dotsAndLinesView : ZMapView?
	var highlightMapView : ZMapView?
	var controller       : ZMapController?
	var isBigMap         : Bool { return controller?.isBigMap ?? true }
	override func menu(for event: ZEvent) -> ZMenu? { return controller?.mapContextualMenu }

	func debugDraw() {
		if  !isBigMap {
			if  var rRect = controller?.rootWidget?.frame {
				rRect     = convert(rRect, to: self)
				rRect                                  .drawColoredRect(ZColor.green)
			}

			if  let sView = superview {
				let sRect = sView.convert(sView.bounds, to: self)
				sRect                                  .drawColoredRect(ZColor.orange)
			}

			if  let hView = gSmallTogglingView {
				let hRect = hView.convert(hView.bounds, to: self)
				hRect                                  .drawColoredRect(ZColor.magenta)
			}

			bounds                 .insetEquallyBy(1.5).drawColoredRect(ZColor.blue)   // height too small
			dotsAndLinesView?.frame.insetEquallyBy(3.0).drawColoredRect(ZColor.red)    // height too tall, width too small
			highlightMapView?.frame.insetEquallyBy(4.5).drawColoredRect(ZColor.purple) //       ",             "
		}
	}

	func updateFrames() {
		if  let              widget = controller?.rootWidget, !isBigMap {
			var                rect = widget.frame
			rect          .origin.x = 8.0
			widget           .frame = rect
			let                size = widget.drawnSize.insetBy(0.0, -8.0)
			rect                    = CGRect(origin: .zero, size: size)
			frame                   = rect
			dotsAndLinesView?.frame = rect
			highlightMapView?.frame = rect
			superview?       .frame = rect
		}
	}

	override func draw(_ iDirtyRect: CGRect) {
		switch mapID {
			case .mText:
				super            .draw(iDirtyRect)
				dotsAndLinesView?.draw(iDirtyRect)
				highlightMapView?.draw(iDirtyRect)
			default:
				for phase in ZDrawPhase.allInOrder {
					ZBezierPath(rect: iDirtyRect).setClip()

					if  (phase == .pDots) != (mapID == .mDotsAndLines) {
						controller?.rootWidget?.traverseAllProgeny(inReverse: false) { widget in
							widget.draw(phase)
						}
					}
				}
		}
	}

	func setup(_ id: ZMapID = .mText, mapController: ZMapController) {
		controller = mapController
		mapID      = id

		if  id != .mText {
			zlayer.backgroundColor = CGColor.clear
			bounds                 = superview!.bounds
		} else {
			dotsAndLinesView       = ZMapView()
			highlightMapView       = ZMapView()

			updateTracking()
			addSubview(dotsAndLinesView!)
			addSubview(highlightMapView!)
			dotsAndLinesView?.setup(.mDotsAndLines, mapController: controller!)
			highlightMapView?.setup(.mHighlight,    mapController: controller!)
		}
	}

	// MARK:- hover
	// MARK:-

	func updateTracking() { addTracking(for: frame) }

	override func mouseMoved(with event: ZEvent) {
		super.mouseMoved(with: event)

		let location = convert(event.locationInWindow, from: nil)

		controller?.detectHover(at: location)?.setNeedsDisplay()
	}

}
