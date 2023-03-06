//
//  ZHelpEssayIntroductionController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import CoreData
import Foundation

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZHelpEssayIntroductionController : ZGenericController {

	override  var controllerID : ZControllerID { return .idHelpEssayIntroduction }
	@IBOutlet var    imageView : ZDarkableImageView?
	@IBOutlet var     topLabel : ZTextField?
	@IBOutlet var  bottomLabel : ZTextField?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func controllerStartup() {
		controllerSetup(with: nil)

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "Any idea can have a note. Notes are normally hidden. To see one, COMMAND-N opens it in the Note Editor. From there you can edit, save and print it. Each note has a title at top (the idea text) followed by the full text of the note, as below."
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "An essay appears when an idea has a note, and at least one child that also has a note."
		imageView?.drawBorder(thickness: 0.5, radius: .zero, color: kDarkGrayColor.cgColor)
	}

}
