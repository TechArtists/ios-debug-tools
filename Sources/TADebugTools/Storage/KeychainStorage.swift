/*
MIT License

Copyright (c) 2025 Tech Artists Agency

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
//
//  KeychainStorage.swift
//  TADebugTools
//
//  Created by Robert Tataru on 20.03.2025.
//

import Foundation
import Combine

final class KeychainStorage<Value: Codable>: Storage {
    private let key: String
    private let subject: CurrentValueSubject<Value, Never>
    private var cancellables: Set<AnyCancellable> = []
    private let defaultValue: Value
    
    var value: Value {
        get {
            self.loadFromKeychain() ?? defaultValue
        }
        set {
            self.saveToKeychain(newValue)
            self.subject.send(newValue)
        }
    }
    
    var publisher: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }
    
    init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
        self.subject = CurrentValueSubject<Value, Never>(defaultValue)
        
        if let initialValue = self.loadFromKeychain() {
            self.subject.send(initialValue)
        }
    }
    
    private func saveToKeychain(_ value: Value) {
        do {
            let data = try JSONEncoder().encode(value)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            SecItemDelete(query as CFDictionary)
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                print("Keychain save error: \(status)")
            }
        } catch {
            print("Keychain encoding error: \(error)")
        }
    }
    
    private func loadFromKeychain() -> Value? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            print("Keychain decoding error: \(error)")
            return nil
        }
    }
}
