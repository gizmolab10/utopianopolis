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

let      gAlertManager = ZAlertManager()
typealias AlertClosure = (NSAlert?) -> (Void)


class ZAlertManager : NSObject {


    var mostRecentError: Error? = nil


    func detectError(_ iError: Any? = nil, _ message: String? = nil, _ closure: BooleanClosure? = nil) {
        let        hasError = iError != nil
        gCloudUnavailable   = hasError

        if  let error = iError as? Error {
            mostRecentError = error
        }

        closure?(hasError)
    }


    func alertError(_ iError: Any? = nil, _ message: String? = nil, _ closure: BooleanClosure? = nil) {
        detectError(iError, message) { iHasError in
            if !iHasError {
                closure?(false) // false means no error
            } else {
                self.report(error: iError) { (iResponse: Any?) in
                    closure?(iResponse as? Bool ?? true) // false means user approved alert
                }
            }
        }
    }


    private func report(error iError: Any? = nil, _ iMessage: String? = nil, _ closure: AnyClosure? = nil) {
        let   message = iMessage ?? gDBOperationsManager.operationText
        let      text = " " + (iMessage ?? "")

        if  let ckError: CKError = iError as? CKError {
            if  ckError.code == CKError.notAuthenticated {
                authAlert(closure)
            } else {
                print(ckError.localizedDescription + text)
            }
        } else if let nsError = iError as? NSError {
            let waitForIt = nsError.userInfo[CKErrorRetryAfterKey] as? String ?? ""

            alert(message, waitForIt) { iAlert in
                let response = iAlert?.runModal()

                closure?(response)
            }
        } else {
            let error = iError as? String ?? ""

            print(error + text)
        }
    }


    func authAlert(_ closure: AnyClosure? = nil) {
        alert("No active iCloud account", "allows you to create new ideas", "Go to Settings and set this up?") { iAlert in
            let response = iAlert?.runModal()

            closure?(response)
        }
    }


    func alert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOkayTitle: String = "OK", _ closure: AlertClosure? = nil) {
        FOREGROUND(canBeDirect: true) {
            let             a = NSAlert()
            a    .messageText = iMessage
            a.informativeText = iExplain ?? ""

            a.addButton(withTitle: iOkayTitle)
            closure?(a)
        }
    }
}
