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
        HSplitView {
            // Left Panel - Options
            OptionsPanel(viewModel: viewModel)
            
            // Right Panel - Document Preview
            DocumentPreview(viewModel: viewModel)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
