//
//  ZAlert.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/30/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import CloudKit

#if os(OSX)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif


enum ZAlertType: Int {
    case eInfo
    case eNoAuth
    case eNoInternet
}


enum ZAlertStatus: Int {
    case eStatusShown
    case eStatusShow
    case eStatusYes
    case eStatusNo
}


let                  gAlerts = ZAlerts()
typealias       AlertClosure = (ZAlert?, ZAlertStatus) -> (Void)
typealias AlertStatusClosure = (ZAlertStatus) -> (Void)


class ZAlerts : NSObject {


    var mostRecentError: Error?


    func detectError(_ iError: Any? = nil, _ message: String? = nil, _ closure: BooleanClosure? = nil) {
        let        hasError = iError != nil

        if  let       error = iError as? Error {
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
        let   message = iMessage ?? gBatches.operationText
        let      text = " " + (iMessage ?? "")

        if  let ckError: CKError = iError as? CKError {
            switch ckError.code {
            case .notAuthenticated: closure?(true) // was showAlert("No active iCloud account", "allows you to create new ideas", "Go to Settings and set this up?", closure)
            case .networkFailure:   gHasInternet = false; closure?(true) // was alertNoInternet
            default:
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
            case .eStatusShow:
                iAlert?.showAlert { iResponse in
                    switch iResponse {
                    case .eStatusYes:
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
                case .eStatusShow:
                    iAlert?.showAlert { iResponse in
                        switch iResponse {
                        case .eStatusYes:
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
}
