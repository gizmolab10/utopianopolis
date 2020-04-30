//
//  ZGenericController.swift
//  Seriously
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

	var  controllerID : ZControllerID { return .idUndefined }
    func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {}
	func startup() {}
	func setup() {}

    override func viewDidLoad() {
        super.viewDidLoad()
		startup()

        gControllers.setSignalHandler(for: self, iID: controllerID) { object, kind in
			self.view.zlayer.backgroundColor = gControllers.backgroundColorFor(self.controllerID).cgColor

			if  kind != .sError && gIsReadyToShowUI {
                self.handleSignal(object, kind: kind)
            }
        }
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
