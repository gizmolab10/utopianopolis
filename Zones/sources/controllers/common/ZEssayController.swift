//
//  ZEssayController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gEssayController: ZEssayController? { return gControllers.controllerForID(.idEssay) as? ZEssayController }

class ZEssayController: ZGenericController, ZGestureRecognizerDelegate, ZScrollDelegate {
	override  var controllerID : ZControllerID { return .idEssay }
	@IBOutlet var    essayView : ZEssayView?

	override func setup() {
		essayView?.updateText()
	}
}
