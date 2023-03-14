//
//  ZEvents.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/5/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import EventKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

let gNotificationCenter = NotificationCenter.default
let gEventStore         = EKEventStore() // calendar API
let gEvents             = ZEvents()

class ZEvents: ZGeneric {

	var      keyDownMonitor: Any?
	var flagsChangedMonitor: Any?

    func clear() { removeAllMonitorsAsync() }

//    func createCalendarEvent(named iName: String) -> EKEvent {
//        var event = EKCalendarItem(eventStore: gEventStore)
//       // event.eventIdentifier = iName
//
//        return event
//    }

    func controllerSetup(with mainView: ZMapView?) {
        setupLocalEventsMonitor()
    }
    
	func removeMonitor(_ monitor: inout Any?, _ closure: Closure? = nil) -> Bool {
		if  let save = monitor {
			monitor  = nil

			FOREGROUND(after: 0.001) {
				ZEvent.removeMonitor(save)
				closure?()
			}

			return false
		}

		return true
	}

	func removeAllMonitorsAsync(_ closure: Closure? = nil) {
#if os(OSX)
		let  key = removeMonitor(&keyDownMonitor,                  closure)
		let flag = removeMonitor(&flagsChangedMonitor, !key ? nil: closure)

		if  key && flag {
			closure?()
		}
        #endif
    }


    func setupLocalEventsMonitor() {
        #if os(OSX)

		flagsChangedMonitor = ZEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event -> ZEvent? in
			let flags = event.modifierFlags
			if  flags.rawValue != 0 {
				gMapController?.replaceAllToolTips(flags)
			}

			return event
		}

		keyDownMonitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> ZEvent? in
			if !isDuplicate(event: event) {

				// do not detect gIsHelpFrontmost nor handle event in gHelpController except in default of work mode switch

				let isWindow = (event.type == .keyDown) || (event.window?.contentView?.frame.contains(event.locationInWindow) ?? false)

				if  gIsEssayMode,
					gMapIsResponder {
					return gMapEditor.handleEvent(event, isWindow: isWindow, forced: true)   // if in essay mode and first responder is in a map
				}

				switch gWorkMode {
					case .wResultsMode:             return gSearchBarController?.handleEvent(event)
					case .wEssayMode:               return gEssayEditor         .handleEvent(event, isWindow: isWindow)
					case .wMapMode, .wEditIdeaMode: return gMapEditor           .handleEvent(event, isWindow: isWindow)
					default:                        return gHelpController?     .handleEvent(event) ?? event
				}
			}

			return event
		}

        #endif
    }
}
