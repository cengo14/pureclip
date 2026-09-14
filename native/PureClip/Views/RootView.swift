import SwiftUI

struct RootView: View {
    let store: HistoryStore

    @State private var searchQuery = ""
    @State private var showingSettings = false
    @State private var pendingDeletion: ClipItem?
    @State private var confirmingClearAll = false

    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipItem] {
        guard !searchQuery.isEmpty else { return store.items }
        return store.items.filter { item in
            // Resimler aramada elenmiyor (Electron sürümüyle aynı davranış).
            item.kind == .image || item.previewText.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 0) {
                header
                Divider().overlay(Theme.border)

                if showingSettings {
                    SettingsView(store: store)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    historyContent
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .frame(width: Layout.panelWidth, height: Layout.panelHeight)
        .animation(.easeInOut(duration: 0.22), value: showingSettings)
        .confirmationDialog("Bu öğeyi silmek istediğinize emin misiniz?",
                            isPresented: Binding(get: { pendingDeletion != nil },
                                                 set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                if let item = pendingDeletion { store.delete(item) }
                pendingDeletion = nil
            }
            Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
        }
        .confirmationDialog("Sabitlenmemiş tüm geçmişi temizlemek istediğinize emin misiniz?",
                            isPresented: $confirmingClearAll,
                            titleVisibility: .visible) {
            Button("Tümünü Temizle", role: .destructive) { store.clearUnpinned() }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    // MARK: - Başlık

    private var header: some View {
        HStack {
            if showingSettings {
                HStack(spacing: 8) {
                    IconButton(systemName: "chevron.left", style: .plain, hoverTint: Theme.text,
                                size: 16, padding: 6, cornerRadius: 8, help: "Geri") {
                        showingSettings = false
                    }
                    Text("Ayarlar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
            } else {
                HStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("PureClip")
                        .font(.system(size: 20, weight: .bold))
                        .kerning(-0.5)
                        .foregroundStyle(Theme.text)
                }
            }

            Spacer()

            if !showingSettings {
                HStack(spacing: 12) {
                    IconButton(systemName: "trash", style: .plain, hoverTint: Theme.text,
                                size: 16, padding: 6, cornerRadius: 8, help: "Tümünü Temizle") {
                        confirmingClearAll = true
                    }
                    IconButton(systemName: "gearshape", style: .plain, hoverTint: Theme.text,
                                size: 16, padding: 6, cornerRadius: 8, help: "Ayarlar") {
                        showingSettings = true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Geçmiş

    private var historyContent: some View {
        VStack(spacing: 0) {
            SearchField(text: $searchQuery)
                .focused($searchFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if filteredItems.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .onAppear { searchFocused = true }
    }

    private var list: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    ClipRowView(
                        item: item,
                        thumbnail: item.imageFile.flatMap { store.images.thumbnail(named: $0) },
                        onCopy: { store.paste(item) },
                        onTogglePin: { store.togglePin(item) },
                        onDelete: { pendingDeletion = item }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
        .animation(.easeOut(duration: 0.25), value: filteredItems)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Theme.text.opacity(0.3))
            Text(searchQuery.isEmpty ? "Geçmiş henüz boş" : "Sonuç bulunamadı")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// `.search-wrapper` — odaklandığında accent kenarlık + 3 px parıltı halkası.
struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            TextField("Geçmişte ara...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .focused($isFocused)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(Theme.cardBackground, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isFocused ? Theme.cardBackgroundHover : Theme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isFocused ? Theme.accent : Theme.border, lineWidth: isFocused ? 1 : 0.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.accentGlow, lineWidth: 3)
                .opacity(isFocused ? 1 : 0)
                .blur(radius: 0.5)
        )
        .animation(.easeInOut(duration: 0.3), value: isFocused)
    }
}
