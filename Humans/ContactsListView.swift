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
                            Text("No contacts found")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(viewModel.contacts) { contact in
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
                    Image("HumanIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .padding(6)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
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
            Group {
                if let imageData = contact.thumbnailImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                        Text(contact.initials)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Name and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.body)
                
                if let subtitle = contact.subtitle {
                    Text(subtitle)
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

