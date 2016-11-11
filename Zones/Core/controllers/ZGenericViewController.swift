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


    func setup() {
        zonesManager.registerUpdateClosure { (object, kind) -> (Void) in
            if kind != .error {
                self.updateFor(object, kind: kind)
            }
        }

        updateFor(nil, kind: .data)
    }


    func updateFor(_ object: NSObject?, kind: ZUpdateKind) {}


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
