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
private let  detailIds : [ZDetailsViewID] = [.vSubscribe, .vKickoffTools, .vData, .vPreferences, .vFavorites]

struct ZDetailsViewID: OptionSet {
	let rawValue : Int

	init(rawValue: Int) { self.rawValue = rawValue }

	static let  vPreferences = ZDetailsViewID(rawValue: 1 << 0)
	static let         vData = ZDetailsViewID(rawValue: 1 << 1)
	static let vKickoffTools = ZDetailsViewID(rawValue: 1 << 2)
	static let    vFavorites = ZDetailsViewID(rawValue: 1 << 3)
	static let    vSubscribe = ZDetailsViewID(rawValue: 1 << 4)
	static let          vAll = ZDetailsViewID(rawValue: 1 << 5)
	static let  vFirstHidden = ZDetailsViewID(rawValue: 1 << 6)
	static let         vLast = vFavorites
}

class ZDetailsController: ZGesturesController {

	var                   viewsByID = [Int : ZTogglingView]()
	@IBOutlet var         stackView : ZStackView?
	override  var      controllerID : ZControllerID                            { return .idDetails }
	func viewIsVisible      (for id : ZDetailsViewID) ->                 Bool  { return !(view(for: id)?.hideHideable ?? true) }
	func view               (for id : ZDetailsViewID) ->        ZTogglingView? { return viewsByID[id.rawValue] }
	func register               (id : ZDetailsViewID, for view: ZTogglingView) { viewsByID[id.rawValue] = view }
	func showViewFor          (_ id : ZDetailsViewID)                          { view(for: id)?.hideHideable = false; detailsUpdate() }

	func temporarilyHideView(for id : ZDetailsViewID, _ closure: Closure) {
		let           view = gDetailsController?.view(for: id)
		let           save = view?.hideHideable ?? false
		view?.hideHideable = true

		closure()

		view?.hideHideable = save
	}
	
	override func handleSignal(kind: ZSignalKind) {
		if  gShowDetailsView {
			detailsUpdate()
		}
    }

	override func viewDidLoad() {
		super.viewDidLoad()

		gestureView = view
		stackView?.layer?.backgroundColor = kClearColor.cgColor
	}

	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIsEssayMode, !gIgnoreEvents {
			gEssayView?.save()
			gControllers.swapMapAndEssay(force: .wMapMode)
		}
	}

    func detailsUpdate() {
		if  gIsReadyToShowUI {
			stackView?.isHidden = false

			for id in detailIds {
				view(for: id)?.updateView()
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
		detailsUpdate()
		stackView?.setAllSubviewsNeedDisplay()
		stackView?.displayAllSubviews()
		gSignal([.sDetails])
		gRelayoutMaps()
	}

	func removeViewFromStack(for id: ZDetailsViewID) {
		let v = view(for: id)

		v?.removeFromSuperview()
		view.display()
	}

	func displayPreferences() {
		if  gShowDetailsView {
			toggleViewsFor(ids: [.vPreferences])
		} else {
			gShowDetailsView = true

			showViewFor(.vPreferences)
		}

		gSignal([.spMain, .sDetails])
	}

}
