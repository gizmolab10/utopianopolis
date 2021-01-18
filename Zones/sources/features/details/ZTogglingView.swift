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

class ZTogglingView: NSStackView {

	@IBOutlet var triangleButton : ZToggleButton?
	@IBOutlet var    titleButton : ZButton?
    @IBOutlet var   hideableView : ZView?
	@IBOutlet var     bannerView : ZView?

    // MARK:- identity
    // MARK:-

	var identity: ZDetailsViewID {
		if  let kind = convertFromOptionalUserInterfaceItemIdentifier(identifier) {
			switch kind {
				case "introduction": return .Introduction
				case "preferences":  return .Preferences
				case "information":  return .Information
				case "status":       return .Status
				case "map":          return .Map
				default:             return .All
			}
		}

		return .All
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

	@IBAction func toggleAction(_ sender: Any) {
		toggleHideableVisibility()
		update()
	}

    func toggleHideableVisibility() {
        hideHideable = !hideHideable
    }
    
    func update() {
		titleButton?.layer?.backgroundColor = gAccentColor.cgColor

		if  identity == .Map,
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
