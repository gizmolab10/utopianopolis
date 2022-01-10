//
//  ZActionsController.swift
//  Seriously
//
//  Created by Jonathan Sand on 9/24/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import UIKit


enum ZFunction: String {
	case eTop        = "At 7Top"
	case eToTop 	 = "Top"

	case eEdit       = "Edit"
    case eNew        = "New"
	case eNext       = "Next"
	case eName       = "Name"
	case eDelete     = "Delete"

	case eMore		 = "More"
	case eHelp       = "Help"
	case ePrefs      = "Preferences"

	case eCloud      = "Cloud"
	case eHang       = "Reconnect"
	case eRefetch    = "Refetch"
	case eRefetchAll = "Refetch All"

	case eFavorites  = "Favorites"
	case ePublic     = "Public"
	case eMe         = "Me"
}


var gActionsController: ZActionsController { return gControllers.controllerForID(.idActions) as! ZActionsController }


class ZActionsController : ZGenericController {

	@IBOutlet var actionsSelector : ZoneSegmentedControl?
	override  var    controllerID : ZControllerID { return .idActions }
	var                     isTop : Bool { return gCurrentFunction == .eTop }


    // MARK: - events
    // MARK: -


	override func handleSignal(_ object: Any?, kind: ZSignalKind) {
		actionUpdate()
	}
	
	
	@IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
		showTop()
	}
	

	@IBAction func selectorAction(iControl: UISegmentedControl) {
		if  let    title = iControl.titleForSegment(at: iControl.selectedSegment),
			let function = ZFunction(rawValue: title) {
			let     zone = gSelecting.currentMoveable
			
			switch function {
			case .eTop, .eEdit, .eCloud,
				 .eMore:    gCurrentFunction = function; actionUpdate()
			case .eRefetchAll,
				 .eRefetch: refetch(for: function == .eRefetchAll)
			case .ePrefs:   switchView(to: function)
			case .eDelete:  gMapEditor.deleteGrabbed()
			case .eNew:     gSelecting.currentMoveable.addIdea()
			case .eHang:    gBatches.unHang()
			case .eName:    gTextEditor.edit(zone)
			case .eHelp:    openBrowserForFocusWebsite()
			case .eNext:    gSelecting.rootMostMoveable.addNext()
			case .eToTop:   showTop()
			default:        break
			}
		}
	}
	

	func actionUpdate() {
		if  let actions = actionsSelector {
			let    font = UIFont.systemFont(ofSize: 17)
			
			actions.setTitleTextAttributes([.font : font], for: .normal)
			actions.apportionsSegmentWidthsByContent = true
			actions.removeAllSegments()
			
			var index  = -1
			let insert = { (iFunction: ZFunction) -> Void in
				index += 1
				
				actions.insertSegment(withTitle: iFunction.rawValue, at:index, animated: false)
			}
			
			if !isTop {
				insert(.eToTop)
				(actions.subviews[0] as UIView).tintColor = UIColor.red
			}
			
			switch gCurrentFunction {
			case .eTop:
				insert(.eEdit)
				insert(.eCloud)
				insert(.eMore)
			case .eEdit:
				insert(.eNew)
				insert(.eNext)
				insert(.eName)
				insert(.eDelete)
			case .eCloud:
				if  gIsLate {
					insert(.eHang)
				} else {
					insert(.eRefetch)
					insert(.eRefetchAll)
				}
			case .eMore:
				insert(.eHelp)
				insert(.ePrefs)
			default: break
			}
		}
	}
	
	
	// MARK: - functions
	// MARK: -
	
	
	func alignView() {
		switch gDatabaseID {
		case .everyoneID: gCurrentMapFunction = .ePublic
		default:          gCurrentMapFunction = .eMe
		}
	}
	
	
	func switchView(to iFunction: ZFunction) {
		let priorShown = gShowSmallMapForIOS
		let    priorID = gDatabaseID

		switch iFunction {
		case .eMe:        gShowSmallMapForIOS = false; gDatabaseID = .mineID
		case .ePublic:    gShowSmallMapForIOS = false; gDatabaseID = .everyoneID
		case .eFavorites: gShowSmallMapForIOS = true
		default: break
		}
		
		if  gDatabaseID != priorID || gShowSmallMapForIOS != priorShown {
			gSelecting.updateAfterMove()
			redrawMap()
		}
	}
	
	
	func showTop() {
		gCurrentFunction = .eTop
		
		actionUpdate()
	}
	

	func refetch(for iAll: Bool) {
		gBatches		 .unHang()
		gWidgets         .clearRegistry()
		gMapController?.clear()
		gControllers     .startupCloudAndUI()
	}
	
}
