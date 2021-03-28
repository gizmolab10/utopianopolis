//
//  ZHelpEssayIntroductionController.swift
//  Seriously
//
//  Created by Jonathan Sand on 6/16/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

class ZHelpEssayIntroductionController : ZGenericController {

	override  var controllerID : ZControllerID { return .idHelpEssayIntroduction }
	override  var allowedKinds : [ZSignalKind] { return [.sRelayout, .sData, .sDatum, .sStartupProgress, .sAppearance] }
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
		bottomLabel?.text = "An essay is made from an idea when it and any of its listed ideas also contains a note. Within the essay, each note displays a drag dot preceding its title (like the grabbed note below)."
		imageView?.addBorder(thickness: 0.5, radius: 0.0, color: kDarkGrayColor.cgColor)
	}

}
