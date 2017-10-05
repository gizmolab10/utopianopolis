//
//  Extensions.swift
//  texst
//
//  Created by Jonathan Sand on 10/4/17.
//  Copyright © 2017 Zones. All rights reserved.
//

import Foundation
import AppKit


extension NSObject {

    func report(_ iMessage: Any?) {
        if  let message = iMessage as? String, message != "" {
            print(message)
        }
    }

}

extension NSResponder {

    func hark(_ iMessage: Any?) {
        if  var   message = iMessage as? String {
            let    window = NSApp.mainWindow
            message       = "key down in: \(message)"

            if  let first = window?.firstResponder, first == self {
                message.append(" <-- FIRST RESPONDER")
            }

            report(message)
        }
    }

}
