//
//  ZRingController.swift
//  Zones
//
//  Created by Jonathan Sand on 1/28/20.
//  Copyright © 2020 Zones. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gRingView:       ZRingView?       { return gRingController?.ringView }
var gRingController: ZRingController? { return gControllers.controllerForID(.idRing) as? ZRingController }

class ZRingController: ZGenericController, ZGestureRecognizerDelegate, ZScrollDelegate {
	override  var controllerID : ZControllerID { return .idRing }
	@IBOutlet var     ringView : ZRingView?

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  [.sRing, .sResize, .sLaunchDone, .sRelayout].contains(iKind) {
			ringView?.updateGeometry()
			ringView?.updateNecklace(doNotResignal: true)
		}
	}

}
