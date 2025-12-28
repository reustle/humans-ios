//
//  ContactDetailView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI
import UIKit

// MARK: - Contact Detail View
struct ContactDetailView: View {
    let contact: Contact
    @State private var contactWithNotes: Contact?
    @State private var isLoadingNotes = false
    
    private var displayContact: Contact {
        contactWithNotes ?? contact
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with avatar (left) and name (right)
                HStack(alignment: .center, spacing: 16) {
                    // Avatar
                    Group {
                        if let imageData = displayContact.thumbnailImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                Text(displayContact.initials)
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Name and organization
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayContact.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !displayContact.organizationName.isEmpty {
                            Text(displayContact.organizationName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Circle button icons row (phone and email)
                if !displayContact.phoneNumbers.isEmpty || !displayContact.emailAddresses.isEmpty {
                    HStack(spacing: 12) {
                        if !displayContact.phoneNumbers.isEmpty, let firstPhone = displayContact.phoneNumbers.first {
                            Button(action: {
                                let cleanedPhone = firstPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                if let url = URL(string: "tel://\(cleanedPhone)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .frame(width: 25, height: 25)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                        }
                        
                        if !displayContact.emailAddresses.isEmpty, let firstEmail = displayContact.emailAddresses.first {
                            Button(action: {
                                if let url = URL(string: "mailto:\(firstEmail)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .frame(width: 25, height: 25)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // Notes section
                if !displayContact.note.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(displayContact.note)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(displayContact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Fetch contact with notes when view appears
            await loadContactWithNotes()
        }
    }
    
    private func loadContactWithNotes() async {
        guard contactWithNotes == nil && !isLoadingNotes else { return }
        isLoadingNotes = true
        defer { isLoadingNotes = false }
        
        let repository = ContactsRepository()
        do {
            if let contactWithNotes = try await repository.fetchContactWithNotes(identifier: contact.id) {
                await MainActor.run {
                    self.contactWithNotes = contactWithNotes
                }
            }
        } catch {
            print("Error fetching contact with notes: \(error)")
            // Silently fail - use original contact without notes
        }
    }
}

