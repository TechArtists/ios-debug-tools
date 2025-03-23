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
//  Debuggable.swift
//  TADebugTools
//
//  Created by Robert Tataru on 19.03.2025.
//

import Foundation
import SwiftUI
import Combine

@propertyWrapper public struct Debuggable<Value> {
    
    /// Type alias for a synchronous button handler.
    public typealias ButtonHandler = (@Sendable () -> Void)
    /// The wrapped value is unavailable.
    ///
    /// Getting or setting the value will throw a fatal error.
    @available(*, unavailable, message: "@DebugEntry can only be applied to classes")
    public var wrappedValue: Value {
        get { fatalError("Getting the wrapped value from a @DebugEntry property wrapper is not supported") }
        // swiftlint:disable:next unused_setter_value
        set { fatalError("Setting the wrapped value on a @DebugEntry property wrapper is not supported") }
    }
    
    public var projectedValue: Binding<Value> {
        .init {
            anyDebugEntry.wrappedValue
        } set: { newValue in
            anyDebugEntry.onUpdateFromApp(newValue)
        }
    }
    
    let anyDebugEntry : AnyDebugEntry<Value>
    let debugSection  : DebugToolSection
    
    private var cancellables: Set<AnyCancellable> = []
    
    public init(
        wrappedValue: Value, key: String, title: String? = nil,
        section: DebugToolSection = .others, storage: AnyStorage<Value>? = nil
    ) where Value == Bool {
        let storedValue = UserDefaults.standard.object(forKey: key) as? Bool ?? wrappedValue
        let debugEntry = DebugEntryBool(
            title: title ?? key.convertToTitleFormat,
            wrappedValue: storedValue,
            storage: storage ?? AnyStorage(UserDefaultsStorage(key: key, defaultValue: storedValue))
        )
        self.anyDebugEntry = AnyDebugEntry(debugEntry)
        self.debugSection = section
    }
    
    public init(
        wrappedValue: Value, key: String, title: String? = nil, section: DebugToolSection = .others,
        storage: AnyStorage<Value>? = nil, textType: DebugTextType = .constant
    ) where Value == String {
        let storedValue = UserDefaults.standard.object(forKey: key) as? String ?? wrappedValue
        switch textType {
        case .constant:
            let debugEntry = DebugEntryConstant(
                title: title ?? key.convertToTitleFormat,
                wrappedValue: storedValue,
                storage: storage ?? AnyStorage(UserDefaultsStorage(key: key, defaultValue: storedValue))
            )
            self.anyDebugEntry = AnyDebugEntry(debugEntry)
        case .textField:
            let debugEntry = DebugEntryTextField(
                title: title ?? key.convertToTitleFormat,
                wrappedValue: storedValue,
                storage: storage ?? AnyStorage(UserDefaultsStorage(key: key, defaultValue: storedValue))
            )
            self.anyDebugEntry = AnyDebugEntry(debugEntry)
        }
        self.debugSection = section
    }
    
    public init(
        wrappedValue: Value, title: String,
        section: DebugToolSection = .others, storage: AnyStorage<Value>? = nil
    ) where Value == ButtonHandler {
        let debugEntry = DebugEntryButton(
            title: title,
            wrappedValue: wrappedValue
        )
        self.anyDebugEntry = AnyDebugEntry(debugEntry)
        self.debugSection = section
    }

    public init(
        wrappedValue: Value, key: String, title: String? = nil,
        section: DebugToolSection = .others, storage: AnyStorage<Value>? = nil
    ) where Value: RawRepresentable & CaseIterable & Hashable, Value.RawValue == String {
        let storedValue: Value
        if let rawValue = UserDefaults.standard.value(forKey: key) as? Value.RawValue,
           let convertedValue = Value(rawValue: rawValue) {
            storedValue = convertedValue
        } else {
            storedValue = wrappedValue
        }
        let debugEntry = DebugEntryOptions(
            title: title ?? key.convertToTitleFormat,
            wrappedValue: storedValue,
            storage: storage ?? AnyStorage(UserDefaultsRawRepresentableStorage(key: key, defaultValue: wrappedValue))
        )
        self.anyDebugEntry = AnyDebugEntry(debugEntry)
        self.debugSection = section
    }
    
    static public subscript<EnclosingSelf: TADebugToolConfiguration>(
        _enclosingInstance instance: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> Value {
        get {
            instance.prepareDebuggableIfNeeded()
            return instance[keyPath: storageKeyPath].anyDebugEntry.wrappedValue
        }
        set {
            instance.prepareDebuggableIfNeeded()
            instance[keyPath: storageKeyPath].anyDebugEntry.onUpdateFromApp(newValue)
            instance.objectWillChange.send()
        }
    }
}

extension Debuggable {
    public enum DebugTextType {
        case constant
        case textField
    }
}

extension Debuggable: Preparable {
    
    func prepare(ownedBy debugConfiguration: TADebugToolConfiguration) {
        debugConfiguration.addEntry(anyDebugEntry, to: debugSection)
    }
}

protocol Preparable {
    
    func prepare( ownedBy debugConfiguration: TADebugToolConfiguration)
}
