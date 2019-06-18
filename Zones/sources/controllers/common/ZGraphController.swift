//
//  ZGraphController.swift
//  Thoughtful
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


var gGraphController: ZGraphController? { return gControllers.controllerForID(.idGraph) as? ZGraphController }


class ZGraphController: ZGenericController, ZGestureRecognizerDelegate, ZScrollDelegate {
    
    
    // MARK:- initialization
    // MARK:-
    
	
	let 		   clickManager =  ZClickManager()
    let      thoughtsRootWidget =  ZoneWidget ()
    let     favoritesRootWidget =  ZoneWidget ()
    var      rubberbandPreGrabs = [Zone] ()
    var     priorScrollLocation =  CGPoint.zero
    var         rubberbandStart =  CGPoint.zero
	var        moveRightGesture :  ZGestureRecognizer?
	var         movementGesture :  ZGestureRecognizer?
	var         moveDownGesture :  ZGestureRecognizer?
	var         moveLeftGesture :  ZGestureRecognizer?
	var           moveUpGesture :  ZGestureRecognizer?
	var            clickGesture :  ZGestureRecognizer?
	var             edgeGesture :  ZGestureRecognizer?
	let              doneStates : [ZGestureRecognizerState] = [.ended, .cancelled, .failed, .possible]
	override  var  controllerID :  ZControllerID { return .idGraph }
    @IBOutlet var       spinner :  ZProgressIndicator?
    @IBOutlet var      dragView :  ZDragView?
    @IBOutlet var   spinnerView :  ZView?
    @IBOutlet var indicatorView :  ZIndicatorView?
	
	
	var rubberbandRect: CGRect? {
		get {
			return dragView?.rubberbandRect
		}
		
		set {
			if  let d = dragView {
				if  newValue == nil || rubberbandStart == .zero {
					if  let type = indicatorView?.hitTest(d.rubberbandRect) {
						toggleMode(isDirection: type == .eDirection)
					}
					
					d.rubberbandRect = .zero
					
					gSelecting.assureMinimalGrabs()
					gSelecting.updateCurrentBrowserLevel()
					gSelecting.updateCousinList()
				} else {
					d.rubberbandRect = newValue
					let      widgets = gWidgets.visibleWidgets
					
					gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
					gHere.ungrab()
					
					for widget in widgets {
						if  let    hitRect = widget.hitRect {
							let widgetRect = widget.convert(hitRect, to: d)
							
							if  let zone = widget.widgetZone, !zone.isRootOfFavorites,
								
								widgetRect.intersects(newValue!) {
								widget.widgetZone?.addToGrab()
							}
						}
					}
				}
				
				d.setAllSubviewsNeedDisplay()
			}
		}
	}


    override func setup() {
        restartGestureRecognition()
        dragView?.addSubview(thoughtsRootWidget)

        if  !kIsPhone {
            dragView?.addSubview(favoritesRootWidget)
        }
        
        indicatorView?.setupGradientView()
    }

    #if os(OSX)
    
    override func platformSetup() {
        guard let lighten = CIFilter(name: "CIColorControls") else { return }
        lighten.setDefaults()
        lighten.setValue(1, forKey: "inputBrightness")
        spinner?.contentFilters = [lighten]
    }
    
    #elseif os(iOS)
    
    @IBOutlet weak var keyInput: ZKeyInput?
    
    override func platformSetup() {
        keyInput?.becomeFirstResponder()
    }
    
    #endif

	
	// MARK:- operations
	// MARK:-


    func clear() {
        thoughtsRootWidget   .widgetZone = nil
        favoritesRootWidget.widgetZone = nil
    }
    
    
    #if os(iOS) && false
    private func updateMinZoomScaleForSize(_ size: CGSize) {
        let           w = thoughtsRootWidget
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

	
	func toggleGraphs() {
		gFocusing.pushHere()
		toggleDatabaseID()
		gHere.grab()
		gHere.revealChildren()
		gFavorites.updateAllFavorites()
	}
	

	func recenter() {
		gScaling      = 1.0
		gScrollOffset = CGPoint.zero
		
		layoutForCurrentScrollOffset()
	}
	

    func layoutForCurrentScrollOffset() {
        if  let d = dragView {
            thoughtsRootWidget.snp.removeConstraints()
            thoughtsRootWidget.snp.makeConstraints { make in
                make.centerY.equalTo(d).offset(gScrollOffset.y)
                make.centerX.equalTo(d).offset(gScrollOffset.x)
            }

            if  favoritesRootWidget.superview == nil {
                d.addSubview(favoritesRootWidget)
            }
            
            favoritesRootWidget.snp.removeConstraints()
            favoritesRootWidget.snp.makeConstraints { make in
				if kIsPhone {
					make.centerY.equalTo(d).offset(gScrollOffset.y)
					make.centerX.equalTo(d).offset(gScrollOffset.x)
				} else {
					make  .top.equalTo(d).offset(45.0 - Double(gGenericOffset.height / 3.0))
					make .left.equalTo(d).offset(15.0 - Double(gGenericOffset.width       ))
				}
			}
            
            d.setNeedsDisplay()
        }
    }
    
    
    // MARK:- events
    // MARK:-

	
	func restartGestureRecognition() { dragView?.gestureHandler = self }
	func isDoneGesture(_ iGesture: ZGestureRecognizer?) -> Bool { return doneStates.contains(iGesture!.state) }
	

    func layoutRootWidget(for iZone: Any?, _ iKind: ZSignalKind, inThoughtsGraph: Bool) {
        if  kIsPhone && (inThoughtsGraph != gShowThoughtsGraph) { return }

        let                        here = inThoughtsGraph ? gHereMaybe : gFavoritesRoot
        var specificWidget: ZoneWidget? = inThoughtsGraph ? thoughtsRootWidget : favoritesRootWidget
        var specificView:        ZView? = dragView
        var specificIndex:         Int?
        var                   recursing = true
        gTextCapturing                  = false
        specificWidget?     .widgetZone = here

        if  let            zone  = iZone as? Zone,
            let          widget  = zone.widget,
            widget.isInThoughts == inThoughtsGraph {
            specificWidget       = widget
            specificIndex        = zone.siblingIndex
            specificView         = specificWidget?.superview
            recursing            = [.eData, .eRelayout].contains(iKind)
        }

        specificWidget?.layoutInView(specificView, atIndex: specificIndex, recursing: recursing, iKind, isThought: inThoughtsGraph, visited: [])
    }

    
    override func handleSignal(_ iSignalObject: Any?, kind iKind: ZSignalKind) {
        if  [.eDatum, .eData, .eRelayout].contains(iKind) { // ignore for preferences, search, information, startup
            if  gWorkMode != .graphMode {
                dragView?.snp.removeConstraints()
            } else if !gIsEditingText {
				prepare(for: iKind)
                layoutForCurrentScrollOffset()
                layoutRootWidget(for: iSignalObject, iKind, inThoughtsGraph: true)
                layoutRootWidget(for: iSignalObject, iKind, inThoughtsGraph: false)
                dragView?.setAllSubviewsNeedDisplay()
            }
        }

		indicatorView?.setNeedsDisplay()
    }
	
	
	func prepare(for iKind: ZSignalKind) {
		if  iKind == .eRelayout {
			gWidgets.clearRegistry()
		}
		
		if  kIsPhone {
			favoritesRootWidget.isHidden =  gShowThoughtsGraph
			thoughtsRootWidget	   .isHidden = !gShowThoughtsGraph
		}
	}

	
	func gestureRecognizer(_ gestureRecognizer: ZGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: ZGestureRecognizer) -> Bool {
		return (gestureRecognizer == clickGesture && otherGestureRecognizer == movementGesture) ||
			otherGestureRecognizer == edgeGesture
	}
	

    @objc func dragGestureEvent(_ iGesture: ZGestureRecognizer?) {
        if  gWorkMode        != .graphMode {
            gSearching.exitSearchMode()
        }
        
        if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
            let (_, dropNearest, location) = widgetNearest(gesture),
            let   flags = gesture.modifiers {
            let   state = gesture.state

            dropNearest.widgetZone?.deferWrite()

            if isEditingText(at: location) {
                restartGestureRecognition()     // let text editor consume the gesture
            } else if flags.isCommand {
                scrollEvent(move: state == .changed, to: location)
            } else if gIsDragging {
                dragMaybeStopEvent(iGesture)
            } else if state == .changed {       // changed
                rubberbandRect = CGRect(start: rubberbandStart, end: location)
            } else if state != .began {         // ended, cancelled or failed
                rubberbandRect = nil

				restartGestureRecognition()
				gControllers.signalFor(nil, regarding: .eDatum) // so color well and indicators get updated
            } else if let dot = detectDot(iGesture) {
                if  !dot.isReveal {
                    dragStartEvent(dot, iGesture)
                } else if let zone = dot.widgetZone {
                    cleanupAfterDrag()
                    gGraphEditor.clickActionOnRevealDot(for: zone, isCommand: flags.isCommand)   // no dragging
                }
            } else {                            // began
                rubberbandStartEvent(location, iGesture)
            }
        }
    }
	
	
	class ZClickManager : NSObject {

		var lastClicked:   Zone?
		var lastClickTime: Date?
		
		func isDoubleClick(on iZone: Zone? = nil) -> Bool {
			let    isFast = lastClickTime?.timeIntervalSinceNow ?? -10.0 > -1.8
			let  isRepeat = lastClicked == iZone
			lastClickTime = Date()
			lastClicked   = iZone
			
			columnarReport("repeat: \(isRepeat)", "fast: \(isFast)")
			
			return isRepeat ? isFast : false
		}
	}
	
	
	@objc func leftEdgeEvent(_ iGesture: ZGestureRecognizer?) {
		gShowThoughtsGraph = !gShowThoughtsGraph
		
		gControllers.signalFor(nil, multiple: [.eRelayout])
	}
	

    @objc func clickEvent(_ iGesture: ZGestureRecognizer?) {
        if  gWorkMode != .graphMode {
            gSearching.exitSearchMode()
        }
        
        if  let    gesture = iGesture {
            let    COMMAND = gesture.isCommandDown
            let      SHIFT = gesture.isShiftDown
            let editWidget = gEditedTextWidget
            var  regarding = ZSignalKind.eDatum
            var withinEdit = false
            
            editWidget?.widgetZone?.deferWrite()

			if  editWidget != nil {

				////////////////////////////////////
				// ignore gestures located inside //
				//   text that is being edited    //
				////////////////////////////////////

                let backgroundLocation = gesture.location(in: dragView)
                let           textRect = editWidget!.convert(editWidget!.bounds, to: dragView)
                withinEdit             = textRect.contains(backgroundLocation)
            }

            if !withinEdit {
				if  let   widget = detectWidget(gesture) {
					if  let zone = widget.widgetZone,
						let  dot = detectDotIn(widget, gesture) {
						
						///////////////
						// dot event //
						///////////////

						if  dot.isReveal {
							gGraphEditor.clickActionOnRevealDot(for: zone, isCommand: COMMAND)
						} else {
							regarding = .eDetails // update selection level
							
							zone.dragDotClicked(COMMAND, SHIFT, clickManager.isDoubleClick(on: zone))
						}
					}
				} else { // click on background
					
					//////////////////////
					// background event //
					//////////////////////

					gTextEditor.stopCurrentEdit()

					if  clickManager.isDoubleClick() {
						recenter()
					} else if !kIsPhone {	// default reaction to click on background: select here
						gHereMaybe?.grab()  // safe version of here prevent crash early in launch
					}
					
                    if  let i = indicatorView, !i.isHidden {
                        let gradientView     = i.gradientView
                        let gradientLocation = gesture.location(in: gradientView)
                        
                        if  gradientView.bounds.contains(gradientLocation) {    // if in indicatorView
                            let isConfinement = indicatorView?.confinementRect.contains(gradientLocation) ?? false
                            toggleMode(isDirection: !isConfinement)             // if in confinement symbol, change confinement; else, change direction
                        }
                    }
                }

                gControllers.signalFor(nil, regarding: regarding)
            }

            restartGestureRecognition()
        }
	}
	
	
    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////
    
    
    func dragStartEvent(_ dot: ZoneDot, _ iGesture: ZGestureRecognizer?) {
        if  var zone = dot.widgetZone { // should always be true
            if  iGesture?.isOptionDown ?? false {
                zone = zone.deepCopy // option means drag a copy
            }

            if  iGesture?.isShiftDown ?? false {
                zone.addToGrab()
            } else if !zone.isGrabbed {
                zone.grab()
            }
            
            if  let location  = iGesture?.location(in: dot) {
                dot.dragStart = location
                gDraggedZone  = zone
            }
        }
    }
    
    
    func dragMaybeStopEvent(_ iGesture: ZGestureRecognizer?) {
        if  dragDropMaybe(iGesture) {
            cleanupAfterDrag()
            
            if  isDoneGesture(iGesture) {
                gControllers.signalFor(nil, regarding: .ePreferences) // so color well gets updated
                restartGestureRecognition()
            }
        }
    }

    
    func scrollEvent(move: Bool, to location: CGPoint) {
        if move {
            gScrollOffset   = CGPoint(x: gScrollOffset.x + location.x - priorScrollLocation.x, y: gScrollOffset.y + priorScrollLocation.y - location.y)
            
            layoutForCurrentScrollOffset()
        }
        
        priorScrollLocation = location
    }
    
    
    /////////////////////////////////////////////
    // next four are only called by controller //
    /////////////////////////////////////////////
    
    
    func rubberbandStartEvent(_ location: CGPoint, _ iGesture: ZGestureRecognizer?) {
        rubberbandStart = location
        gDraggedZone    = nil
        
        //////////////////////
        // detect SHIFT key //
        //////////////////////
        
        if let gesture = iGesture, gesture.isShiftDown {
            rubberbandPreGrabs.append(contentsOf: gSelecting.currentGrabs)
        } else {
            rubberbandPreGrabs.removeAll()
        }
        
        gTextEditor.stopCurrentEdit()
        gSelecting.ungrabAll(retaining: rubberbandPreGrabs)
    }


    func dragDropMaybe(_ iGesture: ZGestureRecognizer?) -> Bool {
        if  let draggedZone       = gDraggedZone {
            if  draggedZone.userCanMove,
                let (isThought, dropNearest, location) = widgetNearest(iGesture) {
                var      dropZone = dropNearest.widgetZone
                let dropIsGrabbed = gSelecting.currentGrabs.contains(dropZone!)
                let     dropIndex = dropZone?.siblingIndex
                let          here = isThought ? gHere : gFavoritesRoot
                let      dropHere = dropZone == here
                let      relation = relationOf(location, to: dropNearest.textWidget)
                let useDropParent = relation != .upon && !dropHere
                ;        dropZone = dropIsGrabbed ? nil : useDropParent ? dropZone?.parentZone : dropZone
                let lastDropIndex = dropZone == nil ? 0 : dropZone!.count
                var         index = (useDropParent && dropIndex != nil) ? (dropIndex! + relation.rawValue) : ((!gInsertionsFollow || dropIsGrabbed) ? 0 : lastDropIndex)
                ;           index = !dropHere ? index : relation != .below ? 0 : lastDropIndex
                let     dragIndex = draggedZone.siblingIndex
                let     sameIndex = dragIndex == index || dragIndex == index - 1
                let  dropIsParent = dropZone?.children.contains(draggedZone) ?? false
                let    spawnCycle = dropZone?.spawnCycle ?? false
                let        isNoop = dropIsGrabbed || spawnCycle || (sameIndex && dropIsParent) || index < 0
                let         prior = gDragDropZone?.widget
                let       dropNow = isDoneGesture(iGesture)
                gDragDropIndices  = isNoop || dropNow ? nil : NSMutableIndexSet(index: index)
                gDragDropZone     = isNoop || dropNow ? nil : dropZone
                gDragRelation     = isNoop || dropNow ? nil : relation
                gDragPoint        = isNoop || dropNow ? nil : location

                if !isNoop && !dropNow && !dropHere && index > 0 {
                    gDragDropIndices?.add(index - 1)
                }

                prior?           .displayForDrag() // erase  child lines
                dropZone?.widget?.displayForDrag() // relayout child lines
                dragView?       .setNeedsDisplay() // relayout drag: line and dot

                // columnarReport(String(describing: gDragRelation), gDragDropZone?.unwrappedName)

                if dropNow, let drop = dropZone, !isNoop {
                    let   toBookmark = drop.isBookmark
                    var dropAt: Int? = index

                    if toBookmark {
                        dropAt       = gInsertionsFollow ? nil : 0
                    } else if dragIndex != nil && dragIndex! <= index && dropIsParent {
                        dropAt!     -= 1
                    }

                    if  let gesture = iGesture as? ZKeyPanGestureRecognizer,
                        let COMMAND = gesture.modifiers?.isCommand {
                        gGraphEditor.moveGrabbedZones(into: drop, at: dropAt, COMMAND) {
                            gSelecting.updateBrowsingLevel()
                            gSelecting.updateCousinList()
                            self.restartGestureRecognition()
                            self.redrawAndSync()
                        }
                    }
                }

                return dropNow
            }
        }

        return true
    }


    // MARK:- large indicators
    // MARK:-
    
    
    func toggleDirectionIndicators() {
        if  let i = indicatorView {
            i.isHidden = !i.isHidden

            i.setNeedsDisplay()
        }
    }


    func showSpinner(_ show: Bool) {
        if  spinnerView?.isHidden == show {
            spinnerView?.isHidden = !show

            if show {
                spinner?.startAnimating()
            } else {
                spinner?.stopAnimating()
            }
        }
    }

    
    // MARK:- internals
    // MARK:-


    func widgetNearest(_ iGesture: ZGestureRecognizer?, isThought: Bool = true) -> (Bool, ZoneWidget, CGPoint)? {
        let      rootWidget = isThought ? thoughtsRootWidget : favoritesRootWidget
        if  let    location = iGesture?.location(in: dragView),
            let dropNearest = rootWidget.widgetNearestTo(location, in: dragView, gHereMaybe) {
            if  isThought, !kIsPhone,

                //////////////////////////////////
                // recurse only for isMain true //
                //////////////////////////////////

                let (_, otherDrop, otherLocation) = widgetNearest(iGesture, isThought: false) {

                ///////////////////////////////////////////////
                //     target zone found in both graphs      //
                // deterimine which zone is closer to cursor //
                ///////////////////////////////////////////////

                let      dotN = dropNearest.dragDot
                let      dotO = otherDrop  .dragDot
                let distanceN = dotN.convert(dotN.bounds.center, to: view) - location
                let distanceO = dotO.convert(dotO.bounds.center, to: view) - location
                let   scalarN = distanceN.scalarDistance
                let   scalarO = distanceO.scalarDistance

                if scalarN > scalarO {
                    return (false, otherDrop, otherLocation)
                }
            }

            return (true, dropNearest, location)
        }

        return nil
    }

    
    func isEditingText(at location: CGPoint) -> Bool {
        if  gIsEditingText, let textWidget = gEditedTextWidget {
            let rect = textWidget.convert(textWidget.bounds, to: dragView)

            return rect.contains(location)
        }

        return false
    }


    func cleanupAfterDrag() {
        rubberbandStart  = CGPoint.zero

        // cursor exited view, remove drag cruft

        let          dot = gDragDropZone?.widget?.revealDot.innerDot // drag view does not "un"draw this
        gDragDropIndices = nil
        gDragDropZone    = nil
        gDragRelation    = nil
        gDragPoint       = nil

        favoritesRootWidget.setNeedsDisplay()
        thoughtsRootWidget    .setNeedsDisplay()
        dragView?          .setNeedsDisplay() // erase drag: line and dot
        dot?               .setNeedsDisplay()
    }


    func relationOf(_ iPoint: CGPoint, to iView: ZView?) -> ZRelation {
        var relation: ZRelation = .upon

        if  iView     != nil {
            let margin = CGFloat(5.0)
            let  point = dragView!.convert(iPoint, to: iView)
            let   rect = iView!.bounds
            let      y = point.y

            if y < rect.minY + margin {
                relation = .above
            } else if y > rect.maxY - margin {
                relation = .below
            }
        }

        return relation
    }


    // MARK:- detect
    // MARK:-


    func detectWidget(_ iGesture: ZGestureRecognizer?) -> ZoneWidget? {
        var hit: ZoneWidget?
        if  let        d = dragView,
            let location = iGesture?.location(in: d),
            d.bounds.contains(location) {
            let  widgets = gWidgets.widgets.values
            for  widget in widgets {
                let rect = widget.convert(widget.outerHitRect, to: d)

                if  rect.contains(location) {
                    hit  = widget

                    break
                }
            }
        }

        return hit
    }


    func detectDotIn(_ widget: ZoneWidget, _ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        var hit:        ZoneDot?

        if  let                d = dragView,
            let         location = iGesture?.location(in: d) {
            let test: DotClosure = { iDot in
                let         rect = iDot.convert(iDot.bounds, to: d)

                if  rect.contains(location) {
                    hit = iDot
                }
            }

            test(widget.dragDot)
            test(widget.revealDot)
        }

        return hit
    }


    func detectDot(_ iGesture: ZGestureRecognizer?) -> ZoneDot? {
        if  let widget = detectWidget(iGesture) {
            return detectDotIn(widget, iGesture)
        }

        return nil
    }

}

