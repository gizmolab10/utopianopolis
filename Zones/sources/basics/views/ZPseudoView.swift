//
//  ZPseudoView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/23/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

class ZPseudoView: NSObject {

	var        toolTip : String?
	var         bounds = CGRect.zero
	var          frame = CGRect.zero
	var     identifier = NSUserInterfaceItemIdentifier("")
	var subpseudoviews = [ZPseudoView] ()

	func draw(_ iDirtyRect: CGRect) {}
//	func convert(_ point: NSPoint, from view: NSView?) -> NSPoint { return .zero }
//	func convert(_ point: NSPoint, to view: NSView?) -> NSPoint { return .zero }
//	func convert(_ size: NSSize, from view: NSView?) -> NSSize { return .zero }
//	func convert(_ size: NSSize, to view: NSView?) -> NSSize { return .zero }
//	func convert(_ rect: NSRect, from view: NSView?) -> NSRect { return .zero }
	func convert(_ rect: NSRect, to view: NSView?) -> NSRect { return .zero }
	func convert(_ point: NSPoint, from view: ZPseudoView?) -> NSPoint { return .zero }
	func convert(_ point: NSPoint, to view: ZPseudoView?) -> NSPoint { return .zero }
	func convert(_ size: NSSize, from view: ZPseudoView?) -> NSSize { return .zero }
	func convert(_ size: NSSize, to view: ZPseudoView?) -> NSSize { return .zero }
	func convert(_ rect: NSRect, from view: ZPseudoView?) -> NSRect { return .zero }
	func convert(_ rect: NSRect, to view: ZPseudoView?) -> NSRect { return .zero }
	func removeFromSuperpseudoview() {}
	func addSubpseudoview(_ sub: ZPseudoView) {
		
	}

	func setFrameSize(_ newSize: NSSize) {
		frame.size = newSize
	}

}
