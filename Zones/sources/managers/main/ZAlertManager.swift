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


enum ZAlertState: Int {
    case eShown
    case eShow
    case eYes
    case eNo
}


let           gAlertManager = ZAlertManager()
typealias      AlertClosure = (ZAlert?, ZAlertState) -> (Void)
typealias AlertStateClosure = (ZAlertState) -> (Void)


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
                    closure?(iResponse as? Bool ?? true) // true means user rejected alert
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
                closure?(true)
            }
        } else if let nsError = iError as? NSError {
            let waitForIt = nsError.userInfo[CKErrorRetryAfterKey] as? String ?? ""

            alert(message, waitForIt) { iAlert, iState in
                iAlert?.showAlert { iResponse in
                    closure?(iResponse)
                }
            }
        } else {
            let error = iError as? String ?? ""

            print(error + text)
            closure?(true)
        }
    }


    func alertNoInternet(_ onCompletion: @escaping Closure) {
        let message = "In System Preferences, please enable network access"

        alert("To gain full use of this app,", message, "Click here to begin") { iAlert, iState in
            switch iState {
            case .eShow:
                iAlert?.showAlert { iResponse in
                    switch iResponse {
                    case .eYes:
                        self.openSystemPreferences()
                        onCompletion()
                    default: break
                    }
                }
            default:
                self.openSystemPreferences()
                onCompletion()
            }
        }
    }


    func alertSystemPreferences(_ onCompletion: @escaping Closure) {
        let message = "In System Preferences, please \n  1. click on iCloud,\n  2. sign in,\n  3. turn on iCloud drive"

        alert("To gain full use of this app,", message, "Click here to begin") { iAlert, iState in
                switch iState {
                case .eShow:
                    iAlert?.showAlert { iResponse in
                        switch iResponse {
                        case .eYes:
                            self.openSystemPreferences()
                            onCompletion()
                        default: break
                        }
                    }
                default:
                    self.openSystemPreferences()
                    onCompletion()
                }
        }
    }


    func openSystemPreferences() {
        #if os(OSX)
            if let url = URL(string: "x-apple.systempreferences:com.apple.ids.service.com.apple.private.alloy.icloudpairing") {
                NSWorkspace.shared().open(url)
            }
        #else
            if let url = URL(string: "App-Prefs:root=General&path=Network") {
                UIApplication.shared.open(url)
            }
        #endif
    }


    func authAlert(_ closure: AnyClosure? = nil) {
        alert("No active iCloud account", "allows you to create new ideas", "Go to Settings and set this up?") { iAlert, iState in
            switch iState {
            case .eShow:
                iAlert?.showAlert { iResponse in
                    closure?(iResponse.rawValue)
                }
            default:
                closure?(iState)
            }
        }
    }


    func alert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOkayTitle: String = "OK", _ closure: AlertClosure? = nil) {
        FOREGROUND(canBeDirect: true) {
            #if os(OSX)
                let             a = ZAlert()
                a    .messageText = iMessage
                a.informativeText = iExplain ?? ""

                a.addButton(withTitle: iOkayTitle)
            #else
                let             a = ZAlert(title: iMessage, message: iExplain, preferredStyle: .alert)
                let          okay = UIAlertAction(title: iOkayTitle, style: .default) { iAction in
                    closure?(a, .eYes)
                }

                a.addAction(okay)
            #endif

            closure?(a, .eShow)
        }
    }
}
