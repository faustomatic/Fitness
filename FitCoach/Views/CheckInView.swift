import SwiftUI
import PhotosUI

/// Weekly accountability: weigh-in, subjective scores, progress photos
/// (front/side/back) and an auto-generated analysis with calorie adjustments.
struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var waistText = ""
    @State private var energy = 3
    @State private var sleepQuality = 3
    @State private var hunger = 3
    @State private var motivation = 3
    @State private var notes = ""
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var photos: [(angle: PhotoAngle, image: UIImage)] = []
    @State private var savedAnalysis: String?

    var body: some View {
        NavigationStack {
            Form {
                if let savedAnalysis {
                    Section("Your analysis") {
                        Text(savedAnalysis)
                        Button("Done") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    formSections
                }
            }
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var formSections: some View {
        Section("Measurements") {
            HStack {
                Text("Weight (kg)")
                Spacer()
                TextField("e.g. 82.4", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            HStack {
                Text("Waist (cm, optional)")
                Spacer()
                TextField("e.g. 84", text: $waistText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            Text("Weigh in fasted, after the bathroom, before coffee — same conditions every week.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("How was the week? (1–5)") {
            scaleRow("Energy", $energy, icon: "bolt.fill")
            scaleRow("Sleep quality", $sleepQuality, icon: "moon.fill")
            scaleRow("Hunger", $hunger, icon: "fork.knife")
            scaleRow("Motivation", $motivation, icon: "flame.fill")
        }

        Section("Progress photos") {
            Text("Front, side, back — same lighting, same spot, relaxed. These beat the scale for judging recomposition.")
                .font(.caption).foregroundStyle(.secondary)
            PhotosPicker(selection: $pickedItems, maxSelectionCount: 3, matching: .images) {
                Label(photos.isEmpty ? "Add photos" : "\(photos.count) photo(s) added — change", systemImage: "camera.fill")
            }
            .onChange(of: pickedItems) { _, items in
                Task { await loadPhotos(items) }
            }
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(photos.enumerated()), id: \.offset) { _, entry in
                            Image(uiImage: entry.image)
                                .resizable().scaledToFill()
                                .frame(width: 80, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }

        Section("Notes") {
            TextField("Stress, travel, anything affecting training…", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }

        Section {
            Button {
                submit()
            } label: {
                Text("Submit Check-In").frame(maxWidth: .infinity).font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private func scaleRow(_ label: String, _ value: Binding<Int>, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).font(.subheadline)
            Spacer()
            ForEach(1...5, id: \.self) { i in
                Button {
                    value.wrappedValue = i
                } label: {
                    Image(systemName: i <= value.wrappedValue ? "circle.fill" : "circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [(PhotoAngle, UIImage)] = []
        let angles = PhotoAngle.allCases
        for (i, item) in items.prefix(3).enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append((angles[min(i, angles.count - 1)], image))
            }
        }
        photos = loaded
    }

    private func submit() {
        var checkIn = CheckIn()
        checkIn.weightKg = Double(weightText.replacingOccurrences(of: ",", with: "."))
        checkIn.waistCm = Double(waistText.replacingOccurrences(of: ",", with: "."))
        checkIn.energy = energy
        checkIn.sleepQuality = sleepQuality
        checkIn.hunger = hunger
        checkIn.trainingMotivation = motivation
        checkIn.notes = notes
        for (angle, image) in photos {
            let photoID = UUID()
            if let filename = PersistenceStore.savePhoto(image, id: photoID) {
                checkIn.photos.append(CheckInPhoto(id: photoID, angle: angle, filename: filename))
            }
        }
        appState.submitCheckIn(checkIn)
        savedAnalysis = appState.checkIns.last?.analysis
    }
}
