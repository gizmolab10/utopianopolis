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
        setupGlobalEventsMonitor()
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


    func setupGlobalEventsMonitor() {
        #if os(OSX)

            self.monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> ZEvent? in
                if !isDuplicate(event: event) {
                    switch gWorkMode {
						case .wSearchMode:
							return     gSearching      .handleEvent(event)
						case .wEssayMode:
							if  gIsHelpFrontmost {
								return gHelpController?.handleEvent(event) ?? nil
							} else {
								return gEssayEditor    .handleEvent(event, isWindow: true)
							}
						case .wMapMode, .wEditIdeaMode:
							if !gIsHelpFrontmost {
								return gMapEditor      .handleEvent(event, isWindow: true)
							}

							fallthrough
						default:
							return     gHelpController?.handleEvent(event) ?? nil
					}
				}

                return event
            }

        #endif
    }
}
