//
//  ORTextInput.swift
//  GenericApp
//
//  Created by Michael Rademaker on 26/10/2020.
//  Copyright © 2020 OpenRemote. All rights reserved.
//

import UIKit

@IBDesignable
public class ORTextInput: UIView {

    private var textInput: UITextField!
    private var placeholderLabel: UILabel!
    private let activeTextColor = UIColor(named: "or_green") // Active color (green)
    private let inactiveTextColor = UIColor.lightGray // Inactive color (light gray)
    private var placeholderText = ""
    private var bottomLine: UIView!

    // Padding for placeholder animation
    private let placeholderDefaultFontSize: CGFloat = 16
    private let placeholderSmallFontSize: CGFloat = 12
    private let placeholderAnimationDuration = 0.2

    // Store an external delegate
    public weak var textFieldDelegate: UITextFieldDelegate?

    @IBInspectable var setPlaceholderText: String {
        get {
            return placeholderText
        }
        set(str) {
            placeholderText = str
            placeholderLabel?.text = str
            textInput?.placeholder = nil  // Clear the UITextField default placeholder
        }
    }

    public var textField: UITextField! {
        get {
            return textInput
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setupInputView()
        setupBottomLine()
        setupPlaceholderLabel()
        updatePlaceholderPosition(animated: false)
    }

    private func setupInputView() {
        if let _ = self.viewWithTag(1) { return }

        textInput = UITextField()
        textInput.tag = 1
        textInput.translatesAutoresizingMaskIntoConstraints = false
        textInput.clearButtonMode = .never
        textInput.textColor = activeTextColor
        textInput.delegate = self // Set the internal delegate

        // Set grey background for the text input
        textInput.backgroundColor = UIColor(white: 0.95, alpha: 1.0) // light grey color

        // Add some padding inside the text field
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 20))
        textInput.leftView = paddingView
        textInput.leftViewMode = .always

        self.addSubview(textInput)

        NSLayoutConstraint.activate([
            textInput.topAnchor.constraint(equalTo: self.topAnchor),
            textInput.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -2), // Leave space for the bottom line
            textInput.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            textInput.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }

    private func setupBottomLine() {
        // If bottom line already exists, return
        if bottomLine != nil { return }

        bottomLine = UIView()
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.backgroundColor = inactiveTextColor // Initially set to light gray

        self.addSubview(bottomLine)

        NSLayoutConstraint.activate([
            bottomLine.heightAnchor.constraint(equalToConstant: 1), // Height of the bottom line
            bottomLine.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    private func setupPlaceholderLabel() {
        if placeholderLabel != nil { return }

        placeholderLabel = UILabel()
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = placeholderText
        placeholderLabel.textColor = inactiveTextColor // Initially set to light gray
        placeholderLabel.font = UIFont.systemFont(ofSize: placeholderDefaultFontSize)

        self.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            placeholderLabel.centerYAnchor.constraint(equalTo: textInput.centerYAnchor)
        ])
    }

    // Function to update the placeholder position based on text field focus and content
    private func updatePlaceholderPosition(animated: Bool) {
        let isTextInputEmpty = textInput.text?.isEmpty ?? true
        let isFocused = textInput.isFirstResponder
        
        let targetFontSize = isFocused || !isTextInputEmpty ? placeholderSmallFontSize : placeholderDefaultFontSize
        let targetY = isFocused || !isTextInputEmpty ? -textInput.frame.height / 2 : 0

        let animationBlock = {
            self.placeholderLabel.font = UIFont.systemFont(ofSize: targetFontSize)
            self.placeholderLabel.transform = CGAffineTransform(translationX: 0, y: targetY)
        }

        if animated {
            UIView.animate(withDuration: placeholderAnimationDuration, animations: animationBlock)
        } else {
            animationBlock()
        }
    }
}

// MARK: - UITextFieldDelegate
extension ORTextInput: UITextFieldDelegate {

    // Forward delegate methods to the external delegate if set
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        updatePlaceholderPosition(animated: true)
        bottomLine.backgroundColor = activeTextColor // Change bottom line color to green when focused
        placeholderLabel.textColor = activeTextColor // Change placeholder color to green when focused
        textFieldDelegate?.textFieldDidBeginEditing?(textField) // Forward to external delegate
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        updatePlaceholderPosition(animated: true)
        bottomLine.backgroundColor = inactiveTextColor // Reset bottom line color to light gray
        placeholderLabel.textColor = inactiveTextColor // Reset placeholder color to light gray
        textFieldDelegate?.textFieldDidEndEditing?(textField) // Forward to external delegate
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        DispatchQueue.main.async {
            self.updatePlaceholderPosition(animated: true)
        }
        return textFieldDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true // Forward to external delegate
    }
}
