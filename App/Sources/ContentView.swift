import SwiftUI
import AppKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(radius: 10, y: 4)

            VStack(spacing: 10) {
                Text("Markdown QuickLook is set up")
                    .font(.largeTitle.bold())
                Text("Select a Markdown file in Finder and press the spacebar to preview it.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Examples.open()
            } label: {
                Label("Open Example Files", systemImage: "folder")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Text("Then press the spacebar on any example to try it.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
}
