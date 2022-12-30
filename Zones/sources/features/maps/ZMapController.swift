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

var gMapController    : ZMapController? { return gControllers.controllerForID(.idBigMap) as? ZMapController }
var gMapView          : ZMapView?       { return gMapController?.view as? ZMapView }
var gLinesAndDotsView : ZMapView?       { return gMapView?.decorationsView }

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

	var                priorLocation = CGPoint.zero
	override  var       controllerID : ZControllerID  { return .idBigMap }
	var                mapLayoutMode : ZMapLayoutMode { return gMapLayoutMode }
	var                 inLinearMode : Bool           { return mode == .linearMode }
	var               inCircularMode : Bool           { return mode == .circularMode }
	var               canDrawWidgets : Bool           { return gCanDrawWidgets } // overridden by help dots controller
	var                   isExemplar : Bool           { return controllerID == .idHelpDots }
	var                     isBigMap : Bool           { return controllerID == .idBigMap }
	var                     hereZone : Zone?          { return gHereMaybe ?? gCloud?.rootZone }
	var                         mode : ZMapLayoutMode { return isBigMap ? gMapLayoutMode : .linearMode }
	var                   widgetType : ZWidgetType    { return .tBigMap }
	var                mapPseudoView : ZPseudoView?
	var                   hereWidget : ZoneWidget?
	var                     rootLine : ZoneLine?
	var                      mapView : ZMapView?
	@IBOutlet var  mapContextualMenu : ZContextualMenu?
	@IBOutlet var ideaContextualMenu : ZoneContextualMenu?
	override func controllerStartup() { controllerSetup(with: gMapView) }    // viewWillAppear is not called, so piggy back on viewDidLoad, which calls startup

	override func controllerSetup(with iMapView: ZMapView?) {
		if  let                     map = iMapView {
			mapView                     = map
			gestureView                 = map         // do this before calling super setup: it uses gesture view
			hereWidget                  = ZoneWidget (view: map)
			mapPseudoView               = ZPseudoView(view: map)
			view.layer?.backgroundColor = kClearColor.cgColor
			mapPseudoView?       .frame = map.frame

			if  isBigMap || isExemplar {
				map.setup(with: self)
			}

			super.controllerSetup(with: map)
			platformSetup()
			mapPseudoView?.addSubpseudoview(hereWidget!)
		}
	}

	func drawWidgets(for phase: ZDrawPhase) {
		if  canDrawWidgets {
			if  phase == .pDots, inLinearMode {
				rootLine?.draw(phase) // for here's drag dot
			}

			if  hereZone?.widget != hereWidget {
				noop()
			}

			hereZone?.widget?.traverseAllWidgetProgeny() { widget in
				widget.draw(phase)
			}

			if  phase == .pLines, inCircularMode,
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
		assignAsFirstResponder(mobileKeyInput)
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
		gFavorites.updateCurrentWithBookmarksTargetingHere()
	}

	func recenter(_ SPECIAL: Bool = false) {
		gScaling          = 1.0
		gMapOffset        = !SPECIAL ? .zero : CGPoint(x: kHalfDetailsWidth, y: .zero)
		gMapRotationAngle = .zero

		layoutForCurrentScrollOffset()
	}

	func setNeedsDisplay() {
		mapView?                  .setNeedsDisplay()
		mapView?.decorationsView?.setNeedsDisplay()
	}

	var doNotLayout: Bool {
		return (kIsPhone && (isBigMap == gShowSmallMapForIOS)) || gIsEditIdeaMode || (gIsEssayMode && isBigMap)
	}

	func createAndLayoutWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		createWidgets(for: iZone, kind)
		layoutForCurrentScrollOffset()
	}

    func createWidgets(for iZone: Any?, _ kind: ZSignalKind) {
		if  doNotLayout || kind == .sResize {
			if  kind != .sResize, isBigMap, gIsEssayMode {   // do not create widgets behind essay view
				mapView?.removeAllTextViews(ofType: .big)
				clearAllToolTips(for: isBigMap ? .big : .small)
			}

			return
		}

		printDebug(.dSpeed, "\(zClassName) createWidgets")

		var specificIndex:    Int?
		let specificView           = mapPseudoView
		var specificWidget         = hereWidget
        var              recursing = true
		let                   here = hereZone
        specificWidget?.widgetZone = here
		gTextCapturing             = false
        if  let               zone = iZone as? Zone,
            let             widget = zone.widget,
			widget.widgetType     == zone.widgetType {
            specificWidget         = widget
            specificIndex          = zone.siblingIndex
            recursing              = [.sData, .spRelayout].contains(kind)
        }

		let type : ZRelayoutMapType = isBigMap ? .big : .small

		// //////////////////////////// //
		// clear remnants of prior loop //
		// //////////////////////////// //

		mapView?.removeAllTextViews(ofType: type)

		// ////////////////////////// //
		// create all new widget tree //
		// ////////////////////////// //

		let    total = specificWidget?.createChildPseudoViews(for: specificView, for: widgetType, atIndex: specificIndex, recursing: recursing, kind, visited: [])

		if  let    r = hereWidget, (!isBigMap || gMapLayoutMode == .linearMode) {
			let line = r.createLineFor(child: r)
			rootLine = line

			line.addDots(reveal: ZoneDot(view: r.absoluteView))
		}

		if  let t = total {
			printDebug(.dWidget, "layout \(widgetType.description): \(t)")
		}
    }

	var mapOrigin: CGPoint? {
		if  let  mapSize = mapView?.frame.size.dividedInHalf {
			let   bigMap = gMapOffset.offsetBy(-gDotHeight, 22.0)
			let smallMap = CGPoint(x: -12.0, y: -6.0)
			let exemplar = CGPoint(x: .zero, y: -6.0)
			var   offset = isExemplar ? exemplar : isBigMap ? bigMap : smallMap
			if  !kIsPhone {
				offset.y = -offset.y    // default values are in iphone coordinates whereas y coordination is opposite in non-iphone devices
			}

			return (isBigMap ? CGPoint(mapSize) : .zero) + offset
		}

		return nil
	}

	func replaceAllToolTips(_ flags: ZEventFlags) {
		clearAllToolTips()
		updateAllToolTips(flags)
	}

	func updateAllToolTips(_ flags: ZEventFlags) {
		view.traverseHierarchy() { subview in
			if  let s = subview as? ZToolTipper {
				s.updateToolTips(flags)
			}

			return .eContinue
		}

		gWidgets.updateAllToolTips(flags)
	}

	func clearAllToolTips(for type: ZRelayoutMapType = .both) {
		view.traverseHierarchy() { subview in
			if  let t = subview as? ZoneTextWidget,
				let z = t.widgetZone,
				z.isInMap(of: type) {
				t.clearToolTips()
			}

			return .eContinue
		}

		gWidgets.clearAllToolTips(for: type)
	}

	func layoutForCurrentScrollOffset() {
		printDebug(.dSpeed, "\(zClassName) layoutForCurrentScrollOffset")

		clearAllToolTips(for: isBigMap ? .big : .small)
		gRemoveAllTracking()

		if  isBigMap, gIsEssayMode {
			return               // when in essay mode, do not process big map's widgets
		}

		if  let  mOrigin = mapOrigin,
			let   widget = hereWidget {
			let     size = widget.drawnSize.dividedInHalf
			let   origin = isBigMap ? mOrigin - size : mOrigin
			widget.frame = CGRect(origin: origin, size: size)

			widget.grandRelayout()
			updateAllToolTips(gModifierFlags) // potentially all new widgets (and their dots): regenerate all their tool tips
			detectHover()
			setNeedsDisplay()
		}
	}

	// MARK: - events
	// MARK: -

    override func handleSignal(_ iSignalObject: Any?, kind: ZSignalKind) {
		if  !gDeferringRedraw, gIsReadyToShowUI {
			switch kind {
				case .sResize:
					resize()
					layoutForCurrentScrollOffset()
				case .sToolTips:
					replaceAllToolTips(gModifierFlags)
				default:
					createAndLayoutWidgets(for: iSignalObject, kind)
			}
		}
	}

	func resize() {
		mapPseudoView?.frame = view.bounds

		mapView?.resize()
	}
	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture
	}

	func restartGestureRecognition() {
		gestureView?.gestureHandler = self

		gDragging.draggedZones.removeAll()
		gRemoveAllTracking() // fix fluttery cursor !!!!!!!!
	}

	func offsetEvent(move: Bool, to location: CGPoint) {
		if  move {
			gMapOffset = CGPoint(x: gMapOffset.x + location.x - priorLocation.x, y: gMapOffset.y + priorLocation.y - location.y)

			layoutForCurrentScrollOffset()
		}

		priorLocation = location
	}

	func rotationEvent(_ location: CGPoint) {
		if  let        origin = mapOrigin {
			let      endAngle = (location            - origin).angle
			let    startAngle = (gDragging.dragStart - origin).angle
			gMapRotationAngle = gDragging.startAngle - startAngle + endAngle
			gDragging.current = location

			layoutForCurrentScrollOffset()
		}
	}

	@objc override func handleDragGesture(_ iGesture: ZGestureRecognizer?) -> Bool { // true means handled
		if  gIgnoreEvents {
			return true
		}

		gExitSearchMode(force: false)
		gHideExplanation()

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

		gExitSearchMode(force: false)
		gHideExplanation()

		if (gIsMapOrEditIdeaMode || gIsEssayMode),
		    let        gesture = iGesture as? ZKeyClickGestureRecognizer {
			let       location = gesture.location(in: mapView)
            var notEditingIdea = true

			printDebug(.dClick, "only")

			if  let editWidget = gCurrentlyEditingWidget {

				// ////////////////////////////////////////
				// detect click inside text being edited //
				// ////////////////////////////////////////

                let   textRect = editWidget.convert(editWidget.bounds, to: mapView)
                notEditingIdea = !textRect.contains(location)
            }

            if  notEditingIdea {
				gTextEditor.stopCurrentEdit()

				if  gIsEssayMode {
					gEssayView?.exit()
				} else {
					gSetMapWorkMode()
				}

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

                gSignal([.sData])
            }

            restartGestureRecognition()
        }
	}

    // MARK: - internals
    // MARK: -
    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditIdeaMode, let textWidget = gCurrentlyEditingWidget {
            let rect = textWidget.convert(textWidget.bounds, to: mapView)

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

