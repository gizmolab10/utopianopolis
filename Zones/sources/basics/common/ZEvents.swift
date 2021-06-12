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

    var monitor: Any?

    func clear() { removeMonitorAsync() }

//    func createCalendarEvent(named iName: String) -> EKEvent {
//        var event = EKCalendarItem(eventStore: gEventStore)
//       // event.eventIdentifier = iName
//
//        return event
//    }

    func setup() {
        setupLocalEventsMonitor()
        gNotificationCenter.addObserver(self, selector: #selector(ZEvents.handleDarkModeChange), name: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }
    
    
    @objc func handleDarkModeChange(iNote: Notification) {
        gRedrawMaps()
		gEssayView?.resetForDarkMode()
    }
    
    
    func removeMonitorAsync(_ closure: Closure? = nil) {
        #if os(OSX)
            if  let save = monitor {
                monitor  = nil

                FOREGROUND(after: 0.001) {
                    ZEvent.removeMonitor(save)
                    closure?()
                }
            } else {
                closure?()
            }
        #endif
    }


    func setupLocalEventsMonitor() {
        #if os(OSX)

		self.monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> ZEvent? in
                if !isDuplicate(event: event) {
					if  gIsHelpFrontmost {
						return gHelpController?    .handleEvent(event) ?? event
					}

					let isWindow = event.window?.contentView?.frame.contains(event.locationInWindow) ?? false

					switch gWorkMode {
						case .wSearchMode:
							return gSearching      .handleEvent(event)
						case .wEssayMode:
							return gEssayEditor    .handleEvent(event, isWindow: isWindow)
						case .wMapMode, .wEditIdeaMode:
							return gMapEditor      .handleEvent(event, isWindow: isWindow)
						default:
							return gHelpController?.handleEvent(event) ?? event
					}
				}

                return event
            }

        #endif
    }
}
