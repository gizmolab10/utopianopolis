//
//  ZGenericController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


protocol ZGenericControllerProtocol {

    func handleSignal(_ object: Any?, kind: ZSignalKind)
    func identifier() -> ZControllerID
    func displayActivity()
    func setup()
}


class ZGenericController: ZController, ZGenericControllerProtocol {
    func identifier() -> ZControllerID { return .undefined }


    func setup() {
        let identity = identifier()

        gControllersManager.register(self, iID: identity) { object, kind in
            if kind != .error {
                self.handleSignal(object, kind: kind)
            }
        }
    }


    func handleSignal(_ object: Any?, kind: ZSignalKind) {}
    func displayActivity() {}


#if os(OSX)

    override func viewDidAppear() {
        super.viewDidAppear()
        setup()
    }

#elseif os(iOS)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setup()
    }

#endif
}
