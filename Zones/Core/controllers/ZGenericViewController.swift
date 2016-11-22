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
        controllersManager.registerUpdateClosure { (object, kind) -> (Void) in
            if kind != .error {
                self.updateFor(object, kind: kind)
            }
        }

        controllersManager.register(self, at: identifier())
        updateFor(nil, kind: .data)
    }


    func updateFor(_ object: Any?, kind: ZUpdateKind) {}


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
