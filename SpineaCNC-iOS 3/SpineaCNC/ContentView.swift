//
//  ContentView.swift
//  Корневая навигация: TabView с пятью вкладками.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    @State private var showSavedChats = false
    @State private var selection: Tab = .chat

    enum Tab: Hashable {
        case chat, alarms, codes, program, more
    }

    var body: some View {
        TabView(selection: $selection) {

            // ── Чат ─────────────────────────────────────────────────────
            NavigationStack {
                ChatView()
                    .navigationTitle(model.t("title_chat"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { commonToolbar }
            }
            .tabItem {
                Label(model.t("nav_chat"), systemImage: "bubble.left.and.bubble.right.fill")
            }
            .tag(Tab.chat)

            // ── Алармы ──────────────────────────────────────────────────
            NavigationStack {
                AlarmsView()
                    .navigationTitle(model.t("title_alarms"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { commonToolbar }
            }
            .tabItem {
                Label(model.t("nav_alarms"), systemImage: "exclamationmark.triangle.fill")
            }
            .tag(Tab.alarms)

            // ── G/M Коды ───────────────────────────────────────────────
            NavigationStack {
                CodesView()
                    .navigationTitle(model.t("title_codes"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { commonToolbar }
            }
            .tabItem {
                Label(model.t("nav_codes"), systemImage: "number.square.fill")
            }
            .tag(Tab.codes)

            // ── Программа ──────────────────────────────────────────────
            NavigationStack {
                ProgramView()
                    .navigationTitle(model.t("title_program"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { commonToolbar }
            }
            .tabItem {
                Label(model.t("nav_program"), systemImage: "doc.text.magnifyingglass")
            }
            .tag(Tab.program)

            // ── Ещё ─────────────────────────────────────────────────────
            NavigationStack {
                MoreView()
                    .navigationTitle(model.t("more"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { commonToolbar }
            }
            .tabItem {
                Label(model.t("more"), systemImage: "ellipsis.circle.fill")
            }
            .tag(Tab.more)
        }
        .tint(Theme.red)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSavedChats) {
            SavedChatsView()
        }
        .alert("⚠️", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { @Bindable var m = model; m.errorMessage = nil } }
        ), actions: {
            Button(model.t("ok"), role: .cancel) {
                @Bindable var m = model
                m.errorMessage = nil
            }
        }, message: {
            Text(model.errorMessage ?? "")
        })
    }

    @ToolbarContentBuilder
    private var commonToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSavedChats = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Theme.text)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(Theme.text)
            }
        }
    }
}

// MARK: - MoreView (вкладка «Ещё»)
struct MoreView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PhotoView()
                        .navigationTitle(model.t("title_photo"))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label {
                        Text(model.t("nav_photo"))
                    } icon: {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.purple)
                    }
                }

                NavigationLink {
                    HistoryView()
                        .navigationTitle(model.t("title_history"))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label {
                        Text(model.t("nav_history"))
                    } icon: {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Theme.blue)
                    }
                }

                NavigationLink {
                    MachineProfileView()
                        .navigationTitle(model.t("title_machine"))
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label {
                        Text(model.t("nav_machine"))
                    } icon: {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(Theme.green)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
