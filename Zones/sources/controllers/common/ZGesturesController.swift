//
//  ZGesturesController.swift
//  iFocus
//
//  Created by Jonathan Sand on 1/29/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZGesturesController: ZGenericController, ZGestureRecognizerDelegate {
	var               gestureView :  ZView?
	var          moveRightGesture :  ZGestureRecognizer?
	var           movementGesture :  ZGestureRecognizer?
	var           moveDownGesture :  ZGestureRecognizer?
	var           moveLeftGesture :  ZGestureRecognizer?
	var             moveUpGesture :  ZGestureRecognizer?
	var              clickGesture :  ZGestureRecognizer?
	var               edgeGesture :  ZGestureRecognizer?
	let                doneStates : [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]

	func restartGestureRecognition() { gestureView?.gestureHandler = self; gDraggedZone = nil }
	@objc func dragGestureEvent(_ iGesture: ZGestureRecognizer?) { defaultHandler(iGesture) }

	override func setup() {
		super.setup()
		restartGestureRecognition()
	}

	func defaultHandler(_ iGesture: ZGestureRecognizer?) {
		if  let gesture = iGesture {
			let    rect = CGRect(origin: gesture.location(in: gestureView), size: CGSize())
			let  inRing = gRingView?.respondToClick(in: rect) ?? false

			print(inRing)

			restartGestureRecognition()
		}
	}

	@objc func clickEvent(_ iGesture: ZGestureRecognizer?) { defaultHandler(iGesture) }
}
