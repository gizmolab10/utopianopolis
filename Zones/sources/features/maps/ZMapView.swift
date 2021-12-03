//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

enum ZMapID: String {
	case mDebugAngles  = "a"
	case mDotsAndLines = "d"
	case mHighlight    = "h"
	case mText         = "t"

	var title          : String { return "\(self)".lowercased().substring(fromInclusive: 1) }
	var identifier     : NSUserInterfaceItemIdentifier { return NSUserInterfaceItemIdentifier(title) }
}

class ZMapView: ZView {

	var mapID                   : ZMapID?
	var debugAnglesView         : ZMapView?
	var dotsAndLinesView        : ZMapView?
	var highlightMapView        : ZMapView?
	override func menu(for event: ZEvent) -> ZMenu? { return gMapController?.mapContextualMenu }

	// MARK:- hover
	// MARK:-

	func updateTracking() { addTracking(for: frame) }

	// MARK:- initialize
	// MARK:-

	func setup(_ id: ZMapID = .mText, mapController: ZMapController) {
		identifier = id.identifier
		mapID      = id

		switch id {
			case .mText:
				debugAnglesView  = ZMapView()
				dotsAndLinesView = ZMapView()
				highlightMapView = ZMapView()

				updateTracking()
				addSubview(dotsAndLinesView!)
				addSubview(highlightMapView!, positioned: .below, relativeTo: dotsAndLinesView)
				addSubview( debugAnglesView!, positioned: .below, relativeTo: highlightMapView)
				debugAnglesView? .setup(.mDebugAngles,  mapController: mapController)
				dotsAndLinesView?.setup(.mDotsAndLines, mapController: mapController)
				highlightMapView?.setup(.mHighlight,    mapController: mapController)
			default:
				zlayer.backgroundColor = CGColor.clear
				bounds                 = superview!.bounds
		}
	}

	func removeAllTextViews(forSmallMap: Bool) {
		for subview in subviews {
			if  let textView = subview as? ZoneTextWidget,
				let inBig = textView.widgetZone?.isInBigMap {
				if  forSmallMap != inBig {
					textView.removeFromSuperview()
				}
			}
		}
	}

	// MARK:- draw
	// MARK:-

	func debugDraw() {
		bounds                 .insetEquallyBy(1.5).drawColoredRect(.blue)
		dotsAndLinesView?.frame.insetEquallyBy(3.0).drawColoredRect(.red)
		highlightMapView?.frame.insetEquallyBy(4.5).drawColoredRect(.purple)
		superview?.drawBox(in: self, with:                          .orange)
	}

	override func draw(_ iDirtyRect: CGRect) {
		if  iDirtyRect.isEmpty {
			return
		}

		switch mapID {
			case .mText:
				if  gDebugAngles {
					removeAllTextViews(forSmallMap: false)
				}

				super            .draw(iDirtyRect) // text fields are drawn by OS
				debugAnglesView? .draw(iDirtyRect)
				dotsAndLinesView?.draw(iDirtyRect)
				highlightMapView?.draw(iDirtyRect)
			default:
				for phase in ZDrawPhase.allInOrder {
					if  (phase == .pDotsAndHighlight) != (mapID == .mDotsAndLines) {
						ZBezierPath(rect: iDirtyRect).setClip()

						switch mapID {
							case .mDotsAndLines: dotsAndLinesView?.clearRect(iDirtyRect)
							case .mDebugAngles:  debugAnglesView? .clearRect(iDirtyRect)
							case .mHighlight:    highlightMapView?.clearRect(iDirtyRect)
							default:             break
						}

						gSmallMapController?.drawWidgets(for: phase)

						if  gDebugAngles {
							debugAnglesView?.drawDebug  (for: phase)
						} else {
							gMapController? .drawWidgets(for: phase)
						}
					}
				}
		}
	}

	func drawDebug(for phase: ZDrawPhase) {

	}

	func clearRect(_ iDirtyRect: CGRect) {
		if  iDirtyRect.isEmpty {
			return
		}

		gBackgroundColor.setFill()
		ZBezierPath(rect: iDirtyRect).fill()
	}

	func clear(forSmallMapOnly: Bool = false) {
		if  mapID == .mText {
			debugAnglesView? .clear()
			highlightMapView?.clear()
			dotsAndLinesView?.clear()

			removeAllTextViews(forSmallMap: forSmallMapOnly)
		}
	}

}
