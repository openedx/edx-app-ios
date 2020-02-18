//
//  AuthenticatedWebViewController.swift
//  edX
//
//  Created by Akiva Leffert on 5/26/15.
//  Copyright (c) 2015 edX. All rights reserved.
//

import UIKit
import WebKit

class HeaderViewInsets : ContentInsetsSource {
    weak var insetsDelegate : ContentInsetsSourceDelegate?
    
    var view : UIView?
    
    var currentInsets : UIEdgeInsets {
        return UIEdgeInsets(top : view?.frame.size.height ?? 0, left : 0, bottom : 0, right : 0)
    }
    
    var affectsScrollIndicators : Bool {
        return true
    }
}

private protocol WebContentController {
    var view : UIView {get}
    var scrollView : UIScrollView {get}
    var isLoading: Bool {get}
    
    var alwaysRequiresOAuthUpdate : Bool { get}
    
    var initialContentState : AuthenticatedWebViewController.State { get }
    
    func loadURLRequest(request : NSURLRequest)
    func resetState()
}

@objc protocol WebViewNavigationDelegate: class {
    func webView(_ webView: WKWebView, shouldLoad request: URLRequest) -> Bool
    func webViewContainingController() -> UIViewController
}

// A class should implement AlwaysRequireAuthenticationOverriding protocol if it always require authentication.
protocol AuthenticatedWebViewControllerRequireAuthentication {
}

protocol AuthenticatedWebViewControllerDelegate {
    func authenticatedWebViewController(authenticatedController: AuthenticatedWebViewController, didFinishLoading webview: WKWebView)
}

private class WKWebViewContentController : WebContentController {
    fileprivate let webView = WKWebView(frame: CGRect.zero)
    
    var view : UIView {
        return webView
    }
    
    var scrollView : UIScrollView {
        return webView.scrollView
    }
    
    func loadURLRequest(request: NSURLRequest) {
        // If the view initialize before registering userAgent the request goes without the required userAgent,
        // to solve this we are setting customeUserAgent here.
        if let userAgent = UserDefaults.standard.string(forKey: "UserAgent"), webView.customUserAgent?.isEmpty ?? false {
            webView.customUserAgent = userAgent
        }
        
        webView.loadRequest(request as URLRequest)
    }
    
    func resetState() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }
    
    var alwaysRequiresOAuthUpdate : Bool {
        return false
    }
    
    var initialContentState : AuthenticatedWebViewController.State {
        return AuthenticatedWebViewController.State.LoadingContent
    }

    var isLoading: Bool {
        return webView.isLoading
    }
}

private let OAuthExchangePath = "/oauth2/login/"

// Allows access to course content that requires authentication.
// Forwarding our oauth token to the server so we can get a web based cookie
public class AuthenticatedWebViewController: UIViewController, WKNavigationDelegate {
    
    fileprivate enum State {
        case CreatingSession
        case LoadingContent
        case NeedingSession
    }

    public typealias Environment = OEXAnalyticsProvider & OEXConfigProvider & OEXSessionProvider & ReachabilityProvider
    var delegate: AuthenticatedWebViewControllerDelegate?
    internal let environment : Environment
    private let loadController : LoadStateViewController
    private let insetsController : ContentInsetsController
    private let headerInsets : HeaderViewInsets
    weak var webViewDelegate: WebViewNavigationDelegate?
    
    private lazy var webController : WebContentController = {
        let controller = WKWebViewContentController()
        controller.webView.navigationDelegate = self
        return controller
    
    }()
    
    var scrollView: UIScrollView {
        return webController.scrollView
    }
    
    private var state = State.CreatingSession
    
    private var contentRequest : NSURLRequest? = nil
    var currentUrl: NSURL? {
        return contentRequest?.url as NSURL?
    }
    
    public func setLoadControllerState(withState state: LoadState) {
        loadController.state = state
    }
    
    public init(environment : Environment) {
        self.environment = environment
        
        loadController = LoadStateViewController()
        insetsController = ContentInsetsController()
        headerInsets = HeaderViewInsets()
        insetsController.addSource(source: headerInsets)
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        webController.view.accessibilityIdentifier = "AuthenticatedWebViewController:authenticated-web-view"
        addObservers()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // Prevent crash due to stale back pointer, since WKWebView's UIScrollView apparently doesn't
        // use weak for its delegate
        webController.scrollView.delegate = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        state = webController.initialContentState
        view.addSubview(webController.view)
        webController.view.snp.makeConstraints { make in
            make.edges.equalTo(safeEdges)
        }
        loadController.setupInController(controller: self, contentView: webController.view)
        webController.view.backgroundColor = OEXStyles.shared().standardBackgroundColor()
        webController.scrollView.backgroundColor = OEXStyles.shared().standardBackgroundColor()
        insetsController.setupInController(owner: self, scrollView: webController.scrollView)
        
        if let request = contentRequest {
            loadRequest(request: request)
        }
    }

    private func addObservers() {
        NotificationCenter.default.oex_addObserver(observer: self, name: NOTIFICATION_DYNAMIC_TEXT_TYPE_UPDATE) { (_, observer, _) in
            observer.reload()
        }
    }

    public func reload() {
        guard let request = contentRequest, !webController.isLoading else { return }

        state = .LoadingContent
        loadRequest(request: request)
    }
    
    private func resetState() {
        loadController.state = .Initial
        state = .CreatingSession
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        if view.window == nil {
            webController.resetState()
        }
        resetState()
    }
    
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        insetsController.updateInsets()
    }
    
    public func showError(error : NSError?, icon : Icon? = nil, message : String? = nil) {
        let buttonInfo = MessageButtonInfo(title: Strings.reload) {[weak self] in
            if let request = self?.contentRequest, self?.environment.reachability.isReachable() ?? false {
                self?.loadController.state = .Initial
                self?.webController.loadURLRequest(request: request)
            }
        }
        loadController.state = LoadState.failed(error: error, icon: icon, message: message, buttonInfo: buttonInfo)
        refreshAccessibility()
    }
    
    // MARK: Header View
    
    var headerView : UIView? {
        get {
            return headerInsets.view
        }
        set {
            headerInsets.view?.removeFromSuperview()
            headerInsets.view = newValue
            if let headerView = newValue {
                webController.view.addSubview(headerView)
                headerView.snp.makeConstraints { make in
                    make.top.equalTo(safeTop)
                    make.leading.equalTo(webController.view)
                    make.trailing.equalTo(webController.view)
                }
                webController.view.setNeedsLayout()
                webController.view.layoutIfNeeded()
            }
        }
    }
    
    private func loadOAuthRefreshRequest() {
        if let hostURL = environment.config.apiHostURL() {
            let URL = hostURL.appendingPathComponent(OAuthExchangePath)
            let exchangeRequest = NSMutableURLRequest(url: URL)
            exchangeRequest.httpMethod = HTTPMethod.POST.rawValue
            
            for (key, value) in self.environment.session.authorizationHeaders {
                exchangeRequest.addValue(value, forHTTPHeaderField: key)
            }
            self.webController.loadURLRequest(request: exchangeRequest)
        }
    }
    
    private func refreshAccessibility() {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
        }
    }
    
    // MARK: Request Loading
    
    public func loadRequest(request : NSURLRequest) {
        contentRequest = request
        loadController.state = .Initial
        state = webController.initialContentState
        
        let isAuthRequestRequire = ((parent as? AuthenticatedWebViewControllerRequireAuthentication) != nil) ? true: webController.alwaysRequiresOAuthUpdate

        if isAuthRequestRequire {
            self.state = State.CreatingSession
            loadOAuthRefreshRequest()
        }
        else {
            webController.loadURLRequest(request: request)
        }
    }
    
    // MARK: WKWebView delegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch navigationAction.navigationType {
        case .linkActivated, .formSubmitted, .formResubmitted:
            if let URL = navigationAction.request.url, webViewDelegate?.webView(webView, shouldLoad: navigationAction.request) ?? true {
                UIApplication.shared.openURL(URL)
            }
            decisionHandler(.cancel)
        default:
            decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
        if let httpResponse = navigationResponse.response as? HTTPURLResponse, let statusCode = OEXHTTPStatusCode(rawValue: httpResponse.statusCode), let errorGroup = statusCode.errorGroup, state == .LoadingContent {
            
            switch errorGroup {
            case HttpErrorGroup.http4xx:
                state = .NeedingSession
                break
            case HttpErrorGroup.http5xx:
                loadController.state = LoadState.failed()
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
        
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        switch state {
        case .CreatingSession:
            if let request = contentRequest {
                state = .LoadingContent
                webController.loadURLRequest(request: request)
                
            }
            else {
                loadController.state = LoadState.failed()
            }
        case .LoadingContent:
            //The class which will implement this protocol method will be responsible to set the loadController state as Loaded
            if delegate?.authenticatedWebViewController(authenticatedController: self, didFinishLoading: webView) == nil {
              loadController.state = .Loaded
            }
        case .NeedingSession:
            state = .CreatingSession
            loadOAuthRefreshRequest()
        }
        
        refreshAccessibility()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showError(error: error as NSError?)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
          showError(error: error as NSError?)
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Don't use basic auth on exchange endpoint. That is explicitly non protected
        // and it screws up the authorization headers
        if let URL = webView.url, ((URL.absoluteString.hasSuffix(OAuthExchangePath)) != false) {
            completionHandler(.performDefaultHandling, nil)
        }
        else if let credential = environment.config.URLCredentialForHost(challenge.protectionSpace.host as NSString)  {
            completionHandler(.useCredential, credential)
        }
        else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
