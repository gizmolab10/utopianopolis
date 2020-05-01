//
//  ZDetailsController.swift
//  Seriously
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
private let  detailIds : [ZDetailsViewID] = [.Preferences, .Status, .Start]

class ZDetailsController: ZGenericController {

	var              viewsByID = [Int : ZTogglingView]()
    @IBOutlet var    stackView : ZStackView?
	override  var controllerID : ZControllerID { return .idDetails }

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		if  gAdvancedSkillLevel {
			update()
		}
    }

    func register(id: ZDetailsViewID, for view: ZTogglingView) {
        viewsByID[id.rawValue] = view
    }

    func update() {
		if  gIsReadyToShowUI {
			stackView?.isHidden = false

			for id in detailIds {
				view(for: id)?.update()
			}
		}
	}
    
    func view(for id: ZDetailsViewID) -> ZTogglingView? {
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

}
