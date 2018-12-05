//
//  ZDetailsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDetailsController: ZGenericController {


    @IBOutlet var stackView: NSStackView?
    var viewsByID = [Int: ZStackableView]()


    override func setup() {
        controllerID = .details
        useDefaultBackgroundColor = false
    }
    
    
    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        update()
    }

    
    func register(id: ZDetailsViewID, for view: ZStackableView) {
        viewsByID[id.rawValue] = view
    }
    

    func update() {
        let ids: [ZDetailsViewID] = [.Tools, .Debug, .Preferences, .Information]

        for id in ids {
            view(for: id)?.update()
        }
    }
    
    
    func view(for id: ZDetailsViewID) -> ZStackableView? {
        return viewsByID[id.rawValue]
    }

    
    func displayViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            gHiddenDetailViewIDs.remove(id)
        }

        update()
    }
}
