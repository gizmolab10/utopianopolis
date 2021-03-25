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

	override  var controllerID : ZControllerID { return .idHelpDots }
	override  var allowedKinds : [ZSignalKind] { return [.sRelayout, .sData, .sDatum, .sStartupProgress] }
	@IBOutlet var     topLabel : ZTextField?
	@IBOutlet var  bottomLabel : ZTextField?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func viewDidAppear() {
		super.viewDidAppear()
	}

	override func startup() {
		setup()

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "Essays and notes are well integrated into Seriously. The essay editor has a typical toolbar with some special added buttons, shown below."
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "Any idea can have a note. This note appears in the essay editor with a title at top (the idea text) followed by the text of the note. An essay is made from such a note when any of its listed ideas also contains a note. Notes within an essay display a drag dot to the left of the title of the note."
	}

}
