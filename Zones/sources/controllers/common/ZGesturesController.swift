//
//  ZGesturesController.swift
//  iFocus
//
//  Created by Jonathan Sand on 1/29/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZGesturesController: ZGenericController, ZGestureRecognizerDelegate {
	var      gestureView :  ZView?
	var moveRightGesture :  ZGestureRecognizer?
	var  movementGesture :  ZGestureRecognizer?
	var  moveDownGesture :  ZGestureRecognizer?
	var  moveLeftGesture :  ZGestureRecognizer?
	var    moveUpGesture :  ZGestureRecognizer?
	var     clickGesture :  ZKeyClickGestureRecognizer?
	var      edgeGesture :  ZGestureRecognizer?
	let       doneStates : [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]

	func restartGestureRecognition() {} // gestureView?.gestureHandler = self; gDraggedZone = nil }
	@objc func handleDragGesture(_ iGesture: ZKeyClickGestureRecognizer?) { ringHandler(iGesture) }

	override func setup() {
		super.setup()
		restartGestureRecognition()
	}

	func ringHandler(_ iGesture: ZKeyClickGestureRecognizer?) {
		if  let gesture = iGesture {
			let    rect = CGRect(origin: gesture.location(in: gestureView), size: CGSize())

			gRingView?.handleClick(in: rect)
			restartGestureRecognition()
		}
	}

	@objc func handleClickGesture(_ iGesture: ZKeyClickGestureRecognizer?) { ringHandler(iGesture) }
}
