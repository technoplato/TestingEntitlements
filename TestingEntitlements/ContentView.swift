//
//  ContentView.swift
//  YouveBeenFramed
//
//  Created by laptop on 1/20/24.
//

import SwiftUI

struct ContentView: View {
    @State private var identity = ""

    var body: some View {
        VStack {
            Text(identity)
                .font(.largeTitle)
                .onAppear {
                    let fileManager = FileManager.default
                  print("hi i appeared in the view")
                    let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.knophy.mybroadcast")!
                    let fileURL = groupURL.appendingPathComponent("identity.txt")

                    do {
                        identity = try String(contentsOf: fileURL, encoding: .utf8)
                    } catch {
                        print("Failed to read identity: \(error)")
                    }
                }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

import Foundation
import Combine

class OpenedAppsViewModel: ObservableObject {
    @Published var openedApps: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private let userDefaults: UserDefaults

    init(appGroup: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroup) else {
            fatalError("Could not initialize UserDefaults with app group: \(appGroup)")
        }
        self.userDefaults = userDefaults

        // Observing the changes in UserDefaults
        userDefaults
            .publisher(for: \.openedAppsKey, options: [.initial, .new])
            .compactMap { $0 }
            
            .assign(to: &$openedApps)
    }
}

struct OpenedAppsView: View {
    @ObservedObject var viewModel: OpenedAppsViewModel

    var body: some View {
        NavigationView {
            List(viewModel.openedApps, id: \.self) { app in
                Text(app)
            }
            .navigationBarTitle("Opened Applications")
        }
    }
}

extension UserDefaults {
    @objc dynamic var openedAppsKey: [String]? {
        return array(forKey: "openedApps") as? [String]
    }
}
