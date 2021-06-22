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
	
	var oneTimerIntervalElapsed : Bool {
		let  lapse = elapsedStartupTime
		let enough = (lapse - prior) > kOneTimerInterval

		if  enough {
			prior = lapse
		}

		return enough
	}

	func startupCloudAndUI() {
		gRefusesFirstResponder = true			// WORKAROUND new feature of mac os x
		gMigrationState        = gCoreDataStack.hasStore() ? .normal : gFiles.hasMine ? .migrate : .firstTime
		gWorkMode              = .wStartupMode

		gRemoteStorage.clear()
		gSearching.setSearchStateTo(.sNot)
		gSignal([.spMain, .spStartupStatus])

		gBatches.startUp { iSame in
			FOREGROUND {
				gIsReadyToShowUI = true

				gLicense.setup()
				gTimers.startTimers(for: [.tStartup, .tLicense])
				gFavorites.setup { result in
					FOREGROUND {
						gFavorites.updateAllFavorites()
						gRefreshPersistentWorkMode()
						gRemoteStorage.recount()
						gRefreshCurrentEssay()

						gRefusesFirstResponder                = false
						gMainController?.helpButton?.isHidden = false
						gHasFinishedStartup                   = true
						gCurrentHelpMode                      = .proMode // so prepare strings will work correctly for all help modes
						gHelpWindowController                 = NSStoryboard(name: "Help", bundle: nil).instantiateInitialController() as? NSWindowController

						gTimers.startTimers(for: [.tCloudAvailable, .tRecount, .tSync])
						gRecents.push()
						gHereMaybe?.grab()

						if  gMigrationState == .normal, gWriteFiles {
							do {
								for dbID in kAllDatabaseIDs {
									try gFiles.writeToFile(from: dbID)
								}
							} catch {}
						}

						if  gIsStartupMode {
							gSetBigMapMode()
						}

						gSignal([.sSwap, .spMain, .spCrumbs, .sLaunchDone, .spPreferences])
						self.requestFeedback()
						gTimers.stopTimer (for: .tStartup)
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
								  "Thank you for downloading Seriously. Might you be interested in helping me beta test it, giving me feedback about it (good and bad)?\n\nYou can let me know at any time, by selecting Report an Issue under the Help menu (red arrow in image), or now, by clicking the Reply button below.",
								  "Reply in an email",
								  "Dismiss",
								  image) { status in
									if  status != .sNo {
										self.sendEmailBugReport()
									}
				}
			}
		}
	}

}
