//
//  ZActionsController.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 9/24/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import UIKit


enum ZFunction: String {
	case eTopLevel   = "TopLevel"
	case eThoughts   = "Thoughts"
	case ePrefs      = "Preferences"
	case eHelp       = "Help"
	case eMore		 = "More"
	case eBack		 = "  <-  "

	case eCreate     = "Create"
    case eNew        = "New"
    case eNext       = "Next"
	case eDelete     = "Delete"

	case eSelection  = "Selection"
	case eExpand     = "Expand"
	case eCollapse   = "Collapse"
	case eFocus      = "Focus"
    case eTravel     = "Travel"
	
	case eBrowse     = "Browse"
	case eUp         = "Up"
	case eDown       = "Down"
	case eLeft       = "Left"
	case eRight      = "Right"

	case eHang       = "Reconnect"
	case eStorage    = "Storage"
	case eRefetch    = "Refetch"
	case eRefetchAll = "Refetch All"
}


var gActionsController: ZActionsController { return gControllers.controllerForID(.idActions) as! ZActionsController }


class ZActionsController : ZGenericController {

    @IBOutlet var actionsSelector : ZoneSegmentedControl?
	override  var    controllerID : ZControllerID { return .idActions }
	var           isTopLevel : Bool { return currentFunction == .eTopLevel }
	var           currentFunction = ZFunction.eTopLevel


    // MARK:- events
    // MARK:-


    override func handleSignal(_ object: Any?, kind iKind: ZSignalKind) {
        let ignoreThese: [ZSignalKind] = [.eSearch, .eFound]

        if !ignoreThese.contains(iKind) {
			update()
        }
    }
	
	
	@IBAction func actionsVisibilityButtonAction(iButton: UIButton) {
		showTopLevel()
	}
	

	@IBAction func selectorAction(iControl: UISegmentedControl) {
		if  let    title = iControl.titleForSegment(at: iControl.selectedSegment),
			let function = function(for: title) {
			
			switch function {
			case .eSelection, .eTopLevel, .eStorage, .eBrowse,
				 .eMore:     currentFunction = function; update()
			case .eRefetchAll,
				 .eRefetch:  refetch(for: function == .eRefetchAll)
			case .eThoughts: gShowThoughtsGraph = !gShowThoughtsGraph; gControllers.signalFor(nil, multiple: [.eRelayout])
			case .eDelete:   gGraphEditor.delete()
			case .eNew:      gGraphEditor.addIdea()
			case .eHang:     gBatches.unHang()
			case .eHelp:     openBrowserForFocusWebsite()
			case .eNext:     gGraphEditor.addNext() { iChild in iChild.edit() }
			case .eFocus:    gFocusing.focus(kind: .eSelected) { gGraphEditor.redrawSyncRedraw() }
			case .eTravel:   gFocusing.maybeTravelThrough(gSelecting.currentMoveable)
			case .eBack:	 showTopLevel()
			default:         break
			}
		}
	}


	func update() {
		if  let selector = actionsSelector {
			let     font = UIFont.systemFont(ofSize: 17)
			
			selector.setTitleTextAttributes([NSAttributedString.Key.font : font], for: .normal)
			selector.apportionsSegmentWidthsByContent = true
			selector.removeAllSegments()

			var index  = -1
			let insert = { (iFunction: ZFunction) -> Void in
				index += 1

				selector.insertSegment(withTitle: self.title(for: iFunction), at:index, animated: false)
			}

			if !isTopLevel {
				insert(.eBack)
//					let    emphasizedColor = ZColor.blue.lighter(by: 5.0)
//					let        borderColor = ZColor.blue
//
//					button.backgroundColor = emphasizedColor
//
//					button.setTitleColor(kWhiteColor, for: .normal)
//					button.addBorder(thickness: 1.0, radius: 5.0, color: borderColor.cgColor)
			}
			

			switch currentFunction {
			case .eTopLevel:
				insert(.eSelection)
				insert(.eBrowse)
				insert(.eThoughts)
				insert( gIsLate ? .eHang : .eStorage )
				insert(.eMore)
			case .eCreate:
				insert(.eNew)
				insert(.eNext)
				insert(.eDelete)
			case .eSelection:
				insert(.eExpand)
				insert(.eCollapse)
				insert(.eFocus)
				insert(.eTravel)
			case .eBrowse:
				insert(.eUp)
				insert(.eDown)
				insert(.eLeft)
				insert(.eRight)
			case .eStorage:
				insert(.eRefetch)
				insert(.eRefetchAll)
			case .eMore:
				insert(.ePrefs)
				insert(.eHelp)
			default: break
			}

			if !isTopLevel {
//				selector.Segment.left
			}
		}
	}
	
	
	// MARK:- functions
	// MARK:-
	

	func title(for iFunction: ZFunction) -> String {
		switch iFunction {
		case .eFocus: return gFavorites.function
		case .eThoughts: return gShowThoughtsGraph ? "Favorites" : "Thoughts"
		default:      return iFunction.rawValue
		}
	}
	

    func function(for iTitle: String) -> ZFunction? {
		switch iTitle {
		case "Favorites": return .eThoughts
		default: if let function = ZFunction(rawValue: iTitle) {
				return  function
			}
		}
		
		return nil
    }

	
	func showTopLevel() {
		currentFunction = .eTopLevel
		
		update()
	}
	
	
	func refetch(for iAll: Bool) {
		gBatches		 .unHang()
		gWidgets         .clearRegistry()
		gGraphController?.clear()
		gControllers     .startupCloudAndUI()
	}
	
}
