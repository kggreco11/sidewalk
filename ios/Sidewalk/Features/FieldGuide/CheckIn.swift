import AVFoundation
import CoreLocation
import PhotosUI
import SwiftUI

struct CheckIn: View {
  @EnvironmentObject private var guide: FieldGuide
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  let place: Place
  var preferredFix: CLLocation? = nil
  var recordID: UUID? = nil
  var onCollected: ((UUID) -> Void)? = nil
  var onSaved: ((UUID) -> Void)? = nil
  @State private var activeRecordID: UUID?
  @State private var note = ""
  @State private var photo: Data?
  @State private var originalNote = ""
  @State private var originalPhoto: Data?
  @State private var photoItem: PhotosPickerItem?
  @State private var camera = false
  @State private var cameraError: String?
  @State private var discard = false
  @State private var loaded = false
  @State private var draftTask: Task<Void, Never>?
  @State private var discarded = false
  @State private var restoredDraft = false
  @State private var draftWritable = true
  private var draftKey: String { place.id }
  private var dirty: Bool { note != originalNote || photo != originalPhoto }
  private var record: VisitRecord? { guide.visitHistory.first { $0.id == activeRecordID } }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(place.name).font(.system(.title2, design: .serif).weight(.semibold))
          if record?.verified == true {
            Label("Visit stamp saved", systemImage: "checkmark.seal.fill").foregroundStyle(
              FieldStyle.clay)
          } else {
            ArrivalUnlock(place: place, preferredFix: preferredFix, recordID: activeRecordID) {
              identity in
              activeRecordID = identity
              onCollected?(identity)
              if dirty { queueDraft(immediate: true) }
              UIAccessibility.post(
                notification: .announcement,
                argument: "Visit stamp saved. You can add a note or continue your walk.")
            }
          }
        }
        Section("Field note · optional") {
          if restoredDraft {
            Label("Unsaved note restored", systemImage: "arrow.counterclockwise").font(.subheadline)
              .foregroundStyle(FieldStyle.secondary)
          }
          TextField("Worth a footnote?", text: $note, axis: .vertical).lineLimit(3...8)
            .accessibilityIdentifier("visit-note")
          if let photo, let image = UIImage(data: photo) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
              .accessibilityLabel("Your place photo")
            Button("Remove photo", role: .destructive) {
              self.photo = nil
              photoItem = nil
            }.frame(minHeight: 44)
          }
          if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button {
              requestCamera()
            } label: {
              Label("Proof you wandered", systemImage: "camera").frame(minHeight: 44)
            }
          }
          PhotosPicker(selection: $photoItem, matching: .images) {
            Label("One for the field guide", systemImage: "photo").frame(minHeight: 44)
          }
          if let cameraError { Text(cameraError).font(.callout).foregroundStyle(FieldStyle.clay) }
          if let error = guide.error { Text(error).font(.callout).foregroundStyle(FieldStyle.clay) }
        }
        Section {
          DisclosureGroup("Read the story") {
            Text(place.story).font(.body).lineSpacing(4).padding(.vertical, 8)
            if let url = URL(string: place.source), url.scheme == "https" {
              Link(place.sourceName, destination: url).frame(minHeight: 44)
            }
          }
        }
      }.scrollContentBackground(.hidden).background(paper).foregroundStyle(ink)
        .navigationTitle("Your visit").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              if dirty {
                discard = true
              } else {
                clearDraft()
                dismiss()
              }
            }
          }
        }
        .safeAreaInset(edge: .bottom) {
          Button(dirty ? "Save note" : "Done") { save() }.buttonStyle(FieldPrimaryButtonStyle())
            .padding(16).background(paper)
        }
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("Keep your changes?", isPresented: $discard, titleVisibility: .visible)
      {
        Button("Save note") { save() }
        Button("Discard changes", role: .destructive) {
          clearDraft()
          dismiss()
        }
        Button("Keep editing", role: .cancel) {}
      }
        .onAppear {
          guard !loaded else { return }
          loaded = true
          activeRecordID = recordID
          if let existing = guide.visitHistory.first(where: { $0.id == recordID }) {
            note = existing.note
            photo = existing.photo
          }
          originalNote = note
          originalPhoto = photo
        }
        .task(id: photoItem) {
          guard let photoItem else { return }
          do {
            guard let data = try await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
            else { throw CocoaError(.fileReadCorruptFile) }
            try Task.checkCancellation()
            let processed = Self.compress(image)
            try Task.checkCancellation()
            photo = processed
            cameraError = nil
          } catch is CancellationError {} catch {
            if !Task.isCancelled { cameraError = "Couldn’t open that photo. Try another image." }
          }
        }
        .task {
          do {
            if let draft = try await MomentDraftStore.shared.load(draftKey),
              draft.placeID == place.id, !dirty
            {
              activeRecordID = draft.recordID ?? activeRecordID
              note = draft.note
              photo = draft.photo
              restoredDraft = true
            }
          } catch {
            draftWritable = false
            cameraError = "Your earlier draft couldn’t be opened. It has been preserved."
          }
        }
        .onChange(of: note) { _, _ in queueDraft() }
        .onChange(of: photo) { _, _ in queueDraft() }
        .onChange(of: scenePhase) { _, phase in
          if phase == .background, dirty { queueDraft(immediate: true) }
        }
        .onDisappear {
          draftTask?.cancel()
          if dirty && !discarded { queueDraft(immediate: true) }
        }
        .fullScreenCover(isPresented: $camera) {
          CameraCapture { image in
            if let image {
              photo = Self.compress(image)
              cameraError = nil
            }
          }
        }
    }
  }
  private func save() {
    if !dirty {
      if let activeRecordID { onSaved?(activeRecordID) }
      clearDraft()
      dismiss()
      return
    }
    if guide.saveMoment(place, note: note, photo: photo, recordID: activeRecordID),
      let saved = guide.visitHistory.first(where: { $0.id == activeRecordID })
        ?? guide.visitHistory.first(where: { $0.placeID == place.id })
    {
      onSaved?(saved.id)
      originalNote = note
      originalPhoto = photo
      clearDraft()
      dismiss()
    }
  }
  private func queueDraft(immediate: Bool = false) {
    guard loaded, !discarded, draftWritable else { return }
    draftTask?.cancel()
    let snapshot = MomentDraft(
      placeID: place.id, recordID: activeRecordID, note: note, photo: photo)
    let key = draftKey
    draftTask = Task {
      do {
        if !immediate { try await Task.sleep(for: .milliseconds(350)) }
        try Task.checkCancellation()
        try await MomentDraftStore.shared.save(snapshot, key: key)
      } catch is CancellationError {} catch {
        cameraError = "Couldn’t save this draft. Keep the sheet open and try Save note."
      }
    }
  }
  private func clearDraft() {
    discarded = true
    draftTask?.cancel()
    let key = draftKey
    guard draftWritable else { return }
    Task { try? await MomentDraftStore.shared.clear(key) }
  }
  private func requestCamera() {
    Task {
      let allowed: Bool
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: allowed = true
      case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
      default: allowed = false
      }
      if allowed {
        camera = true
      } else {
        cameraError =
          "Camera access is off. Choose a photo from your library, or enable Camera in Settings."
      }
    }
  }
  static func compress(_ image: UIImage) -> Data? {
    let scale = min(1, 1400 / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }.jpegData(compressionQuality: 0.8)
  }
}

struct CameraCapture: UIViewControllerRepresentable {
  @Environment(\.dismiss) private var dismiss
  let capture: (UIImage?) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate
  {
    let parent: CameraCapture
    init(_ parent: CameraCapture) { self.parent = parent }
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      parent.capture(info[.originalImage] as? UIImage)
      parent.dismiss()
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
  }
}
