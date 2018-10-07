//
//  ZDetailsController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDetailsController: ZGenericController {


    @IBOutlet var stackView: NSStackView?


    override func setup() {
        controllerID = .details
        useDefaultBackgroundColor = false
    }
    
    
    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        update()
    }


    func update() {
        // applyGradient()
        
        stackView?.applyToAllSubviews { iView in
            if  let stackableView = iView as? ZStackableView {
                stackableView.update()
            }
        }
    }


    func applyGradient() {
        if  let gradientView = stackView {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = gradientView.bounds
            gradientLayer.colors = [gDarkerBackgroundColor, gLighterBackgroundColor]
            gradientView.zlayer = gradientLayer
        }
    }
    
    
    func view(for id: ZDetailsViewID) -> ZStackableView? {
        var found: ZStackableView?  = nil

        stackView?.applyToAllSubviews { iView in
            if  let stackableView = iView as? ZStackableView,
                stackableView.identity == id {
                found = stackableView
            }
        }
        
        return found
    }
    
    
    func displayViewsFor(ids: [ZDetailsViewID]) {
        for id in ids {
            gHiddenDetailViewIDs.remove(id)
        }

        update()
    }
}
