//
//  AppDelegate.swift
//  GenericApp
//
//  Created by Michael Rademaker on 17/06/2020.
//  Copyright © 2020 Remote. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import IQKeyboardManagerSwift
import ORLib

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, URLSessionDelegate {

    var window: UIWindow?
    let gcmMessageIDKey = "gcm.message_id"

    var geofenceProvider : GeofenceProvider?
    var fcmToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor(named: "or_green") as Any], for: .normal)
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(named: "or_green") as Any]
        UIBarButtonItem.appearance().tintColor = UIColor(named: "or_green")
        
        IQKeyboardManager.shared.enable = true

        UNUserNotificationCenter.current().delegate = self
        // if the app was launched because of geofencing

        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let fileName = "\(Date()).log"
        let logFilePath = (documentsDirectory as NSString).appendingPathComponent(fileName)
        freopen(logFilePath.cString(using: String.Encoding.ascii)!, "a+", stderr)

        if launchOptions?[UIApplication.LaunchOptionsKey.location] != nil {
            NSLog("%@", "App started from location update")
            // create new GeofenceProvider which creates a CLLocationManager that will receive the location update
            geofenceProvider = GeofenceProvider()
            if CLLocationManager.authorizationStatus() == .authorizedAlways {
                geofenceProvider?.startMonitoringSignificantLocationChanges()
            }
        } else if let remoteNotifcation = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            NSLog("%@", "App started from remote notification")
            if let action = remoteNotifcation[DefaultsKey.actionKey] as? String {
                if action == Actions.geofenceRefresh {
                    geofenceProvider = GeofenceProvider()
                    geofenceProvider?.refreshGeofences()
                    if CLLocationManager.authorizationStatus() == .authorizedAlways {
                        geofenceProvider?.startMonitoringSignificantLocationChanges()
                    }
                }
            }
        } else {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
        }
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "settings" {
            let userDefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement)
            userDefaults?.removeObject(forKey: DefaultsKey.realmKey)
            (self.window?.rootViewController as? SplashViewController)?.displaySettings = true
            self.window?.rootViewController?.dismiss(animated: false)
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
       
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let action = userInfo[DefaultsKey.actionKey] as? String {
            if action == Actions.geofenceRefresh {
                if let controllerGeofenceProvider = (self.window?.topController as? ORViewcontroller)?.geofenceProvider {

                    controllerGeofenceProvider.refreshGeofences()
                } else if let delegateGeofenceProvider = geofenceProvider {
                    delegateGeofenceProvider.refreshGeofences()
                } else {
                    geofenceProvider = GeofenceProvider()
                    geofenceProvider!.refreshGeofences()
                }
            } else if action == Actions.store {
                if let data = userInfo[DefaultsKey.dataKey] as? [String: String] {
                    if let key = data["key"] {
                        if let storageProvider = (self.window?.topController as? ORViewcontroller)?.storageProvider {
                            storageProvider.store(key: key, data: data["value"])
                        } else {
                            let storageProvider = StorageProvider()
                            storageProvider.store(key: key, data: data["value"])
                        }
                    }
                }
            }
        }

        if let notificationIdString = userInfo[ActionType.notificationId] as? String, let notificationId = Int64(notificationIdString) {
            if let defaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement), let consoleId = defaults.string(forKey: GeofenceProvider.consoleIdKey) {
                ORNotificationResource.sharedInstance.notificationDelivered(notificationId: notificationId, targetId: consoleId)
            }
        }
        completionHandler(UIBackgroundFetchResult.newData)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

extension AppDelegate : UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        var notificationId : Int64? = nil

        if let notificationIdString = userInfo[ActionType.notificationId] as? String{
            notificationId = Int64(notificationIdString)
        }
        if let notiId = notificationId, let defaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement), let consoleId = defaults.string(forKey: GeofenceProvider.consoleIdKey) {
            ORNotificationResource.sharedInstance.notificationDelivered(notificationId: notiId, targetId: consoleId)
        }

        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo
        var notificationId : Int64? = nil
        var consoleId : String?
        var project: ProjectConfig?

        if let notificationIdString = userInfo[ActionType.notificationId] as? String{
            notificationId = Int64(notificationIdString)
        }
        
        if let userDefaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement) {
            consoleId = userDefaults.string(forKey: GeofenceProvider.consoleIdKey) // TODO: geofence provider should also be adapted to store "per project"
            
            let selectedProjectId = userDefaults.string(forKey: DefaultsKey.projectKey)
            if let projectsData = userDefaults.data(forKey: DefaultsKey.projectsConfigurationKey) {
                let projects = (try? JSONDecoder().decode([ProjectConfig].self, from: projectsData)) ?? []
                project = projects.first(where:{ $0.id == selectedProjectId })
            }
        }

        NSLog("%@", "Action chosen: \(response.actionIdentifier)")

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if let urlTo = userInfo[ActionType.appUrl] as? String, !urlTo.isEmpty {
                var urlRequest: URL?
                if urlTo.hasPrefix("http") || urlTo.hasPrefix("https") {
                    urlRequest = URL(string:urlTo)
                } else {
                    if let url = project?.baseURL {
                        urlRequest = URL(string: "\(url)/console/\(urlTo)")
                    }
                }
                if let url = urlRequest{
                    if let InBrowser = userInfo[ActionType.openInBrowser] as? Bool, InBrowser {
                        NSLog("%@", " in browser: \(url)")
                        UIApplication.shared.open(url)
                    } else {
                        NSLog("%@", " in app: \(url)")
                        (self.window?.topController as? ORViewcontroller)?.loadURL(url:url)
                    }
                }
            }
        case UNNotificationDismissActionIdentifier,
             "declineAction":
            if let notiId = notificationId, let conId = consoleId {
                ORNotificationResource.sharedInstance.notificationAcknowledged(notificationId: notiId, targetId: conId, acknowledgement: response.actionIdentifier)
            }
        default :
            if let notiId = notificationId, let conId = consoleId {
                ORNotificationResource.sharedInstance.notificationAcknowledged(notificationId: notiId, targetId: conId, acknowledgement: response.actionIdentifier)
            }
            if let buttonsString = userInfo[DefaultsKey.buttonsKey] as? String {
                if let buttonsData = buttonsString.data(using: .utf8) {
                    if let buttons = try? JSONDecoder().decode([ORPushNotificationButton].self, from: buttonsData) {
                        for button in buttons {
                            if button.title == response.actionIdentifier {
                                if let action = button.action {
                                    var urlRequest: URL?
                                    if action.url.hasPrefix("http") || action.url.hasPrefix("https") {
                                        urlRequest = URL(string:action.url)
                                    } else {
                                        if let url = project?.baseURL {
                                            urlRequest = URL(string: "\(url)/console/\(action.url)")
                                        }
                                    }
                                    if let url = urlRequest {
                                        if action.silent {
                                            let request = NSMutableURLRequest(url: url)
                                            request.httpMethod = action.httpMethod ?? "GET"
                                            if let body = action.data {
                                                request.httpBody = body.data(using: .utf8)
                                                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                                            }
                                            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue : nil)
                                            let reqDataTask = session.dataTask(with: request as URLRequest, completionHandler:{ data, response, error in
                                                if (error != nil) {
                                                    NSLog("error %@", (error! as NSError).localizedDescription)
                                                }
                                            })
                                            reqDataTask.resume()
                                        } else if action.openInBrowser {
                                            NSLog("%@", " in browser: \(url)")
                                            UIApplication.shared.open(url)
                                        } else {
                                            NSLog("%@", " in app: \(url)")
                                            (self.window?.topController as? ORViewcontroller)?.loadURL(url:url)
                                        }
                                    }
                                }
                                break
                            }
                        }
                    }
                }
            }
        }
        completionHandler()
    }
}

extension AppDelegate : MessagingDelegate {
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        if let defaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement){
            defaults.set(fcmToken, forKey: DefaultsKey.fcmTokenKey)
            defaults.synchronize()
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            print("Firebase registration token: \(token)")
            if let defaults = UserDefaults(suiteName: DefaultsKey.groupEntitlement) {
                defaults.set(token, forKey: DefaultsKey.fcmTokenKey)
                defaults.synchronize()
            }
        } else {
            print("No fcm token")
        }
    }
}
