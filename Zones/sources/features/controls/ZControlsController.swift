//
//  ZControlsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/22/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

var gControlsController: ZControlsController? { return gControllers.controllerForID(.idControls) as? ZControlsController }

class ZControlsController: ZGenericController {

	override  var controllerID    : ZControllerID { return .idControls }
	@IBOutlet var mapControlsView : ZMapControlsView?

	override func handleSignal(kind: ZSignalKind) {
		mapControlsView?.setupAndRedraw()
	}

}
