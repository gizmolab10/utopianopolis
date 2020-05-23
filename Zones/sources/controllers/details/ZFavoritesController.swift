//
//  ZFavoritesController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/5/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

var   gRecentsController: ZGraphController? { return gControllers.controllerForID(.idRecents)   as? ZGraphController }
var gFavoritesController: ZGraphController? { return gControllers.controllerForID(.idFavorites) as? ZGraphController }

class ZFavoritesController: ZGraphController {

	override  var        isMap : Bool          { return false }
	override  var     hereZone : Zone?         { return gIsRecentlyMode ?  gRecents.root :  gFavoritesHereMaybe }
	override  var   widgetType : ZWidgetType   { return gIsRecentlyMode ? .tRecent       : .tFavorite }
	override  var controllerID : ZControllerID { return .idFavorites }
	@IBOutlet var controlsView : ZModeControlsView?

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .Favorites) { // don't send signal to a hidden favorites controller
			super.handleSignal(iSignalObject, kind: iKind)
		}
	}

	override func startup() {
		setup() // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
		controlsView?.updateAndRedraw()
	}

}
