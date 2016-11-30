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


    func identifier() -> ZControllerID { return .editor }


    func setup() {
        controllersManager.registerSignal { (object, kind) -> (Void) in
            if kind != .error {
                self.handleSignal(object, kind: kind)
            }
        }

        controllersManager.register(self, at: identifier())
    }


    func handleSignal(_ object: Any?, kind: ZSignalKind) {}
    func displayActivity() {}


#if os(OSX)

    override func viewWillAppear() {
        super.viewWillAppear()
        setup()
    }

#elseif os(iOS)

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setup()
    }

#endif
}
