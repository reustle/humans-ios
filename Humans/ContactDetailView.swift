//
//  ContactDetailView.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import SwiftUI

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

