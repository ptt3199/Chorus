import SwiftUI

/// The "Chrome profile" row in Edit Service. Saves as soon as it changes.
struct PTTServiceProfilePicker: View {
    private let serviceID: UUID
    @State private var links = PTTLinkService.shared
    @State private var selection: String?

    init(serviceID: UUID) {
        self.serviceID = serviceID
        _selection = State(initialValue: PTTLinkService.shared.serviceProfile(for: serviceID))
    }

    var body: some View {
        Picker("Chrome profile", selection: $selection) {
            Text("None").tag(String?.none)
            if let saved = selection, !names.contains(saved) {
                Text("\(saved) (not found)").tag(String?.some(saved))
            }
            ForEach(names, id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
        .help("Links clicked in this service open in this Chrome profile, unless a link rule says otherwise.")
        .onChange(of: selection) { _, newValue in
            links.setServiceProfile(newValue, for: serviceID)
        }
    }

    private var names: [String] {
        links.profiles.map(\.name)
    }
}
