//
//  CelebratoryModalViewController.swift
//  edX
//
//  Created by Salman on 22/01/2021.
//  Copyright © 2021 edX. All rights reserved.
//

import UIKit
import MessageUI

enum ActivityType:String {
    case linkedin = "com.linkedin.LinkedIn.ShareExtension"
}

private enum shareButtonType {
    case linkedin
    case twitter
    case facebook
    case mail
    case none
    
    func source() -> String {
        switch self {
        case .linkedin:
            return "linkedin"
        case .twitter:
            return "twitter"
        case .facebook:
            return "facebook"
        case .mail:
            return "email"
        default:
            return ""
        }
    }
    
    func utmParameter() -> String {
        return String(format: "utm_campaign=edxmilestone&utm_medium=social&utm_source=%@", source())
    }
}

private let facebookShareURL = "https://www.facebook.com/sharer.php?u=%@?%@&quote=%@"
private let twitterShareURL = "https://twitter.com/intent/tweet?url=%@?%@&text=%@"
private let linkedinShareURL = "https://www.linkedin.com/shareArticle?mini=true&url=%@?%@&titlt=%@"

class CelebratoryModalViewController: UIViewController {
    
    typealias Environment = NetworkManagerProvider & OEXConfigProvider & OEXSessionProvider & OEXStylesProvider & OEXAnalyticsProvider
    
    private let environment: Environment
    private var courseID: String
    private let type: shareButtonType = .none
    private let socialButtonSize =  CGSize(width: 30, height: 30)
    private let socialButtonImageSize: CGFloat =  20
    
    private let modalView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 8.0
        return view
    }()
    
    private lazy var shareButtonView: UIView = {
        let view = UIView()
        view.backgroundColor = OEXStyles.shared().infoXXLight()
        return view
    }()
    
    private lazy var congratulationImageView: UIImageView = {
        let gifImage = UIImage.gifImageWithName("CelebrateClaps")
        return UIImageView(image: gifImage)
    }()
    
    private lazy var titleLable: UILabel = {
        let title = UILabel()
        let style = OEXTextStyle(weight: .semiBold, size: .xxxLarge, color : OEXStyles.shared().neutralBlackT())
        title.attributedText = style.attributedString(withText: "Congratulations!")
        return title
    }()
    
    private lazy var titleMessageLable: UILabel = {
        let message = UILabel()
        message.numberOfLines = 0
        message.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        //message.adjustsFontSizeToFitWidth = true
        let style = OEXMutableTextStyle(weight: .normal, size: .large, color : OEXStyles.shared().neutralBlackT())
        style.alignment = .center
        message.attributedText = style.attributedString(withText: "You just completed the first section of your course!")
        return message
    }()
    
    private lazy var celebrationMessageLabel: UILabel = {
        let message = UILabel()
        message.numberOfLines = 0
        //message.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        //message.adjustsFontSizeToFitWidth = true
        let style = OEXMutableTextStyle(weight: .normal, size: .small, color : OEXStyles.shared().neutralBlackT())
        style.alignment = .center
        let string = "You earned it! Take a moment to celebrate and share your progress"
        let range = (string as NSString).range(of: "You earned it!")
        let attributedString = NSMutableAttributedString(string: string)
        attributedString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: message.font.pointSize), range: range)

        message.attributedText =  attributedString// style.attributedString(withText: "You earned it! Take a moment to celebrate and share your progress")
    
        return message
    }()
    
    private lazy var keepGoingButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = OEXStyles.shared().primaryBaseColor()
        button.layer.cornerRadius = 5.0
        let buttonStyle = OEXMutableTextStyle(weight: .semiBold, size: .small, color: OEXStyles.shared().neutralWhiteT())
        button.setAttributedTitle(buttonStyle.attributedString(withText: "Keep going"), for: UIControl.State())
        button.oex_addAction({ [weak self] _ in
            self?.dismiss(animated: false, completion: nil)
        }, for: .touchUpInside)
        
        return button
    }()
    
    private lazy var shareButton: UIButton = {
        let button = UIButton()
        let shareImage = UIImage(named: "shareCourse")?.withRenderingMode(.alwaysTemplate)
        button.setImage(shareImage, for: .normal)
        button.tintColor = environment.styles.primaryBaseColor()
        button.accessibilityLabel = Strings.Accessibility.shareACourse
        button.oex_removeAllActions()
        button.oex_addAction({[weak self] _ in
                if let shateUtmParameters = self?.shareUtmParameters {
                    self?.shareCourse(url: self?.courseURL ?? "", utmParameters: shateUtmParameters)
                }
            }, for: .touchUpInside)
        
        return button
    }()

    private lazy var courseURL:String = {
        let enrollment = OEXInterface.shared().enrollmentForCourse(withID: courseID)
        let courseURL = enrollment?.course.course_about ?? ""
        return courseURL
    }()
    
    private lazy var shareUtmParameters: CourseShareUtmParameters? = {
        var parameters:[String:Any] = [:]
        parameters["facebook"] = "utm_campaign=edxmilestone&utm_medium=social&utm_source=facebook"
        parameters["twitter"] = "utm_campaign=edxmilestone&utm_medium=social&utm_source=twitter"
        parameters["linkedin"] = "utm_campaign=edxmilestone&utm_medium=social&utm_source=linkedin"
        parameters["email"] = "utm_campaign=edxmilestone&utm_medium=social&utm_source=email"
        
        return CourseShareUtmParameters(utmParams: parameters)
    }()
    
    private lazy var shareTextMessage: String = {
        let enrollment = OEXInterface.shared().enrollmentForCourse(withID: courseID)
        let courseName = enrollment?.course.name ?? ""
        let message = String(format: "I'm on my way to completing %@ online with @edxonline. What are you spending your time learning?", courseName)
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        return encodedMessage
    }()
    
    init(courseID: String, environment: Environment) {
        self.courseID = courseID
        self.environment = environment
        
        super.init(nibName: nil, bundle: nil)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor.gray.withAlphaComponent(0.7)
        view.setNeedsUpdateConstraints()
        addViews()
        setupContraints()
    }
    
    private func addViews() {
        modalView.addSubview(titleLable)
        modalView.addSubview(titleMessageLable)
        modalView.addSubview(congratulationImageView)
        modalView.addSubview(shareButtonView)
        modalView.addSubview(keepGoingButton)
        
        shareButtonView.addSubview(celebrationMessageLabel)
        shareButtonView.addSubview(shareButton)
        view.addSubview(modalView)
    }
    
    func removeConstraints() {
        modalView.snp.removeConstraints()
        titleLable.snp.removeConstraints()
        titleMessageLable.snp.removeConstraints()
        congratulationImageView.snp.removeConstraints()
        shareButtonView.snp.removeConstraints()
        keepGoingButton.snp.removeConstraints()
        celebrationMessageLabel.snp.removeConstraints()
        shareButton.snp.removeConstraints()
    }
    
    func setupContraints() {
        modalView.snp.makeConstraints { (make) in
            make.leading.equalTo(view).offset(20)
            make.trailing.equalTo(view).inset(20)
            make.top.equalTo(view).offset((view.frame.size.height/4)/2)
            make.bottom.equalTo(view).offset(-(view.frame.size.height/4)/2)
            make.centerX.equalTo(view)
            make.centerY.equalTo(view)
        }

        titleLable.snp.makeConstraints { (make) in
            make.top.equalTo(modalView).offset(40)
            make.centerX.equalTo(modalView)
            make.height.equalTo(30)
        }

        titleMessageLable.snp.makeConstraints { (make) in
            make.top.equalTo(titleLable.snp.bottom).offset(13)
            make.centerX.equalTo(modalView)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/2.8)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/2.8)
            make.height.equalTo(40)
        }
        
        congratulationImageView.snp.makeConstraints { (make) in
            make.top.equalTo(titleMessageLable.snp.bottom).offset(24)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/3.5)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/3.5)
        }
        
        celebrationMessageLabel.snp.makeConstraints { (make) in
            make.top.equalTo(shareButtonView).offset(StandardVerticalMargin*2)
//            make.centerX.equalTo(shareButtonView)
            make.leading.equalTo(shareButton.snp.trailing).offset(StandardHorizontalMargin-5)
            //make.trailing.equalTo(shareButtonView).inset(StandardHorizontalMargin*2)
            make.width.equalTo(shareButtonView).offset(-StandardHorizontalMargin*4)
            make.bottom.equalTo(shareButtonView).inset(24)
        }

        shareButtonView.snp.makeConstraints { (make) in
            make.top.equalTo(congratulationImageView.snp.bottom).offset(StandardVerticalMargin*2)
            make.centerX.equalTo(modalView)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/3.5)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/3.5)
        }

        keepGoingButton.snp.makeConstraints { (make) in
            make.top.equalTo(shareButtonView.snp.bottom).offset(StandardVerticalMargin*2)
            make.bottom.equalTo(modalView).inset(20)
            make.centerX.equalTo(modalView)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/3.5)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/3.5)
            make.height.equalTo(44)
        }
        
        shareButton.snp.makeConstraints { make in
            make.top.equalTo(shareButtonView).offset(StandardVerticalMargin*2)
            make.leading.equalTo(shareButtonView).offset(StandardHorizontalMargin*2)
            make.height.equalTo(22)
            make.width.equalTo(22)
        }
    }

    func setupLandscapeContraints() {
        
        modalView.snp.updateConstraints { (make) in
            make.leading.equalTo(view).offset((view.frame.size.height/4)/2)
            make.trailing.equalTo(view).offset(-(view.frame.size.height/4)/2)
            make.top.equalTo(view).offset(20)
            make.bottom.equalTo(view).inset(20)
            make.centerX.equalTo(view)
            make.centerY.equalTo(view)
        }

        titleLable.snp.makeConstraints { (make) in
            make.top.equalTo(modalView).offset(40)
            make.centerX.equalTo(modalView)
            make.height.equalTo(30)
        }

        titleMessageLable.snp.makeConstraints { (make) in
            make.top.equalTo(titleLable.snp.bottom).offset(13)
            make.centerX.equalTo(modalView)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/2.8)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/2.8)
            make.height.equalTo(40)
        }
        
        congratulationImageView.snp.makeConstraints { (make) in
            make.top.equalTo(titleMessageLable.snp.bottom).offset(24)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/3.5)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/3.5)
        }
        
        celebrationMessageLabel.snp.makeConstraints { (make) in
            make.top.equalTo(shareButtonView).offset(StandardVerticalMargin*2)
            make.centerX.equalTo(shareButtonView)
            make.leading.equalTo(shareButtonView).offset(StandardHorizontalMargin*2)
            make.trailing.equalTo(shareButtonView).inset(20)
            make.bottom.equalTo(shareButtonView).inset(24)
        }

        shareButtonView.snp.makeConstraints { (make) in
            make.top.equalTo(congratulationImageView.snp.bottom).offset(StandardVerticalMargin*2)
            make.centerX.equalTo(modalView)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/3.5)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/3.5)
        }

        keepGoingButton.snp.makeConstraints { (make) in
            make.top.equalTo(shareButtonView.snp.bottom).offset(StandardVerticalMargin*2)
            make.bottom.equalTo(modalView).inset(20)
            make.centerX.equalTo(modalView)
            make.leading.equalTo(modalView).offset((view.frame.size.width/4)/3.5)
            make.trailing.equalTo(modalView).inset((view.frame.size.width/4)/3.5)
            make.height.equalTo(44)
        }
        
        shareButton.snp.makeConstraints { make in
            make.top.equalTo(shareButtonView).offset(StandardVerticalMargin*2)
            make.leading.equalTo(shareButtonView).offset(StandardHorizontalMargin)
            make.height.equalTo(22)
            make.width.equalTo(22)
        }
    }

    
    private func shareCourse(url: String, utmParameters: CourseShareUtmParameters) {
        if let url = NSURL(string: url) {
            let analytics = environment.analytics
            let courseID = self.courseID
            
            let controller = shareHashtaggedTextAndALinka(textBuilder: { hashtagOrPlatform in
                Strings.shareACourse(platformName: hashtagOrPlatform)
            }, url: url, utmParams: utmParameters, analyticsCallback: { analyticsType in
                analytics.trackCourseCelebrationSocialShareClicked(courseID: courseID, type: analyticsType)
            })
            controller.configurePresentationController(withSourceView: shareButton)
            present(controller, animated: true, completion: nil)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.current.orientation.isLandscape {
            print("Landscape")
            removeConstraints()
            modalView.removeFromSuperview()
            addViews()
            setupLandscapeContraints()
        } else {
            print("Portrait")
            removeConstraints()
            modalView.removeFromSuperview()
            modalView.updateConstraints()
            addViews()
            setupContraints()
        }
    }
    
}
