## Goals and constraints

* **Source of truth**: the system Contacts database via `CNContactStore` (read + write via `CNSaveRequest`). ([Apple Developer][1])
* **Standalone**: no custom backend; all indexing/enrichment runs **on-device**.
* **High performance**: instant search, smooth scrolling with large address books, incremental updates (no full re-scan on every launch).
* **Latest Apple design**: adopt the current system design language (Liquid Glass / new design system) using system components and behaviors. ([Apple Developer][2])
* **Privacy-first**: support modern Contacts and Photos permission models (including limited Contacts access and privacy-friendly Photos picking). ([Apple Developer][3])

---

## Core Apple frameworks to use

**Contacts**

* `CNContactStore` for fetching/saving contacts. ([Apple Developer][1])
* `CNContactFetchRequest` with `keysToFetch` for minimal, fast fetches. ([Apple Developer][4])
* `CNSaveRequest` to batch updates back into Contacts. ([Apple Developer][5])
* `CNContactStoreDidChange` notification to react while app is running. ([Apple Developer][6])
* Change tracking: `CNChangeHistoryFetchRequest` + persisted token for incremental index updates. ([Apple Developer][7])

**Search / indexing**

* **Core Spotlight** for a private, on-device index and semantic search + suggestions (good for “natural language” style queries). ([Apple Developer][8])
* Optionally: a lightweight **SQLite FTS** (or Core Data + FTS) for deterministic matching of phone/email and custom ranking (details below).

**Photos / ML for “smart photo finding”**

* `PHPickerViewController` for privacy-friendly photo selection. ([Apple Developer][9])
* Photo library observation + caching: `PHPhotoLibraryChangeObserver`, `PHCachingImageManager`. ([Apple Developer][10])
* Vision for face detection/quality/similarity:

  * `VNDetectFaceRectanglesRequest` ([Apple Developer][11])
  * `VNDetectFaceCaptureQualityRequest` (0–1 quality score) ([Apple Developer][12])
  * `VNGenerateImageFeaturePrintRequest` + `VNFeaturePrintObservation.computeDistance` for similarity scoring ([Apple Developer][13])

**Background processing**

* `BGAppRefreshTask` for periodic lightweight refresh. ([Apple Developer][14])
* `BGProcessingTask` for heavier local work (index rebuild segments, photo analysis batches). ([Apple Developer][15])
* (If targeting iOS 26+) `BGContinuedProcessingTaskRequest` for workloads the system can continue processing with visible progress/cancel affordance. ([Apple Developer][16])

**Scrolling performance**

* Collection/table prefetching APIs for avatars/thumbnails. ([Apple Developer][17])

---

## High-level architecture

Keep the app “Contacts-backed” while still being fast by introducing **derived local indexes and caches** that can always be rebuilt from Contacts + Photos.

```
Presentation (SwiftUI + UIKit where needed)
 ├─ Contact List + Search UI
 ├─ Contact Detail UI (sections, photos, socials)
 └─ Settings / Permissions / Diagnostics

Domain (Use-cases)
 ├─ SearchContacts(query)
 ├─ OpenContact(contactID)
 ├─ UpdateContact(contactID, edits)
 ├─ SuggestPhotos(contactID)
 └─ SuggestSocials(contactID)

Data / Services
 ├─ ContactsRepository (CNContactStore)
 ├─ ContactsChangeTracker (CNChangeHistory… token-based)
 ├─ SearchIndex
 │    ├─ CoreSpotlightIndex (semantic + suggestions)
 │    └─ FastExactIndex (phone/email/initials)  [optional]
 ├─ PhotoIndex + PhotoMatcher (PhotoKit + Vision)
 └─ LocalMetadataStore (SQLite/SwiftData)  // derived + app-only state
```

### Key design principle

* **Contacts store is authoritative**. Your app stores:

  * only **derived** data (search tokens, normalized strings, ranking signals, photo feature prints),
  * and **app-only** preferences (favorites, pinned contacts, last-opened timestamps),
  * all under strong local file protection.

---

## Contacts access and change tracking (performance-critical)

### 1) Fetch strategy: “summary first, detail on demand”

* **List/search results** should use a minimal projection:

  * name components, organization, primary phone/email, and `thumbnailImageData` only if needed.
* Use `keysToFetch` to keep fetches fast and memory-light. ([Apple Developer][18])

### 2) Incremental updates: don’t rebuild the world

* While running: listen to `CNContactStoreDidChange` and trigger a lightweight “sync pass.” ([Apple Developer][6])
* Across launches/background: persist a **change history token** and use `CNChangeHistoryFetchRequest` to fetch only changes since last token, then update indexes incrementally. ([Apple Developer][7])

This lets you:

* update the search index in milliseconds after small contact edits,
* avoid full enumeration of thousands of contacts on every cold start.

### 3) Writes: batch saves

* Apply edits back to Contacts using `CNSaveRequest` to batch multiple changes (and keep saves fast). ([Apple Developer][5])

---

## Search architecture (robust + fast)

You want “better search” than the system Contacts UI: multi-field, fuzzy-ish, phone/email aware, and optionally semantic/natural language.

### Recommended hybrid approach

#### A) Core Spotlight as the semantic layer

* Maintain a **named Core Spotlight index** containing one `CSSearchableItem` per contact.
* Store:

  * `uniqueIdentifier` = `CNContact.identifier`
  * `title` = display name
  * `textContent` = concatenated normalized fields you want searchable (company, job title, notes, emails, phones (normalized), social handles, etc.)
* Benefit: Apple provides **semantic search**, query understanding, ranked results, and suggestions; content stays in a **private, local index**. ([Apple Developer][8])
* Follow the performance guidance from Spotlight:

  * batch indexing + client state to avoid “over-donation” and rework ([Apple Developer][8])
  * preload query resources right before search UI appears ([Apple Developer][8])

#### B) Add a deterministic “fast exact” index (optional but recommended)

Core Spotlight is great for text. For “contacts-grade” behavior (phone digit matching, email prefix matching, initials), add a tiny local index:

* SQLite FTS or a custom inverted index for:

  * phone digits (E.164-ish normalized)
  * email local-part + domain
  * initials, nicknames, phonetic forms
* This provides:

  * predictable matching,
  * instant incremental filtering as user types,
  * stable ranking rules.

#### Ranking signals (local-only)

* Field weights: name > nickname > org > phone/email > notes.
* User affinity: last-opened, pinned/favorite, frequency of use (stored locally).
* Merge/dedupe: unify results by contact identifier.

---

## Smart photo finding (on-device, permission-aware)

Because there’s no backend, this feature must be **opt-in**, incremental, and power-aware.

### Permission model

* Default workflow uses `PHPickerViewController` so users can pick a photo without granting broad library access. ([Apple Developer][9])
* Offer an optional “scan my library to suggest photos” mode that requests Photo Library access; if enabled:

  * observe changes with `PHPhotoLibraryChangeObserver` ([Apple Developer][10])
  * cache thumbnails with `PHCachingImageManager` ([Apple Developer][19])

### Suggested architecture: two modes

#### Mode 1 — Seeded matching (high quality, controllable)

Works best when a contact already has at least one known image (or user selects a seed photo).

1. Obtain a seed face crop (existing contact photo or user-selected).
2. For candidate assets (recent N photos first, then expand):

   * detect faces: `VNDetectFaceRectanglesRequest` ([Apple Developer][11])
   * score quality: `VNDetectFaceCaptureQualityRequest` (0–1) ([Apple Developer][12])
   * compute feature print on cropped face: `VNGenerateImageFeaturePrintRequest` ([Apple Developer][13])
   * compare with seed using `computeDistance` (lower distance = more similar). ([Apple Developer][20])
3. Rank by: similarity + capture quality + recency.

Store only:

* asset localIdentifier,
* face bounding box,
* feature print (or a compact representation if permitted),
* quality score,
* last processed timestamp.

#### Mode 2 — “Best face” suggestions (no seed)

If no seed exists, you can still help:

* Find high-quality faces in recent photos and present as suggestions, without claiming identity certainty.
* Let the user confirm “this is Alice” (then it becomes seeded going forward).

### Background execution

* Use `BGProcessingTask` for scanning batches (minutes-long, interruptible). ([Apple Developer][15])
* On iOS 26+, consider `BGContinuedProcessingTaskRequest` for an explicit user-visible “scanning photos” task with cancellation. ([Apple Developer][16])

### UI performance

* Photo grids must use prefetching and cached thumbnails:

  * `UICollectionViewDataSourcePrefetching` / `UITableViewDataSourcePrefetching` ([Apple Developer][17])
  * `PHCachingImageManager` for batch preload ([Apple Developer][19])

---

## Social profile finding (no backend)

Without a backend (and without depending on 3rd-party APIs), treat this as **local extraction + user-assisted completion**:

### Sources inside Contacts

* Display and index fields already present (social profiles, URL addresses, IM addresses, notes).

### Local inference and suggestions

* Parse existing fields for handles/URLs (e.g., `@username`, `linkedin.com/in/...`) and propose structured entries.
* Infer likely company domain from email domain; propose “Open LinkedIn search for Name + Company” as a one-tap action (opens Safari), rather than attempting server-side resolution.

### Persisting results

* If a user confirms a found profile:

  * write it back into the contact (e.g., URL address or social profile entry) via `CNSaveRequest`. ([Apple Developer][5])

---

## UI architecture and Apple’s latest design recommendations

### Navigation model

Use a tab-based structure with a **first-class Search experience**:

* Tabs: **Search**, Contacts, Favorites/Pinned, Settings
* Apple’s latest guidance explicitly calls out a **dedicated Search tab** in iOS tab bars. ([Apple Developer][21])

### Liquid Glass / new design system adoption

Follow the core principles:

* Use Liquid Glass primarily for the **navigation layer** (toolbars, tab bars, navigation chrome), not for content like lists. ([Apple Developer][2])
* Avoid “glass on glass” layering; don’t stack Liquid Glass materials. ([Apple Developer][2])
* Don’t add custom background colors behind toolbars/tab bars; rely on layout/grouping for hierarchy. ([Apple Developer][21])
* Ensure your UI works well with system accessibility modifiers:

  * Reduced Transparency / Increased Contrast / Reduced Motion apply automatically when you use the system materials. ([Apple Developer][2])

(Conceptual basis / system description of Liquid Glass: translucent, reflective/refractive material applied across controls/navigation.) ([Apple][22])

### Contacts permission UX (important for adoption)

Support iOS 18+ limited access flows:

* Integrate **ContactAccessButton** into your search flow to grant access to additional contacts as needed. ([Apple Developer][3])
* This avoids demanding full access up front and aligns with Apple’s recommended “ask at the moment of need” pattern. ([Apple Developer][3])

### Where SwiftUI vs UIKit fits for performance

* Use **SwiftUI** for most screens to adopt new design behaviors quickly.
* Use **UIKit** (UICollectionView + diffable data source + prefetching) for:

  * very large contact lists with section index,
  * avatar-heavy grids (photos),
  * extremely tight scroll performance requirements.
    Prefetching APIs are explicitly designed to prepare cell data ahead of display. ([Apple Developer][17])

---

## Performance checklist (practical implementation rules)

1. **Never fetch full contacts for list/search**
   Use `keysToFetch` with only what the UI needs. ([Apple Developer][18])

2. **Two-tier data loading**

   * ContactSummary for list/search.
   * ContactDetail fetched lazily when opening a contact.

3. **Incremental indexing**

   * Use change history fetch + token to update indexes without full scans. ([Apple Developer][7])

4. **Indexing and photo scanning are background tasks**

   * `BGAppRefreshTask` for lightweight refreshes. ([Apple Developer][14])
   * `BGProcessingTask` for heavy work. ([Apple Developer][15])

5. **Aggressive caching**

   * In-memory LRU for contact thumbnails.
   * `PHCachingImageManager` for photo thumbnails. ([Apple Developer][19])

6. **Smooth scrolling**

   * Implement prefetching for avatars/thumbnails and cancel when no longer needed. ([Apple Developer][17])

---

## Suggested implementation milestones

### Milestone 1 — Contacts-backed core

* Permissions + limited access support (ContactAccessButton integrated into search). ([Apple Developer][3])
* Fast list rendering + detail view.
* Editing and saving back with `CNSaveRequest`. ([Apple Developer][5])

### Milestone 2 — High-performance search

* Build local index from Contacts with minimal `keysToFetch`. ([Apple Developer][18])
* Incremental updates via change history token. ([Apple Developer][7])
* Add Core Spotlight semantic layer + suggestions for “natural language” queries. ([Apple Developer][8])

### Milestone 3 — Smart photos (opt-in)

* Photo picker-based assignment (no broad permission required). ([Apple Developer][9])
* Optional photo-library scanning:

  * Vision pipeline (faces + quality + similarity). ([Apple Developer][11])
  * Background batches. ([Apple Developer][15])

### Milestone 4 — Social enrichment + polish

* Local parsing + suggestion UI, write-back to Contacts when confirmed.
* Liquid Glass / new design system final pass (ensure no glass-on-glass, navigation-layer-only glass). ([Apple Developer][2])

---

If you want a concrete next step: implement the **ContactsChangeTracker + SearchIndex** first (summary fetch + incremental updates + fast UI), because everything else (photos/social) benefits from having a stable, low-latency contact identifier → metadata/index mapping.

[1]: https://developer.apple.com/documentation/contacts/cncontactstore?utm_source=chatgpt.com "CNContactStore | Apple Developer Documentation"
[2]: https://developer.apple.com/videos/play/wwdc2025/219/ "Meet Liquid Glass - WWDC25 - Videos - Apple Developer"
[3]: https://developer.apple.com/videos/play/wwdc2024/10121/ "Meet the Contact Access Button - WWDC24 - Videos - Apple Developer"
[4]: https://developer.apple.com/documentation/contacts/cncontactfetchrequest?utm_source=chatgpt.com "CNContactFetchRequest | Apple Developer Documentation"
[5]: https://developer.apple.com/documentation/contacts/cnsaverequest?utm_source=chatgpt.com "CNSaveRequest - Documentation"
[6]: https://developer.apple.com/documentation/Foundation/NSNotification/Name-swift.struct/CNContactStoreDidChange?utm_source=chatgpt.com "CNContactStoreDidChange"
[7]: https://developer.apple.com/documentation/contacts/cnchangehistoryfetchrequest?utm_source=chatgpt.com "CNChangeHistoryFetchRequest"
[8]: https://developer.apple.com/la/videos/play/wwdc2024/10131/ "Support semantic search with Core Spotlight - WWDC24 - Videos - Apple Developer"
[9]: https://developer.apple.com/documentation/PhotoKit/delivering-an-enhanced-privacy-experience-in-your-photos-app?utm_source=chatgpt.com "Delivering an Enhanced Privacy Experience in Your ..."
[10]: https://developer.apple.com/documentation/photos/phphotolibrarychangeobserver?utm_source=chatgpt.com "PHPhotoLibraryChangeObserver"
[11]: https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest?utm_source=chatgpt.com "VNDetectFaceRectanglesRequest"
[12]: https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest?changes=_6&utm_source=chatgpt.com "VNDetectFaceCaptureQualityRe..."
[13]: https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest?utm_source=chatgpt.com "VNGenerateImageFeaturePrintR..."
[14]: https://developer.apple.com/documentation/backgroundtasks/bgapprefreshtask?utm_source=chatgpt.com "BGAppRefreshTask | Apple Developer Documentation"
[15]: https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask?utm_source=chatgpt.com "BGProcessingTask | Apple Developer Documentation"
[16]: https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask?utm_source=chatgpt.com "BGContinuedProcessingTask"
[17]: https://developer.apple.com/documentation/uikit/uicollectionviewdatasourceprefetching/collectionview%28_%3Aprefetchitemsat%3A%29?utm_source=chatgpt.com "collectionView(_:prefetchItemsAt:)"
[18]: https://developer.apple.com/documentation/contacts/cncontactfetchrequest/keystofetch?utm_source=chatgpt.com "keysToFetch | Apple Developer Documentation"
[19]: https://developer.apple.com/documentation/photos/phcachingimagemanager?utm_source=chatgpt.com "PHCachingImageManager | Apple Developer Documentation"
[20]: https://developer.apple.com/documentation/vision/vnfeatureprintobservation/computedistance%28_%3Ato%3A%29?utm_source=chatgpt.com "computeDistance(_:to:) | Apple Developer Documentation"
[21]: https://developer.apple.com/videos/play/wwdc2025/356/ "Get to know the new design system - WWDC25 - Videos - Apple Developer"
[22]: https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/?utm_source=chatgpt.com "Apple introduces a delightful and elegant new software ..."
