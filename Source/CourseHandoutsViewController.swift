//
//  CourseHandoutsViewController.swift
//  edX
//
//  Created by Ehmad Zubair Chughtai on 26/06/2015.
//  Copyright (c) 2015 edX. All rights reserved.
//

import UIKit
import WebKit

public class CourseHandoutsViewController: OfflineSupportViewController, LoadStateViewReloadSupport, InterfaceOrientationOverriding, ScrollableDelegateProvider {
    
    public typealias Environment = DataManagerProvider & NetworkManagerProvider & ReachabilityProvider & OEXAnalyticsProvider & OEXStylesProvider & OEXConfigProvider

    let courseID : String
    let environment : Environment
    let webView : WKWebView
    let loadController : LoadStateViewController
    let handouts : BackedStream<String> = BackedStream()
    
    public weak var scrollableDelegate: ScrollableDelegate?
    private var scrollByDragging = false
    
    init(environment : Environment, courseID : String) {
        self.environment = environment
        self.courseID = courseID
        self.webView = WKWebView(frame: .zero, configuration: environment.config.webViewConfiguration())
        self.loadController = LoadStateViewController()
        
        super.init(env: environment)
        
        addListener()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        loadController.setupInController(controller: self, contentView: webView)
        addSubviews()
        setConstraints()
        setStyles()
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        
        view.backgroundColor = environment.styles.standardBackgroundColor()

        setAccessibilityIdentifiers()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        environment.analytics.trackScreen(withName: OEXAnalyticsScreenHandouts, courseID: courseID, value: nil)
        loadHandouts()
    }
    
    override func reloadViewData() {
        loadHandouts()
    }
    
    override public var shouldAutorotate: Bool {
        return true
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }

    private func setAccessibilityIdentifiers() {
        view.accessibilityIdentifier = "CourseHandoutsViewController:view"
        webView.accessibilityIdentifier = "CourseHandoutsViewController:web-view"
    }
    
    private func addSubviews() {
        view.addSubview(webView)
    }
    
    private func setConstraints() {
        webView.snp.makeConstraints { make in
            make.edges.equalTo(safeEdges)
        }
    }
    
    private func setStyles() {
        self.navigationItem.title = Strings.courseHandouts
    }
    
    private func streamForCourse(course : OEXCourse) -> OEXStream<String>? {
        if let access = course.courseware_access, !access.has_access {
            return OEXStream<String>(error: OEXCoursewareAccessError(coursewareAccess: access, displayInfo: course.start_display_info))
        }
        else {
            let request = CourseInfoAPI.getHandoutsForCourseWithID(courseID: courseID, overrideURL: course.course_handouts)
            let loader = self.environment.networkManager.streamForRequest(request, persistResponse: true)
            return loader
        }
    }

    private func loadHandouts() {
        if !handouts.active {
            loadController.state = .Initial
            let courseStream = self.environment.dataManager.enrollmentManager.streamForCourseWithID(courseID: courseID)
            let handoutStream = courseStream.transform {[weak self] enrollment in
                return self?.streamForCourse(course: enrollment.course) ?? OEXStream<String>(error : NSError.oex_courseContentLoadError())
            }
            self.handouts.backWithStream((courseStream.value != nil) ? handoutStream : OEXStream<String>(error : NSError.oex_courseContentLoadError()))    
        }
    }
    
    private func addListener() {
        handouts.listen(self, success: { [weak self] courseHandouts in
            if let
                displayHTML = OEXStyles.shared().styleHTMLContent(courseHandouts, stylesheet: "handouts-announcements"),
                let apiHostUrl = OEXConfig.shared().apiHostURL()
            {
                self?.webView.loadHTMLString(displayHTML, baseURL: apiHostUrl)
                self?.loadController.state = .Loaded
            }
            else {
                self?.loadController.state = LoadState.failed()
            }
            
            }, failure: {[weak self] error in
                self?.loadController.state = LoadState.failed(error: error)
        } )
    }
    
    override public func updateViewConstraints() {
        loadController.insets = UIEdgeInsets(top: view.safeAreaInsets.top, left: 0, bottom: view.safeAreaInsets.bottom, right: 0)
        super.updateViewConstraints()
    }
    
    //MARK:- LoadStateViewReloadSupport method
    func loadStateViewReload() {
        loadHandouts()
    }
}

extension CourseHandoutsViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch navigationAction.navigationType {
        case .linkActivated, .formSubmitted, .formResubmitted:
            if let URL = navigationAction.request.url, UIApplication.shared.canOpenURL(URL){
                UIApplication.shared.open(URL, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
        default:
            decisionHandler(.allow)
        }

    }
}

extension CourseHandoutsViewController: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollByDragging = true
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollByDragging {
            scrollableDelegate?.scrollViewDidScroll(scrollView: scrollView)
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scrollByDragging = false
    }
}
