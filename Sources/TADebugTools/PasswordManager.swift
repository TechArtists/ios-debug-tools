//
//  PasswordManager.swift
//  TADebugTools
//
//  Created by Robert Tataru on 15.07.2025.
//

import UIKit

public protocol PasswordStrategy {
    func isPasswordValid(_ input: String) -> Bool
    var keyboardType: UIKeyboardType { get }
}

struct StaticPasswordStrategy: PasswordStrategy {
    let correctPassword: String

    func isPasswordValid(_ input: String) -> Bool {
        return input == correctPassword
    }

    var keyboardType: UIKeyboardType {
        return correctPassword.isNumeric ? .numberPad : .default
    }
}

extension TADebugToolConfiguration {
    
    public enum PasswordType {
        case `static`(password: String)
        case dynamic(strategy: PasswordStrategy)
    }
}

struct PasswordManager {
    let strategy: PasswordStrategy

    init(passwordType: TADebugToolConfiguration.PasswordType) {
        switch passwordType {
        case .static(let password):
            self.strategy = StaticPasswordStrategy(correctPassword: password)
        case .dynamic(let strategy):
            self.strategy = strategy
        }
    }

    func isPasswordCorrect(_ input: String) -> Bool {
        strategy.isPasswordValid(input)
    }

    func keyBoardType() -> UIKeyboardType {
        strategy.keyboardType
    }
}
