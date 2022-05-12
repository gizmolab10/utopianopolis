//
//  ZFavoritesController.swift
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

var gFavoritesController : ZFavoritesController? { return gControllers.controllerForID(.idSmallMap) as? ZFavoritesController }

class ZFavoritesController: ZMapController {

	override var       hereZone : Zone?          { return gFavoritesHereMaybe }
	override var     widgetType : ZWidgetType    { return .tFavorite }
	override var   controllerID : ZControllerID  { return .idSmallMap }
	override var  mapLayoutMode : ZMapLayoutMode { return .linearMode }
	override var canDrawWidgets : Bool           { return gSmallMapIsVisible }

	override func createAndLayoutWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		if  gHasFinishedStartup, gSmallMapIsVisible {
			super.createAndLayoutWidgets(for: iZone, kind)
		}
	}

	override func layoutForCurrentScrollOffset() {
		if  let           r = hereWidget,
			let           p = mapPseudoView,
			let detailsSize = gDetailsController?.view.frame.size,
			let   controlsY = gMapControlsView?.frame.height,
			let        mapY = mapView?.bounds.height {
			let     widgetY = r.drawnSize.height
			let      deltaY = CGFloat(16.0)
			let           y = mapY - widgetY - controlsY - detailsSize.height - deltaY
			let        size = CGSize(width: detailsSize.width, height: widgetY + deltaY)
			let      origin = CGPoint(x: .zero, y: y)
			let        rect = CGRect(origin: origin, size: size)
			r.absoluteFrame = rect
			p.absoluteFrame = rect
			r        .frame = rect
			p        .frame = rect
		}

		super.layoutForCurrentScrollOffset()
	}


	override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  gSmallMapIsVisible {  // don't send signal to a hidden controller
			gMapControlsView?.controlsUpdate()
			gFavorites.updateCurrentFavorite()
			super.handleSignal(iSignalObject, kind: kind)
		}
	}

	override func controllerStartup() {
		super.controllerStartup()
		gMapControlsView?.setupAndRedraw()
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {   // true means handled
		return gMapController?.handleDragGesture(iGesture) ?? false                    // use drag view coordinates from big (not small) map controller
	}

}