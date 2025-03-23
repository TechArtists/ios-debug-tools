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
//  AnyStorage.swift
//  TADebugTools
//
//  Created by Robert Tataru on 20.03.2025.
//

import Combine
import Foundation

final public class AnyStorage<Value>: ObservableObject {
    private let setValue: (Value) -> Void
    private let storagePublisher: AnyPublisher<Value, Never>
    
    @Published private(set) var value: Value
    private var cancellables: Set<AnyCancellable> = []
    
    private let writeQueue = DispatchQueue(label: "com.storage.write", attributes: .concurrent)
    
    init<S: Storage>(_ storage: S) where S.Value == Value {
        self.setValue = { newValue in
            DispatchQueue.global(qos: .utility).async {
                storage.value = newValue
            }
        }
        self.storagePublisher = storage.publisher
        self.value = storage.value
        
        self.storagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self,
                      let currentValueEquatable = self.value as? any Equatable,
                      let newValueEquatable = newValue as? any Equatable,
                      AnyEquatable(currentValueEquatable).equals(newValueEquatable) else { return }
                
                self.value = newValue
            }
            .store(in: &cancellables)
    }
    
    func update(_ newValue: Value) {
        writeQueue.async(flags: .barrier) { [weak self] in
            self?.setValue(newValue)
        }
    }
}
