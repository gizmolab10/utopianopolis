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

var gDetailsController : ZDetailsController? { return gControllers.controllerForID(.idDetails) as? ZDetailsController }

class ZDetailsController: ZGenericController {

	var              viewsByID = [Int : ZStackableView]()
    @IBOutlet var    stackView : ZStackView?
	override  var controllerID : ZControllerID { return .idDetails }

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
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
    
    func toggleViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            if  let v = view(for: id) {
                v.toggleHideableVisibility()
            }
        }
        
        update()
    }
    
    func displayViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            gHiddenDetailViewIDs.remove(id)
        }

        update()
    }

}
