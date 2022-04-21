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

	func findAndSetHere(asParentOf zone: Zone) -> Bool {
//		var found = gRecents   .findAndSetHereAsParentOfBookmarkTargeting(zone)
		return gFavorites .findAndSetHereAsParentOfBookmarkTargeting(zone) // || found

//		return found
	}

	func grabAndFocusOn(_ zone: Zone?, _ atArrival: @escaping Closure) {
		if  let z = zone {
			gHere = z // side-effect does push

			z.grab() // so the following will work correctly
			focusOnGrab(.eSelected) {
				atArrival()
			}
		}
	}

	func focusOrPopSmallMap(_ flags: ZEventFlags, kind: ZFocusKind) {
		if  flags.isControl {
			gFavorites.popAndUpdateCurrent()
		} else {
			focusOnGrab(kind, flags.isCommand, shouldGrab: true) { // complex grab logic
				gRelayoutMaps()
			}
		}
	}

	func focusOnGrab(_ kind: ZFocusKind = .eEdited, _ NOBOOKMARK: Bool = false, shouldGrab: Bool = false, _ atArrival: @escaping Closure) {

		// regarding grabbed/edited zone, five states:
		// 1. is a bookmark        -> target becomes here, if in big map then do as for state 2
		// 2. is here              -> update in small map
		// 3. in small map         -> grab here, if grabbed then do as for state 4
		// 4. not here, NOBOOKMARK -> change here
		// 5. not NOBOOKMARK       -> select here, create a bookmark

		guard  let zone = (kind == .eEdited) ? gCurrentlyEditingWidget?.widgetZone : gSelecting.firstSortedGrab else {
			atArrival()

			return
		}

		let finishAndGrabHere = {
			gSignal([.spSmallMap])
			gHere.grab()               // NOTE: changes work mode
			atArrival()
		}

		if  zone.isBookmark {     		// state 1
			zone.focusOnBookmarkTarget() { object, kind in
				gHere = object as! Zone

				finishAndGrabHere()
			}
		} else if zone == gHere {       // state 2
			if !gFavorites.swapBetweenBookmarkAndTarget(doNotGrab: !shouldGrab) {
				gFavorites.matchOrCreateBookmark(for: zone, autoAdd: true)
			}

			atArrival()
		} else if zone.isInFavorites {   // state 3
			finishAndGrabHere()
		} else if NOBOOKMARK {          // state 4
			gFavorites.refocus {
				atArrival()
			}
		} else {                        // state 5
			gHere = zone

			finishAndGrabHere()
		}
	}

}
