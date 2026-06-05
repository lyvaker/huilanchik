//
//  MachineProfileView.swift
//  Профиль станка — все 10 полей с сохранением.
//

import SwiftUI

struct MachineProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var profile = MachineProfile()
    @State private var savedFlash = false

    var body: some View {
        Form {
            field("mach_model",       "mach_model_ph",       \.model)
            field("mach_ctrl",        "mach_ctrl_ph",        \.ctrl)
            field("mach_axes",        "mach_axes_ph",        \.axes)
            field("mach_maxspeed",    "mach_maxspeed_ph",    \.maxspeed, keyboard: .numberPad)
            field("mach_maxfeed",     "mach_maxfeed_ph",     \.maxfeed,  keyboard: .numberPad)
            field("mach_tools",       "mach_tools_ph",       \.tools)
            field("mach_materials",   "mach_materials_ph",   \.materials)
            field("mach_tolerances",  "mach_tolerances_ph",  \.tolerances)
            field("mach_postproc",    "mach_postproc_ph",    \.postproc)

            Section(model.t("mach_notes")) {
                TextEditor(text: $profile.notes)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if profile.notes.isEmpty {
                            Text(model.t("mach_notes_ph"))
                                .foregroundStyle(Theme.text3)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if savedFlash {
                            Image(systemName: "checkmark.circle.fill")
                            Text(model.t("machine_saved")).bold()
                        } else {
                            Image(systemName: "tray.and.arrow.down")
                            Text(model.t("machine_save_btn")).bold()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                }
                .listRowBackground(savedFlash ? Theme.green : Theme.red)
            }
        }
        .onAppear { profile = model.machineProfile }
    }

    private func save() {
        @Bindable var m = model
        m.machineProfile = profile
        model.saveConfig()
        withAnimation { savedFlash = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { savedFlash = false }
        }
    }

    @ViewBuilder
    private func field(_ labelKey: String,
                       _ phKey: String,
                       _ kp: WritableKeyPath<MachineProfile, String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        Section(model.t(labelKey)) {
            TextField(model.t(phKey), text: Binding(
                get: { profile[keyPath: kp] },
                set: { profile[keyPath: kp] = $0 }
            ))
            .keyboardType(keyboard)
            .autocorrectionDisabled()
        }
    }
}
