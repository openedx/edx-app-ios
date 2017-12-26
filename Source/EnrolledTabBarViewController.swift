//
//  EnrolledTabBarViewController.swift
//  edX
//
//  Created by Salman on 19/12/2017.
//  Copyright © 2017 edX. All rights reserved.
//

import UIKit

private enum TabBarOptions: Int {
    case MyCourse, CourseCatalog, Debug
    static let allOptions = [MyCourse, CourseCatalog, Debug]
}

class EnrolledTabBarViewController: UITabBarController, UITabBarControllerDelegate {

    typealias Environment = OEXAnalyticsProvider & OEXConfigProvider & DataManagerProvider & NetworkManagerProvider & OEXRouterProvider & OEXInterfaceProvider & ReachabilityProvider & OEXSessionProvider & OEXStylesProvider
    
    private let environment: Environment
    private var tabBarItems : [CourseDashboardTabBarItem] = []
    
    // add the additional resources options in additionalTabBarItems
    fileprivate var additionalTabBarItems : [CourseDashboardTabBarItem] = []
    
    private var userProfileImageView = ProfileImageView()
    private let UserProfileImageSize = CGSize(width: 30, height: 30)
    private var profileFeed: Feed<UserProfile>?
    private let tabBarImageFontSize : CGFloat = 20
    
    private var screenTitle: String {
        let option = TabBarOptions.allOptions[0]
        switch option {
            case .CourseCatalog:
                return courseCatalogTitle()
            default: return Strings.courses
        }
    }
    
    init(environment: Environment) {
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = screenTitle
        addAccountButton()
        addProfileButton()
        setupProfileLoader()
        prepareTabViewData()
        delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func courseCatalogTitle() -> String {
        switch environment.config.courseEnrollmentConfig.type {
        case .Native:
            return Strings.findCourses
        default:
            return Strings.discover
        }
    }
    
    private func prepareTabViewData() {
        tabBarItems = []
        var item : CourseDashboardTabBarItem
        for option in TabBarOptions.allOptions {
            switch option {
            case .MyCourse:
                item = CourseDashboardTabBarItem(title: Strings.courses, viewController: EnrolledCoursesViewController(environment: environment), icon: Icon.Courseware, detailText: Strings.Dashboard.courseCourseDetail)
                tabBarItems.append(item)
            case .CourseCatalog:
                guard environment.config.courseEnrollmentConfig.isCourseDiscoveryEnabled(), let router = environment.router else { break }
                item = CourseDashboardTabBarItem(title: courseCatalogTitle(), viewController: router.getDiscoveryViewController(), icon: Icon.CourseDiscovery, detailText: Strings.Dashboard.courseCourseDetail)
                tabBarItems.append(item)
            case .Debug:
                if environment.config.shouldShowDebug() {
                    item = CourseDashboardTabBarItem(title:Strings.debug, viewController: DebugMenuViewController(environment: environment), icon: Icon.CourseDiscovery, detailText: Strings.Dashboard.courseCourseDetail)
                    additionalTabBarItems.append(item)
                }
            }
        }
        
        if additionalTabBarItems.count > 0 {
            let item = CourseDashboardTabBarItem(title:Strings.resourses, viewController:
                AdditionalTabBarViewController(environment: environment, cellItems: additionalTabBarItems), icon: Icon.MoreOptionsIcon, detailText: "")
            tabBarItems.append(item)
        }
    
        loadTabBarViewControllers(tabBarItems: tabBarItems)
    }
    
    private func loadTabBarViewControllers(tabBarItems: [CourseDashboardTabBarItem]) {
        var controllers :[UIViewController] = []
        for tabBarItem in tabBarItems {
            let controller = tabBarItem.viewController
            controller.tabBarItem = UITabBarItem(title:tabBarItem.title, image:tabBarItem.icon.imageWithFontSize(size: tabBarImageFontSize), selectedImage: tabBarItem.icon.imageWithFontSize(size: tabBarImageFontSize))
            controllers.append(controller)
        }
        viewControllers = controllers
        tabBar.isHidden = (tabBarItems.count == 1)
    }
    
    private func setupProfileLoader() {
        guard environment.config.profilesEnabled else { return }
        profileFeed = environment.dataManager.userProfileManager.feedForCurrentUser()
        
        profileFeed?.output.listen(self,  success: { profile in
            self.userProfileImageView.remoteImage = profile.image(networkManager: self.environment.networkManager)
        }, failure : { _ in
            Logger.logError("Profiles", "Unable to fetch profile")
        })
        profileFeed?.refresh()
    }

    private func addProfileButton() {
        if environment.config.profilesEnabled {
            let profileView = UIView(frame: CGRect(x: 0, y: 0, width: UserProfileImageSize.width, height: UserProfileImageSize.height))
            let profileButton = UIButton()
            profileView.addSubview(userProfileImageView)
            profileView.addSubview(profileButton)
    
            profileButton.snp_makeConstraints { (make) in
                make.edges.equalTo(profileView)
            }
            
            userProfileImageView.snp_makeConstraints { (make) in
                make.edges.equalTo(profileView)
            }
            
            profileButton.oex_addAction({[weak self] _  in
                guard let currentUserName = self?.environment.session.currentUser?.username else { return }
                self?.environment.router?.showProfileForUsername(controller: self, username: currentUserName, modalTransitionStylePresent: true)
            }, for: .touchUpInside)
            
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileView)
        }
    }
    
    private func addAccountButton() {
        let accountButton = UIBarButtonItem(image: Icon.AccountIcon.imageWithFontSize(size: 20.0), style: .plain, target: nil, action: nil)
        accountButton.accessibilityLabel = Strings.userAccount
        navigationItem.rightBarButtonItem = accountButton
        
        accountButton.oex_setAction { [weak self] in
            self?.environment.router?.showAccount(controller: self, modalTransitionStylePresent: true)
        }
    }
}

extension EnrolledTabBarViewController {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController){
        navigationItem.title = viewController.navigationItem.title
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
}
