//
//  ContactsListView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import Contacts

enum SortOption: String, CaseIterable {
    case lastModified = "Last Modified"
    case alphabetical = "Name"
}

struct ContactsListView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var showWelcomeAlert = false
    @State private var isSearchActive = false
    @State private var showAddHuman = false
    @FocusState private var isSearchFocused: Bool
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
                // If dates are equal (or both nil), sort by name
                return contact1.displayName < contact2.displayName
            }
        case .alphabetical:
            return contacts.sorted { contact1, contact2 in
                contact1.displayName.localizedCaseInsensitiveCompare(contact2.displayName) == .orderedAscending
            }
        }
    }
    
    /// Filtered contacts based on search text
    /// - Name matches are prioritized over notes matches
    /// - If search contains spaces, all terms must match
    private var filteredContacts: [Contact] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return sortContacts(viewModel.contacts)
        }
        
        // Split search text into terms (by spaces)
        let searchTerms = searchText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        guard !searchTerms.isEmpty else {
            return sortContacts(viewModel.contacts)
        }
        
        // Filter contacts where all terms match
        // Each term must match in either the name OR notes (or both)
        // Example: "Emily John" matches "John Smith" if:
        //   - "Emily" is in notes AND "John" is in name, OR
        //   - Both terms are in name, OR
        //   - Both terms are in notes, OR
        //   - Any combination where each term appears somewhere
        let matchingContacts = viewModel.contacts.filter { contact in
            let nameLower = contact.displayName.lowercased()
            let noteLower = contact.note.lowercased()
            
            // For each search term, check if it appears in name OR notes
            // All terms must match somewhere (not necessarily all in the same field)
            let allTermsMatch = searchTerms.allSatisfy { term in
                let matchesName = nameLower.contains(term)
                let matchesNote = noteLower.contains(term)
                return matchesName || matchesNote
            }
            
            return allTermsMatch
        }
        
        // Sort: name matches first, then notes matches
        return matchingContacts.sorted { contact1, contact2 in
            let name1Lower = contact1.displayName.lowercased()
            let name2Lower = contact2.displayName.lowercased()
            
            // Check if contact1 matches by name
            let contact1NameMatch = searchTerms.allSatisfy { term in
                name1Lower.contains(term)
            }
            
            // Check if contact2 matches by name
            let contact2NameMatch = searchTerms.allSatisfy { term in
                name2Lower.contains(term)
            }
            
            // If one matches by name and the other doesn't, prioritize name match
            if contact1NameMatch && !contact2NameMatch {
                return true
            }
            if !contact1NameMatch && contact2NameMatch {
                return false
            }
            
            // If both match by name or both don't, apply selected sort order
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
            ZStack {
                VStack(spacing: 0) {
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
                                    NavigationLink(value: contact.id) {
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
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear
                                    .frame(height: 100)
                            }
                        }
                    }
                }
                
                // Floating Action Buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if isSearchActive {
                            // Search bar with X button when active
                            HStack(spacing: 12) {
                                TextField("Search humans", text: $searchText)
                                    .focused($isSearchFocused)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .conditionalGlassEffect(in: RoundedRectangle(cornerRadius: 28))
                                    .frame(maxWidth: .infinity)
                                
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isSearchActive = false
                                        searchText = ""
                                        isSearchFocused = false
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 56, height: 56)
                                        .conditionalGlassEffect(in: Circle())
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Consume tap to prevent it from passing through to the list
                                isSearchFocused = true
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            VStack(spacing: 16) {
                                // Add contact button (top)
                                Button {
                                    showAddHuman = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 56, height: 56)
                                        .conditionalGlassEffect(in: Circle())
                                }
                                
                                // Search button (bottom)
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isSearchActive = true
                                        isSearchFocused = true
                                    }
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 56, height: 56)
                                        .conditionalGlassEffect(in: Circle())
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                
                if !isSearchActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                sortOptionRaw = SortOption.lastModified.rawValue
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Last Changed")
                                        .font(.callout)
                                    if sortOption == .lastModified {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .font(.callout)
                                    }
                                }
                            }
                            
                            Button {
                                sortOptionRaw = SortOption.alphabetical.rawValue
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Alphabetical")
                                        .font(.callout)
                                    if sortOption == .alphabetical {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .font(.callout)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 14))
                                .frame(width: 20, height: 20)
                                .padding(6)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .alert("Welcome to Humans", isPresented: $showWelcomeAlert) {
                Button("OK", role: .cancel) { }
            }
            .sheet(isPresented: $showAddHuman) {
                NavigationStack {
                    Text("Add Human")
                        .navigationTitle("Add Human")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showAddHuman = false
                                }
                            }
                        }
                }
            }
            .task(id: viewModel.authorizationStatus) {
                await viewModel.loadContacts()
            }
            .navigationDestination(for: String.self) { contactId in
                if let contact = viewModel.contacts.first(where: { $0.id == contactId }) {
                    ContactDetailView(contact: contact)
                }
            }
        }
    }
}

// MARK: - Contact Row View
struct ContactRowView: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Group {
                if let imageData = contact.thumbnailImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    GradientInitialsAvatar(
                        initials: contact.initials,
                        size: 44
                    )
                }
            }
            
            // Name and time ago
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.body)
                
                if let timeAgo = contact.timeAgoString {
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    ContactsListView()
}

// MARK: - Conditional Glass Effect Extension
extension View {
    /// Applies glassEffect on iOS 26+, falls back to material background on earlier versions
    @ViewBuilder
    func conditionalGlassEffect<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background {
                shape
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

