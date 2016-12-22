//
//  AppDelegate.swift
//  ManNight
//
//  Created by Ross Huelin on 16/12/2016.
//  Copyright © 2016 filmstarr. All rights reserved.
//

import UIKit
import UserNotifications
import AirshipKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, UAPushNotificationDelegate {

    let baseUrl = "http://www.[Your Domain Here]".lowercased()
    let baseUrlShort = "www.[Your Domain Here]".lowercased()

    var backgroundTask = UIBackgroundTaskIdentifier()

    var window: UIWindow?
    var manNightViewController: ManNightViewController!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        //Setup view controller
        self.manNightViewController = self.window!.rootViewController! as! ManNightViewController
        self.manNightViewController.baseUrl = self.baseUrl
        self.manNightViewController.baseUrlShort = self.baseUrlShort
        
        //Setup Urban Airship
        self.setupUrbanAirship()

        //Register for Push Notitications
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in }
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let message = "Sorry, we couldn't register for push notifications at this time."
        let alert = UIAlertController(title: "Man Night", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in })
        self.manNightViewController.present(alert, animated: true){}
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        //Perform a background task when exiting the application
        let app = UIApplication.shared
        assert(self.backgroundTask == UIBackgroundTaskInvalid)
        self.backgroundTask = app.beginBackgroundTask(expirationHandler: {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                if self.backgroundTask != UIBackgroundTaskInvalid {
                    app.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = UIBackgroundTaskInvalid
                }
            })
        })

        DispatchQueue.global(qos: .default).async(execute: {() -> Void in
            
            //Update the application's icon badge
            self.updateApplicationIconBadge()

            DispatchQueue.main.async(execute: {() -> Void in
                if self.backgroundTask != UIBackgroundTaskInvalid {
                    app.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = UIBackgroundTaskInvalid
                }
            })
        })
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        self.updateInternalBadges()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if (shortcutItem.type == "UnreadTopics") {
            self.manNightViewController.gotoUrl(string: "\(self.baseUrl)/index.php?action=unread;all")
        } else if (shortcutItem.type == "RecentPosts") {
            self.manNightViewController.gotoUrl(string: "\(self.baseUrl)/index.php?action=recent")
        } else if (shortcutItem.type == "PersonalMessages") {
            self.manNightViewController.gotoUrl(string: "\(self.baseUrl)/index.php?action=pm")
        } else if (shortcutItem.type == "Home") {
            self.manNightViewController.gotoUrl(string: self.baseUrl)
        }
    }
    
    func setupUrbanAirship() {
        UAirship.takeOff()
        UAirship.push().userPushNotificationsEnabled = true
        UAirship.push().pushNotificationDelegate = self
        
        //Register action to handle push notification
        let customAction = UAAction(block: { (args: UAActionArguments, handler: UAActionCompletionHandler) -> Void in
            if args.situation == UASituation.launchedFromPush {
                if let topic = args.value as? String {
                    self.manNightViewController.gotoUrl(string: "\(self.baseUrl)/\(topic)")
                }
            }
            handler(UAActionResult.empty())
        })
        UAirship.shared().actionRegistry.register(customAction, name:"topic")
        
        //If we have a user alias update the registration
        if let alias = UserDefaults.standard.string(forKey: "alias") {
            if alias != "" {
                UAirship.push().alias = alias
                UAirship.push().updateRegistration()
            }
        }
    }
    
    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        //Urban airship in app alert functionality
        return [.alert, .sound]
    }
    
    func updateApplicationIconBadge() {
        let unreadItemsUrl = URL(string: "\(self.baseUrl)/index.php?action=unreadcount;all;")!
        let unreadItemsString = try! String(contentsOf: unreadItemsUrl)
        if let unreadItems = Int(unreadItemsString) {
            UIApplication.shared.applicationIconBadgeNumber = unreadItems
        }
    }
    
    func updateInternalBadges() {
        let webViewHtml = self.manNightViewController.webView!.stringByEvaluatingJavaScript(from: "document.body.innerHTML")!
        if webViewHtml.contains("id=\"toolbar\"") {
            DispatchQueue.global(qos: .default).async(execute: {() -> Void in
                var internalBadgeDetails = self.getInternalBadgeDetails().components(separatedBy: ",")
                if internalBadgeDetails.count == 2 {
                    let newMessagesCountString = internalBadgeDetails[0]
                    let newPostsCountString = internalBadgeDetails[1]
                    if let newMessagesCount = Int(newMessagesCountString) {
                        if let newPostsCount = Int(newPostsCountString) {
                            DispatchQueue.main.async(execute: {() -> Void in
                                self.setInternalBadges(newMessagesCount: newMessagesCount, newPostsCount: newPostsCount)
                            })
                        
                        }
                    }
                }
            })
        }
    }
    
    func getInternalBadgeDetails() -> String {
        let urlNewPosts = URL(string: "\(self.baseUrl)/index.php?action=unreadcount;all;countString;")
        do {
            return try String(contentsOf: urlNewPosts!)
        }
        catch {
            return ""
        }
    }
    
    func setInternalBadges(newMessagesCount: Int, newPostsCount: Int) {
        let webView = self.manNightViewController.webView!
        
        //Set count bages
        webView.stringByEvaluatingJavaScript(from: "$('.unread-messages').last().html('\(newMessagesCount)');")
        webView.stringByEvaluatingJavaScript(from: "$('.unread-posts').last().html('\(newPostsCount)');")

        //Show or hide count badges
        if newMessagesCount != 0 {
            webView.stringByEvaluatingJavaScript(from: "$('.unread-messages').last().show();")
        } else {
            webView.stringByEvaluatingJavaScript(from: "$('.unread-messages').last().hide();")
        }
        
        if newPostsCount != 0 {
            webView.stringByEvaluatingJavaScript(from: "$('.unread-posts').last().show();")
        } else {
            webView.stringByEvaluatingJavaScript(from: "$('.unread-posts').last().hide();")
        }
    }
}
