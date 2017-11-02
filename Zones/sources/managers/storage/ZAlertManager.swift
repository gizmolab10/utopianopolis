//
//  ZAlertManager.swift
//  Zones
//
//  Created by Jonathan Sand on 10/30/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZAlertType: Int {
    case eInfo
    case eNoAuth
    case eNoInternet
}

let gAlertManager = ZAlertManager()


class ZAlertManager : NSObject {


    var currentError: Any?


    func report(error iError: Any? = nil, _ message: String? = nil) {
        let text = message ?? ""

        if let error: CKError = iError as? CKError {
            if error.code == CKError.notAuthenticated {
                authAlert()
            }
            print(error.localizedDescription + text)
        } else if let error: NSError = iError as? NSError {
            let waitForIt = (error.userInfo[CKErrorRetryAfterKey] as? String) ?? ""

            print(waitForIt + text)
        } else {
            let error = iError as? String ?? ""

            print(error + text)
        }
    }


    func authAlert() {
        alert()
    }


    func alert() {
        FOREGROUND(canBeDirect: true) {
            let             a = NSAlert()
            a    .messageText = "Warning"
            a.informativeText = "There are problems, please resolve these first"

            a.addButton(withTitle: "OK")
            a.runModal()
        }
    }
}
