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

var gEssayController   : ZEssayController? { return gControllers.controllerForID(.idNote) as? ZEssayController }
var gEssayControlsView : ZEssayControlsView? { return gEssayController?.essayControlsView }

class ZEssayController : ZGesturesController, ZScrollDelegate {
	override  var         controllerID : ZControllerID { return .idNote }
	var           linkDialogController : ZLinkDialogController?
	var                     parameters : ZEssayLinkParameters?
	@IBOutlet var    essayControlsView : ZEssayControlsView?
	@IBOutlet var            essayView : ZEssayView?

	override func controllerSetup() {
		gestureView = essayView    // do this before calling super setup

		super.controllerSetup()
		essayView?.essayViewSetup()
	}

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gIsEssayMode {
			essayView?.updateTextStorage()
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
