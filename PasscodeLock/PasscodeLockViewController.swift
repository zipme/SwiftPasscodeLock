//
//  PasscodeLockViewController.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit

open class PasscodeLockViewController: UIViewController, PasscodeLockTypeDelegate {
    
    public enum LockState {
        case enterPasscode
        case setPasscode
        case changePasscode
        case removePasscode
        
        public func getState() -> PasscodeLockStateType {
            
            switch self {
            case .enterPasscode: return EnterPasscodeState()
            case .setPasscode: return SetPasscodeState()
            case .changePasscode: return ChangePasscodeState()
            case .removePasscode: return EnterPasscodeState(allowCancellation: true)
            }
        }
    }
    
    @IBOutlet weak var logoImageView: UIImageView!
    
    @IBOutlet open var placeholders: [PasscodeSignPlaceholderView] = [PasscodeSignPlaceholderView]()
    @IBOutlet open weak var cancelButton: UIButton?
    @IBOutlet open weak var deleteSignButton: UIButton?
    @IBOutlet open weak var touchIDButton: UIButton?
    @IBOutlet open weak var placeholdersX: NSLayoutConstraint?
    @IBOutlet open weak var errorView: UIView!
    @IBOutlet open weak var descriptionLabel: UILabel!
    
    open var successCallback: ((_ lock: PasscodeLockType) -> Void)?
    open var canceledCallback: (() -> Void)?
    open var dismissCompletionCallback: (()->Void)?
    open var animateOnDismiss: Bool
    open var notificationCenter: NotificationCenter?
    
    internal let passcodeConfiguration: PasscodeLockConfigurationType
    internal var passcodeLock: PasscodeLockType
    internal var isPlaceholdersAnimationCompleted = true
    
    fileprivate var shouldTryToAuthenticateWithBiometrics = true
    
    // MARK: - Initializers
    
    public init(state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true) {
        
        self.animateOnDismiss = animateOnDismiss
        
        passcodeConfiguration = configuration
        passcodeLock = PasscodeLock(state: state, configuration: configuration)
        
        let nibName = "PasscodeLockView"
        let bundle: Bundle = bundleForResource(nibName, ofType: "nib")
        
        super.init(nibName: nibName, bundle: bundle)
        
        passcodeLock.delegate = self
        notificationCenter = NotificationCenter.default
    }
    
    public convenience init(state: LockState, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true) {
        
        self.init(state: state.getState(), configuration: configuration, animateOnDismiss: animateOnDismiss)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
        clearEvents()
    }
    
    // MARK: - View
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        updatePasscodeView()
        
        setupEvents()
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldTryToAuthenticateWithBiometrics {
        
            authenticateWithBiometrics()
        }
    }
    
    internal func updatePasscodeView() {
        errorView.alpha = 0
        descriptionLabel?.text = passcodeLock.state.description
        if (!passcodeLock.state.isCancellableAction) {
            cancelButton?.isHidden = true
        }
        
        switch passcodeLock.biometricType {
        case .face:
            touchIDButton?.setImage(passcodeLock.configuration.faceIDIcon, for: .normal)
        case .touch:
            touchIDButton?.setImage(passcodeLock.configuration.touchIDIcon, for: .normal)
        default:
            break
        }
        
        touchIDButton?.isHidden = !passcodeLock.isTouchIDAllowed
        
        updateCancelAndDeleteButtons(passcodeCount: 0)
    }
    
    // MARK: - Events
    
    fileprivate func setupEvents() {
        
        notificationCenter?.addObserver(self, selector: #selector(PasscodeLockViewController.appWillEnterForegroundHandler(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.addObserver(self, selector: #selector(PasscodeLockViewController.appDidEnterBackgroundHandler(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    fileprivate func clearEvents() {
        
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        notificationCenter?.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    @objc open func appWillEnterForegroundHandler(_ notification: Notification) {
        
        authenticateWithBiometrics()
    }
    
    @objc open func appDidEnterBackgroundHandler(_ notification: Notification) {
        
        shouldTryToAuthenticateWithBiometrics = false
    }
    
    // MARK: - Actions
    
    @IBAction func passcodeSignButtonTap(_ sender: PasscodeSignButton) {
        
        guard isPlaceholdersAnimationCompleted else { return }
        
        passcodeLock.addSign(sender.passcodeSign)
    }
    
    @IBAction func cancelButtonTap(_ sender: UIButton) {
        dismissPasscodeLock(passcodeLock) { [weak self] () in
            self?.canceledCallback?()
        }
    }
    
    @IBAction func deleteSignButtonTap(_ sender: UIButton) {
        
        passcodeLock.removeSign()
    }
    
    @IBAction func touchIDButtonTap(_ sender: UIButton) {
        
        passcodeLock.authenticateWithBiometrics()
    }
    
    fileprivate func authenticateWithBiometrics() {
        
        if passcodeConfiguration.shouldRequestTouchIDImmediately && passcodeLock.isTouchIDAllowed {
            
            passcodeLock.authenticateWithBiometrics()
        }
    }
    
    internal func dismissPasscodeLock(_ lock: PasscodeLockType, completionHandler: (() -> Void)? = nil) {
        
        // if presented as modal
        if presentingViewController?.presentedViewController == self {
            
            dismiss(animated: animateOnDismiss, completion: { [weak self] () in
                
                self?.dismissCompletionCallback?()
                
                completionHandler?()
            })
            
            return
            
        // if pushed in a navigation controller
        } else if navigationController != nil {
        
            navigationController?.popViewController(animated: animateOnDismiss)
        }
        
        dismissCompletionCallback?()
        
        completionHandler?()
    }
    
    // MARK: - Animations
    
    internal func animateWrongPassword() {
        
        deleteSignButton?.isEnabled = false
        isPlaceholdersAnimationCompleted = false
        
        animatePlaceholders(placeholders, toState: .error)
        
        placeholdersX?.constant = -40
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.5, animations: {
            self.errorView.alpha = 1
            self.descriptionLabel.alpha = 0
        }) { (_) in
            self.resetErrorAnimate(delay: 0.5)
        }
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.2,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                self.placeholdersX?.constant = 0
                self.view.layoutIfNeeded()
            },
            completion: { completed in
                self.isPlaceholdersAnimationCompleted = true
                self.animatePlaceholders(self.placeholders, toState: .inactive)
        })
    }
    
    internal func resetErrorAnimate(delay: TimeInterval = 0) {
        UIView.animate(withDuration: 0.3, delay: delay, animations: {
            self.errorView.alpha = 0
            self.descriptionLabel.alpha = 1
        }, completion: nil)
    }
    
    internal func animatePlaceholders(_ placeholders: [PasscodeSignPlaceholderView], toState state: PasscodeSignPlaceholderView.State) {
        
        for placeholder in placeholders {
            
            placeholder.animateState(state)
        }
    }
    
    fileprivate func animatePlacehodlerAtIndex(_ index: Int, toState state: PasscodeSignPlaceholderView.State) {
        
        guard index < placeholders.count && index >= 0 else { return }
        
        placeholders[index].animateState(state)
    }
    
    fileprivate func updateCancelAndDeleteButtons(passcodeCount: Int) {
        if passcodeCount > 0 {
            cancelButton?.isHidden = true
            deleteSignButton?.isHidden = false
        } else {
            cancelButton?.isHidden = !passcodeLock.state.isCancellableAction
            deleteSignButton?.isHidden = true
        }
    }

    // MARK: - PasscodeLockDelegate
    
    open func passcodeLockDidSucceed(_ lock: PasscodeLockType) {
        
        deleteSignButton?.isEnabled = true
        animatePlaceholders(placeholders, toState: .inactive)
        dismissPasscodeLock(lock, completionHandler: { [weak self] () in
            self?.successCallback?(lock)
        })
    }
    
    open func passcodeLockDidFail(_ lock: PasscodeLockType) {
        
        animateWrongPassword()
    }
    
    open func passcodeLockDidChangeState(_ lock: PasscodeLockType) {
        
        updatePasscodeView()
        animatePlaceholders(placeholders, toState: .inactive)
        updateCancelAndDeleteButtons(passcodeCount: 0)
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, addedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .active)
        updateCancelAndDeleteButtons(passcodeCount: index + 1)
        if (index == 0) {
            resetErrorAnimate()
        }
    }
    
    open func passcodeLock(_ lock: PasscodeLockType, removedSignAtIndex index: Int) {
        
        animatePlacehodlerAtIndex(index, toState: .inactive)
        
        if index == 0 {
            updateCancelAndDeleteButtons(passcodeCount: index)
        }
    }
}
