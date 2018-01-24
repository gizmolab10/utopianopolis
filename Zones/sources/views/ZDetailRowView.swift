//
//  ZDetailRowView.swift
//  Zones
//
//  Created by Jonathan Sand on 1/1/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDetailRowView: ZTableRowView {


    var     identity : ZDetailsViewID = .Information
    var hideableView : ZView?
    let toggleButton = ZButton ()
    let   titleLabel = ZTextField ()
    let      topView = ZView ()


    // MARK:- identity
    // MARK:-


    var hideableIsHidden: Bool {
        get {
            return gDetailsViewIDs.contains(identity)
        }

        set {
            if newValue {
                gDetailsViewIDs.insert(identity)
            } else {
                gDetailsViewIDs.remove(identity)
            }
        }
    }


    // MARK:- internals
    // MARK:-


    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }


    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }


    func copyWithZone(_ zone: NSZone?) -> AnyObject {
        return self
    }


    convenience init(_ iID: ZDetailsViewID, _ iView: ZView) {
        self.init(frame: iView.frame)

        identity     = iID
        hideableView = iView

        iView.removeFromSuperview()
        addSubview(topView)
        topView.addSubview(titleLabel)
        topView.addSubview(toggleButton)
    }


    // MARK:- update to UI
    // MARK:-


    func layoutSubviews() {
        toggleButton.snp.makeConstraints { make in
            make.top.left.bottom.equalTo(self.topView)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.left.right.bottom.equalToSuperview()
        }

        update()
    }


    @IBAction func toggleAction(_ sender: ZButton) {
        hideableIsHidden = !hideableIsHidden

        update()
    }


    func update() {
        updateToggleImage()
        updateHideableView()
    }


    func updateToggleImage() {
        #if os(OSX)
            if  var image = ZImage(named: "yangle.png") {
                if  hideableIsHidden {
                    image = image.imageRotatedByDegrees(180.0) as ZImage
                }

                toggleButton.image = image
            }
        #endif
    }


    func updateHideableView() {
        if !hideableIsHidden {
            hideableView?.removeFromSuperview()
            topView.snp.makeConstraints { make in
                make.top.left.right.bottom.equalTo(self)
            }
        } else if !subviews.contains(hideableView!) {
            addSubview(hideableView!)
            topView.snp.removeConstraints()
            topView.snp.makeConstraints { make in
                make.top.left.right.equalTo(self)
            }

            hideableView?.snp.makeConstraints { make in
                make.top.equalTo(self.topView.snp.bottom)
                make.left.right.bottom.equalTo(self)
            }

            signalFor(nil, regarding: .datum)
            FOREGROUND(after: 0.2) {
                self.hideableView?.setNeedsDisplay()
            }
        }
    }
}
