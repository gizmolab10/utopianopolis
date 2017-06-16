//
//  ZPreferencesController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZSliderKind: String {
    case Vertical   = "vertical"
    case TinyDots   = "tiny dots"
    case Thickness  = "thickness"
    case Horizontal = "horizontal"
}


enum ZColorBoxKind: String {
    case Zones       = "zones"
    case Bookmarks   = "bookmarks"
    case Background  = "background"
    case DragTargets = "drag targets"
}


class ZPreferencesController: ZGenericController {


    @IBOutlet var        countsModeControl: ZSegmentedControl?
    @IBOutlet var graphAlteringModeControl: ZSegmentedControl?
    @IBOutlet var             zoneColorBox: ZColorWell?
    @IBOutlet var         bookmarkColorBox: ZColorWell?
    @IBOutlet var       backgroundColorBox: ZColorWell?
    @IBOutlet var      dragTargetsColorBox: ZColorWell?
    @IBOutlet var        horizontalSpacing: ZSlider?
    @IBOutlet var          verticalSpacing: ZSlider?
    @IBOutlet var            tinyDotsRatio: NSSlider?
    @IBOutlet var                thickness: ZSlider?


    override func identifier() -> ZControllerID { return .preferences }


    override func awakeFromNib() {
        view              .zlayer.backgroundColor = CGColor.clear
        graphAlteringModeControl?.selectedSegment = gGraphAlteringMode.rawValue
        countsModeControl?       .selectedSegment = gCountsMode.rawValue
        tinyDotsRatio?                 .isEnabled = gCountsMode == .dots
        tinyDotsRatio?               .doubleValue = gTinyDotRatio
        thickness?                   .doubleValue = gLineThickness
        verticalSpacing?             .doubleValue = Double(gGenericOffset.height)
        horizontalSpacing?           .doubleValue = Double(gGenericOffset.width)
        dragTargetsColorBox?               .color = gDragTargetsColor
        backgroundColorBox?                .color = gBackgroundColor
        bookmarkColorBox?                  .color = gBookmarkColor
        zoneColorBox?                      .color = gZoneColor
    }


    // MARK:- actions
    // MARK:-


    @IBAction func sliderAction(_ iSlider: NSSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if let kind = ZSliderKind(rawValue: iSlider.identifier!) {
            switch (kind) {
            case   .TinyDots: gTinyDotRatio  = Double(value);                                       break
            case  .Thickness: gLineThickness = Double(value);                                       break
            case .Horizontal: gGenericOffset = CGSize(width: value, height: gGenericOffset.height); break
            case   .Vertical: gGenericOffset = CGSize(width: gGenericOffset.width, height: value);  break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if let kind = ZColorBoxKind(rawValue: iColorBox.identifier!) {
            switch (kind) {
            case .DragTargets: gDragTargetsColor = color
            case .Background:   gBackgroundColor = color
            case  .Bookmarks:     gBookmarkColor = color
            case      .Zones:         gZoneColor = color
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func countsModeAction(_ control: ZSegmentedControl) {
        gCountsMode              = ZCountsMode(rawValue: control.selectedSegment)!
        tinyDotsRatio?.isEnabled = gCountsMode == .dots

        signalFor(nil, regarding: .data)
    }


    @IBAction func graphAlteringModeAction(_ control: ZSegmentedControl) {
        gGraphAlteringMode = ZGraphAlteringMode(rawValue: control.selectedSegment)!
    }


}
