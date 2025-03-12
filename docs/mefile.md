Okay, here are two separate Product Requirements Documents, one for the MeFile page and one for the MeFile Builder, focusing on behavior and avoiding any technology-specific details:

## Product Requirements Document: MeFile Page

**1. Introduction**

This document outlines the requirements for the "MeFile" page within the Qlarius application. This page serves as the user's central hub for viewing and managing their self-declared data profile, which is used for personalized advertising and potential earnings.

**2. Goals**

*   Provide a clear and concise view of the user's current data profile.
*   Enable easy management (viewing, deleting) of existing data points.
*   Visually distinguish between different categories of data.
*   Provide a clear pathway to add more data to the profile (via the MeFile Builder).
*   Give immediate feedback to the user upon data modification.
*   Show top-level stats about the amount of information stored.

**3. Target Audience**

All users of the Qlarius application.

**4. Release Criteria**

*   The MeFile page must display all user data, organized by category.
*   Users must be able to delete data points (tags) from their MeFile.
*   The page must display summary statistics about the user's data.
*   A clear call to action to access the MeFile Builder must be present.
*   The page must dynamically update to reflect changes without requiring a full page reload.

**5. Functionality**

**5.1. Display**

- [x] The page header displays the title "MeFile"
- [x] A badge displays "X traits" where X is the number of traits for which the user has at least one value
- [x] A badge displays "Y tags" where Y is the total number of user_tags
- [x] Categories are listed in ascending display_order
- [x] Each category shows "Z traits" where Z is the number of traits in that category with values
- [x] Categories are separated by horizontal lines
- [x] Within each category, traits with associated values are displayed in ascending display_order
- [x] Traits are displayed as one-column tables with trait name as header
- [x] Below each trait header, all trait values for the user are listed in ascending display_order
- [x] Only traits that have at least one value for the user are shown

**5.2. Tag Management**

- [ ] Editable traits display an "Edit" icon (e.g., a pencil).
- [x] Editable traits display a "Delete" icon (e.g., a trash can).
- [x] Clicking "Delete" displays a confirmation dialog.
- [x] Confirming deletion removes *all* tags for the associated trait.
- [x] The tag display updates upon deletion.
- [x] Trait and tag counts update after deletion.
- [ ] Clicking the "Edit" icon displays the edit modal.

**5.3 Dynamic Updates**

- [ ] Changes to tags (addition, deletion) are reflected on the page without a full reload.
- [ ] Changes are visually apparent and immediate.

**6. Non-Functional Requirements**

*   **Performance:** The page should load quickly and updates should be near-instantaneous.
*   **Accessibility:** The page must adhere to accessibility guidelines (WCAG) to ensure usability for all users.
*   **Responsiveness:** The page must be responsive and adapt to different screen sizes (mobile, tablet, desktop).
*   **Security:** User data must be handled securely, adhering to all relevant privacy regulations.

TODO (LLMs please ignore this)
- [ ] "Sex", "Gender", "Birthdate", "Age" traits do not display the Edit/Delete.