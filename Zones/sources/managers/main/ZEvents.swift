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
                        
                        return gSearchManager.handleEvent(event)
                        
                    case .graphMode:
                        let     flags = event.modifierFlags
                        let isControl = flags.isControl
                        let isCommand = flags.isCommand
                        let  isOption = flags.isOption
                        let     isAny = isOption || isCommand || isControl
                        
                        if  let key = event.charactersIgnoringModifiers {
                            if !gIsEditingText {
                                gGraphEditor.handleKey(key, flags: flags, isWindow: true); return nil
                            } else {
                                switch key {
                                case "a":    if isAny { gEditedTextWidget?.selectAllText(); return nil }
                                case "d":    if isAny { gGraphEditor.addIdeaFromSelectedText(); return nil }
                                case "f":    if isAny { gGraphEditor.search(); return nil }
                                case "/":    if isAny { gFocusManager.focus(kind: .eEdited, false) { self.redrawSyncRedraw() }; return nil }
                                case "?":    if isAny { gGraphEditor.showKeyboardShortcuts(); return nil }
                                case kSpace: if isAny { gGraphEditor.addIdea(); return nil }
                                default:
                                    if  let arrow = key.arrow {
                                        gTextEditor.handleArrow(arrow, flags: flags); return nil
                                    }
                                }
                            }
                        }
                    default: break
                    }
                }

                return event
            }

        #endif
    }
}
