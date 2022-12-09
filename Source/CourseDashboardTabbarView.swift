//
//  CourseDashboardTabbarView.swift
//  edX
//
//  Created by MuhammadUmer on 02/12/2022.
//  Copyright © 2022 edX. All rights reserved.
//

import UIKit

protocol CourseDashboardTabbarViewDelegate: AnyObject {
    func didSelectItem(at position: Int, tabbarItem: TabBarItem)
}

class CourseDashboardTabbarView: UIView {
    typealias Environment = OEXAnalyticsProvider & DataManagerProvider & OEXInterfaceProvider & NetworkManagerProvider & ReachabilityProvider & OEXRouterProvider & OEXConfigProvider & OEXStylesProvider & ServerConfigProvider & OEXSessionProvider & RemoteConfigProvider
    
    weak var delegate: CourseDashboardTabbarViewDelegate?
    
    lazy var textStyle: OEXMutableTextStyle = {
        let style = OEXMutableTextStyle(textStyle: OEXTextStyle(weight: .normal, size: .base, color: OEXStyles.shared().neutralXXDark()))
        style.alignment = .center
        return style
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.accessibilityIdentifier = "CourseDashboardTabbarView:collection-view"
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = environment.styles.neutralWhiteT()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CourseDashboardTabbarViewCell.self, forCellWithReuseIdentifier: CourseDashboardTabbarViewCell.identifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private var shouldShowDiscussions: Bool {
        guard let course = course else { return false }
        return environment.config.discussionsEnabled && course.hasDiscussionsEnabled
    }
    
    private var shouldShowHandouts: Bool {
        guard let course = course else { return false }
        return course.course_handouts?.isEmpty == false
    }
    
    private var selectedItemIndex = 0
    private var tabBarItems: [TabBarItem] = []
    
    private let environment: Environment
    private let course: OEXCourse?
    
    init(environment: Environment, course: OEXCourse?) {
        self.environment = environment
        self.course = course
        super.init(frame: .zero)
        
        accessibilityIdentifier = "CourseDashboardTabbarView"
        prepareTabViewData()
        addSubViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSubViews() {
        addSubview(collectionView)
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        if tabBarItems.isEmpty { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let weakSelf = self else { return }
            let selectedItemIndex = weakSelf.selectedItemIndex
            let tabBarItems = weakSelf.tabBarItems
            let indexPath = IndexPath(item: selectedItemIndex, section: 0)
            weakSelf.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
            weakSelf.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            weakSelf.delegate?.didSelectItem(at: selectedItemIndex, tabbarItem: tabBarItems[selectedItemIndex])
        }
    }
    
    private func prepareTabViewData() {
        tabBarItems = []
        guard let courseID = course?.course_id else { return }
        
        var item = TabBarItem(title: Strings.Dashboard.courseHome, viewController: CourseOutlineViewController(environment: environment, courseID: courseID, rootID: nil, forMode: .full), icon: Icon.Courseware, detailText: Strings.Dashboard.courseCourseDetail)
        tabBarItems.append(item)
        
        if environment.config.isCourseVideosEnabled {
            item = TabBarItem(title: Strings.Dashboard.courseVideos, viewController: CourseOutlineViewController(environment: environment, courseID: courseID, rootID: nil, forMode: .video), icon: Icon.CourseVideos, detailText: Strings.Dashboard.courseVideosDetail)
            tabBarItems.append(item)
        }
        
        if shouldShowDiscussions {
            item = TabBarItem(title: Strings.Dashboard.courseDiscussion, viewController: DiscussionTopicsViewController(environment: environment, courseID: courseID), icon: Icon.Discussions, detailText: Strings.Dashboard.courseDiscussionDetail)
            tabBarItems.append(item)
        }
        
        if environment.config.courseDatesEnabled {
            item = TabBarItem(title: Strings.Dashboard.courseImportantDates, viewController: CourseDatesViewController(environment: environment , courseID: courseID), icon: Icon.Calendar, detailText: Strings.Dashboard.courseImportantDatesDetail)
            tabBarItems.append(item)
        }

        if shouldShowHandouts {
            item = TabBarItem(title: Strings.Dashboard.courseHandouts, viewController: CourseHandoutsViewController(environment: environment, courseID: courseID), icon: Icon.Handouts, detailText: Strings.Dashboard.courseHandoutsDetail)
            tabBarItems.append(item)
        }
        
        if environment.config.isAnnouncementsEnabled {
            item = TabBarItem(title: Strings.Dashboard.courseAnnouncements, viewController: CourseAnnouncementsViewController(environment: environment, courseID: courseID), icon:Icon.Announcements, detailText: Strings.Dashboard.courseAnnouncementsDetail)
            tabBarItems.append(item)
        }
    }
}

extension CourseDashboardTabbarView: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabBarItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CourseDashboardTabbarViewCell.identifier, for: indexPath) as! CourseDashboardTabbarViewCell
        let item = tabBarItems[indexPath.row]
        cell.setTitle(title: item.title, textStyle: textStyle)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedItemIndex = indexPath.item
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        delegate?.didSelectItem(at: selectedItemIndex, tabbarItem: tabBarItems[selectedItemIndex])
    }
}

extension CourseDashboardTabbarView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = tabBarItems[indexPath.row]
        let tabTitle = item.title
        let padding: CGFloat = 20
        if let font = textStyle.attributes["NSFont"] as? UIFont {
            let titleWidth = NSString(string: tabTitle).boundingRect(with: frame.size, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil).size.width
            let tabWidth = titleWidth + padding
            return CGSize(width: tabWidth, height: frame.height)
        }
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
}

class CourseDashboardTabbarViewCell: UICollectionViewCell {
    static let identifier = "CourseDashboardTabbarViewCell"
    
    private let tabbarItemTitle: UILabel = {
        let label = UILabel()
        label.accessibilityIdentifier = "CourseDashboardTabbarViewCell:tabbar-item-title-label"
        return label
    }()
    
    private let indicatorView: UIView = {
        let indicatorView = UIView()
        indicatorView.accessibilityIdentifier = "CourseDashboardTabbarViewCell:indicator-view"
        return indicatorView
    }()
    
    private let indicatorColor: UIColor = OEXStyles.shared().primaryBaseColor()
    
    override var isSelected: Bool {
        didSet {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) { [weak self] in
                    guard let weakSelf = self else { return }
                    weakSelf.indicatorView.backgroundColor = weakSelf.isSelected ? weakSelf.indicatorColor : .clear
                    weakSelf.layoutIfNeeded()
                }
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        accessibilityIdentifier = "CourseDashboardTabbarViewCell"
        addSubviews()
        addConstrains()
    }
    
    private func addSubviews() {
        contentView.addSubview(tabbarItemTitle)
        addSubview(indicatorView)
    }
    
    private func addConstrains() {
        tabbarItemTitle.translatesAutoresizingMaskIntoConstraints = false
        tabbarItemTitle.snp.makeConstraints { make in
            make.center.equalTo(self)
        }
        
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.leading.equalTo(self)
            make.trailing.equalTo(self)
            make.bottom.equalTo(self)
        }
    }
    
    func setTitle(title: String, textStyle: OEXMutableTextStyle) {
        tabbarItemTitle.attributedText = textStyle.attributedString(withText: title)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        tabbarItemTitle.text = ""
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
