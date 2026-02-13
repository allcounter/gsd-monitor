import SwiftUI

struct AnimatedProgressBar: View {
    let progress: Double
    let barColor: Color
    var trackColor: Color = Theme.bg2
    var height: CGFloat = 6
    var gradient: LinearGradient?

    @SwiftUI.State private var hasAppeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(trackColor)
                    .frame(height: height)

                // Fill
                Capsule()
                    .fill(gradient ?? LinearGradient(colors: [barColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geometry.size.width * (hasAppeared ? progress : 0)), height: height)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.6), value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
    }
}
