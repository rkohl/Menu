//
//  MenuView.swift
//  Menus
//
//  Created by Simeon on 2/6/18.
//  Copyright © 2018 Two Lives Left. All rights reserved.
//

import UIKit
import SnapKit

//MARK: - MenuView

public class MenuView: UIView, MenuThemeable, UIGestureRecognizerDelegate {
    
    public static let menuWillPresent = Notification.Name("CodeaMenuWillPresent")
    
    private let titleLabel = UILabel()
    private let gestureBarView = UIView()
    private let tintView = UIView()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let feedback = UISelectionFeedbackGenerator()
    
    public var title: String {
        didSet {
            titleLabel.text = title
            contents?.title = title
        }
    }
    
    private var menuPresentationObserver: Any!
    
    private var contents: MenuContents?
    private var theme: MenuTheme
    private var longPress: UILongPressGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    
    private let itemsSource: () -> [MenuItem]
    
    public enum Alignment {
        case left
        case center
        case right
    }
    public var cornerRadius: CGFloat = 8.0
    public var titleAlignment: NSTextAlignment = .center
    public var contentAlignment = Alignment.right {
        didSet {
            if contentAlignment == .center {
                titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            } else {
                titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            }
        }
    }
    
    public init(title: String, theme: MenuTheme, itemsSource: @escaping () -> [MenuItem]) {
        self.itemsSource = itemsSource
        self.title = title
        self.theme = theme
        
        super.init(frame: .zero)
        
        titleLabel.text = title
        titleLabel.textColor = self.theme.titleColor
        titleLabel.textAlignment = self.titleAlignment
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let clippingView = UIView()
        clippingView.clipsToBounds = true
        
        addSubview(clippingView)
        
        clippingView.snp.makeConstraints {
            make in
            
            make.edges.equalToSuperview()
        }
        
        clippingView.layer.cornerRadius = self.theme.cornerRadius
        
        clippingView.addSubview(tintView)
        clippingView.addSubview(titleLabel)
        clippingView.addSubview(gestureBarView)
        //clippingView.addSubview(effectView)
        
        /*effectView.snp.makeConstraints {
            make in
            
            make.edges.equalToSuperview()
        }
        
        effectView.contentView.addSubview(tintView)
        effectView.contentView.addSubview(titleLabel)
        effectView.contentView.addSubview(gestureBarView)
        */
        
        tintView.snp.makeConstraints {
            make in
            
            make.edges.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints {
            make in
            
            //make.left.right.greaterThanOrEqualToSuperview().inset(12)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().inset(-8)
        }
        
        gestureBarView.layer.cornerRadius = 2
        gestureBarView.snp.makeConstraints {
            make in
            
            make.centerX.equalToSuperview()
            make.height.equalTo(2.0)
            make.width.equalTo(titleLabel.snp.width)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressGesture(_:)))
        longPress.minimumPressDuration = 0.0
        longPress.delegate = self
        addGestureRecognizer(longPress)
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        
        applyTheme(theme)
        effectView.effect = .none
        self.tintView.backgroundColor = .clear
        menuPresentationObserver = NotificationCenter.default.addObserver(forName: MenuView.menuWillPresent, object: nil, queue: nil) {
            [weak self] notification in
            
            if let poster = notification.object as? MenuView, let this = self, poster !== this {
                self?.hideContents(animated: false)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(menuPresentationObserver as Any)
    }
    
    //MARK: - Required Init
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - Gesture Handling
    
    private var gestureStart: Date = .distantPast
    
    @objc private func longPressGesture(_ sender: UILongPressGestureRecognizer) {
        
        //Highlight whatever we can
        if let contents = self.contents {
            let localPoint = sender.location(in: self)
            let contentsPoint = convert(localPoint, to: contents)
            
            if contents.pointInsideMenuShape(contentsPoint) {
                contents.highlightedPosition = CGPoint(x: contentsPoint.x, y: localPoint.y)
            }
        }

        switch sender.state {
        case .began:
            if !isShowingContents {
                gestureStart = Date()
                showContents()
            } else {
                gestureStart = .distantPast
            }
            
            contents?.isInteractiveDragActive = true
        case .cancelled:
            fallthrough
        case .ended:
            let gestureEnd = Date()
            
            contents?.isInteractiveDragActive = false
            
            if gestureEnd.timeIntervalSince(gestureStart) > 0.3 {
                selectPositionAndHideContents(sender)
            }
            
        default:
            ()
        }
    }
    
    @objc private func tapped(_ sender: UITapGestureRecognizer) {
        selectPositionAndHideContents(sender)
    }
    
    private func selectPositionAndHideContents(_ gesture: UIGestureRecognizer) {
        if let contents = contents {
            let point = convert(gesture.location(in: self), to: contents)
            
            if contents.point(inside: point, with: nil) {
                contents.selectPosition(point, completion: {
                    [weak self] menuItem in
                    
                    self?.hideContents(animated: true)
                    
                    menuItem.performAction()
                })
            } else {
                hideContents(animated: true)
            }
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == longPress && otherGestureRecognizer == tapGesture {
            return true
        }
        return false
    }
    
    public func showContents() {
        NotificationCenter.default.post(name: MenuView.menuWillPresent, object: self)
        
        let contents = MenuContents(name: title, items: itemsSource(), theme: theme)
        
        for view in contents.stackView.arrangedSubviews {
            if let view = view as? MenuItemView {
                var updatableView = view
                updatableView.updateLayout = {
                    [weak self] in
                    
                    self?.relayoutContents()
                }
            }
        }
        
        addSubview(contents)
        
        contents.snp.makeConstraints {
            make in
        
            switch contentAlignment {
            case .left:
                make.top.right.equalToSuperview()
            case .right:
                make.top.left.equalToSuperview()
            case .center:
                make.top.centerX.equalToSuperview()
            }
        }
        
        effectView.isHidden = true
        titleLabel.textColor = theme.titleFocusColor
        longPress?.minimumPressDuration = 0.05
        
        self.contents = contents
        tintView.backgroundColor = theme.backgroundTint
        setNeedsLayout()
        layoutIfNeeded()
        
        contents.generateMaskAndShadow(alignment: contentAlignment)
        contents.focusInitialViewIfNecessary()
        
        feedback.prepare()
        contents.highlightChanged = {
            [weak self] in
            
            self?.feedback.selectionChanged()
        }
    }
    
    public func hideContents(animated: Bool) {
        let contentsView = contents
        contents = nil
        
        longPress?.minimumPressDuration = 0.0
        
        effectView.isHidden = false
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                contentsView?.alpha = 0.0
                self.tintView.backgroundColor = .clear
                self.titleLabel.textColor = self.theme.titleColor
            }) {
                finished in
                contentsView?.removeFromSuperview()
            }
        } else {
            contentsView?.removeFromSuperview()
        }
    }
    
    private var isShowingContents: Bool {
        return contents != nil
    }
    
    //MARK: - Relayout
    
    private func relayoutContents() {
        if let contents = contents {
            setNeedsLayout()
            layoutIfNeeded()
            
            contents.generateMaskAndShadow(alignment: contentAlignment)
        }
    }
    
    //MARK: - Hit Testing
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let contents = contents else {
            return super.point(inside: point, with: event)
        }
        
        let contentsPoint = convert(point, to: contents)
        
        if !contents.pointInsideMenuShape(contentsPoint) {
            hideContents(animated: true)
        }
        
        return contents.pointInsideMenuShape(contentsPoint)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let contents = contents else {
            return super.hitTest(point, with: event)
        }
        
        let contentsPoint = convert(point, to: contents)
        
        if !contents.pointInsideMenuShape(contentsPoint) {
            hideContents(animated: true)
        } else {
            return contents.hitTest(contentsPoint, with: event)
        }
        
        return super.hitTest(point, with: event)
    }
    
    //MARK: - Theming
    
    public func applyTheme(_ theme: MenuTheme) {
        self.theme = theme
        
        titleLabel.font = theme.font
        titleLabel.textColor = theme.titleColor
        gestureBarView.backgroundColor = theme.gestureBarTint
        tintView.backgroundColor = theme.backgroundTint
        effectView.effect = theme.blurEffect
        cornerRadius = theme.cornerRadius
        contents?.applyTheme(theme)
    }
    
    public override func tintColorDidChange() {
        titleLabel.textColor = tintColor
    }
}
