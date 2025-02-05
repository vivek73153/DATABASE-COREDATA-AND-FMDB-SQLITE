//
//  LeftMenuViewController.swift
//
//  Created by Edwin Vermeer on 24-07-14.
//  Copyright (c) 2014 EVICT BV. All rights reserved.
//

import UIKit
import CloudKit
import RESideMenu

class LeftMenuViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, RESideMenuDelegate {
    
    var tableView: UITableView!
    var newsController: NewsViewController!
    var chatViewController : ChatViewController?
    
    // ------------------------------------------------------------------------
    // MARK: - Initialisation
    // ------------------------------------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupMenuTableViewLayout()

        connectToNews()
        
        connectToMessagesToMe()
        
        // Only already setup CloudKit connect's will receive these notifications (like the News above)
        EVCloudData.publicDB.fetchChangeNotifications()
    }
    
    func setupMenuTableViewLayout() {
        var rect = CGRectMake(0, ((self.view.frame.size.height - 54 * 5) / 2.0), self.view.frame.size.width, 54 * 5)
        self.tableView = UITableView(frame: rect)
        tableView.autoresizingMask = .FlexibleTopMargin | .FlexibleBottomMargin | .FlexibleWidth
        tableView.delegate = self
        tableView.dataSource = self
        tableView.opaque = false
        tableView.backgroundColor = UIColor.clearColor()
        tableView.backgroundView = nil
        tableView.separatorStyle = .None
        tableView.bounces = false
        tableView.scrollsToTop = false
        self.view.addSubview(self.tableView)
        
        newsController = self.storyboard?.instantiateViewControllerWithIdentifier("newsViewController") as? NewsViewController
        
    }
    
    deinit {
        EVCloudData.publicDB.disconnect("News_All")
        EVCloudData.publicDB.disconnect("Message_ToMe")
    }

    // ------------------------------------------------------------------------
    // MARK: - tableView - menu items
    // ------------------------------------------------------------------------

    
    var titles = ["Home", "News", "Settings", "Search", "Tests"]
    var images = ["IconHome", "IconProfile", "IconSettings", "IconEmpty", "IconEmpty"]
    var controllers = ["homeViewController", "newsViewController", "settingsViewController", "searchViewController", "testsViewController"]

    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        return 54
    }
    
    func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count
    }
    
    var cellIdentifier = "LeftMenuCell";
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell:UITableViewCell! = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as? UITableViewCell
        
        if cell == nil {
            cell = UITableViewCell(style: .Default, reuseIdentifier: cellIdentifier)
            cell.backgroundColor = UIColor.clearColor()
            cell.textLabel?.font = UIFont(name: "HelveticaNeue", size: 21)
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.highlightedTextColor = UIColor.lightGrayColor()
            cell.selectedBackgroundView = UIView()
        }
        
        cell.textLabel?.text = titles[indexPath.row]
        cell.imageView?.image = UIImage(named: images[indexPath.row])
        
        return cell;
    }
    
    func tableView(tableView: UITableView!, didSelectRowAtIndexPath indexPath: NSIndexPath!) {
        if indexPath.row < controllers.count {
            var controllerName:String = controllers[indexPath.row]
            
            var controller:UIViewController?
            if controllerName == "newsViewController" {
                controller = newsController
            } else {
                controller = self.storyboard?.instantiateViewControllerWithIdentifier(controllerName) as? UIViewController
            }
            if controller != nil {
                self.sideMenuViewController.setContentViewController(UINavigationController(rootViewController: controller!), animated: true)
            }
        }
        self.sideMenuViewController.hideMenuViewController()
    }

    func startChat(user:CKDiscoveredUserInfo) {
        startChat(user.userRecordID.recordName, firstName: user.firstName, lastName: user.lastName)
    }
    
    func startChat(recordId:String, firstName:String, lastName:String) {
        if self.chatViewController == nil {
            self.chatViewController = self.storyboard?.instantiateViewControllerWithIdentifier("chatViewController") as? ChatViewController
        }
        self.sideMenuViewController.setContentViewController(UINavigationController(rootViewController: self.chatViewController!), animated: true)
        if self.chatViewController!.chatWithId != recordId {
            chatViewController!.setContact(recordId, firstName: firstName, lastName: lastName)
        }
        self.sideMenuViewController.hideMenuViewController()    
    }

    
    // ------------------------------------------------------------------------
    // MARK: - News data and events
    // ------------------------------------------------------------------------
    
    func connectToNews() {
        
        EVCloudData.publicDB.connect(
            News()
            , predicate: NSPredicate(value: true)
            , filterId: "News_All"
            , configureNotificationInfo: { notificationInfo in
                //notificationInfo.alertBody = "News update"
                notificationInfo.shouldSendContentAvailable = true
                notificationInfo.alertLocalizationKey = "News: %1$@"
                notificationInfo.alertLocalizationArgs = ["Subject"]
                notificationInfo.shouldBadge = true
                // notificationInfo.alertActionLocalizationKey = "subscrioptionActionMessage"
                // notificationInfo.alertLaunchImage = "alertImage"
                // notificationInfo.soundName = "alertSound"
                // notificationInfo.desiredKeys = [""]
            }
            , completionHandler: { results in
                EVLog("There are \(results.count) existing news items")
            }, insertedHandler: {item in
                EVLog("New News item: '\(item.Subject)'")
                Helper.showStatus("New News item: '\(item.Subject)'")
            }, updatedHandler: {item, dataIndex in
                EVLog("Updated News item:'\(item.Subject)'")
                Helper.showStatus("Updated News item:'\(item.Subject)'")
            }, deletedHandler: {recordId, dataIndex in
                EVLog("News item was removed")
                Helper.showStatus("News item was removed")
            }, dataChangedHandler : {
                EVLog("Some News data was changed")
                self.newsController.tableView.reloadData()
            }, errorHandler: {error in
                EVLog("Could not load news: \(error.description)")
                Helper.showError("Could not load news: \(error.description)")
        })
    }
    
    
    func connectToMessagesToMe() {
        var recordIdMe = EVCloudData.publicDB.dao.activeUser.userRecordID.recordName
        EVCloudData.publicDB.connect(Message()
            , predicate: NSPredicate(format: "To_ID = %@", recordIdMe)!
            , filterId: "Message_ToMe"
            , configureNotificationInfo:{ notificationInfo in
                notificationInfo.alertLocalizationKey = "%1$@ %2$@ : %3$@"
                notificationInfo.alertLocalizationArgs = ["FromFirstName", "FromLastName", "Text"]
            }, completionHandler: { results in
                EVLog("Message to me results = \(results.count)")
            }, insertedHandler: { item in
                EVLog("Message to me inserted \(item)")
                self.startChat(item.From_ID, firstName: item.ToFirstName, lastName: item.ToLastName)
            }, updatedHandler: { item, dataIndex in
                EVLog("Message to me updated \(item)")
            }, deletedHandler: { recordId, dataIndex in
                EVLog("Message to me deleted : \(recordId)")
            }, errorHandler: { error in
                EVLog("Could not load messages: \(error.description)")
                Helper.showError("Could not load messages: \(error.description)")
        })
    }
    
    
}