import SwiftUI

struct CartoonCityOverlay: View {
    let selectedPlace: WorldPlace
    let places: [WorldPlace]
    let contributions: [MediaContribution]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.10),
                        Color.mint.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    let position = overlayPosition(for: index, in: size)
                    CartoonBuildingCluster(
                        place: place,
                        contributionCount: contributions.filter { $0.placeID == place.id }.count,
                        isSelected: place.id == selectedPlace.id
                    )
                    .position(position)
                }

                VStack {
                    Spacer()
                    IsometricGround()
                        .frame(height: min(220, size.height * 0.28))
                        .opacity(0.72)
                        .padding(.bottom, 220)
                }
            }
        }
    }

    private func overlayPosition(for index: Int, in size: CGSize) -> CGPoint {
        let columns: [CGFloat] = [0.18, 0.34, 0.52, 0.70, 0.84, 0.60]
        let rows: [CGFloat] = [0.24, 0.39, 0.29, 0.46, 0.22, 0.40]
        return CGPoint(
            x: size.width * columns[index % columns.count],
            y: size.height * rows[index % rows.count]
        )
    }
}

private struct CartoonBuildingCluster: View {
    let place: WorldPlace
    let contributionCount: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                ForEach(0..<3, id: \.self) { index in
                    CartoonTower(
                        color: place.role.color,
                        height: CGFloat(42 + index * 18 + (isSelected ? 16 : 0)),
                        width: CGFloat(24 + index * 6)
                    )
                    .offset(x: CGFloat(index - 1) * 22, y: CGFloat(index % 2) * 8)
                }

                if contributionCount > 0 {
                    Image(systemName: "photo.stack.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(.black.opacity(0.55), in: Circle())
                        .offset(x: 36, y: -42)
                }
            }

            Text(place.name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .scaleEffect(isSelected ? 1.12 : 0.94)
        .animation(.bouncy(duration: 0.45), value: isSelected)
    }
}

private struct CartoonTower: View {
    let color: Color
    let height: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.gradient)
                .frame(width: width, height: height)
                .shadow(color: color.opacity(0.28), radius: 8, y: 7)

            VStack(spacing: 5) {
                ForEach(0..<max(2, Int(height / 18)), id: \.self) { _ in
                    HStack(spacing: 4) {
                        Capsule().fill(.white.opacity(0.72))
                        Capsule().fill(.white.opacity(0.45))
                    }
                    .frame(width: max(12, width - 10), height: 4)
                }
            }
            .padding(.top, 8)
        }
    }
}

private struct IsometricGround: View {
    var body: some View {
        Canvas { context, size in
            let tileWidth: CGFloat = 72
            let tileHeight: CGFloat = 36
            let rows = Int(size.height / tileHeight) + 3
            let columns = Int(size.width / tileWidth) + 4

            for row in 0..<rows {
                for column in 0..<columns {
                    let x = CGFloat(column) * tileWidth - CGFloat(row % 2) * tileWidth / 2
                    let y = CGFloat(row) * tileHeight * 0.72
                    var path = Path()
                    path.move(to: CGPoint(x: x + tileWidth / 2, y: y))
                    path.addLine(to: CGPoint(x: x + tileWidth, y: y + tileHeight / 2))
                    path.addLine(to: CGPoint(x: x + tileWidth / 2, y: y + tileHeight))
                    path.addLine(to: CGPoint(x: x, y: y + tileHeight / 2))
                    path.closeSubpath()

                    let fill = (row + column).isMultiple(of: 2)
                    ? Color.mint.opacity(0.18)
                    : Color.yellow.opacity(0.12)
                    context.fill(path, with: .color(fill))
                    context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
                }
            }
        }
    }
}
