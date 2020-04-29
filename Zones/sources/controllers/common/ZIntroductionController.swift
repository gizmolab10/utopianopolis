//
//  ZIntroductionController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/28/20.
//  Copyright © 2020 Zones. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

enum ZIntroductionButtonID: String {
	case child   = "child"
	case sibling = "sibling"
	case idea    = "idea"
	case note    = "note"
	case up      = "up"
	case down    = "down"
	case left    = "left"
	case right   = "right"
	case focus   = "focus"
	case shift   = "shift"
	case command = "command"
	case option  = "option"
	case control = "control"
	case showMe  = "showMe"
}

class ZIntroductionController: ZGenericController {

	@IBOutlet var  showMeButton: ZButton?
	@IBOutlet var   shiftButton: ZButton?
	@IBOutlet var commandButton: ZButton?
	@IBOutlet var  optionButton: ZButton?
	@IBOutlet var controlButton: ZButton?

	@IBAction func buttonAction(_ button: NSUserInterfaceItemIdentification) {
		if  let  identifier = button.identifier?.rawValue,
			let    buttonID = ZIntroductionButtonID(rawValue: identifier) {
			let        zone = gSelecting.currentMoveable
			switch buttonID {
				case .child:   zone.addIdea()
				case .sibling: zone.addNext()
				case .idea:    zone.edit()
				case .note:    break
				case .up:      break
				case .down:    break
				case .left:    break
				case .right:   break
				case .focus:   break
				case .shift:   break
				case .command: break
				case .option:  break
				case .control: break
				case .showMe:  break
			}
		}
	}

}
