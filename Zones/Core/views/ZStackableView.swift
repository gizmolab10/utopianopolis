//
//  ZStackableView.swift
//  Zones
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZStackableView: ZView {


    @IBOutlet var hideableView: ZView?
    @IBOutlet var   titleLabel: ZTextField?
    @IBOutlet var toggleButton: ZButton?
    var       hideableIsHidden = false


    @IBAction func toggleAction(_ sender: NSButton) {
        hideableIsHidden = !hideableIsHidden

        updateToggleImage()
        updateHideableView()
    }


    override func awakeFromNib() {
        updateToggleImage()
    }


    func updateToggleImage() {
        var image = ZImage(named: "yangle.png")

        if !hideableIsHidden {
            image = (image?.imageRotatedByDegrees(180.0))! as ZImage
        }

        toggleButton?.image = image
    }


    func updateHideableView() {

        if hideableIsHidden {
            hideableView?.removeFromSuperview()
            titleLabel?.snp.makeConstraints({ (make: ConstraintMaker) in
                make.bottom.equalTo(self)
            })
        } else {
            addSubview(hideableView!)
            titleLabel?.snp.removeConstraints()
            hideableView?.snp.makeConstraints({ (make: ConstraintMaker) in
                make.top.equalTo((self.toggleButton?.snp.bottom)!)
                make.left.right.bottom.equalTo(self)
            })
        }
    }
}
