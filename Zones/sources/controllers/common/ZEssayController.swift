//
//  ZEssayController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Zones. All rights reserved.
//

import Foundation


var gEssayController: ZEssayController? { return gControllers.controllerForID(.idEssay) as? ZEssayController }


class ZEssayController: ZGenericController, ZGestureRecognizerDelegate, ZScrollDelegate {
	override  var controllerID : ZControllerID { return .idEssay }
	@IBOutlet var    essayView : ZEssayView?

	override func viewWillAppear() {
		super.viewWillAppear()
		essayView?.setup()
	}
}
