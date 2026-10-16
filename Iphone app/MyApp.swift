
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)

            Text("PhoneFree")
                .font(.largeTitle.bold())

            Text("Make space for life beyond your phone.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Your next moment starts here.")
                .font(.headline)
                .padding(.top, 12)
        }
        .padding(32)
    }
}

#Preview {
    ContentView()
}
