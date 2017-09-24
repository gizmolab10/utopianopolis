//
//  ZPhoneController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import SnapKit
import UIKit


enum ZTabItemID: Int {
    case eUndo
    case eDelete
    case eAddIdea
    case eAddSibling
    case eAddFavorite
}


class ZPhoneController: ZGenericController, UITabBarDelegate {


    override var         controllerID: ZControllerID        { return .main }
    var           favoritesController: ZFavoritesController { return gControllersManager.controllerForID(.favorites) as! ZFavoritesController }
    @IBOutlet var editorTopConstraint: NSLayoutConstraint?
    @IBOutlet var              tabBar: UITabBar?
    var           favoritesAreVisible = true


    @IBAction func favoritesVisibilityButtonAction(iButton: UIButton) {
        favoritesAreVisible           = !favoritesAreVisible
        iButton                .title = favoritesAreVisible ? "<" : ">"
        editorTopConstraint?.constant = favoritesAreVisible ? 45.0 : 0.0
    }


    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let identifier = ZTabItemID(rawValue: item.tag) {

            switch identifier {
            case .eUndo:        gEditingManager.undoManager.undo()
            case .eDelete:      gEditingManager.delete()
            case .eAddIdea:     gEditingManager.createIdea()
            case .eAddSibling:  gEditingManager.createSiblingIdea() { iChild in iChild.edit() }
            case .eAddFavorite: gEditingManager.focus(on: gSelectionManager.firstGrab)
            }
        }
    }
}
