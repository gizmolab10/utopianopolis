//
//  ZGenericViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


protocol ZGenericViewControllerProtocol {

    func handleSignal(_ object: Any?, kind: ZSignalKind)
    func identifier() -> ZControllerID
    func displayActivity()
    func setup()
}


class ZGenericViewController: ZViewController, ZGenericViewControllerProtocol {


    func identifier() -> ZControllerID { return .main }


    func setup() {
        controllersManager.register(self, iID: identifier()) { object, kind in
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
