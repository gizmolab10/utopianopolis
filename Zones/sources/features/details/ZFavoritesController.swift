//
//  ZFavoritesController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/5/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

var gFavoritesController: ZFavoritesController? { return gControllers.controllerForID(.idFavorites) as? ZFavoritesController }

class ZFavoritesController: ZGraphController {

	override  var        isMap : Bool          { return false }
	override  var     hereZone : Zone?         { return gIsRecentlyMode ?  gRecents.root :  gFavoritesHereMaybe }
	override  var   widgetType : ZWidgetType   { return gIsRecentlyMode ? .tRecent       : .tFavorite }
	override  var controllerID : ZControllerID { return .idFavorites }
	override  var allowedKinds : [ZSignalKind] { return [.sDetails, .sFavorites, .sRelayout] }
	@IBOutlet var controlsView : ZFavoriteControlsView?

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .Favorites) { // don't send signal to a hidden favorites controller
			update()
			super.handleSignal(iSignalObject, kind: iKind)
		}
	}

	func update() {
		controlsView?.update()
		gRecents.updateCurrentRecent()
		gFavorites.updateCurrentFavorite()
	}

	override func startup() {
		setup() // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
		controlsView?.setupAndRedraw()
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
		return gGraphController?.handleDragGesture(iGesture) ?? false // use drag view coordinates from graph (not favorites) controller
	}

}
