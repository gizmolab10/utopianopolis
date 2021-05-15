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
	@IBOutlet var        spinner : ZProgressIndicator?
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
			case .vSimpleTools : return "some simple tools which can get you oriented"
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

		zlayer              .backgroundColor =  kClearColor.cgColor
		hideableView?.zlayer.backgroundColor =  kClearColor.cgColor

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
		titleButton?.zlayer.backgroundColor =     gAccentColor.cgColor
		extraButton?.zlayer.backgroundColor = gDarkAccentColor.cgColor

		if  identity == .vSmallMap, gIsReadyToShowUI,
			let  here = gIsRecentlyMode ? gRecentsHereMaybe : gFavoritesHereMaybe {

			titleButton?.title = here.ancestralString
		}

		turnOnTitleButton()
		triangleButton?.setState(!hideHideable)
		updateHideableView()
		updateSpinner()
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
