//
//  ZBreadcrumbsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/14/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gBreadcrumbsController: ZBreadcrumbsController? { return gControllers.controllerForID(.idCrumbs) as? ZBreadcrumbsController }

class ZBreadcrumbsController: ZGenericController {

	// rename as big map toolbar

	@IBOutlet var   crumbsView : ZBreadcrumbsView?
	@IBOutlet var  mapControls : ZMapControlsView?
	@IBOutlet var searchButton : ZButton?
	override  var controllerID : ZControllerID { return .idCrumbs     }

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		crumbsView? .setupAndRedraw()
		mapControls?.setupAndRedraw()
	}

	@IBAction func search(_ sender: ZButton) {
		gSearching.showSearch(false)
	}

}
