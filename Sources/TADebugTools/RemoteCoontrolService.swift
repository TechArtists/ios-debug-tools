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

////
////  QAService.swift
////  TADebugTools
////
////  Created by Robert Tataru on 09.12.2024.
////
//
//import FlyingFox
//import Foundation
//import Combine
//
//actor RemoteControlService {
//    private var server: HTTPServer?
//    private var port: UInt16 = 8080
//    private var registeredRoutes: [String] = []
//    
//    lazy var serverAddressStream: AsyncStream<String?> = {
//        AsyncStream { (continuation: AsyncStream<String?>.Continuation) -> Void in
//            self.continuation = continuation
//        }
//    }()
//    var continuation: AsyncStream<String?>.Continuation?
//    
//    var configuration: TADebugToolConfiguration
//    
//    init(configuration: TADebugToolConfiguration) {
//        self.configuration = configuration
//    }
//
//    func start() async {
//        guard server == nil else { return }
//        
//        var currentPort = port
//        var attempts = 0
//        let maxAttempts = 10
//
//        while attempts < maxAttempts {
//            do {
//                server = HTTPServer(port: currentPort)
//                
//                Task {
//                    try await server?.run()
//                }
//                
//                await self.addRoutes()
//                continuation?.yield(getAddress())
//                print("Server started on port \(currentPort)")
//                return
//            } catch {
//                print("Port \(currentPort) is in use. Trying another port...")
//                currentPort += 1
//                attempts += 1
//            }
//        }
//        
//        print("Failed to start server after \(maxAttempts) attempts.")
//    }
//    
//    func getAddress() -> String? {
//        guard let ipAdress = IPAddressUtil.getDeviceIPAddress() else { return nil }
//        
//        return "http://\(ipAdress):\(port)"
//    }
//
//    private func addRoutes() async {
//        guard let server = server else { return }
//        
//        for (section, entries) in await configuration.sections {
//            for entry in entries {
//                let routePath = "\(section.rawValue)/\(await entry.title)".replacingOccurrences(of: " ", with: "_")
//                
//                if let entry = entry as? DebugEntryBool {
//                    await addRouteForDebugEntryBool(entry, routePath: routePath)
//                } else if let entry = entry as? any DebugEntryActionProtocol {
//                    await addRouteForDebugEntryAction(entry, routePath: routePath)
//                } else if let entry = entry as? DebugEntryConstant<Sendable> {
//                    await addRouteForDebugEntryConstant(entry, routePath: routePath)
//                } else if let entry = entry as? DebugEntryTextField {
//                    await addRouteForDebugEntryTextField(entry, routePath: routePath)
//                }
//            }
//        }
//        
//        await addStaticRoutes()
//    }
//
//    // MARK: - Route Handlers
//
//    private func addRouteForDebugEntryBool(_ entry: DebugEntryBool, routePath: String) async {
//        let getRoute = "GET /\(routePath)"
//        let postRoute = "POST /\(routePath)"
//        registeredRoutes.append(getRoute)
//        registeredRoutes.append(postRoute)
//    
//        await server?.appendRoute(HTTPRoute(stringLiteral: getRoute)) { _ in
//            let value = await MainActor.run { entry.wrappedValue }
//            let jsonData = try JSONSerialization.data(withJSONObject: ["value": value], options: .prettyPrinted)
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: jsonData
//            )
//        }
//        
//        await server?.appendRoute(HTTPRoute(postRoute)) { request in
//            guard let body = try? await request.bodyData,
//                  let jsonObject = try? JSONSerialization.jsonObject(with: body, options: []),
//                  let json = jsonObject as? [String: Any],
//                  let newValue = json["value"] as? Bool else {
//                return HTTPResponse(statusCode: .badRequest, body: "Invalid request body".data(using: .utf8)!)
//            }
//            
//            await MainActor.run {
//                entry.binding.wrappedValue = newValue
//            }
//            return HTTPResponse(statusCode: .ok, body: "Value updated".data(using: .utf8)!)
//        }
//    }
//
//    private func addRouteForDebugEntryAction(_ entry: any DebugEntryActionProtocol, routePath: String) async {
//        let postRoute = "POST /\(routePath)"
//        registeredRoutes.append(postRoute)
//        
//        await server?.appendRoute(HTTPRoute(stringLiteral: postRoute)) { _ in
//            await entry.onTapGesture?()
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: "Action triggered".data(using: .utf8)!
//            )
//        }
//    }
//
//    private func addRouteForDebugEntryConstant(_ entry: DebugEntryConstant<Sendable>, routePath: String) async {
//        let getRoute = "GET /\(routePath)"
//        registeredRoutes.append(getRoute)
//        
//        await server?.appendRoute(HTTPRoute(stringLiteral: getRoute)) { _ in
//            let value: Any = await MainActor.run { entry.binding.wrappedValue }
//            
//            let jsonData2 = try await JSONSerialization.data(withJSONObject: ["value": value], options: .prettyPrinted)
//            let jsonData = Data()
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: jsonData
//            )
//        }
//    }
//
//    private func addRouteForDebugEntryTextField(_ entry: DebugEntryTextField, routePath: String) async {
//        let getRoute = "GET /\(routePath)"
//        let postRoute = "POST /\(routePath)"
//        registeredRoutes.append(getRoute)
//        registeredRoutes.append(postRoute)
//            
//        await server?.appendRoute(HTTPRoute(stringLiteral: getRoute)) { _ in
//            let value = await MainActor.run { entry.binding.wrappedValue }
//            let jsonData = try! JSONSerialization.data(withJSONObject: ["value": value], options: .prettyPrinted)
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: jsonData
//            )
//        }
//        
//        await server?.appendRoute(HTTPRoute(stringLiteral: postRoute)) { request in
//            guard let bodyData = try? await request.bodyData,
//                  let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
//                  let newValue = json["value"] as? String else {
//                return HTTPResponse(
//                    statusCode: .badRequest,
//                    body: "Invalid request body".data(using: .utf8)!
//                )
//            }
//            
//            await MainActor.run {
//                entry.binding.wrappedValue = newValue
//            }
//            
//            return HTTPResponse(
//                statusCode: .ok,
//                body: "Value updated successfully".data(using: .utf8)!
//            )
//        }
//    }
//
//    private func addStaticRoutes() async {
//        registeredRoutes.append("GET /userDefaults")
//        await server?.appendRoute("GET /userDefaults") { _ in
//            let defaults = UserDefaults.standard.dictionaryRepresentation()
//            let serializableDefaults = defaults.compactMapValues { value -> Any? in
//                if JSONSerialization.isValidJSONObject([value]) {
//                    return value
//                }
//                if let dateValue = value as? Date {
//                    return dateValue.ISO8601Format()
//                }
//                if let dataValue = value as? Data {
//                    return dataValue.base64EncodedString()
//                }
//                
//                return String(describing: value)
//           }
//            
//            let jsonData = try JSONSerialization.data(withJSONObject: serializableDefaults, options: .sortedKeys)
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: jsonData
//            )
//        }
//        
//        registeredRoutes.append("GET /appInfo")
//        await server?.appendRoute("GET /appInfo") { _ in
//            let appInfo = [
//                "appName": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown",
//                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
//                "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
//            ]
//            let jsonData = try JSONSerialization.data(withJSONObject: appInfo, options: .prettyPrinted)
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: jsonData
//            )
//        }
//        
//        await server?.appendRoute("GET /routes") { _ in
//            let jsonData = try await JSONSerialization.data(withJSONObject: self.registeredRoutes, options: .prettyPrinted)
//            return HTTPResponse(
//                statusCode: .ok,
//                headers: [.contentType: "application/json"],
//                body: jsonData
//            )
//        }
//    }
//}
