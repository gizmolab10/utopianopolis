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

	override  var      hereZone : Zone?          { return gIsRecentlyMode ?  gRecentsHere :  gFavoritesHereMaybe }
	override  var    widgetType : ZWidgetType    { return gIsRecentlyMode ? .tRecent      : .tFavorite }
	override  var  controllerID : ZControllerID  { return .idSmallMap }
	override  var mapLayoutMode : ZMapLayoutMode { return .linearMode }
	override  var      isBigMap : Bool           { return false }
	var             isRecentMap : Bool           { return rootWidget?.widgetZone?.isInRecents ?? gIsRecentlyMode }

	override func layoutWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		if  gHasFinishedStartup, gDetailsViewIsVisible(for: .vSmallMap) {
			super.layoutWidgets(for: nil, .spRelayout)

			if  let           r = rootWidget,
				let           p = mapPseudoView,
				let detailsSize = gDetailsController?.view.frame.size,
				let   controlsY = gMapControlsView?.frame.height,
				let        mapY = gMapView?.bounds.height {
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

				gMapView?.setAllSubviewsNeedDisplay()
			}
		}
	}

	override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  gDetailsViewIsVisible(for: .vSmallMap) {  // don't send signal to a hidden controller
			update()
			super.handleSignal(iSignalObject, kind: kind)
		}
	}

	func update() {
		layoutForCurrentScrollOffset()
		gMapControlsView?.update()
		gCurrentSmallMapRecords?.updateCurrentBookmark()
	}

	override func startup() {
		setup()                 // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup
		gMapControlsView?.setupAndRedraw()
	}

	override func setup() {
		if  let                          map = gMapView {
			rootWidget                       = ZoneWidget (view: map)
			mapPseudoView                    = ZPseudoView(view: map)
			view     .layer?.backgroundColor = kClearColor.cgColor
			mapPseudoView?            .frame = map.frame

			super.setup()
			platformSetup()
			mapPseudoView?.addSubpseudoview(rootWidget!)
		}
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool {   // true means handled
		return gMapController?.handleDragGesture(iGesture) ?? false                    // use drag view coordinates from big (not small) map controller
	}

}
