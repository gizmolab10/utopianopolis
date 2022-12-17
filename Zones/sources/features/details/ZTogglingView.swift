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

	@IBOutlet var switchConstraint : NSLayoutConstraint?
	@IBOutlet var          spinner : ZProgressIndicator?
	@IBOutlet var      titleButton : ZBannerButton?
	@IBOutlet var  switchingButton : ZButton?
	@IBOutlet var       bannerView : ZView?
	@IBOutlet var     hideableView : ZView?

	var favoritesTitle : String  { return hideHideable ? "Favorites" : gFavoritesHere?.favoritesTitle ?? "Gerglagaster" }
	var kind           : String? { return gConvertFromOptionalUserInterfaceItemIdentifier(identifier) }

	func toggleHideableVisibility() { hideHideable = !hideHideable }
	func    updateTitleBarButtons() {}

    // MARK: - identity
    // MARK: -

	var toolTipText: String {
		switch identity {
			case .vKickoffTools : return "some simple tools to help get you oriented"
			case .vPreferences  : return "display preferences"
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

    // MARK: - events
    // MARK: -

	@IBAction func toggleAction(_ sender: Any) {
		gTextEditor.stopCurrentEdit()
		toggleHideableVisibility()
		gDetailsController?.redisplayOnToggle()
	}

    override func awakeFromNib() {
        super.awakeFromNib()

        repeatUntil({ () -> (Bool) in
            return gDetailsController != nil
		}) {
			gDetailsController?.register(id: self.identity, for: self)
        }

		updateView()
    }

	@IBAction func buttonAction(_ button: ZButton) {
		switch identity {
			case .vSubscribe: gSubscriptionController?.toggleViews()
			case .vData:      gMapController?.toggleMaps()
			default:          return
		}

		gRelayoutMaps()
		gSignal([.sDetails])
	}

	// MARK: - update UI
	// MARK: -

	fileprivate func updateTitleButton() {
		if  gIsReadyToShowUI {
			var                      title = kEmpty
			switch identity {
				case .vData:         title = gDatabaseID.userReadableString.capitalized + " Data"
				case .vSubscribe:    title = gSubscriptionController?.bannerTitle ?? kSubscribe
				case .vFavorites:    title = favoritesTitle
				case .vPreferences:  title = "Display Preferences"
				case .vKickoffTools: title = "Start with These"
				default:             title = "Gargleblaster"
			}

			titleButton?.title =     title
		}
	}

	func updateView() { // gSignal for .sDetails goes here
		updateColors()
		updateTitleBarButtons()
		updateSpinner()
		updateTitleButton()
		updateHideableView()
	}

	func updateColors() {
		zlayer                 .backgroundColor =      kClearColor.cgColor
		hideableView?   .zlayer.backgroundColor =      kClearColor.cgColor
		titleButton?    .zlayer.backgroundColor =     gAccentColor.cgColor
		switchingButton?.zlayer.backgroundColor = gDarkAccentColor.cgColor
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

		titleButton?.updateToolTips(gModifierFlags)

		if  hide == visible { // need for update
			hideableView?.isHidden = hide

			hideableView?.snp.removeConstraints()
			bannerView?  .snp.removeConstraints()

			if  hide {
				hideableView?.removeFromSuperview()
				bannerView?.snp.makeConstraints { make in
					make.bottom.equalTo(self)
				}
			} else {
				addSubview(hideableView!)
				hideableView?.snp.makeConstraints { make in
					if  let b = bannerView {
						make.top.equalTo(b.snp.bottom)
						make.left.right.equalTo(b)
						make.bottom.equalTo(self)
					}
				}
			}
		}
    }

}
