//
//  DiscoveryWebViewHelper.swift
//  edX
//
//  Created by Akiva Leffert on 11/9/15.
//  Copyright © 2015-2016 edX. All rights reserved.
//

import UIKit
import WebKit

fileprivate enum QueryParameterKeys {
    static let searchQuery = "search_query"
    static let subject = "subject"
}

@objc enum DiscoveryType: Int {
    case course
    case program
    case degree
}

class DiscoveryWebViewHelper: NSObject {
    
    typealias Environment = OEXConfigProvider & OEXSessionProvider & OEXStylesProvider & OEXRouterProvider & OEXAnalyticsProvider & OEXSessionProvider
    fileprivate let environment: Environment?
    weak var delegate: WebViewNavigationDelegate?
    fileprivate let contentView = UIView()
    fileprivate let webView = WKWebView()
    fileprivate let searchBar = UISearchBar()
    fileprivate lazy var subjectsController: PopularSubjectsViewController = {
        let controller = PopularSubjectsViewController()
        controller.delegate = self
        return controller
    }()
    fileprivate var loadController = LoadStateViewController()
    fileprivate let discoveryType: DiscoveryType
    
    fileprivate var request: URLRequest? = nil
    @objc var baseURL: URL?
    fileprivate let searchQuery:String?
    let bottomBar: UIView?
    private let searchBarEnabled: Bool
    private let showSubjects: Bool
    private var urlObservation: NSKeyValueObservation?
    private var subjectDiscoveryEnabled: Bool = false
    private var subjectsViewHeight: CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? 145 : 125
    }
    fileprivate var params: [String: String]? {
        return (webView.url as NSURL?)?.oex_queryParameters() as? [String : String]
    }
    
    private var bottomSpace: CGFloat {
        //TODO: this should be the height of bottomBar but for now giving it static value as the NSCopying making new object's frame as zero
        return 90
    }
    
    @objc convenience init(environment: Environment?, delegate: WebViewNavigationDelegate?, bottomBar: UIView?, discoveryType: DiscoveryType = .course) {
        self.init(environment: environment, delegate: delegate, bottomBar: bottomBar, showSearch: false, searchQuery: nil, showSubjects: false, discoveryType: discoveryType)
    }
    
    @objc init(environment: Environment?, delegate: WebViewNavigationDelegate?, bottomBar: UIView?, showSearch: Bool, searchQuery: String?, showSubjects: Bool = false, discoveryType: DiscoveryType = .course) {
        self.environment = environment
        self.delegate = delegate
        self.bottomBar = bottomBar
        self.searchQuery = searchQuery
        self.showSubjects = showSubjects
        self.discoveryType = discoveryType
        let discoveryConfig = discoveryType == .program ? environment?.config.discovery.program : environment?.config.discovery.course
        searchBarEnabled = (discoveryConfig?.webview.searchEnabled ?? false) && showSearch
        super.init()
        searchBarPlaceholder()
        webView.navigationDelegate = self
        webView.scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
        webView.accessibilityIdentifier = discoveryType == .course ? "find-courses-webview" : "find-programs-webview"
        guard let container = delegate?.webViewContainingController() else { return }
        container.view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(container.safeEdges)
        }
        loadController.setupInController(controller: container, contentView: contentView)
        refreshView()
    }
    
    @objc func refreshView() {
        guard let container = delegate?.webViewContainingController() else { return }
        contentView.subviews.forEach { $0.removeFromSuperview() }
        let isUserLoggedIn = environment?.session.currentUser != nil

        subjectDiscoveryEnabled = (environment?.config.discovery.course.webview.subjectFilterEnabled ?? false) && isUserLoggedIn && showSubjects && discoveryType == .course

        var topConstraintItem: ConstraintItem = contentView.snp.top
        if searchBarEnabled {
            searchBar.delegate = self
            contentView.addSubview(searchBar)

            searchBar.snp.makeConstraints{ make in
                make.leading.equalTo(contentView)
                make.trailing.equalTo(contentView)
                make.top.equalTo(contentView)
            }
            topConstraintItem = searchBar.snp.bottom
        }

        if subjectDiscoveryEnabled {
            container.addChild(subjectsController)
            contentView.addSubview(subjectsController.view)
            subjectsController.didMove(toParent: container)
            subjectsController.view.snp.makeConstraints { make in
                make.leading.equalTo(contentView).offset(StandardHorizontalMargin)
                make.trailing.equalTo(contentView)
                make.top.equalTo(topConstraintItem)
                make.height.equalTo(subjectsViewHeight)
            }

            topConstraintItem = subjectsController.view.snp.bottom
        }

        contentView.addSubview(webView)
        if let bar = bottomBar, !isUserLoggedIn {
            contentView.addSubview(bar)
            bar.snp.makeConstraints { make in
                make.leading.equalTo(contentView)
                make.trailing.equalTo(contentView)
                make.bottom.equalTo(contentView)
            }
        }

        webView.snp.makeConstraints { make in
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
            make.bottom.equalTo(contentView)
            make.top.equalTo(topConstraintItem)
            if !isUserLoggedIn {
                make.bottom.equalTo(contentView).offset(-bottomSpace)
            }
            else {
                make.bottom.equalTo(contentView)
            }
        }

        addObserver()
    }
    
    private func searchBarPlaceholder() {
        switch discoveryType {
        case .course:
            searchBar.placeholder = Strings.searchCoursesPlaceholderText
            break
        case .program:
            searchBar.placeholder = Strings.searchProgramsPlaceholderText
            break
        case .degree:
            searchBar.placeholder = Strings.searchDegreesPlaceholderText
            break
        default:
            break
        }
    }
    
    private func addObserver() {
        // Add URL change oberver on webview, so URL change of webview can be tracked and handled.
        urlObservation = webView.observe(\.url, changeHandler: { [weak self] (webView, change) in
            self?.handleURLChangeNotification()
        })
        
        NotificationCenter.default.oex_addObserver(observer: self, name: NOTIFICATION_DYNAMIC_TEXT_TYPE_UPDATE) { (_, observer, _) in
            observer.reload()
        }
    }
    
    private func handleURLChangeNotification() {
        switch discoveryType {
        case .course:
            if subjectDiscoveryEnabled {
                updateSubjectsVisibility()
            }
            break
        case .program:
            if !URLHasSearchFilter {
                searchBar.text = nil
            }
            break
        default:
            break
        }
    }
    
    private var URLHasSearchFilter: Bool {
        guard let URL = webView.url?.absoluteString else { return false }
        
        return URL.contains(find: QueryParameterKeys.searchQuery)
    }

    private func reload() {
        guard let URL = webView.url, !webView.isLoading else { return }

        loadController.state = .Initial
        loadRequest(withURL: URL)
    }
    
    @objc func updateSubjectsVisibility() {
        if contentView.subviews.contains(subjectsController.view) {
            let hideSubjectsView = isiPhoneAndVerticallyCompact || isWebViewQueriedSubject
            let height: CGFloat = hideSubjectsView ? 0 : subjectsViewHeight
            subjectsController.view.snp.remakeConstraints { make in
                make.leading.equalTo(contentView).offset(StandardHorizontalMargin)
                make.trailing.equalTo(contentView)
                make.top.equalTo(searchBarEnabled ? searchBar.snp.bottom : contentView)
                make.height.equalTo(height)
            }
            subjectsController.view.isHidden = hideSubjectsView
        }
    }
    
    private var isiPhoneAndVerticallyCompact: Bool {
        guard let container = delegate?.webViewContainingController() else { return false }
        return container.isVerticallyCompact() && UIDevice.current.userInterfaceIdiom == .phone
    }
    
    private var isWebViewQueriedSubject: Bool {
        guard let url = webView.url?.absoluteString else { return false }
        return url.contains(find: "\(QueryParameterKeys.subject)=")
    }

    private var courseInfoTemplate : String {
        return environment?.config.discovery.course.webview.detailTemplate ?? ""
    }
    
    var isWebViewLoaded : Bool {
        return self.loadController.state.isLoaded
    }

    @objc public func load(withURL url: URL) {
        var discoveryURL = url
        
        if let baseURL = baseURL, let searchQuery = searchQuery {
            searchBar.text = searchQuery
            var params = self.params ?? [:]
            set(value: searchQuery, for: QueryParameterKeys.searchQuery, in: &params)
            if let url = DiscoveryWebViewHelper.buildQuery(baseURL: baseURL.URLString, params: params) {
                discoveryURL = url
            }
        }

        loadRequest(withURL: discoveryURL)
    }
    
    fileprivate func set(value: String, for key: String, in params: inout [String: String]) {
        params[key] = value.addingPercentEncodingForRFC3986
    }

    fileprivate func loadRequest(withURL url: URL) {
        let request = URLRequest(url: url)
        webView.loadRequest(request)
        self.request = request
    }

    fileprivate func showError(error : NSError) {
        let buttonInfo = MessageButtonInfo(title: Strings.reload) {[weak self] in
            if let request = self?.request {
                self?.webView.load(request as URLRequest)
                self?.loadController.state = .Initial
            }
        }
        self.loadController.state = LoadState.failed(error: error, buttonInfo: buttonInfo)
    }
    
    deinit {
        urlObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension DiscoveryWebViewHelper: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        let capturedLink = navigationAction.navigationType == .linkActivated && (delegate?.webView(webView, shouldLoad: request) ?? true)
        
        let outsideLink = (request.mainDocumentURL?.host != self.request?.url?.host)
        if let URL = request.url, outsideLink || capturedLink {
            UIApplication.shared.openURL(URL)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.loadController.state = .Loaded
        
        //Setting webView accessibilityValue for testing
        webView.evaluateJavaScript("document.getElementsByClassName('course-card')[0].innerText",
                                   completionHandler: { [weak self] (result: Any?, error: Error?) in
                                    
                                    if (error == nil) {
                                        self?.webView.accessibilityValue = self?.discoveryType ?? .course == .course ? "findCoursesLoaded" : "findProgramsLoaded"
                                    }
        })
        if let bar = bottomBar {
            bar.superview?.bringSubviewToFront(bar)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error: error as NSError)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error: error as NSError)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let credential = environment?.config.URLCredentialForHost(challenge.protectionSpace.host as NSString) {
            completionHandler(.useCredential, credential)
        }
        else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

extension DiscoveryWebViewHelper: SubjectsViewControllerDelegate, PopularSubjectsViewControllerDelegate {
    
    private func filterCourses(with subject: Subject) {
        guard let baseURL = baseURL,
            var params = params else { return }
        set(value: subject.filter, for: QueryParameterKeys.subject, in: &params)
        environment?.analytics.trackSubjectDiscovery(subjectID: subject.filter)
        if let url = DiscoveryWebViewHelper.buildQuery(baseURL: baseURL.URLString, params: params) {
            loadController.state = .Initial
            loadRequest(withURL: url)
        }
    }
    
    private func viewAllSubjects() {
        guard let container = delegate?.webViewContainingController() else { return }
        environment?.analytics.trackSubjectDiscovery(subjectID: "View All Subjects")
        environment?.router?.showAllSubjects(from: container, delegate: self)
    }
    
    func popularSubjectsViewController(_ controller: PopularSubjectsViewController, didSelect subject: Subject) {
        filterCourses(with: subject)
    }
    
    func didSelectViewAllSubjects(_ controller: PopularSubjectsViewController) {
        viewAllSubjects()
    }
    
    func subjectsViewController(_ controller: SubjectsViewController, didSelect subject: Subject) {
        filterCourses(with: subject)
    }
    
}

extension DiscoveryWebViewHelper: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard discoveryType == .program,
            searchText.isEmpty,
            webView.url != baseURL,
            let baseURL = baseURL else { return }
        loadRequest(withURL: baseURL)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        var action = "landing_screen"
        if let _ = environment?.session.currentUser {
            action = "discovery_tab"
        }
        environment?.analytics.trackCourseSearch(search: searchBar.text ?? "", action: action)
        guard let searchText = searchBar.text,
            let baseURL = baseURL,
            var params = params else { return }
        set(value: searchText, for: QueryParameterKeys.searchQuery, in: &params)
        if let URL = DiscoveryWebViewHelper.buildQuery(baseURL: baseURL.URLString, params: params) {
            loadController.state = .Initial
            loadRequest(withURL: URL)
        }
    }
    
    static func buildQuery(baseURL: String, params: [String: String]) -> URL? {
        var query = baseURL
        for param in params {
            let join = query.contains("?") ? "&" : "?"
            query = query + join + param.key + "=" + param.value
        }
        
        return URL(string: query)
    }
    
}

extension DiscoveryWebViewHelper {
    @objc var t_webView: WKWebView {
        return webView
    }
}

extension String {
    //  Section 2.3 of RFC 3986 lists the characters that you should not percent encode as they have no special meaning in a URL:
    //
    //  ALPHA / DIGIT / “-” / “.” / “_” / “~”
    //
    //  Section 3.4 also explains that since a query will often itself include a URL it is preferable to not percent encode the slash (“/”) and question mark (“?”)
    
    var addingPercentEncodingForRFC3986: String {
        let unreserved = "-._~/?"
        var allowed: CharacterSet = .alphanumerics
        allowed.insert(charactersIn: unreserved)
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
    
}
