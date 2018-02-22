//
//  ZEventsManager.swift
//  Focus
//
//  Created by Jonathan Sand on 10/5/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


let gEventsManager = ZEventsManager()


class ZEventsManager: NSObject {


    var monitor: Any? = nil


    func clear() { removeMonitorAsync() }


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
                switch gWorkMode {
                case .searchMode:

                    return gSearchManager.handleKeyEvent(event)

                case .graphMode:
                    let    flags = event.modifierFlags

                    if  flags.isCommand,
                        gIsEditingText,
                        let    key = event.charactersIgnoringModifiers {
                        switch key {
                        case "f":
                            gTextManager.stopCurrentEdit()
                            gEditingManager.handleKey(key, flags: flags, isWindow: false)

                            return nil
                        default:
                            break
                        }
                    }

                    break

                default: break
                }

                return event
            }

        #endif
    }
}
