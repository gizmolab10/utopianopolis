//
//  ZGenericController.swift
//  Thoughtful
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


class ZGenericController: ZController {
    var useDefaultBackgroundColor = true
    var controllerID = ZControllerID.undefined
    var backgroundColor: CGColor { return gBackgroundColor.cgColor }
    func handleSignal(_ object: Any?, iKind: ZSignalKind) {}
    func displayActivity(_ show: Bool) {}
    func setup() {}


    override func awakeFromNib() {
        super.awakeFromNib()

        gControllers.register(self, iID: controllerID) { object, kind in
            if  self.useDefaultBackgroundColor {
                self.view.zlayer.backgroundColor = self.backgroundColor
            }

            if  kind != .eError && gIsReadyToShowUI {
                self.handleSignal(object, iKind: kind)
            }
        }

        setup()
    }


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
