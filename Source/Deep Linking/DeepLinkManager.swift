//
//  DeepLinkManager.swift
//  edX
//
//  Created by Salman on 02/10/2018.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit


@objc class DeepLinkManager: NSObject {

    static let sharedInstance = DeepLinkManager()
    typealias Environment = OEXSessionProvider & OEXRouterProvider & OEXConfigProvider
    var environment: Environment?
    
    private override init() {
        super.init()
    }

    func processDeepLink(with params: [String: Any], environment: Environment) {
        self.environment = environment
        let deepLink = DeepLink(dictionary: params)
        guard let deepLinkType = deepLink.type, deepLinkType != .None else {
            return
        }
        
        if isUserLoggedin() {
            navigateToDeepLink(with: deepLinkType, link: deepLink)
        }
        else {
            showLoginScreen()
        }
    }
    
    private func showLoginScreen() {
        if let topViewController = topMostViewController(), !topViewController.isKind(of: OEXLoginViewController.self) {
            dismissPresentedView(controller: topViewController)
            environment?.router?.showLoginScreen(from: nil, completion: nil)
        }
    }
        
    private func isUserLoggedin() -> Bool {
        return environment?.session.currentUser != nil
    }
    
    private func linkTypeOfView(controller: UIViewController) -> DeepLinkType {
        if controller.isKind(of: CourseOutlineViewController.self), let courseOutlineViewController = controller as? CourseOutlineViewController {
            return courseOutlineViewController.courseOutlineMode == .full ? .CourseDashboard : .CourseVideos
        }
        else if controller.isKind(of: ProgramsViewController.self) {
            return .Programs
        } else if controller.isKind(of: DiscussionTopicsViewController.self) {
            return .Discussions
        } else if controller.isKind(of: AccountViewController.self) {
            return .Account
        }
        
        return .None
    }
    
    private func classTypeOfView(linkType: DeepLinkType) -> AnyClass? {
        var classType: AnyClass?
        switch linkType {
        case .CourseDashboard, .CourseVideos:
            classType = CourseOutlineViewController.self
            break
        case .Discussions:
            classType = DiscussionTopicsViewController.self
            break
        case .Programs:
            classType = ProgramsViewController.self
            break
        case .Account:
            classType = AccountViewController.self
            break
        default:
            break
        }
        return classType
    }
    
    private func showCourseDashboardViewController(with link: DeepLink) {
        guard let topViewController = topMostViewController() else {
            return
        }
        
        if let parentViewController = topViewController.parent, parentViewController.isKind(of: CourseDashboardViewController.self), let courseDashboardView = parentViewController as? CourseDashboardViewController, courseDashboardView.getCourseId() == link.courseId {
            
            if !viewAlreadyDisplay(type: link.type ?? .None) {
                courseDashboardView.switchTab(with: link.type ?? .None)
            }
        } else {
            dismissPresentedView(controller: topViewController)
            environment?.router?.showCourseWithDeepLink(type: link.type ?? .None, courseID: link.courseId ?? "")
        }
    }
    
    private func showPrograms(with link: DeepLink) {
        if !viewAlreadyDisplay(type: link.type ?? .None), let topViewController = topMostViewController() {
            dismissPresentedView(controller: topViewController)
            environment?.router?.showPrograms(with: link.type ?? .None)
        }
    }

    private func showAccountViewController(with link: DeepLink) {
        if !viewAlreadyDisplay(type: link.type ?? .None), let topViewController = topMostViewController() {
            dismissPresentedView(controller: topViewController)
            environment?.router?.showAccount(controller:UIApplication.shared.keyWindow?.rootViewController, modalTransitionStylePresent: true)
        }
    }
    
    private func topMostViewController() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController?.topMostController()
    }
    
    private func viewAlreadyDisplay(type: DeepLinkType) -> Bool {
        guard let topViewController = topMostViewController(), let ClassType = classTypeOfView(linkType: type) else {
            return false
        }
        
        return (topViewController.isKind(of: ClassType) && linkTypeOfView(controller: topViewController) == type)
    }
    
    private func dismissPresentedView(controller: UIViewController) {
        if controller.isModal() || controller.isRootModal() {
            controller.dismiss(animated: false, completion: nil)
        }
    }

    private func navigateToDeepLink(with type: DeepLinkType, link: DeepLink) {
        switch type {
        case .CourseDashboard, .CourseVideos, .Discussions:
            showCourseDashboardViewController(with: link)
            break
        case .Programs:
            guard environment?.config.programConfig.enabled ?? false else { return }
            showPrograms(with: link)
        case .Account:
            showAccountViewController(with: link)
        break
        default:
            break
        }
    }
}
