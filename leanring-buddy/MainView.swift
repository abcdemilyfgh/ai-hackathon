import SwiftUI

struct MainView: View {
    @StateObject private var store = ClipStore()

    var body: some View {
        HSplitView {
            FileBrowserView(store: store)
            ChatView(store: store)
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

