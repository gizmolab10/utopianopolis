//
//  ZMapController.swift
//  Seriously
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

var gMapController : ZMapController? { return gControllers.controllerForID(.idBigMap) as? ZMapController }
var gMapView       : ZMapView?       { return gMapController?.mapView }

enum ZMapLayoutMode: Int { // do not change the order, they are persisted
	case linearMode
	case circularMode

	var next: ZMapLayoutMode {
		switch self {
		case .linearMode: return .circularMode
		default:          return .linearMode
		}
	}

	var title: String {
		switch self {
		case .linearMode: return "Tree"
		default:          return "Star"
		}
	}
}

class ZMapController: ZGesturesController, ZScrollDelegate {

	var          priorScrollLocation = CGPoint.zero
	var                mapLayoutMode : ZMapLayoutMode { return gMapLayoutMode }
	override  var       controllerID : ZControllerID  { return .idBigMap }
	var                   widgetType : ZWidgetType    { return .tBigMap }
	var                   isExemplar : Bool           { return false }
	var                     isBigMap : Bool           { return true }
	var                     hereZone : Zone?          { return gHereMaybe ?? gCloud?.rootZone }
	var                         mode : ZMapLayoutMode { return isBigMap ? gMapLayoutMode : .linearMode }
	var                      mapView : ZMapView?      { return view as? ZMapView}
	var                mapPseudoView : ZPseudoView?
	var                   hereWidget : ZoneWidget?
	var                     rootLine : ZoneLine?
	@IBOutlet var  mapContextualMenu : ZContextualMenu?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?

	override func controllerSetup() {
		if  let                          map = mapView {
			gestureView                      = map         // do this before calling super setup: it uses gesture view
			hereWidget                       = ZoneWidget (view: map)
			mapPseudoView                    = ZPseudoView(view: map)
			view     .layer?.backgroundColor = kClearColor.cgColor
			mapPseudoView?            .frame = map.frame

			super.controllerSetup()
			platformSetup()
			mapPseudoView?.addSubpseudoview(hereWidget!)
		}
	}

	func drawWidgets(for phase: ZDrawPhase) {
		if  isBigMap || gDetailsViewIsVisible(for: .vSmallMap) {
			if  phase == .pDots,
				mode  == .linearMode {
				rootLine?.draw(phase) // for here's drag dot
			}

			hereWidget?.traverseAllWidgetProgeny() { widget in
				widget.draw(phase)
			}

			if  phase == .pLines,
				mode  == .circularMode,
				gCirclesDisplayMode.contains(.cRings) {
				circularDrawLevelRings()      // now, draw level rings
			}
		}
	}

    #if os(OSX)
    
	func platformSetup() {}
    
    #elseif os(iOS)
    
    @IBOutlet weak var mobileKeyInput: ZMobileKeyInput?
    
    func platformSetup() {
        mobileKeyInput?.becomeFirstResponder()
    }

    #if false

	private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = hereWidget
        let heightScale = size.height / w.bounds.height
        let  widthScale = size.width  / w.bounds.width
        let    minScale = min(widthScale, heightScale)
        gScaling        = Double(minScale)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateMinZoomScaleForSize(view.bounds.size)
    }

	#endif

	#endif

	// MARK: - operations
	// MARK: -

	func toggleMaps() {
		gToggleDatabaseID()
		gHere.grab()
		gHere.expand()
		gFavorites.updateCurrentFavorite()
	}

	func recenter(_ SPECIAL: Bool = false) {
		gScaling      = 1.0
		gScrollOffset = !SPECIAL ? .zero : CGPoint(x: kHalfDetailsWidth, y: .zero)
		
		layoutForCurrentScrollOffset()
	}

	func setNeedsDisplay() {
		view.setNeedsDisplay()
		mapView?.linesAndDotsView?.setNeedsDisplay()

	}

	func layoutForCurrentScrollOffset() {
		printDebug(.dSpeed, "\(zClassName) layoutForCurrentScrollOffset")

		var            offset = isExemplar ? .zero : isBigMap ? gScrollOffset.offsetBy(.zero, 22.0) : CGPoint(x: -12.0, y: -6.0)
		offset.y              = -offset.y               // why?
		if  let          size = hereWidget?.drawnSize {
			let      relocate = CGPoint((view.frame.size - size).dividedInHalf)
			let        origin = (isBigMap ? relocate : .zero) + offset
			hereWidget?.frame = CGRect(origin: origin, size: size)

			hereWidget?.grandUpdate()
			detectHover(at: view.currentMouseLocationInWindow)
			setNeedsDisplay()
		}
	}

	var doNotLayout: Bool {
		return (kIsPhone && (isBigMap == gShowSmallMapForIOS)) || gIsEditIdeaMode
	}

	enum ZRelayoutMapType: Int {
		case small
		case both
		case big
	}

    func layoutWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		if  doNotLayout || kind == .sResize { return }

		printDebug(.dSpeed, "\(zClassName) layoutWidgets")

		var specificIndex:    Int?
		let specificView           = mapPseudoView
		var specificWidget         = hereWidget
        var              recursing = true
		let                   here = hereZone
        specificWidget?.widgetZone = here
		gTextCapturing             = false
        if  let               zone = iZone as? Zone,
            let             widget = zone.widget,
			widget.type           == zone.widgetType {
            specificWidget         = widget
            specificIndex          = zone.siblingIndex
            recursing              = [.sData, .spRelayout].contains(kind)
        }

		let type : ZRelayoutMapType = isBigMap ? .big : .small

		mapView?.removeAllTextViews(ofType: type)

		let total = specificWidget?.layoutAllPseudoViews(parentPseudoView: specificView, for: widgetType, atIndex: specificIndex, recursing: recursing, kind, visited: [])

		if  let    r = hereWidget, (!isBigMap || gMapLayoutMode == .linearMode) {
			let line = r.createLineFor(child: r)
			rootLine = line

			line.addDots(reveal: ZoneDot(view: r.absoluteView))
		}

		layoutForCurrentScrollOffset()

		if  let t = total {
			printDebug(.dWidget, "layout \(widgetType.description): \(t)")
		}
    }

	// MARK: - events
	// MARK: -

    override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  !gDeferringRedraw, gIsReadyToShowUI {
			if  kind == .sResize {
				resize()
				layoutForCurrentScrollOffset()
			} else {
				layoutWidgets(for: iSignalObject, kind)
			}

			view.setAllSubviewsNeedDisplay()
		}
	}

	func resize() {
		mapPseudoView?.frame = view.bounds

		gMapView?.resize()
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture
	}

	func restartGestureRecognition() {
		gestureView?.gestureHandler = self

		gDragging.draggedZones.removeAll()
	}

	func scrollEvent(move: Bool, to location: CGPoint) {
		if  move {
			gScrollOffset = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)

			layoutForCurrentScrollOffset()
		}

		priorScrollLocation = location
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
		if  gIgnoreEvents {
			return true
		}

        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if  gIsDraggableMode,
			let gesture  = iGesture as? ZPanGestureRecognizer {
			let location = gesture.location(in: gesture.view)

			printDebug(.dClick, "drag")

			if  isEditingText(at: location) {
				restartGestureRecognition()                       // let text editor consume the gesture
			} else {
				gDragging.handleDragGesture(gesture, in: self)
			}

			return true
        }

		return false
    }
	
	@objc override func handleClickGesture(_ iGesture: ZGestureRecognizer?) {
		if  gIgnoreEvents {
			return
		}

        if  gIsSearchMode {
            gSearching.exitSearchMode()
        }

		if (gIsMapOrEditIdeaMode || gIsEssayMode),
		    let    gesture  = iGesture as? ZKeyClickGestureRecognizer {
			let   location  = gesture.location(in: gMapView)
            let editWidget  = gCurrentlyEditingWidget
            var  notInEdit  = true

			printDebug(.dClick, "only")

			if  editWidget != nil {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let textRect = editWidget!.convert(editWidget!.bounds, to: gMapView)
                notInEdit    = !textRect.contains(location)
            }

            if  notInEdit {

				if !gIsEssayMode {
					gSetMapWorkMode()
				}

				gTextEditor.stopCurrentEdit()
				
				if  let any = detectHit(at: location) {
					if  let w = any as? ZoneWidget {
						w.widgetZone?.grab()
					} else if let d = any as? ZoneDot,
						let   flags = gesture.modifiers {
						d.widgetZone?.dotClicked(flags, isReveal: d.isReveal)
					}
				} else if gIsMapMode {

					// //////////////////////
					// click in background //
					// //////////////////////

					if !kIsPhone {	// default reaction to click on background: select here
						gHereMaybe?.grab()  // safe version of here prevent crash early in launch
						setNeedsDisplay()
					}
                } else if gIsEssayMode {
					gControllers.swapMapAndEssay(force: .wMapMode)
				}

                gSignal([ZSignalKind.sData])
            }

            restartGestureRecognition()
        }
	}

    // MARK: - internals
    // MARK: -
    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: gMapView)

            return rect.contains(location)
        }

        return false
    }

    func relationOf(_ point: CGPoint, to widget: ZoneWidget?) -> ZRelation {
        var     relation = ZRelation.upon
		if  let     text = widget?.pseudoTextWidget {
			let     rect = text.absoluteFrame.insetBy(dx: .zero, dy: 5.0)
			let     minY = rect.minY
			let     maxY = rect.maxY
			let        y = point.y
            if         y < minY {
                relation = .below
            } else if  y > maxY {
                relation = .above
			}
		}

        return relation
    }

}

