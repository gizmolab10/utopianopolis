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
	var            isRecentMap : Bool          { return rootWidget?.widgetZone?.isInRecents ?? gIsRecentlyMode }

	override func updateFrames() {
		mapView?.updateFrames(with: self)
		if  let          mHeight = mapView?.bounds.size.height,
			let          rHeight = rootWidget?.drawnSize.height,
			let          cHeight = gMapControlsView?.frame.height,
			let           sFrame = gDetailsController?.stackView?.frame {
			let           yDelta = CGFloat(16.0)
			let           height = mHeight - rHeight - cHeight - sFrame.height - yDelta
			let             size = CGSize(width: sFrame.width, height: rHeight + yDelta)
			let           origin = CGPoint(x: .zero, y: height)
			mapPseudoView?.frame = CGRect(origin: origin, size: size)
		}
	}

	override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSmallMap) {  // don't send signal to a hidden controller
			update()
			super.handleSignal(iSignalObject, kind: kind)
		}
	}

	func update() {
		updateFrames()
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
