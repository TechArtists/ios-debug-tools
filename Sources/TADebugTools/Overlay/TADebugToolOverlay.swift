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

import SwiftUI

public extension View {
    func taDebugToolOverlay(
        configuration: TADebugToolConfiguration,
        liveFeedSources: [TADebugLiveFeedSource] = [],
        allowedPositions: [TADebugToolCollapsedPosition] = TADebugToolCollapsedPosition.allCases,
        initialPosition: TADebugToolCollapsedPosition = .bottomTrailing,
        sheetConfiguration: TADebugToolSheetConfiguration = .default
    ) -> some View {
        modifier(
            TADebugToolOverlayModifier(
                configuration: configuration,
                liveFeedSources: liveFeedSources,
                allowedPositions: allowedPositions,
                initialPosition: initialPosition,
                sheetConfiguration: sheetConfiguration
            )
        )
    }
}

private struct TADebugToolOverlayModifier: ViewModifier {
    @ObservedObject private var configuration: TADebugToolConfiguration
    let liveFeedSources: [TADebugLiveFeedSource]
    let allowedPositions: [TADebugToolCollapsedPosition]
    let initialPosition: TADebugToolCollapsedPosition
    let sheetConfiguration: TADebugToolSheetConfiguration

    @State private var isSheetPresented = false
    @State private var selectedDetent: PresentationDetent
    @State private var selectedPosition: TADebugToolCollapsedPosition
    @StateObject private var liveFeedStore = TADebugLiveFeedStore()

    private let positionStore = TADebugToolCollapsedPositionStore(key: DefaultsConstants.collapsedLauncherPosition)

    init(
        configuration: TADebugToolConfiguration,
        liveFeedSources: [TADebugLiveFeedSource],
        allowedPositions: [TADebugToolCollapsedPosition],
        initialPosition: TADebugToolCollapsedPosition,
        sheetConfiguration: TADebugToolSheetConfiguration
    ) {
        self._configuration = ObservedObject(wrappedValue: configuration)
        self.liveFeedSources = liveFeedSources
        self.allowedPositions = allowedPositions
        self.initialPosition = initialPosition
        self.sheetConfiguration = sheetConfiguration
        self._selectedDetent = State(initialValue: sheetConfiguration.initialDetent)
        self._selectedPosition = State(initialValue: initialPosition)
    }

    private var sanitizedAllowedPositions: [TADebugToolCollapsedPosition] {
        allowedPositions.reduce(into: [TADebugToolCollapsedPosition]()) { partialResult, position in
            guard !partialResult.contains(position) else {
                return
            }

            partialResult.append(position)
        }
        .nonEmpty(or: [initialPosition])
    }

    private var liveFeedSourceSignature: String {
        liveFeedSources.map(\.id).joined(separator: ",")
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if configuration.isEmbeddedDebugLauncherEnabled {
                    GeometryReader { proxy in
                        ZStack(alignment: selectedPosition.alignment) {
                            Color.clear
                                .allowsHitTesting(false)

                            launcher
                                .padding(selectedPosition.launcherPadding(safeAreaInsets: proxy.safeAreaInsets))
                        }
                    }
                }
            }
            .sheet(isPresented: $isSheetPresented) {
                TADebugToolOverlaySheet(
                    configuration: configuration,
                    liveFeedSources: liveFeedSources,
                    liveFeedStore: liveFeedStore,
                    allowedPositions: sanitizedAllowedPositions,
                    selectedPosition: $selectedPosition
                )
                .presentationDetents(Set(sheetConfiguration.detents), selection: $selectedDetent)
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                let restoredPosition = positionStore.load(
                    allowedPositions: sanitizedAllowedPositions,
                    initialPosition: initialPosition
                )
                selectedPosition = restoredPosition
                positionStore.save(restoredPosition)
                selectedDetent = sheetConfiguration.initialDetent
            }
            .task(id: liveFeedSourceSignature) {
                liveFeedStore.connect(to: liveFeedSources)
            }
            .onChange(of: selectedPosition) { newValue in
                positionStore.save(newValue)
            }
            .onChange(of: isSheetPresented) { isPresented in
                guard isPresented else {
                    return
                }

                selectedDetent = sheetConfiguration.initialDetent
            }
            .onChange(of: configuration.isEmbeddedDebugLauncherEnabled) { isEnabled in
                if !isEnabled {
                    isSheetPresented = false
                }
            }
    }

    private var launcher: some View {
        Button {
            isSheetPresented = true
        } label: {
            Image(systemName: "ladybug.fill")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Debug tools")
    }
}

private enum TADebugToolOverlayTab: String, CaseIterable, Identifiable {
    case live
    case tools

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .live:
            return "Live"
        case .tools:
            return "Tools"
        }
    }
}

private struct TADebugToolOverlaySheet: View {
    @ObservedObject var configuration: TADebugToolConfiguration
    let liveFeedSources: [TADebugLiveFeedSource]
    @ObservedObject var liveFeedStore: TADebugLiveFeedStore
    let allowedPositions: [TADebugToolCollapsedPosition]

    @Binding var selectedPosition: TADebugToolCollapsedPosition
    @State private var selectedTab: TADebugToolOverlayTab

    init(
        configuration: TADebugToolConfiguration,
        liveFeedSources: [TADebugLiveFeedSource],
        liveFeedStore: TADebugLiveFeedStore,
        allowedPositions: [TADebugToolCollapsedPosition],
        selectedPosition: Binding<TADebugToolCollapsedPosition>
    ) {
        self.configuration = configuration
        self.liveFeedSources = liveFeedSources
        self.liveFeedStore = liveFeedStore
        self.allowedPositions = allowedPositions
        self._selectedPosition = selectedPosition
        self._selectedTab = State(initialValue: liveFeedSources.isEmpty ? .tools : .live)
    }

    var body: some View {
        NavigationStack {
            Group {
                if liveFeedSources.isEmpty {
                    TADebugToolSectionsView(configuration: configuration)
                } else {
                    VStack(spacing: 12) {
                        Picker("Tab", selection: $selectedTab) {
                            ForEach(TADebugToolOverlayTab.allCases) { tab in
                                Text(tab.title)
                                    .tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)

                        selectedTabContent
                    }
                }
            }
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Position") {
                        ForEach(allowedPositions) { position in
                            Button {
                                selectedPosition = position
                            } label: {
                                if position == selectedPosition {
                                    Label(position.title, systemImage: "checkmark")
                                } else {
                                    Text(position.title)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .live:
            TADebugLiveFeedView(liveFeedStore: liveFeedStore)
        case .tools:
            TADebugToolSectionsView(configuration: configuration)
        }
    }
}

private extension Array {
    func nonEmpty(or fallback: [Element]) -> [Element] {
        isEmpty ? fallback : self
    }
}
