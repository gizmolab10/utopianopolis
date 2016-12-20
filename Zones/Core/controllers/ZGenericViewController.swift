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


class ZGenericViewController: ZViewController {


    func identifier() -> ZControllerID { return .main }


    func setup() {
        controllersManager.register(self, at: identifier()) { (object, kind) -> (Void) in
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
