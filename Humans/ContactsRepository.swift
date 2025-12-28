//
//  ContactsRepository.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import Foundation
import Contacts

/// Repository for accessing and managing contacts from CNContactStore
/// Follows BUILD_PLAN.md: minimal keysToFetch for performance, summary-first approach
class ContactsRepository {
    private let contactStore = CNContactStore()
    
    /// Minimal keys for list/search display (summary-first approach)
    private let summaryKeysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor
    ]
    
    /// Check current authorization status (static method, doesn't need actor isolation)
    nonisolated func authorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
    
    /// Request contacts access permission
    /// Must be called from main thread
    @MainActor
    func requestAccess() async throws -> Bool {
        print("📱 requestAccess() called on main thread")
        return try await withCheckedThrowingContinuation { continuation in
            print("📱 Starting requestAccess continuation...")
            contactStore.requestAccess(for: .contacts) { granted, error in
                print("📱 requestAccess completion: granted=\(granted), error=\(String(describing: error))")
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    /// Fetch all contacts using minimal keys for performance
    /// CNContactStore is thread-safe, so we can enumerate in background
    func fetchAllContacts() async throws -> [Contact] {
        let status = authorizationStatus()
        
        guard status == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        // Run enumeration in a background task to avoid blocking UI
        // CNContactStore is thread-safe per Apple documentation
        return try await Task.detached(priority: .userInitiated) { [contactStore, summaryKeysToFetch] in
            let request = CNContactFetchRequest(keysToFetch: summaryKeysToFetch)
            request.sortOrder = .givenName
            
            var contacts: [Contact] = []
            
            try contactStore.enumerateContacts(with: request) { cnContact, _ in
                let phoneNumbers = cnContact.phoneNumbers.map { $0.value.stringValue }
                let emailAddresses = cnContact.emailAddresses.map { $0.value as String }
                
                let contact = Contact(
                    id: cnContact.identifier,
                    givenName: cnContact.givenName,
                    familyName: cnContact.familyName,
                    organizationName: cnContact.organizationName,
                    phoneNumbers: phoneNumbers,
                    emailAddresses: emailAddresses,
                    thumbnailImageData: cnContact.thumbnailImageData
                )
                contacts.append(contact)
            }
            
            return contacts
        }.value
    }
    
}

enum ContactsError: LocalizedError {
    case notAuthorized
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Contacts access is not authorized. Please grant permission in Settings."
        case .fetchFailed(let error):
            return "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }
}

