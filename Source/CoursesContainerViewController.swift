//
//  CoursesContainerViewController.swift
//  edX
//
//  Created by Muhammad Umer on 26/03/2020.
//  Copyright © 2020 edX. All rights reserved.
//

import UIKit

private let valuePropViewHeight: CGFloat = 40

class CourseCardCell : UICollectionViewCell {
    
    static let margin = StandardVerticalMargin
    
    fileprivate static let cellIdentifier = "CourseCardCell"
    fileprivate let courseView = CourseCardView(frame: CGRect.zero)
    fileprivate lazy var valuePropView: ValuePropCourseCardView = {
        let view = ValuePropCourseCardView()
        view.clipsToBounds = true
        view.layer.cornerRadius = 5
        view.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        view.backgroundColor = OEXStyles.shared().primaryBaseColor()
        return view
    }()
    fileprivate lazy var containerView = UIView()
    fileprivate var course : OEXCourse?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.backgroundColor = OEXStyles.shared().standardBackgroundColor()
        setAccessibilityIdentifiers()
        courseView.isAccessibilityElement = true
    }
    
    fileprivate func resetCellView() {
        for view in contentView.subviews {
            view.removeFromSuperview()
        }
    }
    
    fileprivate func setUp(valuePropEnabled: Bool) {
        if valuePropEnabled {
            configureAuditCourseCardView()
        } else {
            configureCourseCardView()
        }
    }
    
    private func configureAuditCourseCardView() {
        contentView.addSubview(containerView)
        containerView.addSubview(courseView)
        containerView.addSubview(valuePropView)
        
        containerView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(CourseCardCell.margin)
            make.bottom.equalTo(contentView)
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
        }
        
        courseView.snp.makeConstraints { make in
            make.top.equalTo(containerView)
            make.leading.equalTo(containerView).offset(CourseCardCell.margin)
            make.trailing.equalTo(containerView).inset(CourseCardCell.margin)
            make.height.equalTo(CourseCardView.cardHeight(leftMargin: CourseCardCell.margin, rightMargin: CourseCardCell.margin))
        }
        
        valuePropView.snp.makeConstraints { make in
            make.top.equalTo(courseView.snp.bottom).inset(StandardVerticalMargin/2)
            make.leading.equalTo(containerView).offset(CourseCardCell.margin)
            make.trailing.equalTo(containerView).inset(CourseCardCell.margin)
            make.bottom.equalTo(containerView)
            make.height.equalTo(valuePropViewHeight)
        }
    }
    
    private func configureCourseCardView() {
        courseView.applyBorderStyle(style: BorderStyle())
        contentView.addSubview(courseView)
        
        courseView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(CourseCardCell.margin)
            make.leading.equalTo(contentView).offset(CourseCardCell.margin)
            make.trailing.equalTo(contentView).inset(CourseCardCell.margin)
            make.bottom.equalTo(contentView)
            make.height.equalTo(CourseCardView.cardHeight(leftMargin: CourseCardCell.margin, rightMargin: CourseCardCell.margin))
        }
    }

    private func setAccessibilityIdentifiers() {
        contentView.accessibilityIdentifier = "CourseCardCell:content-view"
        courseView.accessibilityIdentifier = "CourseCardCell:course-card-view"
        valuePropView.accessibilityIdentifier = "CourseCardCell:value-prop-view"
        containerView.accessibilityIdentifier = "CourseCardCell:container-view"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol CoursesContainerViewControllerDelegate : AnyObject {
    func coursesContainerChoseCourse(course : OEXCourse)
    func showValuePropDetailView(with course: OEXCourse)
    func reload()
}

extension CoursesContainerViewControllerDelegate {
    func showValuePropDetailView(with course: OEXCourse) {}
    func reload() {}
}

class CoursesContainerViewController: UICollectionViewController, ScrollableDelegateProvider {
    
    enum Context {
        case courseCatalog
        case enrollmentList
    }
    
    typealias Environment = NetworkManagerProvider & OEXRouterProvider & OEXConfigProvider & OEXInterfaceProvider & OEXAnalyticsProvider & ServerConfigProvider
    
    weak var scrollableDelegate: ScrollableDelegate?
    private var scrollByDragging = false
    
    private let environment : Environment
    private let context: Context
    
    weak var delegate: CoursesContainerViewControllerDelegate?
    
    private var isAuditModeCourseAvailable: Bool = false
    
    private lazy var errorView: GeneralErrorView = {
        let errorView = GeneralErrorView()
        return errorView
    }()
    
    var courses: [OEXCourse] = [] {
        didSet {
            if isiPad() {
                let auditModeCourses = courses.filter { valuePropEnabled(for: $0) }
                isAuditModeCourseAvailable = !auditModeCourses.isEmpty
            }
            
            canShowEmptyScreen = courses.isEmpty
        }
    }
    
    private let insetsController = ContentInsetsController()
    
    private var isDiscoveryEnabled: Bool {
        return environment.config.discovery.isEnabled
    }
    
    private var shouldShowFooter: Bool {
        return context == .enrollmentList && isDiscoveryEnabled && canShowEmptyScreen
    }
    
    //Empty Screen should be shown after fetching the enrollments API
    var canShowEmptyScreen: Bool = false
        
    init(environment: Environment, context: Context) {
        self.environment = environment
        self.context = context
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.alwaysBounceVertical = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = OEXStyles.shared().neutralXLight()
        collectionView.accessibilityIdentifier = "courses-container-view"
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        
        collectionView.register(CourseCardCell.self, forCellWithReuseIdentifier: CourseCardCell.cellIdentifier)
        collectionView.register(EnrolledCoursesFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: EnrolledCoursesFooterView.identifier)
        
        insetsController.addSource(
            source: ConstantInsetsSource(insets: UIEdgeInsets(top: 0, left: 0, bottom: StandardVerticalMargin, right: 0), affectsScrollIndicators: false)
        )
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                self?.collectionView.collectionViewLayout.invalidateLayout()
            },
            completion: { _ in }
        )
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: shouldShowFooter ? collectionView.frame.size.height : 0)
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: EnrolledCoursesFooterView.identifier, for: indexPath) as! EnrolledCoursesFooterView
            footerView.findCoursesAction = { [weak self] in
                self?.environment.router?.showCourseCatalog(fromController: self, bottomBar: nil)
                self?.environment.analytics.trackUserFindsCourses(self?.courses.count ?? 0)
            }
            return footerView
        }
        
        return UICollectionReusableView()
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return courses.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let course = courses[indexPath.row]
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CourseCardCell.cellIdentifier, for: indexPath as IndexPath) as! CourseCardCell
        DispatchQueue.main.async {
            cell.courseView.accessibilityLabel = cell.courseView.updateAcessibilityLabel()
        }
        cell.courseView.accessibilityHint = Strings.accessibilityShowsCourseContent
        cell.courseView.tapAction = { [weak self] card in
            self?.delegate?.coursesContainerChoseCourse(course: course)
        }
        
        cell.valuePropView.tapAction = { [weak self] in
            self?.delegate?.showValuePropDetailView(with: course)
        }
        
        switch context {
        case .courseCatalog:
            CourseCardViewModel.onCourseCatalog(course: course, wrapTitle: true).apply(card: cell.courseView, networkManager: environment.networkManager)
            break
        case .enrollmentList:
            CourseCardViewModel.onHome(course: course).apply(card: cell.courseView, networkManager: environment.networkManager)
            break
        }
        cell.course = course

        cell.resetCellView()
        cell.setUp(valuePropEnabled: valuePropEnabled(for: course))
        
        return cell
    }
    
    private func valuePropEnabled(for course: OEXCourse) -> Bool {
        guard let enrollment = environment.interface?.enrollmentForCourse(withID: course.course_id) else { return false }
        return enrollment.isUpgradeable && environment.serverConfig.valuePropEnabled
    }
    
    private func calculateValuePropHeight(for indexPath: IndexPath) -> CGFloat {
        if isiPad() {
            return isAuditModeCourseAvailable ? valuePropViewHeight : 0
        } else {
            return valuePropEnabled(for: courses[indexPath.row]) ? valuePropViewHeight : 0
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        insetsController.updateInsets()
    }
    
    func showError(message: String? = nil) {
        setupErrorView()
        errorView.setErrorMessage(message: message)
        
        errorView.tapAction = { [weak self] in
            self?.delegate?.reload()
        }
    }
    
    private func setupErrorView() {
        collectionView.alpha = 0
        view.addSubview(errorView)
        view.bringSubviewToFront(errorView)
        
        errorView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
    }
    
    func showOutdatedVersionError() {
        setupErrorView()
        errorView.showOutdatedVersionError()
        
        errorView.tapAction = { [weak self] in
            if let URL = self?.environment.config.appUpgradeConfig.iOSAppStoreURL() as? URL, UIApplication.shared.canOpenURL(URL) {
                UIApplication.shared.open(URL as URL, options: [:], completionHandler: nil)
            }
        }
    }
    
    func showEmptyScreen(show: Bool = true) {
        canShowEmptyScreen = show
        collectionView.reloadData()
    }
    
    func removeErrorView() {
        if view.subviews.contains(errorView) {
            errorView.removeFromSuperview()
            collectionView.alpha = 1
        }
    }
}

extension CoursesContainerViewController: UICollectionViewDelegateFlowLayout {
    private var sectionInsets: UIEdgeInsets {
        return .zero
    }
    
    private var itemsPerRow: CGFloat {
        return isiPad() ? 2 : 1
    }
    
    private var minimumSpace: CGFloat {
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return minimumSpace
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return minimumSpace
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let widthPerItem = view.frame.width / itemsPerRow
        let valuePropHeight: CGFloat = calculateValuePropHeight(for: indexPath)
        let heightPerItem =  widthPerItem * StandardImageAspectRatio + valuePropHeight
        return CGSize(width: widthPerItem, height: heightPerItem)
    }
}

extension CoursesContainerViewController {
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollByDragging = true
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollByDragging {
            scrollableDelegate?.scrollViewDidScroll(scrollView: scrollView)
        }
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scrollByDragging = false
    }
}
