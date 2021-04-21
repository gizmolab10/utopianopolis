//
//  ZWebLinkController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/5/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation

enum ZLinkButtonType: String {
	case tCancel = "cancel"
	case tApply  = "apply"
}

var gLinkDialogController : ZLinkDialogController? { return gControllers.controllerForID(.idLink) as? ZLinkDialogController }

class ZLinkDialogController: ZGenericController {

	@IBOutlet var         link : ZTextField?
	@IBOutlet var        shown : ZTextField?
	@IBOutlet var        label : ZTextField?
	override  var controllerID : ZControllerID { return .idLink }
	var               callback : StringStringClosure?
	var                   type : ZEssayHyperlinkType?

	func setupWith(_ iType: ZEssayHyperlinkType?, title: String?, onCompletion: StringStringClosure?) {
		type        = iType
		callback    = onCompletion
		shown?.text = title ?? "click here"
		label?.text = (type == .hWeb) ? "Text of link" : "Name of file"
	}

	@IBAction func buttonAction(button: ZButton) {
		var  linkText : String?
		var titleText : String?
		if  let  type = button.linkButtonType, type == .tApply {
			titleText = shown?.text
			linkText  = link? .text
		}

		dismiss(nil)
		callback?(linkText, titleText)
	}

}
