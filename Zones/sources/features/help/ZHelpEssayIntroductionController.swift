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
	@IBOutlet var     topLabel : ZTextField?
	@IBOutlet var  bottomLabel : ZTextField?
	@IBOutlet var    imageView : NSImageView?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func startup() {
		setup()

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "Any idea can [optionally] have a note, which can be viewed, edited, saved and printed in the essay editor. Each note has a title at top (the idea text) followed by the full text of the note (like this, ignoring the grey rectangle)."
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "An essay is made from a note when any of the listed ideas within its idea also contain a note. Each such note displays a drag dot preceding its title (like the grabbed note at bottom left)."
		imageView?.drawBorder(thickness: 0.5, radius: 0.0, color: kDarkGrayColor.cgColor)
	}

}
