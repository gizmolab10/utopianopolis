//
//  ZStackableView.swift
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

class ZStackableView: ZView {

	@IBOutlet var  titleButton : ZButton?
    @IBOutlet var hideableView : ZView?
	@IBOutlet var   bannerView : ZView?
    @IBOutlet var   toggleIcon : ZToggleButton?

    // MARK:- identity
    // MARK:-

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
		turnOnTitleButton()
		toggleIcon?.setState(!hideHideable)
		updateHideableView()
    }

    func updateHideableView() {
        let    hide = hideHideable
        let visible = subviews.contains(hideableView!)

		if  hide == visible { // need for update
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
