//
//  PhotoView.swift
//  Анализ фото со станка: камера или галерея + опциональный вопрос.
//

import SwiftUI
import PhotosUI

struct PhotoView: View {
    @Environment(AppModel.self) private var model

    @State private var image: UIImage?
    @State private var question: String = ""
    @State private var result: String = ""
    @State private var streaming: Bool = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @FocusState private var qFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text(model.t("photo_label"))
                    .font(.caption).bold()
                    .foregroundStyle(Theme.text2)

                // Превью или подсказка
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                image = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, Color.black.opacity(0.6))
                                    .padding(8)
                            }
                        }
                } else {
                    placeholder
                }

                // Кнопки выбора источника
                HStack(spacing: 8) {
                    Button {
                        showCamera = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                            Text("Камера").bold()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Theme.bg2)
                        .foregroundStyle(Theme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack {
                            Spacer()
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Галерея").bold()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Theme.bg2)
                        .foregroundStyle(Theme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                    }
                }

                // Поле вопроса
                TextField(model.t("photo_q_ph"), text: $question, axis: .vertical)
                    .focused($qFocused)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                // Кнопка анализировать
                Button {
                    Task { await analyze() }
                } label: {
                    HStack {
                        Spacer()
                        if streaming {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles.rectangle.stack")
                            Text(model.t("photo_go")).bold()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(image != nil ? Theme.red : Theme.text3)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(image == nil || streaming)

                // Результат
                if !result.isEmpty || streaming {
                    ResultBlock(title: model.t("result_title"),
                                empty: model.t("result_empty"),
                                text: result)
                }
            }
            .padding(16)
        }
        .background(Theme.bg)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $image)
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    image = ui
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - Placeholder
    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.text3)
            Text(model.t("photo_hint"))
                .font(.footnote)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Theme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
        )
    }

    // MARK: - Run
    private func analyze() async {
        guard let img = image else {
            @Bindable var m = model
            m.errorMessage = model.t("photo_err"); return
        }
        guard !model.apiKey.isEmpty else {
            @Bindable var m = model
            m.errorMessage = model.t("err_key"); return
        }
        qFocused = false
        result = ""
        streaming = true

        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt: String
        if q.isEmpty {
            prompt = model.t("q_photo0")
        } else {
            let tmpl = model.t("q_photo")
            prompt = String(format: tmpl, q)
        }

        var full = ""
        do {
            for try await chunk in model.streamWithImage(prompt: prompt, image: img) {
                full += chunk
                result = full
            }
            model.addHistory(kind: .photo, query: q.isEmpty ? "📷" : q, reply: full)
        } catch {
            result = "❌ \(error.localizedDescription)"
        }
        streaming = false
    }
}

// MARK: - Камера через UIImagePickerController
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        p.allowsEditing = false
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { self.parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack { PhotoView().environment(AppModel()) }
}
