//
//  ContactsViewModel.swift
//  Humans
//
//  Created by Shane Reustle on 2025-12-28.
//

import Foundation
import SwiftUI
import Combine
import Contacts

/// View model managing contacts state and permissions
class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let repository = ContactsRepository()
    private var isRequestingAccess = false // Prevent duplicate requests
    
    init() {
        authorizationStatus = repository.authorizationStatus()
    }
    
    /// Load contacts if authorized, otherwise request permission
    @MainActor
    func loadContacts() async {
        // Prevent duplicate simultaneous requests
        guard !isRequestingAccess else {
            print("📱 Already requesting access, skipping...")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
            isRequestingAccess = false
        }
        
        // Check current status
        let currentStatus = repository.authorizationStatus()
        authorizationStatus = currentStatus
        
        //print("📱 Contacts authorization status: \(currentStatus.rawValue)")
        
        // If not determined, request access
        if currentStatus == .notDetermined {
            isRequestingAccess = true
            print("📱 Requesting contacts access...")
            
            // Ensure we're on main thread for the permission dialog
            await MainActor.run {
                // This ensures the permission dialog can appear
            }
            
            do {
                let granted = try await repository.requestAccess()
                let newStatus = repository.authorizationStatus()
                authorizationStatus = newStatus
                print("📱 Access request completed. Granted: \(granted), new status: \(newStatus.rawValue)")
                
                if !granted {
                    errorMessage = "Contacts access was denied. Please enable it in Settings."
                    return
                }
            } catch {
                print("📱 Error requesting access: \(error)")
                errorMessage = "Failed to request contacts access: \(error.localizedDescription)"
                return
            }
        }
        
        // Re-check status after potential request
        let finalStatus = repository.authorizationStatus()
        authorizationStatus = finalStatus
        
        // If denied or restricted, show error
        guard finalStatus == .authorized else {
            errorMessage = "Contacts access is not available. Please enable it in Settings."
            return
        }
        
        // Fetch contacts
        //print("📱 Fetching contacts...")
        do {
            let fetchedContacts = try await repository.fetchAllContacts()
            //print("📱 Fetched \(fetchedContacts.count) contacts")
            // Sort by modification date (most recent first), then by name for contacts without dates
            contacts = fetchedContacts.sorted { contact1, contact2 in
                let date1 = contact1.modificationDate ?? Date.distantPast
                let date2 = contact2.modificationDate ?? Date.distantPast
                if date1 != date2 {
                    return date1 > date2
                }
                // If dates are equal (or both nil), sort by name
                return contact1.displayName < contact2.displayName
            }
        } catch {
            print("📱 Error fetching contacts: \(error)")
            errorMessage = error.localizedDescription
            contacts = []
        }
    }
    
    /// Refresh contacts (re-fetch from store)
    @MainActor
    func refresh() async {
        await loadContacts()
    }
}

