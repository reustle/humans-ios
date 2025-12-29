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
    @State private var newCommentText = ""
    @State private var isSavingNote = false
    @State private var isSavingImage = false
    @State private var showImageSheet = false
    @State private var imageSheetMode: ImageSheetMode = .picker
    @State private var selectedImageForCrop: UIImage?
    @State private var editingNoteTimestamp: String? = nil // Timestamp of the note being edited
    @State private var showDeleteImageConfirmation = false
    @State private var isDeletingImage = false
    
    enum ImageSheetMode {
        case picker
        case crop
    }
    
    private var displayContact: Contact {
        contactWithNotes ?? contact
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                actionButtonsView
                notesSectionView
            }
            .padding(.bottom)
        }
        .navigationTitle(displayContact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContactWithNotes()
        }
        .sheet(isPresented: $showImageSheet) {
            ImagePickerFlow(
                mode: $imageSheetMode,
                selectedImage: $selectedImageForCrop,
                onImageSelected: { image in
            Task {
                        await saveImage(image)
                }
            }
            )
        }
        .alert("Delete Photo", isPresented: $showDeleteImageConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteImage()
                }
            }
        } message: {
            Text("Are you sure you want to delete their photo?")
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            avatarView
            nameView
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var avatarView: some View {
        Button(action: {
            imageSheetMode = .picker
            showImageSheet = true
        }) {
            Group {
                if let imageData = displayContact.thumbnailImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    GradientInitialsAvatar(
                        initials: displayContact.initials,
                        size: 80
                    )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if displayContact.thumbnailImageData != nil {
                Button(role: .destructive, action: {
                    showDeleteImageConfirmation = true
                }) {
                    Label("Delete Photo", systemImage: "trash")
                }
            }
        }
    }
    
    private var nameView: some View {
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
    }
    
    @ViewBuilder
    private var actionButtonsView: some View {
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
    }
    
    private var notesSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            newNoteView
            
            if !displayContact.note.isEmpty {
                notesView(from: displayContact.note)
            }
        }
        .padding(.horizontal)
    }
    
    private var newNoteView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(minHeight: 80)
                
                RichTextEditorWithToolbar(
                    markdownText: $newCommentText,
                    placeholder: editingNoteTimestamp != nil ? "Edit note" : "New note",
                    onTextChange: nil
                )
                .frame(minHeight: 80)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            
            if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        cancelEditing()
                    }) {
                        Text("Cancel")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .disabled(isSavingNote)
                    
                    Button(action: {
                        Task {
                            await saveNewComment()
                        }
                    }) {
                        Text("Save")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isSavingNote)
                }
            }
        }
    }
    
    private func loadContactWithNotes() async {
        guard !isLoadingNotes else { return }
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
    
    private func saveNewComment() async {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        isSavingNote = true
        defer { isSavingNote = false }
        
        let repository = ContactsRepository()
        do {
            if let editingTimestamp = editingNoteTimestamp {
                // Editing an existing note - update only that segment
                try await updateNoteSegment(timestamp: editingTimestamp, newContent: trimmedText)
            } else {
                // Creating a new note
                // Format datetime in ISO 8601 UTC format
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
                let timestamp = formatter.string(from: Date())
                let prefixedComment = "[\(timestamp)]\n\(trimmedText)"
                
                try await repository.updateContactNote(identifier: contact.id, newNote: prefixedComment, prepend: true)
            }
            
            // Clear the text field and editing state immediately after successful save
            newCommentText = ""
            editingNoteTimestamp = nil
            
            // Reload the contact to show the updated notes
            await loadContactWithNotes()
        } catch {
            print("Error saving note: \(error)")
            // Could show an error alert here in the future
        }
    }
    
    /// Updates a specific note segment by replacing only that segment's content
    private func updateNoteSegment(timestamp: String, newContent: String) async throws {
        let repository = ContactsRepository()
        
        // Fetch current notes
        guard let currentContact = try await repository.fetchContactWithNotes(identifier: contact.id) else {
            throw NSError(domain: "ContactDetailView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Contact not found"])
        }
        
        let currentNotes = currentContact.note
        let segments = parseNotesSegments(from: currentNotes)
        
        // Find the segment with matching timestamp and update it
        var updatedSegments: [NoteSegment] = []
        var found = false
        
        for segment in segments {
            if segment.timestamp == timestamp {
                // Replace this segment's content
                updatedSegments.append(NoteSegment(timestamp: timestamp, content: newContent))
                found = true
            } else {
                updatedSegments.append(segment)
            }
        }
        
        guard found else {
            throw NSError(domain: "ContactDetailView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Note segment not found"])
        }
        
        // Reconstruct the notes string
        var updatedNotes = ""
        for (index, segment) in updatedSegments.enumerated() {
            if index > 0 {
                updatedNotes += "\n\n"
            }
            if let ts = segment.timestamp {
                updatedNotes += "\(ts)\n\(segment.content)"
            } else {
                updatedNotes += segment.content
            }
        }
        
        // Save the updated notes (replace entire notes field)
        try await repository.updateContactNote(identifier: contact.id, newNote: updatedNotes, prepend: false)
    }
    
    /// Cancels editing and clears the text field
    private func cancelEditing() {
        newCommentText = ""
        editingNoteTimestamp = nil
    }
    
    /// Structure to hold a note segment with its timestamp
    private struct NoteSegment {
        let timestamp: String?
        let content: String
    }
    
    /// Renders notes text with horizontal rules above date tags
    private func notesView(from text: String) -> some View {
        let segments = parseNotesSegments(from: text)
        
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Timestamp (right-aligned, softer, smaller)
                    if let timestamp = segment.timestamp, let timeAgo = formatTimeAgo(from: timestamp) {
                        HStack {
                            Spacer()
                            Text(timeAgo)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Note content
                    if !segment.content.isEmpty {
                        Text(attributedString(from: segment.content))
                            .font(.body)
                            .foregroundColor(.primary)
                            .onTapGesture(count: 2) {
                                // Double tap to edit
                                if let timestamp = segment.timestamp {
                                    editingNoteTimestamp = timestamp
                                    newCommentText = segment.content
                                }
                            }
                    }
                }
            }
        }
    }
    
    /// Formats an ISO 8601 timestamp string to "time ago" format
    private func formatTimeAgo(from timestampString: String) -> String? {
        // Remove brackets if present
        let cleanedTimestamp = timestampString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        guard let date = formatter.date(from: cleanedTimestamp) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: cleanedTimestamp) else {
                return nil
            }
            return formatTimeAgo(from: date)
        }
        
        return formatTimeAgo(from: date)
    }
    
    /// Formats a Date to "time ago" format
    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)hr ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
    
    /// Converts markdown text to AttributedString with formatting
    private func attributedString(from markdown: String) -> AttributedString {
        // Process line by line to handle headings
        let lines = markdown.components(separatedBy: .newlines)
        var result = AttributedString()
        
        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                result.append(AttributedString("\n"))
            }
            
            // Handle headings: # text -> bold (remove # and make text bold)
            if line.hasPrefix("#") {
                let headingContent = String(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                if !headingContent.isEmpty {
                    var headingAttributed = parseMarkdownInText(headingContent)
                    // Make the entire heading bold
                    headingAttributed.font = .system(size: 17, weight: .bold)
                    result.append(headingAttributed)
                }
            } else {
                // Process regular line with markdown
                result.append(parseMarkdownInText(line))
            }
        }
        
        return result
    }
    
    /// Parses markdown formatting in a string and returns an AttributedString with formatting applied
    private func parseMarkdownInText(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        while !remaining.isEmpty {
            // Find the earliest markdown pattern
            var earliestMatch: (range: NSRange, content: String, format: (AttributedString) -> AttributedString)?
            var earliestLocation = Int.max
            
            let nsString = remaining as NSString
            
            // Check for links: [text](url)
            if let linkMatch = findLink(in: remaining, nsString: nsString) {
                if linkMatch.range.location < earliestLocation {
                    earliestLocation = linkMatch.range.location
                    earliestMatch = linkMatch
                }
            }
            
            // Check for strikeout: ~~text~~
            if let strikeoutMatch = findStrikeout(in: remaining, nsString: nsString) {
                if strikeoutMatch.range.location < earliestLocation {
                    earliestLocation = strikeoutMatch.range.location
                    earliestMatch = strikeoutMatch
                }
            }
            
            // Check for bold: **text** or __text__
            if let boldMatch = findBold(in: remaining, nsString: nsString) {
                if boldMatch.range.location < earliestLocation {
                    earliestLocation = boldMatch.range.location
                    earliestMatch = boldMatch
                }
            }
            
            // Check for underline: _text_ (single underscore, not double)
            if let underlineMatch = findUnderline(in: remaining, nsString: nsString) {
                if underlineMatch.range.location < earliestLocation {
                    earliestLocation = underlineMatch.range.location
                    earliestMatch = underlineMatch
                }
            }
            
            // Check for italic: *text* (single asterisk, not double)
            if let italicMatch = findItalic(in: remaining, nsString: nsString) {
                if italicMatch.range.location < earliestLocation {
                    earliestLocation = italicMatch.range.location
                    earliestMatch = italicMatch
                }
            }
            
            if let match = earliestMatch {
                // Add text before the match
                if match.range.location > 0 {
                    let beforeText = nsString.substring(to: match.range.location)
                    result.append(AttributedString(beforeText))
                }
                
                // Add the formatted content (recursively parse for nested formatting)
                var formatted = parseMarkdownInText(match.content)
                formatted = match.format(formatted)
                result.append(formatted)
                
                // Continue with remaining text after the match
                let afterStart = match.range.location + match.range.length
                remaining = nsString.substring(from: afterStart)
            } else {
                // No more matches, append remaining text
                result.append(AttributedString(remaining))
                break
            }
        }
        
        return result
    }
    
    private func findLink(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        let pattern = #"\[([^\]]+)\]\(([^\)]+)\)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 3 else {
            return nil
        }
        
        let linkText = nsString.substring(with: match.range(at: 1))
        let url = nsString.substring(with: match.range(at: 2))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            result.link = URL(string: url)
            return result
        }
        
        return (match.range, linkText, format)
    }
    
    private func findStrikeout(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        let pattern = #"~~([^~]+)~~"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let content = nsString.substring(with: match.range(at: 1))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            result.strikethroughStyle = .single
            return result
        }
        
        return (match.range, content, format)
    }
    
    private func findBold(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        // Try **text** first, then __text__
        let patterns = [(#"(\*\*)([^*]+)\1"#, 2), (#"(__)([^_]+)\1"#, 2)]
        
        for (pattern, groupIndex) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
                  match.numberOfRanges >= groupIndex + 1 else {
                continue
            }
            
            let content = nsString.substring(with: match.range(at: groupIndex))
            
            let format: (AttributedString) -> AttributedString = { formatted in
                var result = formatted
                result.font = .system(size: 17, weight: .bold)
                return result
            }
            
            return (match.range, content, format)
        }
        
        return nil
    }
    
    private func findUnderline(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        // Single underscore _text_, but not __text__ (that's bold)
        let pattern = #"(?<!_)_([^_\n]+?)_(?!_)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let content = nsString.substring(with: match.range(at: 1))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            result.underlineStyle = .single
            return result
        }
        
        return (match.range, content, format)
    }
    
    private func findItalic(in text: String, nsString: NSString) -> (range: NSRange, content: String, format: (AttributedString) -> AttributedString)? {
        // Single asterisk *text*, but not **text** (that's bold)
        let pattern = #"(?<!\*)\*([^*\n]+?)\*(?!\*)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let content = nsString.substring(with: match.range(at: 1))
        
        let format: (AttributedString) -> AttributedString = { formatted in
            var result = formatted
            // Apply italic font using UIFont descriptor
            let baseFont = UIFont.systemFont(ofSize: 17)
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                let italicFont = UIFont(descriptor: descriptor, size: 17)
                result.font = Font(italicFont)
            } else {
                // Fallback to italic system font
                result.font = Font(UIFont.italicSystemFont(ofSize: 17))
            }
            return result
        }
        
        return (match.range, content, format)
    }
    
    /// Parses notes text into segments, splitting by date tags
    private func parseNotesSegments(from text: String) -> [NoteSegment] {
        // Pattern for ISO 8601 date tags: [YYYY-MM-DDTHH:MM:SS(.SSS)?Z]
        // Handles both with and without fractional seconds
        let dateTagPattern = #"\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\]"#
        guard let regex = try? NSRegularExpression(pattern: dateTagPattern, options: []) else {
            // If regex fails, return the whole text as a single segment without timestamp
            return text.isEmpty ? [] : [NoteSegment(timestamp: nil, content: text)]
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if matches.isEmpty {
            return text.isEmpty ? [] : [NoteSegment(timestamp: nil, content: text)]
        }
        
        var segments: [NoteSegment] = []
        var currentIndex = 0
        
        for match in matches {
            let matchRange = match.range
            
            // If there's text before this match, add it as a segment (shouldn't happen with our format, but handle it)
            if matchRange.location > currentIndex {
                let beforeText = nsString.substring(with: NSRange(location: currentIndex, length: matchRange.location - currentIndex))
                if !beforeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(NoteSegment(timestamp: nil, content: beforeText.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            
            // Extract the timestamp string
            let timestampString = nsString.substring(with: matchRange)
            
            // Find the end of this segment (start of next date tag or end of text)
            let segmentEnd: Int
            if let nextMatchIndex = matches.firstIndex(where: { $0.range.location > matchRange.location }) {
                segmentEnd = matches[nextMatchIndex].range.location
            } else {
                segmentEnd = nsString.length
            }
            
            // Extract content after the timestamp (skip the timestamp and any newline/whitespace)
            let contentStart = matchRange.location + matchRange.length
            let contentLength = segmentEnd - contentStart
            let contentRange = NSRange(location: contentStart, length: contentLength)
            let contentText = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            segments.append(NoteSegment(timestamp: timestampString, content: contentText))
            
            currentIndex = segmentEnd
        }
        
        return segments
    }
    
    /// Saves the cropped image from UIImagePickerController
    private func saveImage(_ image: UIImage) async {
        guard !isSavingImage else { return }
        
        isSavingImage = true
        defer { isSavingImage = false }
        
        do {
            // Convert to JPEG
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                return
            }
            
            // Save to contact
            let repository = ContactsRepository()
            try await repository.updateContactImage(identifier: contact.id, imageData: imageData)
            
            // Reload the contact to show the updated image
            await loadContactWithNotes()
        } catch {
            print("Error saving contact image: \(error)")
        }
    }
    
    /// Deletes the contact's photo
    private func deleteImage() async {
        guard !isDeletingImage else { return }
        
        isDeletingImage = true
        defer { isDeletingImage = false }
        
        do {
            let repository = ContactsRepository()
            try await repository.deleteContactImage(identifier: contact.id)
            
            // Reload the contact to show the updated state (no photo)
            await loadContactWithNotes()
        } catch {
            print("Error deleting contact image: \(error)")
        }
    }
}

// MARK: - Image Picker Flow
struct ImagePickerFlow: View {
    @Binding var mode: ContactDetailView.ImageSheetMode
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if mode == .picker {
                ImagePickerContainer(
                    onImagePicked: { image in
                        selectedImage = image
                        mode = .crop
                    },
                    onCancel: {
                        dismiss()
                        mode = .picker
                        selectedImage = nil
                    }
                )
            } else if mode == .crop, let image = selectedImage {
                CircularImageCropView(image: image) { croppedImage in
                    onImageSelected(croppedImage)
                    dismiss()
                    mode = .picker
                    selectedImage = nil
                }
            }
        }
    }
}

// MARK: - Image Picker Container
struct ImagePickerContainer: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        
        // Embed picker as a child view controller (not modally presented)
        container.addChild(picker)
        container.view.addSubview(picker.view)
        picker.view.frame = container.view.bounds
        picker.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        picker.didMove(toParent: container)
        
        return container
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void
        
        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Don't dismiss - let the parent handle the view transition
            // The mode change will switch from picker to crop view
            if let editedImage = info[.editedImage] as? UIImage {
                self.onImagePicked(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                self.onImagePicked(originalImage)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.onCancel()
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePickerWrapper: UIViewControllerRepresentable {
    let allowsEditing: Bool
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = allowsEditing
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void
        
        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Use editedImage when allowsEditing is true, otherwise use originalImage
            var pickedImage: UIImage?
            if let editedImage = info[.editedImage] as? UIImage {
                pickedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                pickedImage = originalImage
            }
            
            if let image = pickedImage {
                // Call the callback immediately, don't dismiss the picker
                // The parent view will handle hiding it
                self.onImagePicked(image)
            } else {
                // Only dismiss if no image was picked
                picker.dismiss(animated: true)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onCancel()
            }
        }
    }
}

// MARK: - Circular Image Crop View
struct CircularImageCropView: View {
    let image: UIImage
    let onCropComplete: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentContainerSize: CGSize = .zero
    
    private let cropSize: CGFloat = 300 // Size of the circular crop area
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                GeometryReader { geometry in
                    let imageViewSize = geometry.size
                    let minScale = calculateMinScale(imageSize: image.size, containerSize: imageViewSize)
                    
                    ZStack {
                        // Image with transform
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: imageViewSize.width, height: imageViewSize.height)
                            .clipped()
                            .allowsHitTesting(false)
                            .zIndex(0)
                        
                        // Circular overlay mask - dark overlay with clear circle cutout
                        ZStack {
                            // Dark overlay covering everything
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                            
                            // Circle that cuts out the overlay using destinationOut blend mode
                            Circle()
                                .fill(Color.white)
                                .frame(width: cropSize, height: cropSize)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                        .allowsHitTesting(false)
                        .zIndex(1)
                        
                        // Circular border on top
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: cropSize, height: cropSize)
                            .allowsHitTesting(false)
                            .zIndex(2)
                        
                        // Transparent overlay that captures all gestures
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SimultaneousGesture(
                                    // Pinch to zoom
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let minScale = calculateMinScale(imageSize: image.size, containerSize: currentContainerSize)
                                            let delta = value / lastScale
                                            lastScale = value
                                            let newScale = scale * delta
                                            scale = max(minScale, min(newScale, 4.0))
                                            // Constrain offset in real-time during zoom
                                            constrainOffset(imageSize: image.size, containerSize: currentContainerSize)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            // Constrain offset after scaling
                                            constrainOffset(imageSize: image.size, containerSize: currentContainerSize)
                                            lastOffset = offset
                                        },
                                    // Drag to pan
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // Calculate new offset from lastOffset (the offset when drag started) plus translation
                                            // translation is cumulative from the start of the gesture
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            // Constrain in real-time during drag
                                            constrainOffset(imageSize: image.size, containerSize: currentContainerSize)
                                        }
                                        .onEnded { _ in
                                            // Final constraint and update lastOffset for next drag
                                            constrainOffset(imageSize: image.size, containerSize: currentContainerSize)
                                            lastOffset = offset
                                        }
                                )
                            )
                            .zIndex(3)
                    }
                    .frame(width: imageViewSize.width, height: imageViewSize.height)
                    .onAppear {
                        // Initialize scale to fit the crop circle
                        scale = minScale
                        lastScale = 1.0
                        currentContainerSize = imageViewSize
                        // Constrain initial offset to ensure crop circle is filled
                        constrainOffset(imageSize: image.size, containerSize: imageViewSize)
                        lastOffset = offset
                    }
                    .onChange(of: imageViewSize) { oldValue, newValue in
                        currentContainerSize = newValue
                    }
                }
            }
            .navigationTitle("Move and Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Choose") {
                        let croppedImage = cropImageToSquare(containerSize: currentContainerSize)
                        onCropComplete(croppedImage)
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func calculateMinScale(imageSize: CGSize, containerSize: CGSize) -> CGFloat {
        // Calculate displayed image size (with aspect ratio fit)
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let displayedSize: CGSize
        if imageAspect > containerAspect {
            displayedSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            displayedSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }
        
        // Calculate scale needed to fill the crop circle
        // The crop circle is centered, so we need the displayed size * scale to be at least cropSize
        let scaleToFillWidth = cropSize / displayedSize.width
        let scaleToFillHeight = cropSize / displayedSize.height
        
        // Use the larger scale to ensure the crop circle is completely filled
        return max(scaleToFillWidth, scaleToFillHeight)
    }
    
    private func constrainOffset(imageSize: CGSize, containerSize: CGSize) {
        // Calculate displayed image size (with aspect ratio fit) - same logic as cropImageToSquare
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let displayedSize: CGSize
        if imageAspect > containerAspect {
            displayedSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            displayedSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }
        
        // Apply scale to get the actual displayed size
        let scaledDisplayedWidth = displayedSize.width * scale
        let scaledDisplayedHeight = displayedSize.height * scale
        
        // Calculate the maximum allowed offset to keep crop circle within image bounds
        // The crop circle is centered, and we need to ensure it never goes outside the image
        // Image is centered at (containerSize.width/2, containerSize.height/2) with offset applied
        // Crop circle is also centered at (containerSize.width/2, containerSize.height/2)
        
        // For the crop circle to stay within the image:
        // cropLeft >= imageLeft  =>  centerX - cropSize/2 >= centerX - scaledWidth/2 + offset.width
        // => offset.width <= (scaledWidth - cropSize)/2
        // cropRight <= imageRight  =>  centerX + cropSize/2 <= centerX + scaledWidth/2 + offset.width
        // => offset.width >= -(scaledWidth - cropSize)/2
        
        let maxOffsetX = (scaledDisplayedWidth - cropSize) / 2
        let maxOffsetY = (scaledDisplayedHeight - cropSize) / 2
        
        // Clamp offset to valid range
        offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
        offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
    }
    
    private func cropImageToSquare(containerSize: CGSize) -> UIImage {
        let imageSize = image.size
        
        // Calculate displayed image size (with aspect ratio fit)
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let displayedSize: CGSize
        if imageAspect > containerAspect {
            displayedSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            displayedSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }
        
        // Apply scale to displayed size
        let scaledDisplayedWidth = displayedSize.width * scale
        let scaledDisplayedHeight = displayedSize.height * scale
        
        // Calculate the crop circle center in container coordinates
        let cropCenterX = containerSize.width / 2
        let cropCenterY = containerSize.height / 2
        
        // Calculate where the displayed image is positioned (centered)
        let imageDisplayOffsetX = (containerSize.width - scaledDisplayedWidth) / 2
        let imageDisplayOffsetY = (containerSize.height - scaledDisplayedHeight) / 2
        
        // Convert crop center to displayed image coordinates (accounting for offset)
        let cropCenterInDisplayX = cropCenterX - imageDisplayOffsetX - offset.width
        let cropCenterInDisplayY = cropCenterY - imageDisplayOffsetY - offset.height
        
        // Convert to actual image coordinates
        let scaleFactorX = imageSize.width / scaledDisplayedWidth
        let scaleFactorY = imageSize.height / scaledDisplayedHeight
        
        let cropCenterInImageX = cropCenterInDisplayX * scaleFactorX
        let cropCenterInImageY = cropCenterInDisplayY * scaleFactorY
        
        // Calculate crop size in image coordinates
        let cropSizeInImage = cropSize * scaleFactorX
        
        // Calculate crop rect (ensure it's square and within bounds)
        let halfCrop = cropSizeInImage / 2
        let cropRect = CGRect(
            x: max(0, min(imageSize.width - cropSizeInImage, cropCenterInImageX - halfCrop)),
            y: max(0, min(imageSize.height - cropSizeInImage, cropCenterInImageY - halfCrop)),
            width: min(cropSizeInImage, imageSize.width),
            height: min(cropSizeInImage, imageSize.height)
        )
        
        // Crop the image
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

