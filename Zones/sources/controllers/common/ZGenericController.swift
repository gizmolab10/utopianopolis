//
//  ZGenericController.swift
//  Zones
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


protocol ZGenericControllerProtocol {

    func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind)
    func displayActivity(_ show: Bool)
    func setup()
}


class ZGenericController: ZController, ZGenericControllerProtocol {
    var controllerID:  ZControllerID { return .undefined }
    override func awakeFromNib() { view.zlayer.backgroundColor = gBackgroundColor.cgColor }
    func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {}
    func displayActivity(_ show: Bool) {}


    func setup() {
        view.zlayer.backgroundColor = gBackgroundColor.cgColor

        gControllersManager.register(self, iID: controllerID) { object, mode, kind in
            if kind != .error {
                self.handleSignal(object, in: mode, kind: kind)
            }
        }
    }


    func syncToCloudAndSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        gControllersManager.syncToCloudAndSignalFor(zone, regarding: regarding, onCompletion: onCompletion)
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
