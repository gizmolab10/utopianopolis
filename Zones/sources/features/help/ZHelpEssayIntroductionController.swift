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
	@IBOutlet var controlsView : NSView?

	override func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return super.shouldHandle(kind) && (gHelpWindow?.isVisible ?? false)
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		updateImage()
	}

	override func startup() {
		setup()

		topLabel?   .font = kLargeHelpFont
		topLabel?   .text = "Essays and notes"
		bottomLabel?.font = kLargeHelpFont
		bottomLabel?.text = "All of this is explained in detail in the table below"
	}

	func updateImage() {
		if  let       cView = controlsView, cView.subviews.count == 0,
			let       image = ZImage(named: "essay.controls"),
			var       frame = controlsView?.frame {
			let   imageView = ZImageView(image: image)

			cView.addSubview(imageView)

			let     fCenter = frame.center
			let       iSize = frame.size.scaleToFit(size: image.size)
			let     iBounds = CGRect(origin: .zero, size: iSize)
			let     iCenter = iBounds.center
			frame   .origin = CGPoint(fCenter - iCenter)
			frame     .size = iSize
			imageView.frame = frame
		}
	}

}
