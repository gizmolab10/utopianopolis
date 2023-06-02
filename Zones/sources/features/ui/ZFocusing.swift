//
//  ZFocusing.swift
//  Seriously
//
//  Created by Jonathan Sand on 3/11/22.
//  Copyright © 2022 Zones. All rights reserved.
//

import Foundation

enum ZFocusKind: Int {
	case eSelected
	case eEdited
}

let gFocusing = ZFocusing()

class ZFocusing : NSObject {

	func grabAndFocusOn(_ zone: Zone?, _ atArrival: @escaping Closure) {
		if  let z = zone {
			gHere = z // side-effect does push

			z.grab() // so the following will work correctly
			focusOnGrab(.eSelected) {
				atArrival()
			}
		}
	}

	func pushPopFavorite(_ flags: ZEventFlags, kind: ZFocusKind) {
		if  flags.hasControl {
			gFavoritesCloud.popAndUpdateCurrent()
		} else {
			focusOnGrab(kind, flags, shouldGrab: true) { // complex grab logic
				gRelayoutMaps()
			}
		}
	}

	func focusOnGrab(_ kind: ZFocusKind = .eEdited, _ flags: ZEventFlags = ZEventFlags(), shouldGrab: Bool = false, _ atArrival: @escaping Closure) {

		// regarding grabbed/edited zone, five states:
		// 1. is a bookmark        -> target becomes here, if in main map then do as for state 2
		// 2. is here              -> update in favorites map
		// 3. in favorites map     -> grab here, if grabbed then do as for state 4
		// 4. not here, COMMAND    -> change here
		// 5. not COMMAND          -> change here to grab

		guard let zone = (kind == .eEdited) ? gCurrentlyEditingZone : gSelecting.firstSortedGrab else {
			atArrival()

			return
		}

		let finishAndGrabHere = {
			gDispatchSignals([.spFavoritesMap])
			gHere.grab()               // NOTE: changes work mode
			atArrival()
		}

		if  zone.isBookmark {     		// state 1
			zone.focusOnBookmarkTarget() { object, kind in
				gHere = object as! Zone

				finishAndGrabHere()
			}
		} else if zone == gHere {       // state 2
			if !gFavoritesCloud.swapBookmarkAndTarget(flags, doNotGrab: !shouldGrab) {
				gFavoritesCloud.matchOrCreateBookmark(for: zone, addToRecents: true)
			}

			atArrival()
		} else if zone.isInFavorites {  // state 3
			finishAndGrabHere()
		} else if flags.hasCommand {    // state 4
			gFavoritesCloud.refocus {
				atArrival()
			}
		} else {                        // state 5
			gHere = zone

			finishAndGrabHere()
		}
	}

}
