//
//  ManNightViewController.swift
//  ManNight
//
//  Created by Ross Huelin on 16/12/2016.
//  Copyright © 2016 filmstarr. All rights reserved.
//

import UIKit
import AirshipKit

class ManNightViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet var webView: UIWebView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var cancelLoadingButton: UIButton!
    
    var refreshControl: UIRefreshControl!
    var documentController: UIDocumentInteractionController?
    var baseUrl: String?
    var baseUrlShort: String?
    
    override func viewDidLoad() {

        super.viewDidLoad()

        self.webView.delegate = self

        //Hide webview until loaded
        self.cancelLoadingButton.isHidden = false
        self.activityIndicator.startAnimating()
        self.webView.isHidden = true
        
        //Load the main forum page
        self.gotoUrl(string: self.baseUrl!)
        
        //Add refresh control
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: #selector(self.refresh), for: .valueChanged)
        self.webView.scrollView.insertSubview(refreshControl, at: 0)
        
        //Round button corners
        self.cancelLoadingButton.layer.cornerRadius = 25
        self.cancelLoadingButton.clipsToBounds = true
    }

    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        let url = request.url!
        let urlAddress = url.absoluteString.lowercased()
        
        //User logging in. Get user id and set as push notification alias.
        if urlAddress.contains("action=login") && urlAddress.contains("member=") {
            let range = urlAddress.range(of:"(?<=member=)[^.]+", options:.regularExpression)
            var alias = urlAddress.substring(with: range!)
            let range2 = alias.range(of: "[^.]+(?=;)", options:.regularExpression)
            if range2 != nil {
                alias = alias.substring(with: range2!)
            }
            
            if alias != "" {
                //Save user alias
                UserDefaults.standard.set(alias, forKey: "alias")
                UserDefaults.standard.synchronize()

                //Register with Urban Airship
                UAirship.push().alias = alias
                UAirship.push().updateRegistration()
            }
        }
        
        //Open all URLs if they are part of the forum as long as it's not a file
        if navigationType == .linkClicked {
            if urlAddress.contains(self.baseUrlShort!) {
                if let query = url.query {
                    if query.contains("openFileInNewWindow=") {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        return false
                    }
                }
                return true
            } else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return false
            }
        }
        return true
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        self.webView.isHidden = false
        self.stoppedLoading()
        
        if (error as NSError).code != NSURLErrorCancelled {
            let message = "Sorry, we couldn't connect to the forum at this time."
            let alert = UIAlertController(title: "Man Night", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in })
            self.present(alert, animated: true){}
        }
    }

    func webViewDidFinishLoad(_ webView: UIWebView)
    {
        self.webView.isHidden = false
        self.stoppedLoading()
    }
    
    override var shouldAutorotate : Bool {
        return true
    }
    
    @IBAction func cancelLoading(_ sender: Any) {
        self.webView.stopLoading()
        self.stoppedLoading()
    }
    
    func gotoUrl(string: String) {
        let webViewHtmlHead = self.webView.stringByEvaluatingJavaScript(from: "document.head.innerHTML")!
        if !webViewHtmlHead.contains("jquery.mobile") {
            let url = URL(string: string)!
            self.webView.loadRequest(URLRequest(url: url))
        } else {
            _ = self.webView.stringByEvaluatingJavaScript(from: "$.mobile.changePage('\(string)', { reloadPage : true })")!
        }
    }
    
    func refresh() {
        self.cancelLoadingButton.isHidden = false
        self.activityIndicator.startAnimating()

        if let url = self.webView.request?.url {
            //Refresh the current page
            if url.absoluteString.lowercased().contains(self.baseUrlShort!) {
                self.webView.reload()
                return
            }
        }

        //No current page so just load the base URL
        self.gotoUrl(string: self.baseUrl!)
    }
    
    func stoppedLoading() {
        self.activityIndicator.stopAnimating()
        self.cancelLoadingButton.isHidden = true
        self.refreshControl.endRefreshing()
    }
}
