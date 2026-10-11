import CoreLocation
import MapKit
import SwiftData
import SwiftUI

/// Where Settings → Places can go.
enum PlaceRoute: Hashable {
    case list
    case edit(Place)
    /// A new place, optionally with a name already filled in.
    case new(String)
}

/// 12a: saved places, plus which place reminders to offer.
struct PlacesListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Place.name) private var places: [Place]

    var body: some View {
        @Bindable var settingsStore = model.settingsStore

        List {
            Section {
                ForEach(places) { place in
                    NavigationLink(value: PlaceRoute.edit(place)) {
                        PlaceRow(place: place)
                    }
                }
                NavigationLink(value: PlaceRoute.new("")) {
                    Label("Add Place", systemImage: "plus")
                        .foregroundStyle(Theme.blue)
                }
            } header: {
                Text("Used for “When I leave” and “When I arrive” reminders.")
                    .textCase(nil)
            }

            Section {
                Toggle("Offer “When I leave”", isOn: $settingsStore.settings.offerLeave)
                Toggle("Offer “When I arrive”", isOn: $settingsStore.settings.offerArrive)
            } footer: {
                Text("Locations stay on this iPhone. Catch only checks where you are when a place reminder is waiting.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Places")
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: PlaceIcon.name(for: place.name))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(place.name)
                Text("\(place.address) · \(Int(place.radiusMeters)) m")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
        }
    }
}

enum PlaceIcon {
    static func name(for placeName: String) -> String {
        switch placeName.lowercased() {
        case "home": return "house.fill"
        case "office", "work": return "briefcase.fill"
        case "gym": return "figure.run"
        case "school": return "graduationcap.fill"
        default: return "mappin"
        }
    }
}

/// Edit a place: map, name, address (search or current location), radius.
struct PlaceEditorView: View {
    let place: Place?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var address: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var radius: Double
    @State private var camera: MapCameraPosition = .automatic
    @State private var isLocating = false
    @State private var message: String?
    @State private var isRemoved = false

    init(place: Place?, suggestedName: String = "") {
        self.place = place
        _name = State(initialValue: place?.name ?? suggestedName)
        _address = State(initialValue: place?.address ?? "")
        _latitude = State(initialValue: place?.latitude)
        _longitude = State(initialValue: place?.longitude)
        _radius = State(initialValue: place?.radiusMeters ?? 150)
    }

    var body: some View {
        List {
            Section {
                map
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                TextField("Name", text: $name)
                HStack {
                    TextField("Address", text: $address)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        if isLocating {
                            ProgressView()
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundStyle(Theme.blue)
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Use current location")
                }
            } footer: {
                if let message {
                    Text(message)
                }
            }

            Section {
                HStack {
                    Text("Radius")
                    Spacer()
                    Text("\(Int(radius)) m")
                        .foregroundStyle(Theme.ink2)
                        .monospacedDigit()
                }
                Slider(value: $radius, in: 100...300, step: 50)
                    .accessibilityLabel("Radius")
                    .accessibilityValue("\(Int(radius)) meters")
            } header: {
                Text("Size")
            } footer: {
                Text("Bigger is more reliable in tall buildings.")
            }

            if let place {
                Section {
                    Button("Remove Place", role: .destructive) {
                        isRemoved = true
                        model.removePlace(place)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle(name.isEmpty ? "New Place" : name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if place == nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: moveCamera)
        .onDisappear {
            // Edits to a saved place keep when going back.
            if place != nil, !isRemoved, canSave { save() }
        }
    }

    @ViewBuilder
    private var map: some View {
        Map(position: $camera, interactionModes: []) {
            if let coordinate {
                Marker(name.isEmpty ? "Place" : name, coordinate: coordinate)
                    .tint(Theme.green)
                MapCircle(center: coordinate, radius: radius)
                    .foregroundStyle(Theme.blue.opacity(0.15))
                    .stroke(Theme.blue, lineWidth: 2)
            }
        }
        .overlay {
            if coordinate == nil {
                Text("Search for an address or use your location")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .onChange(of: radius) { moveCamera() }
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && coordinate != nil
    }

    private func moveCamera() {
        guard let coordinate else { return }
        camera = .region(MKCoordinateRegion(center: coordinate,
                                            latitudinalMeters: radius * 6, longitudinalMeters: radius * 6))
    }

    private func save() {
        guard let latitude, let longitude else { return }
        model.savePlace(place, name: name, address: address,
                        latitude: latitude, longitude: longitude, radius: radius)
    }

    private func search() async {
        let query = address.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                message = "No match for that address."
                return
            }
            let coordinate = item.placemark.coordinate
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            address = item.placemark.title ?? query
            message = nil
            moveCamera()
        } catch {
            message = "Couldn't search right now."
        }
    }

    private func useCurrentLocation() async {
        isLocating = true
        defer { isLocating = false }
        guard let location = await model.location.currentLocation() else {
            message = model.location.isDenied
                ? "Location is off for Catch. Turn it on in iOS Settings."
                : "Couldn't find your location."
            return
        }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            address = [placemark.name, placemark.locality].compactMap { $0 }.joined(separator: ", ")
        }
        message = nil
        moveCamera()
    }
}
