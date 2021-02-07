//
//  ZSmallMapController.swift
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

var gSmallMapController: ZSmallMapController? { return gControllers.controllerForID(.idSmallMap) as? ZSmallMapController }

class ZSmallMapController: ZMapController {

	override  var     isBigMap : Bool          { return false }
	override  var     hereZone : Zone?         { return gIsRecentlyMode ?  gRecentsHere :  gFavoritesHereMaybe }
	override  var   widgetType : ZWidgetType   { return gIsRecentlyMode ? .tRecent      : .tFavorite }
	override  var controllerID : ZControllerID { return .idSmallMap }
	override  var allowedKinds : [ZSignalKind] { return [.sDetails, .sSmallMap, .sRelayout] }
	var            isRecentMap : Bool          { return rootWidget.widgetZone?.isInRecents ?? gIsRecentlyMode }

	override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
		if  let c = gDetailsController, !c.hideableIsHidden(for: .vSmallMap) { // don't send signal to a hidden favorites controller
			update()
			super.handleSignal(iSignalObject, kind: iKind)
		}
	}

	func update() {
		gBreadcrumbsController?.mapControls?.update()
		gCurrentSmallMapRecords?.updateCurrentForMode()
	}

	override func startup() {
		setup() // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
		gBreadcrumbsController?.mapControls?.setupAndRedraw()
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
		return gMapController?.handleDragGesture(iGesture) ?? false // use drag view coordinates from big (not small) map controller
	}

}
