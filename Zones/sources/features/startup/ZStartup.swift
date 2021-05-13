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
	var count = 0.0
	var prior = 0.0

	func addShouldDisplay(_ increment: Double) -> Bool {
		count       += increment
		let  display = 0.5 <= (count - prior)

		if  display {
			if  gCurrentOp == .oRestoreIdeas {
				noop()
			}

			prior    = count
		}

		return display
	}

	func startupCloudAndUI() {
		gRefusesFirstResponder = true			// WORKAROUND new feature of mac os x
		gWorkMode              = .wStartupMode
		gHelpWindowController  = NSStoryboard(name: "Help", bundle: nil).instantiateInitialController() as? NSWindowController // instantiated once

		gRemoteStorage.clear()
		gSignal([.sMain, .sStartupProgress])
		gTimers.startTimer(for: .tStartup)

		gBatches.startUp { iSame in
			FOREGROUND {
				gIsReadyToShowUI   = true

//				gRecents.push()
				gHereMaybe?.grab()
				gFavorites.setup { result in
					FOREGROUND {
						gFavorites.updateAllFavorites()
						gRemoteStorage.updateLastSyncDates()
						gRefreshCurrentEssay()
						gRefreshPersistentWorkMode()
						gSignal([.sCrumbs, .sLaunchDone])

						gBatches.finishUp { iSame in
							FOREGROUND {
								gHasFinishedStartup    = true
								gRefusesFirstResponder = false

								gTimers .stopTimer (for:  .tStartup)
								gTimers.startTimers(for: [.tCloudAvailable, .tRecount, .tSync])

								if  gIsStartupMode {
									gSetBigMapMode()
								}

								gSignal([.sSwap, .sMain, .sCrumbs, .sRelayout, .sPreferences])
								self.requestFeedback()

								FOREGROUND(after: 10.0) {
									gFiles.writeAll()
								}
							}
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
