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
//  UIApplication+Share.swift
//  TADebugTools
//
//  Created by Robert Tataru on 05.02.2025.
//

import UIKit

extension UIApplication {
    public func presentShareSheet(with fileURL: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        // Dismiss any active modal
        rootViewController.dismiss(animated: true) {
            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

            // iPad compatibility
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = rootViewController.view
                popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                      y: rootViewController.view.bounds.midY,
                                                      width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }

            rootViewController.present(activityViewController, animated: true)
        }
    }
}
