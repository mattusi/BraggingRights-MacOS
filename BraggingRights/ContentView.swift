//
//  ContentView.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        MultiStepWorkflowView(viewModel: viewModel)
            .frame(minWidth: 1000, minHeight: 700)
    }
}

#Preview {
    ContentView()
}
