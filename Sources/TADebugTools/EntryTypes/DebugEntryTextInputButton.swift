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
//  DebugEntryTextInputButton.swift
//  TADebugTools
//
//  Created by Robert Tataru on 13.02.2025.
//

import SwiftUI

public class DebugEntryTextInputButton: DebugEntryActionProtocol, ObservableObject {
    public typealias Value = String

    weak public var taDebugToolConfiguration: TADebugToolConfiguration?
    
    public var id: UUID
    public var title: String
    public var wrappedValue: String
    public var labels: [DebugToolLabel]
    
    public var onTapGesture: (@Sendable () -> Void)? = nil
    public var onTapShowDestinationView: AnyView? = nil
    
    public lazy var stream: AsyncStream<String> = { [weak self] in
        AsyncStream { continuation in
            self?.continuation = continuation
        }
    }()
    public var continuation: AsyncStream<String>.Continuation?
    
    public var onUpdateFromDebugTool: ((String) -> Void)?
    public var onUpdateFromApp: ((String) -> Void) = { _ in }
    
    public var onConfirm: (String) -> Void

    public init(
        title: String,
        wrappedValue: String = "",
        labels: [DebugToolLabel] = [],
        onConfirm: @escaping (String) -> Void,
        taDebugToolConfiguration: TADebugToolConfiguration? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.wrappedValue = wrappedValue
        self.labels = labels
        self.onConfirm = onConfirm
        self.taDebugToolConfiguration = taDebugToolConfiguration
    }
    
    @MainActor
    public var renderView: AnyView {
        AnyView(DebugEntryTextInputButtonView(debugEntry: self))
    }
}

public struct TextFieldAlert {
    let title: String
    let message: String?
    let placeholder: String
    let accept: String
    let cancel: String
    let action: (String?) -> Void
}

// MARK: - TextFieldAlertWrapper

struct TextFieldAlertWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: TextFieldAlert

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }
        
        let alertController = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = alert.placeholder
        }
        
        alertController.addAction(UIAlertAction(title: alert.cancel, style: .cancel) { _ in
            isPresented = false
            alert.action(nil)
        })
        
        let confirmAction = UIAlertAction(title: alert.accept, style: .default) { _ in
            isPresented = false
            let text = alertController.textFields?.first?.text
            alert.action(text)
        }
        
        alertController.addAction(confirmAction)
        alertController.preferredAction = confirmAction
        
        DispatchQueue.main.async {
            uiViewController.present(alertController, animated: true, completion: nil)
        }
    }
}

extension View {
    public func textFieldAlert(isPresented: Binding<Bool>, alert: TextFieldAlert) -> some View {
        self.background(TextFieldAlertWrapper(isPresented: isPresented, alert: alert))
    }
}

// MARK: - DebugEntryTextInputButtonView

public struct DebugEntryTextInputButtonView: View {
    @ObservedObject var debugEntry: DebugEntryTextInputButton
    @State private var isShowingAlert = false

    public var body: some View {
        Button(action: {
            isShowingAlert = true
        }) {
            Text(debugEntry.title)
        }
        .textFieldAlert(isPresented: $isShowingAlert, alert: .init(
            title: "Enter text",
            message: nil,
            placeholder: "Type here",
            accept: "Confirm",
            cancel: "Cancel",
            action: { text in
                if let text = text {
                    debugEntry.onConfirm(text)
                }
            }
        ))
    }
}
