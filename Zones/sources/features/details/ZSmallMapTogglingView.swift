//
//  ZSmallMapTogglingView.swift
//  Seriously
//
//  Created by Jonathan Sand on 10/31/21.
//  Copyright © 2021 Zones. All rights reserved.
//

import Foundation

var gSmallTogglingView: ZSmallMapTogglingView?

class ZSmallMapTogglingView: ZTogglingView {

	@IBOutlet var heightConstraint : NSLayoutConstraint?

	override func awakeFromNib() {
		super.awakeFromNib()
		hideableView?.snp.removeConstraints()

		gSmallTogglingView = self
	}

	override func updateHideableView() {
		let    hide = hideHideable
		let visible = subviews.contains(hideableView!)

		titleButton?.updateTooltips()

		if  hide == visible { // need for update
			hideableView?.isHidden = hide

			if  hide {
				hideableView?.removeFromSuperview()
			} else {
				addSubview(hideableView!)
			}

			if  let            bannerFrame = bannerView?.frame {
				var                 height = bannerFrame.height
				if  let   rootWidgetHeight = gSmallMapController?.rootWidget?.drawnSize.height, !hide {
					let               size = CGSize(width: frame.width, height: rootWidgetHeight + 8.0)
					hideableView?   .frame = CGRect(origin: CGPoint(x: 0.0, y: height + 1.0), size: size)
					height                += rootWidgetHeight + 9.0
				}

				heightConstraint?.constant = height
			}
		}
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		if  !hideHideable {
			gSmallMapController?.mapView?.debugDraw()
		}
	}

}
