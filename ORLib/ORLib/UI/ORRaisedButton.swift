//
//  ORRaisedButton.swift
//  ORLib
//
//  Created by Michael Rademaker on 05/09/2024.
//

import UIKit

@IBDesignable
public class ORRaisedButton: UIButton {
    
    // Initializer to set up the button when created programmatically
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    // Initializer to set up the button when created from a storyboard or xib
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupButton()
    }
    
    private func setupButton() {
        // Rounded corners
        self.layer.cornerRadius = 4.0
        
        // Background color (you can set a different color if needed)
        self.backgroundColor = UIColor(named: "or_green") ?? UIColor.systemBlue
        
        // Text color
        self.setTitleColor(.white, for: .normal)
        
        // Font (Optional: Customize the font if needed)
        self.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        // Shadow to create the "raised" effect
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 4.0
        self.layer.shadowOpacity = 0.3
        self.layer.masksToBounds = false
        self.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        
        // Set default state to be fully visible
        updateAppearance()
    }
    
    // Add touch-down animation for a ripple effect (approximate)
    public override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.2) {
                    self.alpha = 0.7
                }
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.alpha = 1.0
                }
            }
        }
    }
    
    public override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    // Function to update appearance based on the enabled state
    private func updateAppearance() {
        if isEnabled {
            self.alpha = 1.0  // Fully visible when enabled
        } else {
            self.alpha = 0.5  // Semi-transparent when disabled
        }
    }
    
}

