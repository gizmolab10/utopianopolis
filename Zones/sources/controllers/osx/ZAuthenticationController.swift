//
//  ZAuthenticationController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/28/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


var gAuthenticationController: ZAuthenticationController? { return gControllersManager.controllerForID(.authenticate) as? ZAuthenticationController }


class ZAuthenticationController : ZGenericController, NSTextFieldDelegate {


    override var controllerID:  ZControllerID { return .authenticate }
    @IBOutlet var emailEntryField: NSTextField?
    var closure: Closure? = nil


    func authenticate(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            self.FOREGROUND {
                switch iStatus {
                case .available: onCompletion()
                default:
                    gMainController?.authenticationView?.isHidden = false
                    self               .emailEntryField?.isHidden = true
                    self                                 .closure = onCompletion
                }
            }
        }
    }


    func finishAuthentication() {
        if  let      callback = closure,
            let      authView = gMainController?.authenticationView {
            authView.isHidden = true

            callback()
        }
    }


    @IBAction func authenticationButtonAction(_ iButton: ZButton) {

        enum ZAuthenticateChoice: Int {
            case eAuthenticateSame
            case eAuthenticateNew
        }

        if let choice = ZAuthenticateChoice(rawValue: iButton.tag) {
            switch (choice) {
            case .eAuthenticateSame: finishAuthentication()
            case .eAuthenticateNew:  emailEntryField?.isHidden = false
            }
        }
    }


    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if  let field = emailEntryField,
            let email = field.text {
            gContainer.fetchShareParticipant(withEmailAddress: email) { (iCKShareParticipant, iError) in
                if let participant = iCKShareParticipant {
                    self.finishAuthentication()
                }
            }
        }

        return true
    }

}
