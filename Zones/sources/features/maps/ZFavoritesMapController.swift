//
//  ZFavoritesMapController.swift
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

var gFavoritesMapController : ZFavoritesMapController { return gControllers.controllerForID(.idFavoritesMap) as? ZFavoritesMapController ?? ZFavoritesMapController() }

class ZFavoritesMapController: ZMapController {

	override var        mapType : ZMapType       { return .tFavorite }
	override var   controllerID : ZControllerID  { return .idFavoritesMap }
	override var  mapLayoutMode : ZMapLayoutMode { return .linearMode }
	override var canDrawWidgets : Bool           { return gFavoritesAreVisible }
	override var       hereZone : Zone?          { return gFavoritesHereMaybe }

	override func createAndLayoutWidgets(_ kind: ZSignalKind) {
		if  gHasFinishedStartup, gFavoritesAreVisible, shouldHandle(kind) {
			FOREGROUND(after: kind == .sLaunchDone ? 0.01 : .zero) { // so favorites map is not too high when other details views are shown
				super.createAndLayoutWidgets(kind)
			}
		}
	}

	override func layoutForCurrentScrollOffset() {
		if  let           w = hereWidget,
			let           p = mapPseudoView,
			let detailsSize = gDetailsController?.view.frame.size,
			let   controlsY = gMapControlsView?.frame.height,
			let        mapY = mapView?.bounds.height {
			let     widgetY = w.drawnSize.height
			let      deltaY = CGFloat(16.0)
			let           y = mapY - widgetY - controlsY - detailsSize.height - deltaY
			let        size = CGSize(width: detailsSize.width, height: widgetY + deltaY)
			let      origin = CGPoint(x: .zero, y: y)
			let        rect = CGRect(origin: origin, size: size)
			w.absoluteFrame = rect
			p.absoluteFrame = rect
			w        .frame = rect
			p        .frame = rect
		}

		super.layoutForCurrentScrollOffset()
	}

	override func handleSignal(kind: ZSignalKind) {
		if  gFavoritesAreVisible {  // don't send signal to a hidden controller
			gMapControlsView?.controlsUpdate()
			gFavoritesCloud.updateCurrentWithBookmarksTargetingHere()
			super.handleSignal(kind: kind)
		}
	}

	override func controllerStartup() {
		super.controllerStartup()
		gMapControlsView?.setupAndRedraw()
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {   // true means handled
		return gMapController?.handleDragGesture(iGesture) ?? false                    // use drag view coordinates from main (not favorites) map controller
	}

}
