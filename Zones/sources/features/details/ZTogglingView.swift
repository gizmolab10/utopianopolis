//
//  ZTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

class ZBannerButton : ZButton {
	@IBOutlet var   togglingView : ZTogglingView?
}

class ZTogglingView: NSStackView {

	@IBOutlet var triangleButton : ZToggleButton?
	@IBOutlet var    titleButton : ZBannerButton?
	@IBOutlet var    extraButton : ZBannerButton?
	@IBOutlet var     bannerView : ZView?
    @IBOutlet var   hideableView : ZView?

    // MARK:- identity
    // MARK:-

	var kind: String? {
		return convertFromOptionalUserInterfaceItemIdentifier(identifier)
	}

	var toolTipText: String {
		switch identity {
			case .vPreferences : return "preference controls"
			case .vSimpleTools : return "basic buttons to get you started"
			case .vSmallMap    : return "\(gCurrentSmallMapName)s map"
			case .vData        : return "useful data about Seriously"
			default            : return ""
		}
	}

	var identity: ZDetailsViewID {
		if  let    k = kind {
			switch k {
				case "preferences": return .vPreferences
				case "startHere":   return .vSimpleTools
				case "smallMap":    return .vSmallMap
				case "data":        return .vData
				default:            return .vAll
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

    // MARK:- update UI
    // MARK:-

    override func awakeFromNib() {
        super.awakeFromNib()
        update()

		layer?              .backgroundColor = kClearColor.cgColor
		hideableView?.layer?.backgroundColor = kClearColor.cgColor

        repeatUntil({ () -> (Bool) in
            return gDetailsController != nil
        }) {
            gDetailsController?.register(id: self.identity, for: self)
        }
    }

	@IBAction func extraButtonAction(_ sender: Any) {
		gSwapSmallMapMode()
	}

	@IBAction func toggleAction(_ sender: Any) {
		toggleHideableVisibility()
		gSignal([.sDetails])
	}

    func toggleHideableVisibility() {
        hideHideable = !hideHideable
    }
    
    func update() {
		titleButton?.layer?.backgroundColor = gAccentColor.cgColor

		if  identity == .vSmallMap,
			let  here = gIsRecentlyMode ? gRecentsHereMaybe : gFavoritesHereMaybe {

			titleButton?.title = here.ancestralString
		}

		turnOnTitleButton()
		triangleButton?.setState(!hideHideable)
		updateHideableView()
    }

    func updateHideableView() {
        let    hide = hideHideable
        let visible = subviews.contains(hideableView!)

		titleButton?.updateTooltips()

		if  hide == visible { // need for update
			hideableView?.isHidden = hide
			if  hide {
				hideableView?.removeFromSuperview()
				bannerView?.snp.makeConstraints { make in
					make.bottom.equalTo(self)
				}
			} else {
				addSubview(hideableView!)

				bannerView?.snp.removeConstraints()
				hideableView?.snp.makeConstraints { make in
					make.top.equalTo((self.bannerView?.snp.bottom)!)
					make.left.right.bottom.equalTo(self)
				}
			}
		}
    }
}
