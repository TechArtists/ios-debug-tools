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
//  MailSenderView.swift
//  TADebugTools
//
//  Created by Robert Tataru on 03.02.2025.
//

import SwiftUI
import MessageUI
import MobileCoreServices
import UniformTypeIdentifiers

public struct MailSenderView: View {
    @State private var email: String = ""
    @State private var isShowingMailView = false
    @State private var showMailErrorAlert = false

    var fileURL: URL
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .autocorrectionDisabled()

                Text("File: \(fileURL.lastPathComponent)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                Button("Send File") {
                    if MFMailComposeViewController.canSendMail() {
                        isShowingMailView = true
                    } else {
                        showMailErrorAlert = true
                    }
                }
                .padding()
                .alert(isPresented: $showMailErrorAlert) {
                    Alert(title: Text("Mail Services Unavailable"),
                          message: Text("Your device is not configured to send mail."),
                          dismissButton: .default(Text("OK")))
                }

                Spacer()
            }
            .navigationTitle("Send File via Email")
            .sheet(isPresented: $isShowingMailView) {
                MailComposeView(fileURL: fileURL, recipientEmail: email)
            }
        }
    }
}

public struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentation
    let recipientEmail: String?
    let fileURL: URL
    
    public init( fileURL: URL, recipientEmail: String? = nil) {
        self.recipientEmail = recipientEmail
        self.fileURL = fileURL
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = context.coordinator

        if let recipientEmail {
            mailVC.setToRecipients([recipientEmail])
        }
        mailVC.setSubject("File Attachment")
        mailVC.setMessageBody("Please find the attached file.", isHTML: false)

        if let fileData = try? Data(contentsOf: fileURL) {
            let mimeType = mimeTypeForPath(fileURL.path)
            let fileName = fileURL.lastPathComponent
            mailVC.addAttachmentData(fileData, mimeType: mimeType, fileName: fileName)
        }

        return mailVC
    }

    public func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) { }

    public class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        @MainActor public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentation.wrappedValue.dismiss()
        }
    }

    // Get MIME type based on file extension
    func mimeTypeForPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let pathExtension = url.pathExtension

        if
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return mimeType as String
        }
        return "application/octet-stream"
    }
}

struct MailSenderView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("example.pdf")
        MailSenderView(fileURL: sampleFileURL)
    }
}
