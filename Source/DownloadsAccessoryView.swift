//
//  DownloadsAccessoryView.swift
//  edX
//
//  Created by Akiva Leffert on 9/24/15.
//  Copyright © 2015 edX. All rights reserved.
//

import UIKit


class DownloadsAccessoryView : UIView {
    
    enum State {
        case Available
        case Downloading
        case Deleting
        case Done
        case Gated
    }
    
    private let downloadButton = UIButton(type: .system)
    private let downloadSpinner = SpinnerView(size: .Medium, color: .Primary)
    private let iconFontSize : CGFloat = 15
    private let countLabel : UILabel = UILabel()
    
    override init(frame : CGRect) {
        state = .Available
        itemCount = nil
        
        super.init(frame: frame)
        
        downloadButton.backgroundColor = OEXStyles.shared().neutralLight()
        downloadButton.tintColor = OEXStyles.shared().primaryXLightColor()
        
        //downloadButton.contentEdgeInsets = UIEdgeInsets.init(top: 15, left: 10, bottom: 15, right: 10)
        downloadButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        downloadSpinner.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        addSubview(downloadButton)
        addSubview(downloadSpinner)
        addSubview(countLabel)
        
        // This view is atomic from an accessibility point of view
        isAccessibilityElement = true
        
        downloadSpinner.accessibilityTraits = UIAccessibilityTraits.notEnabled;
        countLabel.accessibilityTraits = UIAccessibilityTraits.notEnabled;
        downloadButton.accessibilityTraits = UIAccessibilityTraits.notEnabled;
        
        downloadSpinner.stopAnimating()
        
        downloadSpinner.snp.makeConstraints { make in
            make.center.equalTo(self)
        }
        
        downloadButton.snp.makeConstraints { make in
            make.trailing.equalTo(self)
            make.centerY.equalTo(self)
            make.height.equalTo(30)
            make.width.equalTo(30)
        }
        
        countLabel.snp.makeConstraints { make in
            make.centerY.equalTo(self)
            make.leading.equalTo(downloadButton.snp.trailing).offset(6)
            make.width.equalTo(10)
            make.height.equalTo(10)
        }

        setAccessibilityIdentifiers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        downloadButton.layer.masksToBounds = true
        downloadButton.layer.cornerRadius = downloadButton.frame.size.width / 2
    }

    private func setAccessibilityIdentifiers() {
        accessibilityIdentifier = "DownloadsAccessoryView:view"
        downloadButton.accessibilityIdentifier = "DownloadsAccessoryView:download-button"
        countLabel.accessibilityIdentifier = "DownloadsAccessoryView:count-label"
        downloadSpinner.accessibilityIdentifier = "DownloadsAccessoryView:download-spinner"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func useIcon(icon : Icon?) {
        downloadButton.setImage(icon?.imageWithFontSize(size: iconFontSize), for:.normal)
    }
    
    var downloadAction : (() -> Void)? = nil {
        didSet {
            downloadButton.oex_removeAllActions()
            downloadButton.oex_addAction({ _ in self.downloadAction?() }, for: .touchUpInside)
        }
    }
    
    var itemCount : Int? {
        didSet {
            let count = itemCount ?? 0
            let text = (count > 0 ? "\(count)" : "")
            let styledText = CourseOutlineItemView.detailFontStyle.attributedString(withText: text)
            countLabel.attributedText = styledText
        }
    }
    
    var state : State {
        didSet {
            switch state {
            case .Available:
                useIcon(icon: .ContentCanDownload)
                downloadSpinner.isHidden = true
                downloadButton.isUserInteractionEnabled = true
                downloadButton.isHidden = false
                isUserInteractionEnabled = true
                countLabel.isHidden = false
                
                if let count = itemCount {
                    let message = Strings.downloadManyVideos(videoCount: count)
                    accessibilityLabel = message
                }
                else {
                    accessibilityLabel = Strings.download
                }
                accessibilityTraits = UIAccessibilityTraits.button
            case .Downloading:
                downloadSpinner.startAnimating()
                downloadSpinner.isHidden = false
                downloadButton.isUserInteractionEnabled = true
                isUserInteractionEnabled = true
                downloadButton.isHidden = true
                countLabel.isHidden = true
                
                accessibilityLabel = Strings.downloading
                accessibilityTraits = UIAccessibilityTraits.button
            case .Deleting:
                downloadSpinner.startAnimating()
                downloadSpinner.isHidden = false
                downloadButton.isUserInteractionEnabled = false
                isUserInteractionEnabled = false
                downloadButton.isHidden = true
                countLabel.isHidden = true
                
                accessibilityLabel = Strings.downloading
                accessibilityTraits = UIAccessibilityTraits.button
            case .Done:
                useIcon(icon: .ContentDidDownload)
                downloadSpinner.isHidden = true
                isUserInteractionEnabled = false
                downloadButton.isHidden = false
                countLabel.isHidden = false
                
                if let count = itemCount {
                    let message = Strings.downloadManyVideos(videoCount: count)
                    accessibilityLabel = message
                }
                else {
                    accessibilityLabel = Strings.downloaded
                }
                accessibilityTraits = UIAccessibilityTraits.staticText
            case .Gated:
                useIcon(icon: .Closed)
                downloadSpinner.isHidden = true
                isUserInteractionEnabled = false
                downloadButton.isHidden = false
                countLabel.isHidden = true
                downloadButton.tintColor = OEXStyles.shared().primaryDarkColor()
            }
        }
    }
}
