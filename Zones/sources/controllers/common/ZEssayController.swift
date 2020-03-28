//
//  ZEssayController.swift
//  Thoughtful
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
	override  var      controllerID : ZControllerID { return .idNote }
	@IBOutlet var webLinkController : ZWebLinkController?
	@IBOutlet var         essayView : ZEssayView?

	override func setup() {
		gestureView = essayView    // do this before calling super setup

		super.setup()
		essayView?.updateText()
	}

	override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  gIsNoteMode && iKind != .sRelayout {
			essayView?.updateText()
		}
	}

	func modalForWebLink(_ title: String?) -> String? {
		if  let name = title {
			performSegue(withIdentifier: "webLink", sender: nil)
//			let a = ZAlert()
//
//			a.accessoryView = webLinkController?.view
//
//			a.showAlert { status in
//				print(name)
//			}
		}

		return nil
	}

}
