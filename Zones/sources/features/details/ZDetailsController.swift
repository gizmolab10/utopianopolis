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
private let  detailIds : [ZDetailsViewID] = [.Preferences, .Information, .Introduction, .Status, .Map]

class ZDetailsController: ZGesturesController {

	var              viewsByID = [Int : ZTogglingView]()
    @IBOutlet var    stackView : ZStackView?
	override  var controllerID : ZControllerID { return .idDetails }

    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
		update()
    }

    func register(id: ZDetailsViewID, for view: ZTogglingView) {
        viewsByID[id.rawValue] = view
    }

	override func viewDidLoad() {
		super.viewDidLoad()

		gestureView = view
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIsNoteMode {
			gEssayView?.save()
			gControllers.swapMapAndEssay(force: .mapMode)
		}
	}

    func update() {
		if  gIsReadyToShowUI {
			stackView?.isHidden               = false
			stackView?.layer?.backgroundColor = kClearColor.cgColor

			for id in detailIds {
				view(for: id)?.update()
			}
		}
	}
    
    func view(for id: ZDetailsViewID) -> ZTogglingView? {
        return viewsByID[id.rawValue]
    }

	func hideableIsHidden(for id: ZDetailsViewID) -> Bool {
		return view(for: id)?.hideHideable ?? true
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
