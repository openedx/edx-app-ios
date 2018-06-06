//
//  SubjectCollectionViewCell.swift
//  edX
//
//  Created by Zeeshan Arif on 5/23/18.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit

class SubjectCollectionViewCell: UICollectionViewCell {
    static let identifier = "SubjectCollectionViewCell"
    static var defaultHeight: CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? 90 : 70
    }
    static var defaultWidth: CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? 200 : 150
    }
    
    private(set) var subject: Subject? {
        didSet {
            
            let subjectNameStyle = OEXMutableTextStyle(weight: .semiBold, size: UIDevice.current.userInterfaceIdiom == .pad ? .large : .base, color: OEXStyles.shared().neutralWhite())
            subjectNameStyle.alignment = .center
            imageView.image = subject?.image ?? nil
            subjectNameLabel.attributedText = subjectNameStyle.attributedString(withText: subject?.name ?? "")
        }
    }
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.cornerRadius = 5
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.accessibilityIdentifier = "SubjectCollectionViewCell:image-view"
        return imageView
    }()
    
    lazy var subjectNameLabel: UILabel = {
        let label = UILabel()
        label.accessibilityIdentifier = "SubjectCollectionViewCell:subject-name-label"
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSubviews() {
        contentView.addSubview(imageView)
        contentView.addSubview(subjectNameLabel)
        setConstraints()
    }
    
    private func setConstraints() {
        imageView.snp.makeConstraints { make in
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
            make.height.equalTo(SubjectCollectionViewCell.defaultHeight)
            make.center.equalToSuperview()
        }
        
        subjectNameLabel.snp.makeConstraints { make in
            make.height.lessThanOrEqualToSuperview().offset(StandardHorizontalMargin)
            make.width.equalTo(imageView).inset(StandardVerticalMargin)
            make.center.equalTo(imageView)
        }
    }
    
    func configure(subject: Subject) {
        self.subject = subject
        subjectNameLabel.accessibilityHint = Strings.Accessibility.browserBySubjectHint(name: subject.name)
    }
    
}

