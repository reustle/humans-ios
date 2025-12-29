//
//  SearchView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import Contacts

struct SearchView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var showWelcomeAlert = false
    @AppStorage("sortOption") private var sortOptionRaw: String = SortOption.lastModified.rawValue
    
    private var sortOption: SortOption {
        get {
            SortOption(rawValue: sortOptionRaw) ?? .lastModified
        }
        set {
            sortOptionRaw = newValue.rawValue
        }
    }
    
    /// Sorts contacts based on the selected sort option
    private func sortContacts(_ contacts: [Contact]) -> [Contact] {
        switch sortOption {
        case .lastModified:
            return contacts.sorted { contact1, contact2 in
                let date1 = contact1.modificationDate ?? Date.distantPast
                let date2 = contact2.modificationDate ?? Date.distantPast
                if date1 != date2 {
                    return date1 > date2
                }
                return contact1.displayName < contact2.displayName
            }
        case .alphabetical:
            return contacts.sorted { contact1, contact2 in
                contact1.displayName.localizedCaseInsensitiveCompare(contact2.displayName) == .orderedAscending
            }
        }
    }
    
    /// Filtered contacts based on search text
    private var filteredContacts: [Contact] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return sortContacts(viewModel.contacts)
        }
        
        let searchTerms = searchText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        guard !searchTerms.isEmpty else {
            return sortContacts(viewModel.contacts)
        }
        
        let matchingContacts = viewModel.contacts.filter { contact in
            let nameLower = contact.displayName.lowercased()
            let noteLower = contact.note.lowercased()
            
            let allTermsMatch = searchTerms.allSatisfy { term in
                let matchesName = nameLower.contains(term)
                let matchesNote = noteLower.contains(term)
                return matchesName || matchesNote
            }
            
            return allTermsMatch
        }
        
        return matchingContacts.sorted { contact1, contact2 in
            let name1Lower = contact1.displayName.lowercased()
            let name2Lower = contact2.displayName.lowercased()
            
            let contact1NameMatch = searchTerms.allSatisfy { term in
                name1Lower.contains(term)
            }
            
            let contact2NameMatch = searchTerms.allSatisfy { term in
                name2Lower.contains(term)
            }
            
            if contact1NameMatch && !contact2NameMatch {
                return true
            }
            if !contact1NameMatch && contact2NameMatch {
                return false
            }
            
            switch sortOption {
            case .lastModified:
                let date1 = contact1.modificationDate ?? Date.distantPast
                let date2 = contact2.modificationDate ?? Date.distantPast
                if date1 != date2 {
                    return date1 > date2
                }
                return contact1.displayName < contact2.displayName
            case .alphabetical:
                return contact1.displayName.localizedCaseInsensitiveCompare(contact2.displayName) == .orderedAscending
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else if viewModel.authorizationStatus == .notDetermined {
                            Button("Grant Access") {
                                Task {
                                    await viewModel.loadContacts()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.contacts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No humans found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredContacts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No humans match your search")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                        VStack(spacing: 0) {
                            NavigationLink {
                                ContactDetailView(contact: contact)
                            } label: {
                                ContactRowView(contact: contact)
                            }
                            
                            if index < filteredContacts.count - 1 {
                                Divider()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .searchable(text: $searchText, prompt: "Search humans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showWelcomeAlert = true
                    } label: {
                        Image("HumanIcon")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(6)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(NavigationBarPreserver())
            .alert("Welcome to Humans", isPresented: $showWelcomeAlert) {
                Button("OK", role: .cancel) { }
            }
            .task(id: viewModel.authorizationStatus) {
                await viewModel.loadContacts()
            }
        }
    }
}

// Helper to keep navigation bar visible when search is focused
struct NavigationBarPreserver: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            // Find the navigation controller and keep the navigation bar visible
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                func findNavigationController(in viewController: UIViewController?) -> UINavigationController? {
                    guard let viewController = viewController else { return nil }
                    
                    if let navController = viewController as? UINavigationController {
                        return navController
                    }
                    
                    if let navController = viewController.navigationController {
                        return navController
                    }
                    
                    for child in viewController.children {
                        if let navController = findNavigationController(in: child) {
                            return navController
                        }
                    }
                    
                    return nil
                }
                
                if let navController = findNavigationController(in: window.rootViewController) {
                    // Keep navigation bar visible and prevent automatic hiding
                    navController.setNavigationBarHidden(false, animated: false)
                    navController.hidesBarsWhenKeyboardAppears = false
                    navController.hidesBarsOnSwipe = false
                }
            }
        }
    }
}

#Preview {
    SearchView()
}

