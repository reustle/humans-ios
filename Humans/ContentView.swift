//
//  ContentView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import Contacts

struct ContentView: View {
    @StateObject private var viewModel = ContactsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
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
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No contacts found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.contacts) { contact in
                            NavigationLink {
                                ContactDetailView(contact: contact)
                            } label: {
                                ContactRowView(contact: contact)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
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
            if let imageData = contact.thumbnailImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                // Initials circle
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(width: 40, height: 40)
            }
            
            // Name and info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if !contact.organizationName.isEmpty && !contact.displayName.contains(contact.organizationName) {
                    Text(contact.organizationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let firstPhone = contact.phoneNumbers.first {
                    Text(firstPhone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let firstEmail = contact.emailAddresses.first {
                    Text(firstEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Contact Detail View
struct ContactDetailView: View {
    let contact: Contact
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with avatar
                VStack(spacing: 16) {
                    if let imageData = contact.thumbnailImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                            Text(contact.initials)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text(contact.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if !contact.organizationName.isEmpty {
                        Text(contact.organizationName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top)
                
                // Phone numbers
                if !contact.phoneNumbers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Phone")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ForEach(contact.phoneNumbers, id: \.self) { phone in
                            HStack {
                                Image(systemName: "phone")
                                    .foregroundColor(.secondary)
                                Text(phone)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Email addresses
                if !contact.emailAddresses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ForEach(contact.emailAddresses, id: \.self) { email in
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                Text(email)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
