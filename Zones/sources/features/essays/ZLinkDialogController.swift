//
//  ZWebLinkController.swift
//  Seriously
//
//  Created by Jonathan Sand on 2/5/20.
//  Copyright © 2020 Jonathan Sand. All rights reserved.
//

import Foundation
import Cocoa

enum ZLinkButtonType: String {
	case tCancel = "cancel"
	case tApply  = "apply"
}

struct ZEssayLinkParameters {
	let    type : ZEssayLinkType?
	let  showAs : String?
	let closure : StringStringClosure?
}

class ZLinkDialogController: ZGenericController {

	@IBOutlet var         link : ZTextField?
	@IBOutlet var        label : ZTextField?
	@IBOutlet var       showAs : ZTextField?
	@IBOutlet var  applyButton : NSButton?
	override  var controllerID : ZControllerID { return .idLink }
	var                 params : ZEssayLinkParameters?

	override func awakeFromNib() {
		applyButton?.keyEquivalent = kReturn

		super.awakeFromNib()
	}

	func setupWith(_   parameters: ZEssayLinkParameters?) {
		params       = parameters
		showAs?.text = params?.showAs ?? "click here"
		label? .text = params?.type?.linkDialogLabel
	}

	@IBAction func buttonAction(button: ZButton) {
		var  linkText : String?
		var titleText : String?
		if  let  type = button.linkButtonType, type == .tApply {
			titleText = showAs?.text
			linkText  = link?  .text
		}

		dismiss(nil)
		params?.closure?(linkText, titleText)
	}

}
