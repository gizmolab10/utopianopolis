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

var gEssayController: ZEssayController? { return gControllers.controllerForID(.idNote) as? ZEssayController }

class ZEssayController: ZGesturesController, ZScrollDelegate {
	override  var         controllerID : ZControllerID { return .idNote }
	var           linkDialogController : ZLinkDialogController?
	var                        closure : StringStringClosure?
	var                           type : ZEssayHyperlinkType?
	var                          shown : String?
	@IBOutlet var            essayView : ZEssayView?

	override func setup() {
		gestureView = essayView    // do this before calling super setup
//		linkDialogController = NSStoryboard(name: "Main", bundle: nil).instantiateController(identifier: "linkDialog", creator: nil)

		super.setup()
		essayView?.setup()
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  gIsEssayMode,
			[.sEssay, .sAppearance].contains(iKind) {        // ignore the signal from the end of process next batch
			essayView?.updateText()
		}
	}

	override func prepare(for segue: ZStoryboardSegue, sender: Any?) {
		linkDialogController = segue.destinationController as? ZLinkDialogController
		linkDialogController?.loadView()
		linkDialogController?.setupWith(type, title: shown, onCompletion: closure)
	}

	func modalForHyperlink(type: ZEssayHyperlinkType, _ title: String?, onCompletion: StringStringClosure?) {
		self.type = type
		shown     = title
		closure   = onCompletion
		performSegue(withIdentifier: "webLink", sender: self)
	}

}
