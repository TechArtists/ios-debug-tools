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
//  UserDefaultsStorage.swift
//  TADebugTools
//
//  Created by Robert Tataru on 20.03.2025.
//

import Combine
import Foundation

final class UserDefaultsStorage<Value>: Storage {
    private let key: String
    private let defaultValue: Value
    private let subject: CurrentValueSubject<Value, Never>
    private var cancellables: Set<AnyCancellable> = []

    var value: Value {
        get {
            return UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: self.key)
            self.subject.send(newValue)
        }
    }

    var publisher: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }

    init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
        let initialValue = UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        self.subject = CurrentValueSubject<Value, Never>(initialValue)

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newValue = UserDefaults.standard.object(forKey: self.key) as? Value ?? self.defaultValue
                self.subject.send(newValue)
            }
            .store(in: &cancellables)
    }
}

// Specialized storage for RawRepresentable values
final class UserDefaultsRawRepresentableStorage<Value: RawRepresentable>: Storage where Value.RawValue: Any {
    private let key: String
    private let defaultValue: Value
    private let subject: CurrentValueSubject<Value, Never>
    private var cancellables: Set<AnyCancellable> = []

    var value: Value {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: key) as? Value.RawValue,
               let convertedValue = Value(rawValue: rawValue) {
                return convertedValue
            }
            return defaultValue
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: self.key)
            self.subject.send(newValue)
        }
    }

    var publisher: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }

    init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue

        let storedValue: Value
        if let rawValue = UserDefaults.standard.value(forKey: key) as? Value.RawValue,
           let convertedValue = Value(rawValue: rawValue) {
            storedValue = convertedValue
        } else {
            storedValue = defaultValue
        }
        self.subject = CurrentValueSubject<Value, Never>(storedValue)

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newValue: Value
                if let rawValue = UserDefaults.standard.value(forKey: self.key) as? Value.RawValue,
                   let convertedValue = Value(rawValue: rawValue) {
                    newValue = convertedValue
                } else {
                    newValue = self.defaultValue
                }
                self.subject.send(newValue)
            }
            .store(in: &cancellables)
    }
}
