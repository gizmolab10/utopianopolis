//
//  ZMapView.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/27/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import CloudKit
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZMapID: String {
	case mDotsAndLines = "d"
	case mHighlight    = "h"
	case mText         = "t"

	var title          : String { return "\(self)".lowercased().substring(fromInclusive: 1) }
	var identifier     : NSUserInterfaceItemIdentifier { return NSUserInterfaceItemIdentifier(title) }
}

class ZMapView: ZView {

	var mapID                   : ZMapID?
	var dotsAndLinesView        : ZMapView?
	var highlightMapView        : ZMapView?
	override func menu(for event: ZEvent) -> ZMenu? { return gMapController?.mapContextualMenu }

	// MARK: - hover
	// MARK: -

	func updateTracking() { addTracking(for: frame) }

	// MARK: - initialize
	// MARK: -

	func setup(_ id: ZMapID = .mText) {
		identifier = id.identifier
		mapID      = id

		switch id {
			case .mText:
				dotsAndLinesView = ZMapView()
				highlightMapView = ZMapView()

				updateTracking()
				addSubview(dotsAndLinesView!)
				addSubview(highlightMapView!)
				dotsAndLinesView?.setup(.mDotsAndLines)
				highlightMapView?.setup(.mHighlight)
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
			if  mapID == .mText {
				highlightMapView?.resize()
				dotsAndLinesView?.resize()
			}
		}
	}

	func removeAllTextViews(ofType: ZRelayoutMapType = .both) {
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
		dotsAndLinesView?.frame.insetEquallyBy(3.0).drawColoredRect(.red)
		highlightMapView?.frame.insetEquallyBy(4.5).drawColoredRect(.purple)
		superview?.drawBox(in: self, with:                          .orange)
	}
	
	func mustDrawFor(_ phase: ZDrawPhase) -> Bool {
		switch mapID {
		case .mDotsAndLines: return phase == .pLines || phase == .pDots
		case .mText:         return phase == .pLines
		case .mHighlight:    return phase == .pHighlights
		default:             return false
		}
	}

	override func draw(_ iDirtyRect: CGRect) {
		if  iDirtyRect.hasZeroSize {
			return
		}

		switch mapID {
			case .mText:
				super            .draw(iDirtyRect) // text fields are drawn by OS
				dotsAndLinesView?.draw(iDirtyRect)
				highlightMapView?.draw(iDirtyRect)
			default:
				for phase in ZDrawPhase.allInOrder {
					if  mustDrawFor(phase) {
						ZBezierPath(rect: iDirtyRect).setClip()
						gSmallMapController?.drawWidgets(for: phase)
						gMapController?     .drawWidgets(for: phase)
					}
				}
		}
	}

	func clearRect(_ iDirtyRect: CGRect) {
		if  iDirtyRect.hasZeroSize {
			return
		}

		gBackgroundColor.setFill()
		ZBezierPath(rect: iDirtyRect).fill()
	}

	func clear(ofType: ZRelayoutMapType = .both) {
		if  mapID == .mText {
			highlightMapView?.clear()
			dotsAndLinesView?.clear()

			removeAllTextViews(ofType: ofType)
		}
	}

	@objc override func printView() {
		gDetailsController?.temporarilyHideView(for: .vSmallMap) {
			clear(ofType: .small)
			super.printView()
		}
		
		gRelayoutMaps()
	}

}
