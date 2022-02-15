//
//  ValuePropDetailViewController.swift
//  edX
//
//  Created by Salman on 19/11/2020.
//  Copyright © 2020 edX. All rights reserved.
//

import UIKit

enum CourseUpgradeScreen: String {
    case courseEnrollment
    case courseDashboard
    case courseUnit
    case none
}

class ValuePropDetailViewController: UIViewController, InterfaceOrientationOverriding {
    
    typealias Environment = OEXAnalyticsProvider & OEXStylesProvider & ReachabilityProvider & NetworkManagerProvider & OEXConfigProvider & OEXInterfaceProvider
    
    private lazy var valuePropTableView: ValuePropMessagesView = {
        let tableView = ValuePropMessagesView()
        tableView.accessibilityIdentifier = "ValuePropDetailViewController:table-view"
        return tableView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = titleStyle.attributedString(withText: Strings.ValueProp.upgrade(courseName: course.name ?? "")).setLineSpacing(4)
        label.accessibilityIdentifier = "ValuePropDetailViewController:title-label"
        return label
    }()
    
    private lazy var upgradeButton: CourseUpgradeButtonView = {
        let upgradeButton = CourseUpgradeButtonView()
        upgradeButton.tapAction = { [weak self] in
            self?.upgradeCourse()
        }
        upgradeButton.accessibilityIdentifier = "ValuePropDetailViewController:upgrade-button"
        return upgradeButton
    }()
    
    private var titleStyle: OEXMutableTextStyle = {
        let style = OEXMutableTextStyle(weight: .bold, size: .xxLarge, color: OEXStyles.shared().primaryDarkColor())
        style.alignment = .left
        return style
    }()
    
    private let crossButtonSize: CGFloat = 20
    private var isModalDismissable = true
    
    private var screen: CourseUpgradeScreen
    private let course: OEXCourse
    private let environment: Environment
    private let blockID: CourseBlockID?
    
    init(screen: CourseUpgradeScreen, course: OEXCourse, blockID: CourseBlockID? = nil, environment: Environment) {
        self.screen = screen
        self.course = course
        self.blockID = blockID
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = environment.styles.neutralWhiteT()
        navigationController?.navigationBar.apply(barTintColor: environment.styles.neutralWhiteT(), tintColor: environment.styles.primaryBaseColor(), clearShadow: true)
        navigationController?.presentationController?.delegate = self
        
        addObserver()
        configureView()
        
        guard let courseSku = UpgradeSKUManager.shared.courseSku(for: course) else { return }
        PaymentManager.shared.productPrice(courseSku) { [weak self] price in
            if let price = price {
                self?.upgradeButton.setPrice(price)
            }
        }
    }
    
    private func configureView() {
        addSubviews()
        setConstraints()
    }
    
    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(valuePropTableView)
        view.addSubview(upgradeButton)
        addCloseButton()
    }
    
    private func addObserver() {
        NotificationCenter.default.oex_addObserver(observer: self, name: UIApplication.willEnterForegroundNotification.rawValue) { _, observer, _ in
            observer.enableUserInteraction()
        }
    }
    
    private func addCloseButton() {
        let closeButton = UIBarButtonItem(image: Icon.Close.imageWithFontSize(size: crossButtonSize), style: .plain, target: nil, action: nil)
        closeButton.accessibilityLabel = Strings.Accessibility.closeLabel
        closeButton.accessibilityHint = Strings.Accessibility.closeHint
        closeButton.accessibilityIdentifier = "ValuePropDetailView:close-button"
        navigationItem.rightBarButtonItem = closeButton
        
        closeButton.oex_setAction { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func setConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(view).offset(StandardHorizontalMargin)
            make.trailing.equalTo(view).inset(StandardHorizontalMargin)
            make.top.equalTo(view).offset(StandardVerticalMargin * 5)
        }
        
        valuePropTableView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel).inset(-StandardHorizontalMargin / 2)
            make.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(StandardVerticalMargin)
            make.bottom.equalTo(upgradeButton.snp.top).offset(-StandardVerticalMargin)
        }
        
        upgradeButton.snp.makeConstraints { make in
            make.leading.equalTo(view).offset(StandardHorizontalMargin)
            make.trailing.equalTo(view).inset(StandardHorizontalMargin)
            make.bottom.equalTo(safeBottom).inset(StandardVerticalMargin)
            make.height.equalTo(CourseUpgradeButtonView.height)
        }
    }
    
    private func upgradeCourse() {
        guard let courseSku = UpgradeSKUManager.shared.courseSku(for: course) else { return }
        
        disableUserInteraction()
        
        let pacing = course.isSelfPaced ? "self" : "instructor"
        environment.analytics.trackUpgradeNow(with: course.course_id ?? "", blockID: courseSku, pacing: pacing)
        
        CourseUpgradeHandler.shared.upgradeCourse(course, environment: environment) { [weak self] status in
            self?.disableUserInteraction()
            
            switch status {
            case .payment:
                self?.upgradeButton.stopAnimating()
                break
            case .verify:
                CourseUpgradeCompletion.shared.handleCourseUpgrade(state: .intermediate, screen: self?.screen ?? .none)
                break
            case .complete:
                self?.enableUserInteraction()
                self?.upgradeButton.isHidden = true
                self?.dismiss(animated: true) {
                    CourseUpgradeCompletion.shared.handleCourseUpgrade(state: .success(self?.course.course_id ?? "", self?.blockID), screen: self?.screen ?? .none)
                }
                break
            case .error:
                self?.enableUserInteraction()
                self?.upgradeButton.stopAnimating()
                self?.dismiss(animated: true) {
                    CourseUpgradeCompletion.shared.handleCourseUpgrade(state: .error, screen: self?.screen ?? .none)
                }
                break
            default:
                break
            }
        }
    }
    
    private func disableUserInteraction() {
        isModalDismissable = false
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = false
            self?.view.isUserInteractionEnabled = false
        }
    }
    
    private func enableUserInteraction() {
        isModalDismissable = true
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.rightBarButtonItem?.isEnabled = true
            self?.view.isUserInteractionEnabled = true
        }
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
}

extension ValuePropDetailViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return isModalDismissable
    }
}
