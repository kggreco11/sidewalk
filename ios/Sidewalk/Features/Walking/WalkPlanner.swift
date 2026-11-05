import MapKit
import SwiftUI

struct TourOcclusion: Equatable {
  var top: CGFloat = 0
  var bottom: CGFloat = 0
}
struct TourOcclusionKey: PreferenceKey {
  static var defaultValue = TourOcclusion()
  static func reduce(value: inout TourOcclusion, nextValue: () -> TourOcclusion) {
    let next = nextValue()
    value.top = max(value.top, next.top)
    value.bottom = max(value.bottom, next.bottom)
  }
}

struct WalkPlanner: View {
  @EnvironmentObject private var guide: FieldGuide
  @EnvironmentObject private var tour: TourController
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduced
  @StateObject private var model: RoutePlannerModel
  @StateObject private var location = StartingLocation()
  @StateObject private var verifier = VisitLocation()
  @ObservedObject var navigation: WalkNavigation
  let close: () -> Void
  @FocusState private var focused: RouteSearchField?
  @State private var editing: Bool
  @State private var stopCount = 3
  @State private var extraMinutes = 15
  @State private var itinerary = false
  @State private var directions = false
  @State private var endConfirmation = false
  @State private var skipConfirmation = false
  @State private var story: TourStop?
  @State private var pendingNote: TourStop?
  @State private var pendingStory: TourStop?
  @State private var note: TourStop?
  @State private var task: Task<Void, Never>?
  init(destination: Place?, navigation: WalkNavigation, editing: Bool, close: @escaping () -> Void)
  {
    _model = StateObject(wrappedValue: RoutePlannerModel(place: destination))
    _editing = State(initialValue: editing)
    self.navigation = navigation
    self.close = close
  }
  private var session: TourSession? { tour.session }
  private var current: TourStop? { session?.currentStop }
  private var busy: Bool { model.busy || tour.busy }
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header(in: geometry.size.height)
          .background(
            paper, in: UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24)
          )
          .background {
            GeometryReader { measurement in
              Color.clear.preference(
                key: TourOcclusionKey.self, value: .init(top: measurement.size.height))
            }
          }
        Spacer(minLength: 12)
        VStack(spacing: 0) {
          ScrollView {
            VStack(alignment: .leading, spacing: 16) { panelContent }
              .frame(maxWidth: .infinity, alignment: .leading).padding(20)
          }.scrollBounceBehavior(.basedOnSize).id(
            "panel-\(editing)-\(session?.phase.rawValue ?? "")-\(session?.activeIndex ?? 0)")
          primaryButton.padding(.horizontal, 20).padding(.bottom, 12).padding(.top, 8)
        }.frame(height: panelHeight(in: geometry.size.height))
          .background(
            paper, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
          )
          .background(alignment: .bottom) {
            paper.frame(height: geometry.safeAreaInsets.bottom).offset(
              y: geometry.safeAreaInsets.bottom)
          }
          .background {
            GeometryReader { measurement in
              Color.clear.preference(
                key: TourOcclusionKey.self, value: .init(bottom: measurement.size.height))
            }
          }
      }.foregroundStyle(ink)
    }
    .onAppear {
      model.catalog = guide.places
      synchronizeNavigation()
    }
    .onDisappear {
      task?.cancel()
      model.cancel()
      tour.cancelWork()
      location.cancel()
      verifier.cancel()
      if scenePhase != .background || !navigation.canContinueInBackground { navigation.stop() }
    }
    .task(id: navigationKey) { synchronizeNavigation() }
    .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
      tour.checkpoint(progress: navigation.progress?.along)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        task?.cancel()
        tour.cancelWork()
        if navigation.canContinueInBackground {
          tour.checkpoint(progress: navigation.progress?.along, force: true)
        } else {
          tour.pause(
            reason: "Paused while Sidewalk is in the background. Resume when you’re ready.",
            progress: navigation.progress?.along)
          navigation.stop()
        }
        location.cancel()
        verifier.cancel()
      }
    }
    .sheet(
      isPresented: $itinerary,
      onDismiss: {
        if let pendingStory {
          story = pendingStory
          self.pendingStory = nil
        }
      }
    ) { itinerarySheet }
    .sheet(isPresented: $directions) { directionsSheet }
    .sheet(
      item: $story,
      onDismiss: {
        if let pendingNote {
          note = pendingNote
          self.pendingNote = nil
        }
      }
    ) { stop in
      StopStory(
        stop: stop,
        continueWalk: session?.phase != .preview && session?.phase != .finished
          && current?.id == stop.id
          ? {
            story = nil
            run { await tour.advance(skipping: false, from: currentLocation) }
          } : nil,
        collect: current?.id == stop.id && stop.place != nil && stop.verifiedAt == nil
          ? {
            story = nil
            collectStop()
          } : nil,
        keepNote: current?.id == stop.id && stop.place != nil
          ? {
            pendingNote = stop
            story = nil
          } : nil,
        lastStop: session?.activeIndex == (session?.stops.count ?? 0) - 1)
    }
    .sheet(item: $note) { stop in
      if let place = stop.place {
        CheckIn(
          place: place, preferredFix: navigation.fix, recordID: stop.visitRecordID,
          onCollected: { identity in
            tour.recordArrival(verified: true, recordID: identity, stopID: stop.id)
          },
          onSaved: { identity in
            tour.attachMoment(identity, stopID: stop.id)
            tour.notice = "Field note saved."
          }
        )
        .environmentObject(guide)
      }
    }
    .confirmationDialog("End this walk?", isPresented: $endConfirmation, titleVisibility: .visible)
    {
      Button("Save and end walk", role: .destructive) { tour.end() }
      Button("Keep walking", role: .cancel) {}
    } message: {
      Text("Your visited stops and moments will stay in your walk history.")
    }
    .confirmationDialog(
      "Skip this stop?", isPresented: $skipConfirmation, titleVisibility: .visible
    ) {
      Button("Skip stop") { run { await tour.advance(skipping: true, from: currentLocation) } }
      Button("Keep stop", role: .cancel) {}
    }
  }
  private var navigationKey: String {
    "\(session?.id.uuidString ?? "none"):\(session?.phase.rawValue ?? ""):\(session?.currentLeg?.id.uuidString ?? ""):\(editing)"
  }
  private var currentLocation: RoutePoint? {
    guard navigation.live, let fix = navigation.fix else { return nil }
    return RoutePoint(name: "Current location", coordinate: fix.coordinate)
  }
  private func synchronizeNavigation() {
    verifier.cancel()
    if !editing, session?.phase == .walking, let leg = session?.currentLeg, let stop = current {
      let controller = tour
      navigation.onCheckpoint = { [weak controller] progress in
        controller?.checkpoint(progress: progress)
      }
      navigation.start(leg, target: stop.point.coordinate, seedProgress: session?.legProgress)
    } else {
      navigation.stop()
      if editing || session?.phase == .preview || session?.phase == .finished {
        navigation.overview = true
      }
    }
  }
  private func panelHeight(in height: CGFloat) -> CGFloat {
    if typeSize.isAccessibilitySize { return height * 0.43 }
    if editing { return min(height * 0.30, 220) }
    if session?.phase == .preview || session?.phase == .finished { return min(height * 0.48, 400) }
    return min(height * 0.38, 310)
  }
  private func header(in height: CGFloat) -> some View {
    VStack(spacing: 0) {
      HStack {
        FieldIconButton(
          symbol: "xmark", label: session == nil ? "Close planner" : "Save and close walk"
        ) {
          tour.pause(progress: navigation.progress?.along)
          close()
        }
        if !typeSize.isAccessibilitySize {
          Text(
            editing ? "Plan a walk" : session?.phase == .finished ? "Walk complete" : "Your walk"
          ).font(.headline)
        }
        Spacer()
        if !editing, session?.phase == .preview {
          Button("Edit") {
            editing = true
            seedFields()
          }.frame(minWidth: 44, minHeight: 44)
        }
        if session != nil {
          Menu {
            Button("Stops", systemImage: "list.number") { itinerary = true }
            Button("Walking directions", systemImage: "arrow.triangle.turn.up.right.diamond") {
              directions = true
            }
            Button("Show entire walk", systemImage: "map") { navigation.overview = true }
            if session?.phase == .walking {
              Button("Pause walk", systemImage: "pause") {
                tour.pause(progress: navigation.progress?.along)
              }
            }
            Toggle("Approach haptics", isOn: $navigation.haptics)
            Toggle("Keep guiding when locked", isOn: $navigation.backgroundEnabled)
            if session?.phase != .preview && session?.phase != .finished {
              Button("End walk", role: .destructive) { endConfirmation = true }
            }
          } label: {
            Image(systemName: "ellipsis").font(.system(size: 20, weight: .semibold)).frame(
              width: 44, height: 44)
          }.accessibilityLabel("Walk options")
        }
      }.padding(.horizontal, 8)
      if editing {
        ScrollView {
          VStack(spacing: 8) {
            HStack(spacing: 8) {
              VStack(spacing: 0) {
                endpoint(.origin, symbol: "circle", placeholder: "Starting point")
                Divider().padding(.leading, 36)
                endpoint(.destination, symbol: "mappin", placeholder: "Where to?")
              }.padding(.horizontal, 12).background(
                FieldStyle.inset, in: RoundedRectangle(cornerRadius: 16))
              FieldIconButton(
                symbol: "arrow.up.arrow.down", label: "Swap starting point and destination"
              ) {
                invalidateDraft()
                model.swap()
              }
            }
            if model.originText.isEmpty || focused == .origin {
              Button {
                focused = nil
                location.request { item in
                  task?.cancel()
                  tour.cancelWork()
                  model.choose(.origin, item: item)
                  if model.destinationText.isEmpty { focused = .destination }
                }
              } label: {
                Label(
                  location.busy ? "Finding location…" : "Use current location",
                  systemImage: "location"
                ).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              }.buttonStyle(.plain).disabled(location.busy)
            }
            if let message = location.message {
              Text(message).font(.callout).foregroundStyle(FieldStyle.clay)
            }
            if let field = focused {
              LocationSuggestions(query: model.text(for: field), places: guide.places) {
                item, place in
                invalidateDraft()
                model.choose(field, item: item, place: place)
                focused = nil
              }.id(field).frame(height: min(190, height * 0.24))
            }
          }.padding(.horizontal, 16).padding(.bottom, 12)
        }.frame(maxHeight: height * 0.36).scrollDismissesKeyboard(.interactively)
      } else if session?.phase == .walking {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            if navigation.live, let progress = navigation.progress {
              HStack(alignment: .top, spacing: 14) {
                Image(systemName: progress.maneuver.symbol).font(
                  .system(size: 28, weight: .semibold)
                ).foregroundStyle(FieldStyle.clay).frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                  if let distance = progress.maneuverDistance {
                    Text(distance < 5 ? "Now" : "In \(WalkNavigation.distance(distance))").font(
                      .subheadline
                    ).foregroundStyle(FieldStyle.secondary)
                  }
                  Text(progress.instruction).font(.headline).fixedSize(
                    horizontal: false, vertical: true)
                  if let upcoming = progress.upcoming {
                    Text("Then: \(upcoming)").font(.subheadline).foregroundStyle(
                      FieldStyle.secondary)
                  }
                }
              }.accessibilityElement(children: .combine)
            } else {
              if typeSize.isAccessibilitySize {
                Text(navigation.state.title).font(.headline).fixedSize(
                  horizontal: false, vertical: true
                )
                .accessibilityHint(navigation.state.message ?? "")
                if navigation.canOpenSettings {
                  Button("Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                  }.frame(minHeight: 44)
                }
              } else {
                HStack(alignment: .top) {
                  Label(navigation.state.title, systemImage: "location.slash").font(.headline)
                  Spacer()
                  if navigation.canOpenSettings {
                    Button("Settings") {
                      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }.frame(minHeight: 44)
                  }
                }
                Text(navigation.state.message ?? "Directions remain available.").font(.subheadline)
                  .foregroundStyle(FieldStyle.secondary)
              }
            }
          }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(
            .bottom, 12)
        }.frame(
          height: min(
            typeSize.isAccessibilitySize ? 190 : navigation.live ? 115 : 80, height * 0.25))
      }
    }
  }
  @ViewBuilder private var panelContent: some View {
    if editing {
      HStack {
        Text("Stops").font(.headline)
        Spacer()
        HStack(spacing: 4) {
          ForEach([1, 3, 5], id: \.self) { count in
            Button {
              stopCount = count
            } label: {
              Text("\(count)").font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                .background(
                  stopCount == count ? paper : .clear, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain).accessibilityLabel("\(count) \(count == 1 ? "stop" : "stops")")
            .accessibilityAddTraits(stopCount == count ? .isSelected : [])
          }
        }.padding(4).background(FieldStyle.inset, in: RoundedRectangle(cornerRadius: 14))
      }
      HStack {
        Text("Extra walking").font(.subheadline)
        Spacer()
        Picker("Extra walking time", selection: $extraMinutes) {
          Text("10 min").tag(10)
          Text("15 min").tag(15)
          Text("30 min").tag(30)
        }.pickerStyle(.menu).frame(minWidth: 88, minHeight: 44)
      }
    } else if let session {
      switch session.phase {
      case .preview:
        Text("Your walking tour").font(.system(.title2, design: .serif).weight(.semibold))
        metrics(session)
        Text(
          navigation.backgroundEnabled
            ? "Location stays on during the walk, including when locked."
            : "Guidance pauses when you leave Sidewalk."
        ).font(.caption).foregroundStyle(FieldStyle.secondary)
        stopRows(session)
        DisclosureGroup("Map key, effort & access") {
          Text("Numbered pins are stops. + pins group optional discoveries.").font(.subheadline)
          Text(
            "Time is estimated walking time and excludes time at stops. Hills, stairs, opening hours and public entrances have not been reviewed for this walk."
          ).font(.callout)
        }.font(.subheadline)
      case .walking, .paused:
        if let stop = session.currentStop {
          HStack(alignment: .center) {
            Text("Stop \(session.activeIndex + 1) of \(session.stops.count)").font(
              .subheadline.weight(.medium)
            ).foregroundStyle(FieldStyle.secondary)
            Spacer()
            FieldIconButton(
              symbol: navigation.following ? "location.fill" : "location",
              label: "Follow my location"
            ) {
              navigation.overview = false
              navigation.recenter += 1
            }.disabled(navigation.fix == nil)
          }
          Text(stop.point.name).font(.system(.title2, design: .serif).weight(.semibold)).fixedSize(
            horizontal: false, vertical: true)
          if session.phase == .paused {
            Label("Walk paused", systemImage: "pause.fill").font(.headline)
            if let reason = session.pauseReason {
              Text(reason).font(.subheadline).foregroundStyle(FieldStyle.secondary)
            }
          } else if stop.verifiedAt != nil {
            Label("Visit stamp saved", systemImage: "checkmark.seal.fill").foregroundStyle(
              FieldStyle.sage
            ).font(.headline)
          } else if navigation.live, navigation.progress?.nearby == true {
            Label("Nearby · ready to check in", systemImage: "sparkle").foregroundStyle(
              FieldStyle.clay
            ).font(.headline)
          }
          if let progress = navigation.progress, session.phase == .walking {
            HStack {
              Text(
                progress.offRoute
                  ? "Stop is \(WalkNavigation.distance(progress.distanceToPlace)) away"
                  : "\(WalkNavigation.distance(progress.remaining)) remaining")
              if !progress.offRoute, let leg = session.currentLeg, leg.distance > 0 {
                Text(
                  "· ~\(max(1, Int(ceil(leg.duration * progress.remaining / leg.distance / 60)))) min"
                )
              }
            }.font(.subheadline).monospacedDigit()
            if !navigation.live {
              Text("Last known position").font(.caption).foregroundStyle(FieldStyle.secondary)
            }
            if progress.offRoute {
              Button("Update route from here") {
                if let currentLocation { run { await tour.reroute(from: currentLocation) } }
              }.frame(minHeight: 44).disabled(navigation.fix == nil)
            }
          } else if let leg = session.currentLeg {
            Text(
              "This leg: \(WalkNavigation.distance(leg.distance)) · ~\(Int(ceil(leg.duration / 60))) min"
            ).font(.subheadline).foregroundStyle(FieldStyle.secondary)
          }
          HStack(spacing: 16) {
            Button("Stops") { itinerary = true }.frame(minHeight: 44)
            Button("Directions") { directions = true }.frame(minHeight: 44)
            if stop.place != nil { Button("Note / photo") { note = stop }.frame(minHeight: 44) }
          }.font(.subheadline.weight(.medium))
          if session.phase == .walking {
            HStack {
              if stop.place != nil, stop.verifiedAt == nil {
                Button(verifier.checking ? "Checking…" : "Check in") { collectStop() }.frame(
                  minHeight: 44
                ).disabled(verifier.checking)
              }
              Spacer()
              Button("Skip stop") { skipConfirmation = true }.frame(minHeight: 44)
            }.font(.subheadline)
          }
          if let message = verifier.message {
            Text(message).font(.callout).foregroundStyle(FieldStyle.clay)
          }
          if verifier.canOpenSettings {
            Button("Open Settings") {
              UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }.frame(minHeight: 44)
          }
          if stop.status != .visited {
            Button(
              session.activeIndex + 1 == session.stops.count
                ? "Finish without checking in" : "Continue without checking in"
            ) { run { await tour.advance(skipping: false, from: currentLocation) } }.font(
              .subheadline
            ).frame(minHeight: 44)
          }
        }
      case .finished:
        WalkSummaryContent(session: session)
      }
    }
    if let error = model.error {
      Text(error).font(.callout).foregroundStyle(FieldStyle.clay).accessibilityIdentifier(
        "route-error")
    }
    if let error = tour.error { Text(error).font(.callout).foregroundStyle(FieldStyle.clay) }
    if let notice = tour.notice {
      HStack(alignment: .top) {
        Text(notice).font(.callout)
        Spacer()
        FieldIconButton(symbol: "xmark", label: "Dismiss notice") { tour.notice = nil }
      }
    }
  }
  private var primaryLabel: String {
    if busy { return editing ? "Building walk…" : "Updating route…" }
    if editing { return "Find route" }
    switch session?.phase {
    case .preview: return "Start walk"
    case .paused: return "Resume walk"
    case .finished: return "Done"
    case .walking:
      if current?.status == .visited {
        return session?.activeIndex == (session?.stops.count ?? 0) - 1 ? "Finish walk" : "Continue"
      }
      if navigation.live && navigation.progress?.nearby == true && current?.place != nil {
        return "Check in"
      }
      return "View stop"
    case nil: return "Find route"
    }
  }
  private var primaryButton: some View {
    Button {
      if editing {
        prepare()
      } else if session?.phase == .preview || session?.phase == .paused {
        tour.start()
      } else if session?.phase == .finished {
        tour.dismissFinished()
        close()
      } else if current?.status == .visited {
        run { await tour.advance(skipping: false, from: currentLocation) }
      } else if navigation.live && navigation.progress?.nearby == true && current?.place != nil {
        collectStop()
      } else {
        story = current
      }
    } label: {
      HStack(spacing: 10) {
        if busy { ProgressView().tint(paper) }
        Text(primaryLabel)
        if !busy {
          Image(systemName: session?.phase == .finished ? "checkmark" : "arrow.right").font(
            .system(size: 18, weight: .semibold))
        }
      }
    }
    .buttonStyle(FieldPrimaryButtonStyle()).disabled(
      busy || (editing && !model.canPlan) || verifier.checking
    )
    .accessibilityIdentifier("tour-primary")
  }
  private func endpoint(_ field: RouteSearchField, symbol: String, placeholder: String) -> some View
  {
    HStack(spacing: 10) {
      Image(systemName: symbol).font(.system(size: 18)).frame(width: 24).foregroundStyle(
        field == .origin ? ink : FieldStyle.clay)
      TextField(
        placeholder,
        text: Binding(
          get: { model.text(for: field) },
          set: {
            if $0 != model.text(for: field) {
              invalidateDraft()
              model.edit(field, text: $0)
            }
          })
      )
      .font(.body).focused($focused, equals: field).autocorrectionDisabled().submitLabel(.route)
      .accessibilityIdentifier(field == .origin ? "route-origin" : "route-destination").onSubmit {
        if model.canPlan {
          prepare()
        } else {
          focused = model.originText.isEmpty ? .origin : .destination
        }
      }
      if !model.text(for: field).isEmpty {
        FieldIconButton(
          symbol: "xmark.circle.fill",
          label: field == .origin ? "Clear starting point" : "Clear destination"
        ) {
          invalidateDraft()
          model.edit(field, text: "")
          focused = field
        }
      }
    }.frame(minHeight: 52)
  }
  private func prepare() {
    guard !busy else { return }
    focused = nil
    model.catalog = guide.places
    run {
      await model.plan()
      guard !Task.isCancelled, let route = model.route, let origin = model.origin,
        let destination = model.destination
      else { return }
      let source = RoutePoint(origin)
      let target = TourStop(point: RoutePoint(destination), place: model.place)
      await tour.prepare(
        origin: source, target: target, catalog: guide.places, count: stopCount,
        extraMinutes: extraMinutes,
        direct: WalkingLeg(origin: source, destination: target.point, route: route))
      if tour.error == nil, tour.session != nil {
        withAnimation(SidewalkMotion.spring(reduced)) { editing = false }
        navigation.overview = true
      }
    }
  }
  private func seedFields() {
    guard let session else { return }
    model.choose(.origin, item: session.origin.mapItem)
    if let target = session.stops.last {
      model.choose(.destination, item: target.point.mapItem, place: target.place)
    }
    stopCount = session.stops.count <= 1 ? 1 : session.stops.count <= 3 ? 3 : 5
  }
  private func collectStop() {
    guard let stop = current, let place = stop.place else { return }
    verifier.verify(place, preferredFix: navigation.fix) {
      if let identity = guide.verifyVisit(place, recordID: stop.visitRecordID) {
        tour.recordArrival(verified: true, recordID: identity, stopID: stop.id)
        UIAccessibility.post(
          notification: .announcement, argument: "Visit stamp saved. Continue when you’re ready.")
      }
    }
  }
  private func run(_ operation: @escaping @MainActor () async -> Void) {
    guard !busy else { return }
    task?.cancel()
    task = Task { await operation() }
  }
  private func invalidateDraft() {
    task?.cancel()
    tour.cancelWork()
    location.cancel()
    model.cancel()
  }
  private func metrics(_ session: TourSession) -> some View {
    Text(
      "~\(Int(ceil(session.duration / 60))) min · \(WalkNavigation.distance(session.distance)) · \(session.stops.count) stops"
    ).font(.headline).monospacedDigit()
  }
  private func stopRows(_ session: TourSession) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(session.stops.enumerated()), id: \.element.id) { index, stop in
        Button {
          story = stop
        } label: {
          HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)").font(.system(size: 16, weight: .semibold)).frame(
              width: 32, height: 32
            ).background(index == session.activeIndex ? FieldStyle.clay : ink, in: Circle())
              .foregroundStyle(paper)
            VStack(alignment: .leading, spacing: 4) {
              Text(stop.point.name).font(.body.weight(.semibold)).foregroundStyle(ink)
              if session.phase != .preview {
                Text(
                  stop.verifiedAt != nil
                    ? "Visit stamp collected"
                    : stop.status == .pending
                      ? stop.place?.kind ?? "Destination" : stop.status.rawValue.capitalized
                ).font(.subheadline).foregroundStyle(FieldStyle.secondary)
              }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
              .foregroundStyle(FieldStyle.secondary)
          }.padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).contentShape(
            Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(
          "Stop \(index + 1), \(stop.point.name), \(stop.status.rawValue)")
      }
    }
  }
  private var itinerarySheet: some View {
    NavigationStack {
      List {
        if let session {
          Section { metrics(session) }
          ForEach(Array(session.stops.enumerated()), id: \.element.id) { index, stop in
            Button {
              pendingStory = stop
              itinerary = false
            } label: {
              HStack {
                Text("\(index+1)").font(.headline.monospacedDigit()).frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                  Text(stop.point.name).font(.headline)
                  Text(stop.status.rawValue.capitalized).font(.subheadline).foregroundStyle(
                    FieldStyle.secondary)
                }
              }.padding(.vertical, 8)
            }.buttonStyle(.plain)
          }.onMove { offsets, destination in
            run { await tour.reorder(from: offsets, to: destination) }
          }.moveDisabled(session.phase != .preview)
        }
      }.navigationTitle("Stops").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { itinerary = false } }
        ToolbarItem(placement: .topBarLeading) { if session?.phase == .preview { EditButton() } }
      }
    }
  }
  private var directionsSheet: some View {
    NavigationStack {
      List {
        if let leg = session?.currentLeg {
          Section("To \(leg.destination.name)") {
            ForEach(leg.steps) { step in
              Label {
                VStack(alignment: .leading, spacing: 6) {
                  Text(step.instruction)
                  Text("At \(WalkNavigation.distance(step.start))").font(.subheadline)
                    .foregroundStyle(FieldStyle.secondary)
                }
              } icon: {
                Image(systemName: step.maneuver.symbol)
              }.padding(.vertical, 8)
            }
          }
          Section {
            Button("Open this leg in Apple Maps") {
              MKMapItem.openMaps(
                with: [leg.origin.mapItem, leg.destination.mapItem],
                launchOptions: [
                  MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                ])
            }.frame(minHeight: 44)
          }
        }
      }.navigationTitle("Directions").navigationBarTitleDisplayMode(.inline).toolbar {
        Button("Done") { directions = false }
      }
    }
  }
}
