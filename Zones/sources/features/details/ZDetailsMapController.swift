//
//  ZDetailsMapController.swift
//  Seriously
//
//  Created by Jonathan Sand on 5/5/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gDetailsMapController: ZDetailsMapController? { return gControllers.controllerForID(.idFavorites) as? ZDetailsMapController }

class ZDetailsMapController: ZGraphController {

	override  var        isMap : Bool          { return false }
	override  var     hereZone : Zone?         { return gIsRecentlyMode ?  gRecentsHere :  gFavoritesHereMaybe }
	override  var   widgetType : ZWidgetType   { return gIsRecentlyMode ? .tRecent      : .tFavorite }
	override  var controllerID : ZControllerID { return .idFavorites }
	override  var allowedKinds : [ZSignalKind] { return [.sDetails, .sFavorites, .sRelayout] }
	@IBOutlet var controlsView : ZDetailsMapControlsView?

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .Map) { // don't send signal to a hidden favorites controller
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
