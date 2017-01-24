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


class ZSettingsViewController: ZGenericViewController, ZTableViewDelegate, ZTableViewDataSource {


    @IBOutlet var         fractionInMemory: ZProgressIndicator?
    @IBOutlet var     favoritesTableHeight: NSLayoutConstraint?
    @IBOutlet var graphAlteringModeControl: ZSegmentedControl?
    @IBOutlet var       favoritesTableView: NSTableView?
    @IBOutlet var          totalCountLabel: ZTextField?
    @IBOutlet var           graphNameLabel: ZTextField?
    @IBOutlet var               levelLabel: ZTextField?
    @IBOutlet var             zoneColorBox: ZColorWell?
    @IBOutlet var         bookmarkColorBox: ZColorWell?
    @IBOutlet var       backgroundColorBox: ZColorWell?
    @IBOutlet var        horizontalSpacing: ZSlider?
    @IBOutlet var          verticalSpacing: ZSlider?
    @IBOutlet var                thickness: ZSlider?


    // MARK:- generic methods
    // MARK:-

    
    override func identifier() -> ZControllerID { return .settings }


    override func handleSignal(_ object: Any?, kind: ZSignalKind) {
        let                     count = cloudManager.zones.count
        let                     total = travelManager.manifest.total
        totalCountLabel?        .text = "of \(total), retrieved: \(count)"
        graphNameLabel?         .text = "in graph: \(gStorageMode.rawValue)"
        levelLabel?             .text = "focus level: \((travelManager.hereZone?.level)!)"
        view  .zlayer.backgroundColor = gBackgroundColor.cgColor
        fractionInMemory?   .maxValue = Double(total)
        fractionInMemory?.doubleValue = Double(count)


        if let              tableView = favoritesTableView {
            tableView.reloadData()

            favoritesTableHeight?.constant = CGFloat((favoritesManager.count + 1) * 20)
        }
    }


    override func awakeFromNib() {
        fractionInMemory?               .minValue = 0
        graphAlteringModeControl?.selectedSegment = gGraphAlteringMode.rawValue
        thickness?                   .doubleValue = gLineThickness
        verticalSpacing?             .doubleValue = Double(gGenericOffset.height)
        horizontalSpacing?           .doubleValue = Double(gGenericOffset.width)
        backgroundColorBox?                .color = gBackgroundColor
        bookmarkColorBox?                  .color = gBookmarkColor
        zoneColorBox?                      .color = gZoneColor
    }


    func displayViewFor(id: ZSettingsViewID) {
        let type = ZStackableView.self.className()

        gSettingsViewIDs.insert(id)
        view.applyToAllSubviews { (iView: ZView) in
            if type == iView.className {
                let stackView = iView as? ZStackableView

                stackView?.update()
            }
        }
    }


    // MARK:- preference actions
    // MARK:-


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


    @IBAction func graphAlteringModeAction(_ control: ZSegmentedControl) {
        gGraphAlteringMode = ZGraphAlteringMode(rawValue: control.selectedSegment)!
    }


    // MARK:- cloud tool actions
    // MARK:-
    

    @IBAction func emptyTrashButtonAction(_ button: ZButton) {

        // needs elaborate gui, like search results, but with checkboxes and [de]select all checkbox

        //operationsManager.emptyTrash {
        //    self.toConsole("eliminated")
        //}
    }


    @IBAction func restoreFromTrashButtonAction(_ button: ZButton) {
        operationsManager.undelete {
            self.signalFor(nil, regarding: .redraw)
        }
        
    }


    @IBAction func restoreZoneButtonAction(_ button: ZButton) {
        // similar to editingManager.moveInto
        if  let               zone = selectionManager.firstGrabbableZone {
            let               root = travelManager.rootZone
            travelManager.hereZone = root

            root?.needChildren()
            operationsManager.children(true) {
                root?.addAndReorderChild(zone, at: 0)
                controllersManager.syncToCloudAndSignalFor(nil, regarding: .redraw) {}
            }
        }
    }

    
    @IBAction func pushToCloudButtonAction(_ button: ZButton) {
        cloudManager.royalFlush {}
    }


    // MARK:- favorites table
    // MARK:-


    func numberOfRows(in tableView: NSTableView) -> Int {
        let count = favoritesManager.count

        return count + 1
    }

    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let  text = row == 0 ? "edit favorites" : (favoritesManager.textAtIndex(row - 1))!
        let value = "     \(text)"

        return value
    }


    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let select = operationsManager.isReady

        if  select {
            if row == 0 {
                gStorageMode = .favorites

                travelManager.travel {
                    self.signalFor(nil, regarding: .redraw)
                }
            } else if let zone: Zone = favoritesManager.zoneAtIndex(row - 1) {
                favoritesManager.favoritesIndex = row - 1

                editingManager.focusOnZone(zone)
            }
        }

        return select
    }
}
