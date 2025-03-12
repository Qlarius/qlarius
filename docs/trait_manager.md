# Product Requirements Document: Trait Manager

## 1. Introduction

This document outlines the requirements for the Trait Manager feature within the Qlarius application. The Trait Manager allows administrators (specifically users with "marketer" access, though currently protected by HTTP Basic Auth) to define and manage user traits and their associated values. These traits are used for categorizing users and targeting advertising campaigns. This PRD focuses specifically on the `/trait_manager` endpoint and its associated functionality.

## 2. Goals

*   Provide a centralized interface for managing all aspects of traits.
*   Enable efficient creation and organization of traits and their values.
*   Support different input types for trait values.
*   Facilitate the use of traits in other parts of the system (e.g., campaign targeting).
*   Provide a clear and intuitive user interface.

## 3. Target Audience

The primary users of the Trait Manager are Qlarius administrators responsible for defining and managing user attributes used for advertising targeting. These users are assumed to have a basic understanding of the Qlarius system and the concept of user traits.  The current implementation uses HTTP Basic Auth with username "marketer" and password "password" for access control.

## 4. Release Criteria

The Trait Manager feature will be considered complete and ready for release when:

*   All functionality described in this document is fully implemented and tested.
*   The user interface is intuitive and easy to use.
*   The system performs efficiently, even with a large number of traits and values.
*   All known bugs have been resolved.
*   Documentation (including updates to `_LOG.md`) is complete.
*   Code has been reviewed and formatted.

## 5. Functional Requirements

### 5.1. Trait Manager Page (`/trait_manager`)

- [x] The page shall have a three-column layout.
- [x] The left column shall display a list of all traits.
- [x] The middle column shall display the values associated with the currently selected trait.
- [x] The right column shall display a form for adding new trait values to the selected trait.
- [x] Access to the `/trait_manager` endpoint shall be restricted to users with "marketer" access (currently implemented via HTTP Basic Auth).
- [x] When the page is first loaded, the left column shall display all traits, sorted alphabetically by name.
- [x] When the page is first loaded, the middle and right columns shall be initially empty.

### 5.2. Left Column: Trait List

- [x] Each trait shall be displayed as a list item.
- [x] Each list item shall show the trait's name.
- [x] Each list item shall include a right-facing arrow icon (">") to visually indicate that clicking the trait will show more details.
- [x] The currently selected trait (if any) shall be visually highlighted (e.g., with a different background color).
- [x] Clicking on a trait in the list shall select that trait.
- [x] Selecting a trait shall populate the middle and right columns with the trait's values and the "Add Value" form, respectively.
- [x] A "+" button shall be displayed next to the "Traits" subheading.
- [x] Clicking the "+" button shall open a modal for creating a new trait.

### 5.3. Trait Creation Modal

- [x] The modal shall include a "Name" field (Text input, required).
- [x] The modal shall include an "Input Type" field (Dropdown, required).
- [x] The "Input Type" dropdown shall allow selection between "Single" and "Multi".
- [x] The modal shall include a "Trait Category" field (Dropdown, required).
- [x] The "Trait Category" dropdown shall allow selection from existing trait categories, sorted by `display_order`.
- [x] The "Trait Category" dropdown shall show a "Select category" prompt.
- [x] The modal shall include a "Create Trait" button.
- [x] The modal shall include a "Cancel" button.
- [x] Clicking the "Cancel" button shall close the modal without creating a trait.
- [x] The "Name" field shall be validated as required.
- [x] The "Input Type" field shall be validated as required.
- [x] The "Trait Category" field shall be validated as required.
- [x] Validation errors shall be displayed within the modal if submission fails.
- [x] Upon successful trait creation, the modal shall close.
- [x] Upon successful trait creation, the trait list in the left column shall be updated to include the new trait.
- [x] Upon successful trait creation, the form values shall be cleared.

### 5.4. Middle Column: Trait Values

- [x] The name of the currently selected trait shall be displayed as a subheading.
- [x] If the selected trait has associated values, they shall be displayed in a table.
- [x] The table shall have two columns: "Name" and "Order".
- [x] Trait values shall be sorted by their `display_order` attribute.
- [x] If the selected trait has no associated values, a message "No values defined." shall be displayed.

### 5.5. Right Column: Add Value Form

- [x] The heading "Add value" shall be displayed.
- [x] The form shall be displayed only when a trait is selected.
- [x] The form shall include a "Name" field (Text input, required).
- [x] The form shall include a "Display Order" field (Number input, required).
- [x] A hidden input field for `trait_id` shall be included, pre-populated with the ID of the selected trait.
- [x] The form shall include an "Add Value" button.
- [x] Clicking the "Add Value" button shall submit the form.
- [x] Upon successful submission, the new trait value shall be created and associated with the selected trait.
- [x] Upon successful submission, the trait values list in the middle column shall be updated.
- [x] Upon successful submission, the form fields shall be cleared and reset.
- [x] Upon failed submission, validation errors shall be displayed within the form.
- [x] The "Name" field shall be validated as required.
- [x] The "Display Order" field shall be validated as required.

## 6. Non-Functional Requirements

* **Performance:** The Trait Manager page and all its interactions should be responsive and load quickly, even with a large number of traits and values.
* **Usability:** The interface should be intuitive and easy to use for administrators.
* **Security:** Access to the Trait Manager should be properly restricted to authorized users.
* **Maintainability:** The code should be well-structured, documented, and easy to maintain.
* **Accessibility:** The Trait Manager should be accessible to users with disabilities, following accessibility best practices.
* **Responsiveness:** The Trait Manager should be responsive and work correctly on different screen sizes.

## 7. Future Considerations

* **Editing and Deleting Traits:** Implement functionality to edit and delete existing traits.
* **Editing and Deleting Trait Values:** Implement functionality to edit and delete existing trait values.
* **Bulk Operations:** Consider adding functionality for bulk operations, such as importing or exporting traits and values.
* **User Interface Improvements:** Explore options for improving the user interface, such as drag-and-drop functionality for reordering trait values.
* **Advanced Search/Filtering:** Implement search and filtering capabilities for traits and values.
* **Integration with other features:**  Ensure seamless integration with other Qlarius features, particularly campaign targeting.
* **Trait Group Management:** Consider integrating trait group management directly into the Trait Manager, rather than having a separate page.
* **Parent/Child Traits:**  Fully implement the parent/child trait relationship (currently only partially implemented).
* **More Input Types:** Consider supporting additional input types beyond "Single" and "Multi" (e.g., date, number, boolean).
* **User Interface for Assigning Traits:**  While not part of the *Trait Manager*, consider how users will be assigned traits (currently a many-to-many relationship between `User` and `Trait`). This might involve a separate administrative interface or integration with user profiles.

## 8. Open Issues

* The current implementation uses HTTP Basic Auth for "marketer" access.  A more robust authentication and authorization system should be implemented.
* The relationship between `Trait` and `TraitGroup` is defined, but the UI for managing this relationship is on a separate page (`/trait_groups`).  Consider integrating this into the Trait Manager.
* The handling of parent/child traits is incomplete. The `parent_id` field exists in the `Trait` model, but the UI doesn't fully leverage this relationship.
* The documentation in `_LOG.md` needs to be kept up-to-date with any changes.
* The handling of the `input_type` field (Single/Multi) is not fully defined.  The implications of this choice on data validation and UI presentation need to be clarified.
* The "display_order" field is present, but there is no UI to easily reorder traits or values.

This PRD provides a comprehensive overview of the requirements for the Qlarius Trait Manager. It serves as a guide for development and testing, ensuring that the final product meets the needs of the Qlarius application and its users.
