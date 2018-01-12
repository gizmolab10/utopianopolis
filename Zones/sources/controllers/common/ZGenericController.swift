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

    func handleSignal(_ object: Any?, iKind: ZSignalKind)
    func displayActivity(_ show: Bool)
    func setup()
}


class ZGenericController: ZController, ZGenericControllerProtocol {
    var controllerID = ZControllerID.undefined 
    override func awakeFromNib() { setup() }
    func handleSignal(_ object: Any?, iKind: ZSignalKind) {}
    func displayActivity(_ show: Bool) {}


    func setup() {
        gControllersManager.register(self, iID: controllerID) { object, kind in
            self.view.zlayer.backgroundColor = gBackgroundColor.cgColor

            if  kind != .error && gManifest.alreadyExists {
                self.handleSignal(object, iKind: kind)
            }
        }
    }


    func syncToCloudAndSignalFor(_ widget: ZoneWidget?, regarding: ZSignalKind,  onCompletion: Closure?) {
        gControllersManager.syncToCloudAndSignalFor(widget, regarding: regarding, onCompletion: onCompletion)
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
