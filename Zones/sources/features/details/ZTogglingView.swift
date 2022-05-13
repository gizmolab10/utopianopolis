//
//  ZTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZBannerButton : ZButton {
	@IBOutlet var togglingView : ZTogglingView? // point back at the container (specific stack view)
}

class ZTogglingView: ZView {

	@IBOutlet var          spinner : ZProgressIndicator?
	@IBOutlet var      titleButton : ZBannerButton?
	@IBOutlet var  switchingButton : ZButton?
	@IBOutlet var       downButton : ZButton?
	@IBOutlet var         upButton : ZButton?
	@IBOutlet var       upDownView : ZView?
	@IBOutlet var       bannerView : ZView?
	@IBOutlet var     hideableView : ZView?

    // MARK: - identity
    // MARK: -

	var kind: String? { return gConvertFromOptionalUserInterfaceItemIdentifier(identifier) }

	var toolTipText: String {
		switch identity {
			case .vKickoffTools : return "some simple tools to help get you oriented"
			case .vPreferences  : return "preference controls"
			case .vFavorites    : return "favorites map"
			case .vSubscribe    : return "license details"
			case .vData         : return "useful data about Seriously"
			default             : return kEmpty
		}
	}

	var identity: ZDetailsViewID {
		if  let    k = kind {
			switch k {
				case "kickoffTools": return .vKickoffTools
				case "preferences":  return .vPreferences
				case "subscribe":    return .vSubscribe
				case "smallMap":     return .vFavorites
				case "data":         return .vData
				default:             return .vAll
			}
		}

		return .vAll
	}

    var hideHideable: Bool {
        get {
            return !gIsReadyToShowUI || gHiddenDetailViewIDs.contains(identity)
        }

        set {
            if  newValue {
                gHiddenDetailViewIDs.insert(identity)
            } else {
                gHiddenDetailViewIDs.remove(identity)
            }
        }
    }

	func toggleHideableVisibility() {
		hideHideable = !hideHideable
	}

    // MARK: - update UI
    // MARK: -

	@IBAction func toggleAction(_ sender: Any) {
		toggleHideableVisibility()
		gDetailsController?.redisplayOnToggle()
	}

    override func awakeFromNib() {
        super.awakeFromNib()

        repeatUntil({ () -> (Bool) in
            return gDetailsController != nil
		}) { [self] in
            gDetailsController?.register(id: identity, for: self)
        }

		updateView()
    }

	@IBAction func buttonAction(_ button: ZButton) {
		switch identity {
			case .vSubscribe: gSubscriptionController?.toggleViews()
			case .vData:      gMapController?.toggleMaps()
			case .vFavorites: goAccordingTo(button)
			default:          return
		}

		gRelayoutMaps()
		gSignal([.sDetails])
	}

	fileprivate func goAccordingTo(_ button: ZButton) {
		switch button {
			case   upButton: gFavorites.showNextList(down: false)
			case downButton: gFavorites.showNextList(down: true)
			default:         break
		}
	}

	fileprivate func updateTitleButton() {
		if  gIsReadyToShowUI {
			var                      title = kEmpty
			switch identity {
				case .vData:         title = gDatabaseID.userReadableString.capitalized + " Data"
				case .vFavorites:    title = gFavoritesHere?.favoritesTitle ?? "Gerglagaster"
				case .vSubscribe:    title = gSubscriptionController?.bannerTitle ?? kSubscribe
				case .vPreferences:  title = "Preferences"
				case .vKickoffTools: title = "Kickoff Tools"
				default:             title = "Gargleblaster"
			}

			titleButton?.title =     title
		}
	}

	func updateView() { // gSignal for .sDetails goes here
		updateColors()
		updateFavoritesButtons()
		updateSpinner()
		updateTitleButton()
		updateHideableView()
	}

	func updateColors() {
		zlayer                 .backgroundColor =      kClearColor.cgColor
		hideableView?   .zlayer.backgroundColor =      kClearColor.cgColor
		titleButton?    .zlayer.backgroundColor =     gAccentColor.cgColor
		switchingButton?.zlayer.backgroundColor = gDarkAccentColor.cgColor
		downButton?     .zlayer.backgroundColor = gDarkAccentColor.cgColor
		upButton?       .zlayer.backgroundColor = gDarkAccentColor.cgColor
	}

	func updateFavoritesButtons() {
		if  identity == .vFavorites {
			let           hidden = hideHideable
			upDownView?.isHidden = hidden

			if !hidden {
				downButton?.title = gFavorites.nextList(down:  true)?.unwrappedName ?? kEmpty
				upButton?  .title = gFavorites.nextList(down: false)?.unwrappedName ?? kEmpty
			}

			titleButton?.snp.removeConstraints()
			titleButton?.snp.makeConstraints{ make in
				if  hidden {
					make.right.equalToSuperview() .offset(-1.0)
				} else if let v = upDownView {
					make.right.equalTo(v.snp.left).offset(-1.0)
				}
			}
		}
	}

	func updateSpinner() {
		if  let      s = spinner {
			let   hide = gCurrentOp.isDoneOp && gCoreDataStack.isDoneOp
			s.isHidden = hide

			if  hide {
				s.stopAnimation (spinner)
			} else {
				s.startAnimation(spinner)
			}
		}
	}

    func updateHideableView() {
        let    hide = hideHideable
        let visible = subviews.contains(hideableView!)

		titleButton?.updateTooltips()

		if  hide == visible { // need for update
			hideableView?.isHidden = hide

			hideableView?.snp.removeConstraints()
			bannerView?.snp.removeConstraints()

			if  hide {
				hideableView?.removeFromSuperview()
				bannerView?.snp.makeConstraints { make in
					make.bottom.equalTo(self)
				}
			} else {
				addSubview(hideableView!)
				hideableView?.snp.makeConstraints { make in
					make.bottom.equalTo(self)

					if  let b = bannerView {
						make.top.equalTo(b.snp.bottom)
						make.left.right.equalTo(b)
					}
				}
			}
		}
    }

}
