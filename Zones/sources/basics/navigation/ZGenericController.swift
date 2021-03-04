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

	var     isVisible = false
	var  controllerID : ZControllerID { return .idUndefined }
	var  allowedKinds : [ZSignalKind] { return [] }
    func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {}
	func startup() {}
	func setup() {}

	func shouldHandle(_ kind: ZSignalKind) -> Bool {
		return (allowedKinds.count == 0 || allowedKinds.contains(kind)) &&
			((    gHasFinishedStartup && ![.sError, .sStartupProgress].contains(kind)) ||
				(!gHasFinishedStartup &&  [.sMain,  .sStartupProgress].contains(kind)))
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

	override func viewDidLayout() {
		super.viewDidLayout()
		gMainWindow?.updateEssayEditorInspectorBar(show: gIsNoteMode)
	}

#if os(OSX)

    override func viewDidAppear() {
        super.viewDidAppear()
		isVisible = true
        setup()
    }

	override func viewDidDisappear() {
		super.viewDidDisappear()
		isVisible = false
	}

#elseif os(iOS)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
		isVisible = true
        setup()
    }

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		isVisible = false
	}


#endif

}
