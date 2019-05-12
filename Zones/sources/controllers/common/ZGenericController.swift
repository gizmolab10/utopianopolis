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
    var controllerID: ZControllerID { return .undefined }
    var backgroundColor: CGColor { return gBackgroundColor.cgColor }
    func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {}
    func platformSetup() {}
    func setup() {}


    override func viewDidLoad() {
        super.viewDidLoad()

        gControllers.setSignalHandler(for: self, iID: controllerID) { object, kind in
            if  self.useDefaultBackgroundColor {
                self.view.zlayer.backgroundColor = self.backgroundColor
            }

            if  kind != .eError && gIsReadyToShowUI {
                self.handleSignal(object, kind: kind)
            }
        }

        setup()
    }


#if os(OSX)

    override func viewDidAppear() {
        super.viewDidAppear()
        platformSetup()
        setup()
    }

#elseif os(iOS)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        platformSetup()
        setup()
    }

#endif

}
