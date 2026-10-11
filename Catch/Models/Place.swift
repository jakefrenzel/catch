import CoreLocation
import Foundation
import SwiftData

@Model
final class Place {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    /// 100–300 m in the place editor.
    var radiusMeters: Double = 150

    @Relationship(deleteRule: .nullify, inverse: \Item.place)
    var items: [Item]? = []

    init(name: String, address: String, latitude: Double, longitude: Double, radiusMeters: Double = 150) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
