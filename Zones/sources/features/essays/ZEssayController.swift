//
//  ZEssayController.swift
//  Seriously
//
//  Created by Jonathan Sand on 12/22/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

var gEssayController   : ZEssayController?   { return gControllerForID(.idEssay) as? ZEssayController }
var gEssayControlsView : ZEssayControlsView? { return gEssayController?.essayControlsView }

class ZEssayController : ZGesturesController, ZScrollDelegate {
	override  var      controllerID : ZControllerID { return .idEssay }
	var        linkDialogController : ZLinkDialogController?
	var                  parameters : ZEssayLinkParameters?
	@IBOutlet var essayControlsView : ZEssayControlsView?
	@IBOutlet var         essayView : ZEssayView?

	override func viewDidLoad() {
		super.viewDidLoad()
		viewWillAppear()
	}

	override func controllerSetup(with mapView: ZMapView?) {
		gestureView = essayView    // do this before calling super setup

		super.controllerSetup(with: mapView)
		essayView?.essayViewSetup()
	}

	override func handleSignal(kind: ZSignalKind) {
		if  gIsEssayMode {
			essayView?.essayRecordName = nil // force shouldOverwrite to true

			essayView?.readTraitsIntoView()
			essayView?.setNeedsDisplay()
		}
	}

	override func prepare(for segue: ZStoryboardSegue, sender: Any?) {
		linkDialogController  = segue.destinationController as? ZLinkDialogController
		linkDialogController?.loadView()
		linkDialogController?.setupWith(parameters)
	}

	func modalForLink(type: ZEssayLinkType, _ showAs: String?, onCompletion: StringStringClosure?) {
		parameters = ZEssayLinkParameters(type: type, showAs: showAs, closure: onCompletion)

		performSegue(withIdentifier: "link", sender: self)
	}

}
