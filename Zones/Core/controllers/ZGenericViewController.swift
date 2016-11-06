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
                self.updateFor(object)
            }
        }

        updateFor(nil)
    }


    func updateFor(_ object: NSObject?) {}
    func userEvent() {}


#if os(OSX)

    override func viewWillAppear() {
        super.viewWillAppear()
        setup()
    }


    override func mouseDown(with event: ZEvent) {
        super.mouseDown(with:event)
        userEvent()
    }

#elseif os(iOS)

    override func viewWillAppear(_ animated: Bool) {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(ZoneDot.handleTap))
        let gestures = Array(view.gestureRecognizers ?? [])

        for recognizer in gestures {
            view.removeGestureRecognizer(recognizer)
        }

        super.viewWillAppear(animated)
        view.addGestureRecognizer(gesture)
        setup()
    }

    func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            userEvent()
        }
    }

#endif
}
