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

class ZGenericController: ZController, ZGeneric {

	var  controllerID : ZControllerID { return .idUndefined }
	var  allowedKinds : [ZSignalKind] { return [] }
    func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {}
	func startup() {}
	func setup() {}

	func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return ((kind != .sError && gIsReadyToShowUI) || [.sMain, .sStartup].contains(kind)) &&
			(allowedKinds.count == 0 || allowedKinds.contains(kind))
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		startup()

        gControllers.setSignalHandler(for: self, iID: controllerID) { object, kind in
			self.view.zlayer.backgroundColor = gControllers.backgroundColorFor(self.controllerID).cgColor

			if  self.shouldHandle(kind) {
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
