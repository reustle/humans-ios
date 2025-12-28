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
    /// Note: CNContactNoteKey requires special entitlement (com.apple.developer.contacts.notes)
    /// and is not included here. Notes can be fetched separately if needed.
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
                    thumbnailImageData: cnContact.thumbnailImageData,
                    note: "" // Note field requires special entitlement, left empty for now
                )
                contacts.append(contact)
            }
            
            return contacts
        }.value
    }
    
    /// Fetch a single contact by identifier with all keys including notes
    /// Falls back to fetching without notes if notes entitlement is unavailable
    func fetchContactWithNotes(identifier: String) async throws -> Contact? {
        let status = authorizationStatus()
        
        guard status == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        return try await Task.detached(priority: .userInitiated) { [contactStore, summaryKeysToFetch] in
            // Try to fetch with notes first
            // Include modification date key as string (no constant available)
            let keysWithNotes: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor,
                CNContactNoteKey as CNKeyDescriptor,
                "modificationDate" as CNKeyDescriptor
            ]
            
            do {
                let cnContact = try contactStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysWithNotes)
                let phoneNumbers = cnContact.phoneNumbers.map { $0.value.stringValue }
                let emailAddresses = cnContact.emailAddresses.map { $0.value as String }
                
                // Check if notes need normalization (missing date tag)
                var note = cnContact.note
                if !note.isEmpty {
                    // Check if note has our date tag format
                    let dateTagPattern = #"\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\]"#
                    let hasDateTag = (try? NSRegularExpression(pattern: dateTagPattern, options: []))?
                        .firstMatch(in: note, options: [], range: NSRange(location: 0, length: note.utf16.count)) != nil
                    
                    if !hasDateTag {
                        // Normalize the note by prepending a timestamp
                        // Try to use contact's modification date if available, otherwise use current time
                        // Note: CNContact framework doesn't provide per-property modification dates
                        var dateToUse = Date()
                        
                        // Try to access modification date using value(forKey:)
                        // This is safe because we're using optional casting
                        if cnContact.responds(to: Selector(("modificationDate"))) {
                            if let modificationDate = cnContact.value(forKey: "modificationDate") as? Date {
                                dateToUse = modificationDate
                            }
                        }
                        
                        // Format datetime in ISO 8601 UTC format (same format as new comments)
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
                        let timestamp = formatter.string(from: dateToUse)
                        
                        // Normalize the note by prepending the timestamp
                        let normalizedNote = "[\(timestamp)]\n\(note.trimmingCharacters(in: .whitespacesAndNewlines))"
                        
                        // Save the normalized note back to the contact store
                        let mutableContact = cnContact.mutableCopy() as! CNMutableContact
                        mutableContact.note = normalizedNote
                        
                        let saveRequest = CNSaveRequest()
                        saveRequest.update(mutableContact)
                        try contactStore.execute(saveRequest)
                        
                        // Use the normalized note
                        note = normalizedNote
                    }
                }
                
                return Contact(
                    id: cnContact.identifier,
                    givenName: cnContact.givenName,
                    familyName: cnContact.familyName,
                    organizationName: cnContact.organizationName,
                    phoneNumbers: phoneNumbers,
                    emailAddresses: emailAddresses,
                    thumbnailImageData: cnContact.thumbnailImageData,
                    note: note
                )
            } catch let error as NSError {
                // If it's an unauthorized keys error (code 102), fetch without notes
                if error.domain == CNError.errorDomain && error.code == 102 {
                    let cnContact = try contactStore.unifiedContact(withIdentifier: identifier, keysToFetch: summaryKeysToFetch)
                    let phoneNumbers = cnContact.phoneNumbers.map { $0.value.stringValue }
                    let emailAddresses = cnContact.emailAddresses.map { $0.value as String }
                    
                    return Contact(
                        id: cnContact.identifier,
                        givenName: cnContact.givenName,
                        familyName: cnContact.familyName,
                        organizationName: cnContact.organizationName,
                        phoneNumbers: phoneNumbers,
                        emailAddresses: emailAddresses,
                        thumbnailImageData: cnContact.thumbnailImageData,
                        note: ""
                    )
                }
                throw error
            }
        }.value
    }
    
    /// Checks if notes text contains our date tag format
    private func hasDateTagFormat(_ text: String) -> Bool {
        // Pattern for ISO 8601 date tags: [YYYY-MM-DDTHH:MM:SS(.SSS)?Z]
        let dateTagPattern = #"\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\]"#
        guard let regex = try? NSRegularExpression(pattern: dateTagPattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    /// Update a contact's note field
    /// Prepends new content to existing notes if append is true, otherwise replaces
    func updateContactNote(identifier: String, newNote: String, prepend: Bool = true) async throws {
        let status = authorizationStatus()
        
        guard status == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        return try await Task.detached(priority: .userInitiated) { [contactStore] in
            // Fetch the contact with notes to get current note
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactNoteKey as CNKeyDescriptor
            ]
            
            let cnContact = try contactStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
            
            // Create mutable copy
            let mutableContact = cnContact.mutableCopy() as! CNMutableContact
            
            // Update note: prepend new note if prepend is true, otherwise replace
            if prepend {
                let existingNote = cnContact.note
                if existingNote.isEmpty {
                    mutableContact.note = newNote
                } else {
                    mutableContact.note = "\(newNote)\n\n\(existingNote)"
                }
            } else {
                mutableContact.note = newNote
            }
            
            // Save the updated contact
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            
            try contactStore.execute(saveRequest)
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

