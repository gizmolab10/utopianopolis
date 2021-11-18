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
private let  detailIds : [ZDetailsViewID] = [.vSubscribe, .vSimpleTools, .vData, .vPreferences, .vSmallMap]

class ZDetailsController: ZGesturesController {

	var                  viewsByID = [Int : ZTogglingView]()
	@IBOutlet var        stackView : ZStackView?
	override  var     controllerID : ZControllerID                            { return .idDetails }
	func viewIsVisible     (for id : ZDetailsViewID) ->                 Bool  { return !(view(for: id)?.hideHideable ?? true) }
	func view              (for id : ZDetailsViewID) ->        ZTogglingView? { return viewsByID[id.rawValue] }
	func register              (id : ZDetailsViewID, for view: ZTogglingView) { viewsByID[id.rawValue] = view }
	func showViewFor         (_ id : ZDetailsViewID)                          { view(for: id)?.hideHideable = false; update() }

	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		if  gShowDetailsView {
			update()
		}
    }

	override func viewDidLoad() {
		super.viewDidLoad()

		gestureView = view
		stackView?.layer?.backgroundColor = kClearColor.cgColor
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIsEssayMode {
			gEssayView?.save()
			gControllers.swapMapAndEssay(force: .wMapMode)
		}
	}

    func update() {
		if  gIsReadyToShowUI {
			stackView?.isHidden = false

			for id in detailIds {
				view(for: id)?.update()
			}

			stackView?.layoutAllSubviews()
			stackView?.setAllSubviewsNeedLayout()
		}
	}

    func toggleViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            if  let v = view(for: id) {
				v.toggleHideableVisibility()
            }
        }

		redisplayOnToggle()
    }

	func redisplayOnToggle() {
		update()
		stackView?.setAllSubviewsNeedDisplay()
		stackView?.displayAllSubviews()
		gRelayoutMaps()
	}

}
