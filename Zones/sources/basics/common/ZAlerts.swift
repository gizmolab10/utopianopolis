//
//  ZAlert.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/30/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

enum ZAlertStatus: Int {
    case sShown
    case sShow
    case sYes
    case sNo
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
		detectError(iError, message) { [self] iHasError in
            if !iHasError {
                closure?(false) // false means no error
            } else {
                report(error: iError) { (choice: Any?) in
                    closure?(choice as? Bool ?? true) // true means user rejected alert
                }
            }
        }
    }

    private func report(error iError: Any? = nil, _ iMessage: String? = nil, _ closure: AnyClosure? = nil) {
        let   message = iMessage ?? gBatches.operationText
        let      text = kSpace + (iMessage ?? kEmpty)

        if  let ckError: CKError = iError as? CKError {
			switch ckError.code {
//				case .notAuthenticated: closure?(true) // was showAlert("No active iCloud account", "allows you to create new ideas", "Go to Settings and set this up?", closure)
				case .networkUnavailable: gHasInternet = false; closure?(true) // was alertNoInternet
				default:
					printDebug(.dError, ckError.localizedDescription + text)
					closure?(true)
			}
        } else if let nsError = iError as? NSError {
            let waitForIt = nsError.userInfo[CKErrorRetryAfterKey] as? String ?? kEmpty

            alertWithClosure(message, waitForIt) { alert, status in
				alert?.showModal { choice in
                    closure?(choice)
                }
            }
        } else {
            let error = iError as? String ?? kEmpty

            printDebug(.dError, error + text)
            closure?(true)
        }
    }

    func alertNoInternet(_ onCompletion: @escaping Closure) {
        let message = "In System Preferences, please enable network access"

		alertWithClosure("To gain full use of this app,", message, "Click here to begin") { [self] alert, status in
			switch status {
				case .sShow:
					alert?.showModal { [self] choice in
						switch choice {
							case .sYes:
								openSystemPreferences()
								onCompletion()
							default: break
						}
					}
				default:
					openSystemPreferences()
					onCompletion()
			}
        }
    }

    func alertSystemPreferences(_ onCompletion: @escaping Closure) {
        let message = "In System Preferences, please \n  1. click on iCloud,\n  2. sign in,\n  3. turn on iCloud drive"

		alertWithClosure("To gain full use of this app,", message, "Click here to begin") { [self] alert, status in
			switch status {
				case .sShow:
					alert?.showModal { [self] choice in
						switch choice {
							case .sYes:
								openSystemPreferences()
								onCompletion()
							default: break
						}
					}
				default:
					openSystemPreferences()
					onCompletion()
			}
        }
    }
}
