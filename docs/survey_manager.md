**Product Requirements Document: Survey Manager

**1. Introduction**

This document outlines the product requirements for the `/survey_manager` LiveView within the Qlarius Phoenix application.  This LiveView provides an interface for managing surveys, including viewing, creating, editing, and deleting them. It also allows for associating surveys with categories.  Critically, this version describes *only* the functionality present in the code, not planned or documented features.

**2. Goals**

*   Provide a centralized interface for managing surveys.
*   Enable users to create and modify surveys.
*   Enable users to delete surveys.
*   Associate surveys with pre-existing categories.
*   Facilitate easy navigation and interaction with survey data.

**3. Target Audience**

The target audience for this LiveView includes users who need to create and manage surveys within the Qlarius application. These users likely have administrative or content creation roles.

**4. Release Criteria**

The `/survey_manager` LiveView is considered ready for release when it meets all the functional requirements outlined in Section 5.

**5. Functional Requirements**

**5.1.  Survey Listing and Overall Page Structure**

- [x] The page displays a heading "Survey Manager".
- [x] The page is divided into three columns.
- [x] The left column displays survey categories and their associated surveys.
- [x] The middle column displays details of the selected survey (or a message if none is selected).
- [x] The right column displays available traits that can be added to the selected survey.
- [x] Survey Categories are displayed in ascending order of their `display_order` attribute.
- [x] Surveys within each category are displayed in ascending order of their `display_order` attribute.

**5.2. Left Column: Categories and Surveys**

- [ ] Each category is displayed with its name as a heading.
- [ ] A "+" button is displayed next to each category name, linking to the "new survey" form pre-selected with that category.
- [x] Under each category heading, surveys are listed by name, ordered by their `display_order`
- [x] Clicking a survey link updates the URL to `/survey_manager/<survey_id>` and displays its details.

**5.3. Middle Column: Survey Details**

- [x] If no survey is selected, the right column displays the message "Select a survey from the left panel to view details".
- [x] If a survey is selected, the right column displays the survey's name as a heading.
- [x] An "edit" icon (pencil) is displayed next to the survey name heading.
- [x] Clicking the edit icon opens the edit modal for the selected survey.
- [x] Below the survey name, each trait is displayed in a panel.
- [x] Each trait panel shows:
  - The trait name as the panel title
  - An "x" button in the top right to remove the trait from the survey
  - The trait's question (if present)
  - A list of the trait's values ordered by display_order
  - For each value:
    - A disabled checkbox (if trait type is "checkboxes") or radio button (if trait type is "radios")
    - The value's answer (if present) or name as fallback
- [x] Clicking the "x" button removes the trait from the survey immediately

**5.4.  New Survey Creation**

- [ ] Clicking the "+" button next to a category name opens a modal dialog with a form.
- [ ] The form contains fields for "Name" (text input), "Category" (select dropdown), and "Display Order" (number input).
- [ ] The "Category" dropdown is pre-populated with all existing survey categories.
- [ ] When opened from a category's "+" button, the "Category" dropdown is pre-selected with that category.
- [ ] The "Display Order" field defaults to 1.
- [ ] The form contains a "Save" button.
- [ ] The form contains a "Cancel" button that closes the modal.
- [ ] Clicking "Save" with valid data creates a new survey.
- [x] After successful creation, the URL updates to `/survey_manager/<survey_id>` to select the new survey.
- [x] A success flash message is displayed upon successful creation.
- [x] The newly created survey is automatically selected, and its details are displayed in the right column.
- [ ] Clicking "Save" with invalid data (e.g., empty name) displays an error message within the modal.
- [ ] The modal remains open if there are validation errors.

**5.5.  Survey Editing**

- [ ] Clicking the "edit" icon for a survey displays a modal dialog with a form pre-populated with the survey's data.
- [ ] The form contains fields for "Name" (text input), "Category" (select dropdown), and "Display Order" (number input).
- [ ] The "Category" dropdown is pre-populated with all existing survey categories.
- [ ] The form contains a "Save" button.
- [ ] The form contains a "Cancel" button that closes the modal.
- [ ] Clicking "Save" with valid data updates the survey.
- [ ] After successful update, the user is redirected back to the survey list (same view).
- [ ] A success flash message is displayed upon successful update.
- [ ] The updated survey remains selected, and its updated details are displayed in the right column.
- [ ] Clicking "Save" with invalid data (e.g., empty name) displays an error message within the modal.
- [ ] The modal remains open if there are validation errors.

**6. Non-Functional Requirements**

*   **Performance:** The LiveView should load and respond to user interactions quickly.
*   **Usability:** The interface should be intuitive and easy to use.
*   **Accessibility:** The LiveView should be accessible to users with disabilities. (Note: This is a general requirement, and the provided code may or may not fully meet accessibility standards. This PRD focuses on *current* functionality.)
*   **Security:** The LiveView should prevent unauthorized access and modification of data.

**5.6. Right Column: Available Traits**

- [x] The right column is only visible when a survey is selected.
- [x] Available traits are grouped by their categories.
- [x] Categories are ordered by their `display_order` attribute.
- [x] Only categories with at least one available trait are shown.
- [x] Each trait is displayed in a three-column table:
  - A left chevron button that adds the trait to the survey
  - The trait name
  - The trait's question (if present)
- [x] Adding a trait to the survey immediately removes it from the available traits list.
- [x] If removing a trait from the survey makes it available again, it reappears in the right column.
- [x] If a trait is the last one in its category, removing it from the survey makes the category reappear.

**7. Open Issues and Risks**

