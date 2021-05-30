//
//  ZStartup.swift
//  Seriously
//
//  Created by Jonathan Sand on 8/9/20.
//  Copyright © 2020 Zones. All rights reserved.
//

import Foundation

let gStartup = ZStartup()

class ZStartup: NSObject {
	var              prior = 0.0
	let          startedAt = Date()
	var elapsedStartupTime : Double { return Date().timeIntervalSince(startedAt) }

	var elapsedEnough : Bool {
		let  lapse = elapsedStartupTime
		let enough = (lapse - prior) > kThreshold

		if  enough {
			prior = lapse
		}

		return enough
	}

	func startupCloudAndUI() {
		gRefusesFirstResponder = true			// WORKAROUND new feature of mac os x
		gWorkMode              = .wStartupMode
		gHelpWindowController  = NSStoryboard(name: "Help", bundle: nil).instantiateInitialController() as? NSWindowController // instantiated once

		gRemoteStorage.clear()
		gSignal([.spMain, .spStartupStatus])
		gTimers.startTimer(for: .tStartup)
		gSearching.setStateTo(.sNot)

		gBatches.startUp { iSame in
			FOREGROUND {
				gIsReadyToShowUI = true

				gFavorites.setup { result in
					FOREGROUND {
						gFavorites.updateAllFavorites()
						gRefreshCurrentEssay()
						gRefreshPersistentWorkMode()

						gHasFinishedStartup    = true
						gRefusesFirstResponder = false
						gMainController?.helpButton?.isHidden = false

						gTimers .stopTimer (for:  .tStartup)
						gTimers.startTimers(for: [.tCloudAvailable, .tRecount, .tSync])
						gRecents.push()
						gHereMaybe?.grab()

						if  gIsStartupMode {
							gSetBigMapMode()
						}

						gSignal([.sSwap, .spMain, .spCrumbs, .sLaunchDone, .sRelayout, .spPreferences])
						self.requestFeedback()

						FOREGROUND(after: 10.0) {
							gFiles.writeAll()
						}
					}
				}
			}
		}
	}

	func requestFeedback() {
		if       !emailSent(for: .eBetaTesting) {
			recordEmailSent(for: .eBetaTesting)

			FOREGROUND(after: 0.1) {
				let image = ZImage(named: kHelpMenuImageName)

				gAlerts.showAlert("Please forgive my interruption",
								  "Thank you for downloading Seriously. Might you be interested in helping me beta test it, giving me feedback about it (good and bad)? \n\nYou can let me know at any time, by selecting Report an Issue under the Help menu (red arrow in image), or now, by clicking the Reply button below.",
								  "Reply in an email",
								  "Dismiss",
								  image) { iObject in
									if  iObject != .eStatusNo {
										self.sendEmailBugReport()
									}
				}
			}
		}
	}

}
