//
//  ZGesturesController.swift
//  Seriously
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

	func restartGestureRecognition() {}
	@objc func handleDragGesture(_ iGesture: ZKeyClickGestureRecognizer?) -> Bool { return false } // false means not handled

	override func setup() {
		super.setup()
		restartGestureRecognition()
	}

	@objc func handleClickGesture(_ iGesture: ZKeyClickGestureRecognizer?) { }
}
