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

var gSmallMapController : ZSmallMapController? { return gControllers.controllerForID(.idSmallMap) as? ZSmallMapController }
var gSmallMapHere       : Zone?                { return gSmallMapController?.hereZone }

class ZSmallMapController: ZMapController {

	override  var     hereZone : Zone?         { return gIsRecentlyMode ?  gRecentsHere :  gFavoritesHereMaybe }
	override  var   widgetType : ZWidgetType   { return gIsRecentlyMode ? .tRecent      : .tFavorite }
	override  var controllerID : ZControllerID { return .idSmallMap }
	override  var     isBigMap : Bool          { return false }
	var            isRecentMap : Bool          { return rootWidget.widgetZone?.isInRecents ?? gIsRecentlyMode }

	override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSmallMap) {  // don't send signal to a hidden controller
			update()

			if ![.spSmallMap, .sRelayout].contains(kind) {
				super.handleSignal(iSignalObject, kind: kind)
			} else if let m = mapView {
				m.snp.removeConstraints()
				super.handleSignal(iSignalObject, kind: kind)
				m.snp.makeConstraints { make in
					make.top.equalTo(rootWidget)
				}
			}
		}
	}

	func update() {
		gMapControlsView?.update()
		gCurrentSmallMapRecords?.updateCurrentBookmark()
	}

	override func startup() {
		setup()                                                // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
		gMapControlsView?.setupAndRedraw()
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {   // true means handled
		return gMapController?.handleDragGesture(iGesture) ?? false                    // use drag view coordinates from big (not small) map controller
	}

}
