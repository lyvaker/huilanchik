//
//  SettingsView.swift
//  Настройки: API-ключ, язык (4 языка), выбор модели.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var saveKey: Bool = true
    @State private var lang: AppLanguage = .ru
    @State private var modelChoice: ClaudeModel = .sonnet
    @State private var showKeyText: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // ── API key ─────────────────────────────────────────────
                Section {
                    HStack {
                        if showKeyText {
                            TextField("sk-ant-...", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("sk-ant-...", text: $apiKey)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                        }
                        Button {
                            showKeyText.toggle()
                        } label: {
                            Image(systemName: showKeyText ? "eye.slash" : "eye")
                                .foregroundStyle(Theme.text2)
                        }
                    }
                    Toggle(model.t("api_save_cb"), isOn: $saveKey)
                } header: {
                    Text(model.t("api_lbl"))
                } footer: {
                    Text(model.t("api_hint"))
                        .font(.footnote)
                        .foregroundStyle(Theme.text3)
                }

                // ── Язык (4 опции) ─────────────────────────────────────
                Section(model.t("language")) {
                    ForEach(AppLanguage.allCases) { l in
                        Button {
                            lang = l
                        } label: {
                            HStack {
                                Text(l.flag).font(.title3)
                                Text(l.displayName)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if lang == l {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.red)
                                        .bold()
                                }
                            }
                        }
                    }
                }

                // ── Модель ─────────────────────────────────────────────
                Section(model.t("model_label")) {
                    ForEach(ClaudeModel.allCases) { m in
                        Button {
                            modelChoice = m
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.displayName)
                                        .foregroundStyle(Theme.text)
                                        .bold()
                                    Text(m.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.text3)
                                }
                                Spacer()
                                if modelChoice == m {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.red)
                                        .bold()
                                }
                            }
                        }
                    }
                }

                // ── Профиль станка ─────────────────────────────────────
                Section {
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

                // ── Версия ─────────────────────────────────────────────
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(Theme.text2)
                        Spacer()
                        Text("1.0 (iOS port)")
                            .foregroundStyle(Theme.text3)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(model.t("set_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(model.t("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(model.t("save")) {
                        save()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                apiKey      = model.apiKey
                saveKey     = model.saveKey
                lang        = model.lang
                modelChoice = model.chatModel
            }
        }
    }

    private func save() {
        @Bindable var m = model
        m.apiKey      = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        m.saveKey     = saveKey
        m.lang        = lang
        m.chatModel   = modelChoice
        model.saveConfig()
    }
}

#Preview {
    SettingsView().environment(AppModel())
}
