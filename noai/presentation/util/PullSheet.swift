//
//  PullSheet.swift
//  noai
//
//  Created by Niki Izvorski on 24.10.25.
//
import SwiftUI

struct PullSheet: View {
    @ObservedObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pull a model by name").font(.headline).foregroundStyle(Theme.textPrimary)
            TextField("e.g. mistral, qwen2.5:3b, deepseek-r1:7b", text: $vm.pullName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(vm.pulling ? "Pulling…" : "Pull") { Task { await vm.pull() } }
                    .disabled(vm.pulling || vm.pullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Divider().overlay(Theme.strokeSoft)
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(Array(vm.pullLines.enumerated()), id: \.offset) { _, l in
                        Text(l).font(.caption).monospaced().foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(minHeight: 120)
        }
        .padding()
        .frame(width: 520)
        .background(Theme.background)
    }
}
