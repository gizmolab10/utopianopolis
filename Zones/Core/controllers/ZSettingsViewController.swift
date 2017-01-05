//
//  ZSettingsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZSliderKind: String {
    case Vertical   = "vertical"
    case Thickness  = "thickness"
    case Horizontal = "horizontal"
}


enum ZColorBoxKind: String {
    case Zones      = "zones"
    case Bookmarks  = "bookmarks"
    case Background = "background"
}


class ZSettingsViewController: ZGenericViewController {


    @IBOutlet var    totalCountLabel: ZTextField?
    @IBOutlet var         depthLabel: ZTextField?
    @IBOutlet var   fractionInMemory: NSProgressIndicator?
    @IBOutlet var  horizontalSpacing: NSSlider?
    @IBOutlet var    verticalSpacing: NSSlider?
    @IBOutlet var          thickness: NSSlider?
    @IBOutlet var       zoneColorBox: NSColorWell?
    @IBOutlet var   bookmarkColorBox: NSColorWell?
    @IBOutlet var backgroundColorBox: NSColorWell?

    
    override func identifier() -> ZControllerID { return .settings }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        let                     count = cloudManager.zones.count
        let                     total = travelManager.manifest.total
        totalCountLabel?        .text = "of \(total), retrieved: \(count)"
        depthLabel?             .text = "depth within graph: \((travelManager.hereZone?.level)!)"
        view  .zlayer.backgroundColor = gBackgroundColor.cgColor
        fractionInMemory?   .maxValue = Double(total)
        fractionInMemory?.doubleValue = Double(count)
    }


    override func awakeFromNib() {
        fractionInMemory?    .minValue = 0
        thickness?        .doubleValue = gLineThickness
        verticalSpacing?  .doubleValue = Double(gGenericOffset.height)
        horizontalSpacing?.doubleValue = Double(gGenericOffset.width)
        backgroundColorBox?     .color = gBackgroundColor
        bookmarkColorBox?       .color = gBookmarkColor
        zoneColorBox?           .color = gZoneColor
    }


    @IBAction func sliderAction(_ iSlider: NSSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if let kind = ZSliderKind(rawValue: iSlider.identifier!) {
            switch (kind) {
            case  .Thickness: gLineThickness = Double(value);                                       break
            case .Horizontal: gGenericOffset = CGSize(width: value, height: gGenericOffset.height); break
            case   .Vertical: gGenericOffset = CGSize(width: gGenericOffset.width, height: value);  break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: NSColorWell) {
        let color = iColorBox.color

        if let kind = ZColorBoxKind(rawValue: iColorBox.identifier!) {
            switch (kind) {
            case .Background: gBackgroundColor = color; break
            case  .Bookmarks:   gBookmarkColor = color; break
            case      .Zones:       gZoneColor = color; break
            }

            signalFor(nil, regarding: .redraw)
        }
    }

    
    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        cloudManager.royalFlush {}
    }


    @IBAction func editModeChoiceAction(_ control: ZSegmentedControl) {
        gGraphAlteringMode = ZGraphAlteringMode(rawValue: control.selectedSegment)!
    }
}
