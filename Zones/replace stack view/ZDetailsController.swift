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


class ZDetailsController: ZGenericTableController {


    @IBOutlet var informationContainerView : ZContainerView?
    @IBOutlet var preferencesContainerView : ZContainerView?
    @IBOutlet var   shortcutsContainerView : ZContainerView?
    @IBOutlet var       toolsContainerView : ZContainerView?
    @IBOutlet var       debugContainerView : ZContainerView?
    @IBOutlet var         bottomConstraint : NSLayoutConstraint?
    var                           rowViews = [ZDetailRowView] ()
    let                   numberOfRowViews = 5

    
    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {}


    override func setup() {
        controllerID               = .details
        bottomConstraint?.isActive = false

        for index in 0 ..< numberOfRowViews {
            let          id = detailsViewIDFor(index)
            if  let    view = containerView(for: id) {
                let rowView = ZDetailRowView(id, view)
                rowView.layoutSubviews()
                rowViews.append(rowView)
            }
        }

        tableView.reloadData()
    }


    func displayViewFor(_ iID: ZDetailsViewID)                                                             { gDetailsViewIDs.insert(iID) }
    func detailsViewIDFor(_ iRow: Int) -> ZDetailsViewID                                                   { return ZDetailsViewID(rawValue: 1 << iRow) }
    func controllerFor(_ iID: ZDetailsViewID) -> ZGenericController?                                       { return gControllersManager.controllerForID(viewIDFor(iID)) }
    override func numberOfRows(in tableView: ZTableView) -> Int                                            { return numberOfRowViews }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { return rowViews[row] }


    func viewIDFor(_ iID: ZDetailsViewID) -> ZControllerID? {
        switch iID {
        case .Information: return .information
        case .Preferences: return .preferences
        case .Shortcuts:   return .shortcuts
        case .Tools:       return .tools
        case .Debug:       return .debug
        default:           return nil
        }
    }


    func containerView(for iID: ZDetailsViewID) -> ZContainerView? {
        switch iID {
        case .Information: return informationContainerView
        case .Preferences: return preferencesContainerView
        case .Shortcuts:   return shortcutsContainerView
        case .Tools:       return toolsContainerView
        case .Debug:       return debugContainerView
        default:           return nil
        }

    }


    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if  let controller = controllerFor(detailsViewIDFor(row)) {
            return controller.view.bounds.size.height
        }

        return 50.0
    }

}
