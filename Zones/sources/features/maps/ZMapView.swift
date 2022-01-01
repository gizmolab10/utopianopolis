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
	case mDotsAndLines      = "d"
	case mTextAndHighlights = "t"

	var title      : String { return "\(self)".lowercased().substring(fromInclusive: 1) }
	var identifier : NSUserInterfaceItemIdentifier { return NSUserInterfaceItemIdentifier(title) }
}

class ZMapView: ZView {

	var mapID                    : ZMapID?
	var dotsAndLinesView         : ZMapView?
	override func menu(for event : ZEvent) -> ZMenu? { return gMapController?.mapContextualMenu }

	// MARK: - hover
	// MARK: -

	func updateTracking() { addTracking(for: frame) }

	// MARK: - initialize
	// MARK: -

	func setup(_ id: ZMapID = .mTextAndHighlights) {
		identifier = id.identifier
		mapID      = id

		switch id {
			case .mTextAndHighlights:
				dotsAndLinesView = ZMapView()

				updateTracking()
				addSubview(dotsAndLinesView!)
				dotsAndLinesView?.setup(.mDotsAndLines)
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
			if  mapID == .mTextAndHighlights {
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
		superview?.drawBox(in: self, with:                          .orange)
	}
	
	func mustDrawFor(_ phase: ZDrawPhase) -> Bool {
		switch mapID {
		case .mDotsAndLines:      return phase == .pLines || phase == .pDots
		case .mTextAndHighlights: return phase == .pHighlights
		default:                  return false
		}
	}

	override func draw(_ iDirtyRect: CGRect) {
		if  iDirtyRect.hasZeroSize {
			return
		}

//		clearRect(iDirtyRect)

		if  mapID == .mTextAndHighlights {
			super            .draw(iDirtyRect) // text fields are drawn by OS
			dotsAndLinesView?.draw(iDirtyRect)
		}

		for phase in ZDrawPhase.allInOrder {
			if  mustDrawFor(phase) {
				ZBezierPath(rect: iDirtyRect).setClip()
				gSmallMapController?.drawWidgets(for: phase)
				gMapController?     .drawWidgets(for: phase)
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

	@objc override func printView() {
		gDetailsController?.temporarilyHideView(for: .vSmallMap) {
			super.printView()
		}
		
		gRelayoutMaps()
	}

}
