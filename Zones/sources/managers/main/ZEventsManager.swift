//
//  ZEventsManager.swift
//  Focus
//
//  Created by Jonathan Sand on 10/5/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import EventKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


let gNotificationCenter = NotificationCenter.default
let gEventsManager      = ZEventsManager()
let gEventStore         = EKEventStore()


class ZEventsManager: NSObject {


    var monitor: Any? = nil


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
        gControllersManager.signalFor(nil, regarding: .redraw)
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
                if  gCurrentEvent != event {
                    gCurrentEvent  = event
                    
                    switch gWorkMode {
                    case .searchMode:
                        
                        return gSearchManager.handleKeyEvent(event)
                        
                    case .graphMode:
                        let    flags = event.modifierFlags
                        let    key = event.charactersIgnoringModifiers
                        
                        if  flags.isCommand,
                            gIsEditingText,
                            key != nil {
                            switch key! {
                            case "f":
                                gTextManager.stopCurrentEdit()
                                gEditingManager.handleKey(key, flags: flags, isWindow: false)
                                
                                return nil
                            default:
                                break
                            }
                        } else if !gIsEditingText {
                            gEditingManager.handleKey(key, flags: flags, isWindow: false)
                        }
                        
                        break
                        
                    default: break
                    }
                }

                return event
            }

        #endif
    }
}
