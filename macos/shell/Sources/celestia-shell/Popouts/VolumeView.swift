import SwiftUI

struct VolumePopout: View {
    @ObservedObject var model: BarModel
    @ObservedObject private var volume = VolumeSensor.shared

    private static let trackHeight: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            HStack {
                model.title("Volume")
                Spacer()
                model.number(volume.muted ? "Muted" : "\(volume.percent)%")
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(model.color("surface_container_high"))
                    Capsule().fill(model.color("primary"))
                        .frame(width: geometry.size.width * CGFloat(volume.percent) / 100)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    volume.set(percent: Int((drag.location.x / geometry.size.width * 100).rounded()))
                })
            }
            .frame(height: Self.trackHeight)
            model.detail(volume.deviceName)
        }
    }
}
