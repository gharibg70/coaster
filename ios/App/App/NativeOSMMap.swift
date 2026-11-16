import SwiftUI
import CoreLocation

struct NativeOSMMapView: View {
    let coordinate: CLLocationCoordinate2D?
    @State private var center: CGPoint = CGPoint(x: 36.62, y: 43.05)
    @State private var zoom: Double = 11
    @State private var drag = CGSize.zero
    @State private var magnification: CGFloat = 1
    private let tileSize: CGFloat = 256

    var body: some View {
        GeometryReader { geometry in
            let effectiveZoom = min(18, max(3, zoom + log2(Double(magnification))))
            let centerCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: center.x, longitude: center.y)
            let tiles = visibleTiles(center: centerCoordinate, zoom: effectiveZoom, size: geometry.size)
            ZStack {
                Color(red: 0.88, green: 0.91, blue: 0.87)
                ForEach(tiles) { tile in
                    AsyncImage(url: tile.url) { phase in
                        if case .success(let image) = phase { image.resizable().interpolation(.high) }
                        else { Color(red: 0.82, green: 0.88, blue: 0.80) }
                    }
                    .frame(width: tileSize, height: tileSize)
                    .position(tile.position)
                }
                if coordinate != nil { Image(systemName: "bus.fill").font(.title).foregroundColor(.green).padding(10).background(.regularMaterial).clipShape(Circle()) }
                VStack { Spacer(); HStack { Spacer(); Text("© OpenStreetMap contributors").font(.caption2).padding(5).background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 5)) } }
                    .padding(8)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged { drag = $0.translation }.onEnded { value in
                let scale = tileSize * pow(2, effectiveZoom) / 360
                center.y -= value.translation.width / scale
                center.x += value.translation.height / scale
                drag = .zero
            })
            .simultaneousGesture(MagnificationGesture().onChanged { magnification = $0 }.onEnded { value in zoom = min(18, max(3, zoom + log2(Double(value)))); magnification = 1 })
        }
    }

    private func visibleTiles(center: CLLocationCoordinate2D, zoom: Double, size: CGSize) -> [NativeOSMTile] {
        let z = Int(zoom.rounded(.down)); let n = pow(2.0, Double(z))
        let x = (center.longitude + 180) / 360 * n
        let lat = center.latitude * .pi / 180
        let y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * n
        let columns = Int(ceil(size.width / tileSize)) + 2; let rows = Int(ceil(size.height / tileSize)) + 2
        let startX = Int(floor(x)) - columns / 2; let startY = Int(floor(y)) - rows / 2
        return (startX..<(startX + columns)).flatMap { tx in (startY..<(startY + rows)).compactMap { ty in
            let wrappedX = ((tx % Int(n)) + Int(n)) % Int(n); guard ty >= 0 && Double(ty) < n else { return nil }
            let px = size.width / 2 + (CGFloat(tx) - CGFloat(x) + drag.width / tileSize) * tileSize
            let py = size.height / 2 + (CGFloat(ty) - CGFloat(y) + drag.height / tileSize) * tileSize
            return NativeOSMTile(id: "\(z)-\(wrappedX)-\(ty)", url: URL(string: "https://tile.openstreetmap.org/\(z)/\(wrappedX)/\(ty).png")!, position: CGPoint(x: px, y: py))
        } }
    }
}

struct NativeOSMTile: Identifiable { let id: String; let url: URL; let position: CGPoint }
