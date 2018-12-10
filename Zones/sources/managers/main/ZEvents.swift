//
//  ZEventsManager.swift
//  Thoughtful
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
let gEventStore         = EKEventStore()
let gEvents             = ZEvents()


class ZEvents: NSObject {


    var monitor: Any?


    func clear() { removeMonitorAsync() }

//
//    func createCalendarEvent(named iName: String) -> EKEvent {
//        var event = EKCalendarItem(eventStore: gEventStore)
//       // event.eventIdentifier = iName
//
//        return event
//    }
//

    
    func setup() {
        setupGlobalEventsMonitor()
//        gNotificationCenter.addObserver(self, selector: #selector(ZEventsManager.handleDarkModeChange), name: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }
    
    
    func handleDarkModeChange(iNote: Notification) {
        gControllers.signalFor(nil, regarding: .eRelayout)
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
                    case .searchMode:
                        return gSearching.handleEvent(event)
                    case .graphMode:
                        return gGraphEditor.handleEvent(event, isWindow: true)
                    default: break
                    }
                }

                return event
            }

        #endif
    }
}
