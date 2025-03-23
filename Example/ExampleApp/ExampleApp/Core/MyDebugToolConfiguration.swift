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
//  MyDebugToolConfiguration.swift
//  ExampleApp
//
//  Created by Robert Tataru on 31.01.2025.
//

import SwiftUI
import TADebugTools

let sampleFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("example.pdf")

public class MyDebugToolConfiguration: TADebugToolConfiguration {
    
    let isPremiumEntry: DebugEntryBool = .init(
        title: "Is Premium",
        wrappedValue: UserDefaults.standard.bool(forKey: "isPremium")
    )
    
    let isPremium2Entry: DebugEntryBool = .init(
        title: "Is Premium2",
        wrappedValue: UserDefaults.standard.bool(forKey: "isPremium2")
    )
    
    let databaseSignUpEntry: DebugEntryBool = .init(
        title: "Database Sign Up",
        wrappedValue: nil
    )
    
    let mailSenderEntry: DebugEntryButton = .init(
        title: "Send Logs To Mail",
        wrappedValue: {},
        onTapShowDestinationView: {
            AnyView(MailComposeView(fileURL: sampleFileURL))
        }
    )
    
    let textFieldEntry: DebugEntryTextField = .init(title: "Example TextField", wrappedValue: "Default")
    
    let buttonTexfieldEntry: DebugEntryTextFieldAlertButton = .init(title: "Example button with TextField") { text in
        print(text)
    }
    
    override init(password: String? = nil) {
        
        super.init(password: password)
        addEntriesToSections()
    }
    
    func addEntriesToSections() {
        
        self.addEntry( isPremiumEntry, to: .app)
        
        self.addEntry( isPremium2Entry, to: .app)
        
        self.addEntry( mailSenderEntry, to: .app)
        
        self.addEntry( buttonTexfieldEntry, to: .others)
        
        self.addEntry(textFieldEntry, to: .others)
    }
    
    //pass the service here
    func addDatabaseSignUpEntry() {
        self.addEntry(
            databaseSignUpEntry,
            to: .others
        )
    }
}
