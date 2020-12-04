//
//  SBATrackedLoggingStepViewController.swift
//  BridgeApp
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit

/// Extend `SBATrackedItemsLoggingStepObject` to implement the step view controller vendor.
extension SBATrackedItemsLoggingStepObject : RSDStepViewControllerVendor {
}

/// Table step view for logging tracked data.
open class SBATrackedLoggingStepViewController: RSDTableStepViewController {
    
    override open func registerReuseIdentifierIfNeeded(_ reuseIdentifier: String) {
        guard !_registeredIdentifiers.contains(reuseIdentifier) else { return }
        _registeredIdentifiers.insert(reuseIdentifier)
        
        let reuseId = RSDFormUIHint(rawValue: reuseIdentifier)
        switch reuseId {
        case .logging:
            tableView.register(SBATrackedLoggingCell.nib, forCellReuseIdentifier: reuseIdentifier)
        default:
            super.registerReuseIdentifierIfNeeded(reuseIdentifier)
        }
    }
    private var _registeredIdentifiers = Set<String>()
}

/// Table cell for logging tracked data.
open class SBATrackedLoggingCell: RSDButtonCell {
    
    /// The nib to use with this cell. Default will instantiate a `SBATrackedLoggingCell`.
    open class var nib: UINib {
        let bundle = Bundle.module
        let nibName = String(describing: SBATrackedLoggingCell.self)
        return UINib(nibName: nibName, bundle: bundle)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var checkmarkView: RSDCheckmarkView!
    @IBOutlet weak var loggedLabel: UILabel!
    @IBOutlet weak var loggedDateLabel: UILabel!
    

    override open func setDesignSystem(_ designSystem: RSDDesignSystem, with background: RSDColorTile) {
        super.setDesignSystem(designSystem, with: background)
        self.contentView.backgroundColor = background.color
        updateCheckmarkColor()
    }
    
    func updateCheckmarkColor() {
        let designSystem = self.designSystem ?? RSDDesignSystem()
        self.checkmarkView.backgroundColor = designSystem.colorRules.palette.secondary.normal.color
    }
    
    var loggedButton: RSDRoundedButton? {
        return self.actionButton as? RSDRoundedButton
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        
        updateCheckmarkColor()
        self.checkmarkView.isHidden = true
        self.loggedLabel.isHidden = true
        self.loggedDateLabel.isHidden = true
        
        self.loggedButton?.isSecondaryButton = false
        
        let buttonTitle = Localization.localizedString("LOG_BUTTON_TITLE")
        self.actionButton.setTitle(buttonTitle, for: .normal)
        
        self.loggedLabel.text = Localization.localizedString("LOGGED_LABEL_TITLE")
    }
    
    override open var tableItem: RSDTableItem! {
        didSet {
            guard let loggingItem = tableItem as? SBATrackedLoggingTableItem
                else {
                    return
            }
            self.titleLabel.text = loggingItem.title
            if let loggedDate = loggingItem.loggedDate {
                self.setLoggedDate(loggedDate, animated: _loggedDate == nil)
            } else {
                self.actionButton.isHidden = false
                self.checkmarkView.isHidden = true
                self.loggedLabel.isHidden = true
                self.loggedDateLabel.isHidden = true
            }
        }
    }
    
    private var _loggedDate: Date?
    
    func setLoggedDate(_ loggedDate: Date, animated: Bool) {
        _loggedDate = loggedDate
        
        // Set the timestamp
        self.loggedDateLabel.text = DateFormatter.localizedString(from: loggedDate, dateStyle: .none, timeStyle: .short)
        guard self.loggedDateLabel.isHidden else { return }
        
        // crossfade between unselected and selected state.
        self.checkmarkView.alpha = 0
        self.loggedLabel.alpha = 0
        self.loggedDateLabel.alpha = 0
        self.checkmarkView.isHidden = false
        self.loggedLabel.isHidden = false
        self.loggedDateLabel.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.checkmarkView.alpha = 1
            self.loggedLabel.alpha = 1
            self.loggedDateLabel.alpha = 1
            self.actionButton.alpha = 0
        }) { (_) in
            self.actionButton.isHidden = true
            self.actionButton.alpha = 1
        }
    }
}
