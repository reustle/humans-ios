//
//  ContactsListView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import Contacts

struct ContactsListView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var showWelcomeAlert = false
    
    /// Filtered contacts based on search text
    /// - Name matches are prioritized over notes matches
    /// - If search contains spaces, all terms must match
    private var filteredContacts: [Contact] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return viewModel.contacts
        }
        
        // Split search text into terms (by spaces)
        let searchTerms = searchText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        guard !searchTerms.isEmpty else {
            return viewModel.contacts
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
            
            // If both match by name or both don't, maintain original sort order
            // (by modification date, then by name)
            let date1 = contact1.modificationDate ?? Date.distantPast
            let date2 = contact2.modificationDate ?? Date.distantPast
            if date1 != date2 {
                return date1 > date2
            }
            return contact1.displayName < contact2.displayName
        }
    }

    var body: some View {
        NavigationStack {
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
                        List(filteredContacts) { contact in
                            VStack(spacing: 0) {
                                NavigationLink {
                                    ContactDetailView(contact: contact)
                                } label: {
                                    ContactRowView(contact: contact)
                                }
                                
                                Divider()
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Search bar at the bottom
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .onKeyPress(.escape) {
                            if !searchText.isEmpty {
                                searchText = ""
                                return .handled
                            }
                            return .ignored
                        }
                        .overlay(alignment: .trailing) {
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showWelcomeAlert = true
                    } label: {
                        Image("HumanIcon")
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
            .alert("Welcome to Humans", isPresented: $showWelcomeAlert) {
                Button("OK", role: .cancel) { }
            }
            .task(id: viewModel.authorizationStatus) {
                await viewModel.loadContacts()
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
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    GradientInitialsAvatar(
                        initials: contact.initials,
                        size: 40
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

