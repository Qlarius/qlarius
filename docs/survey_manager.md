# Survey Manager Page Specification

## Overview

The Survey Manager page provides users with a centralized interface to view, create, and manage Surveys and their Categories. The page follows a two-column layout design, where the left column displays hierarchical survey data, and the right column shows details of the selected survey.

## Page Structure

*   **URL Path**: `/survey_manager`
*   **Page Title**: "Survey Manager"
*   **Layout**: Two-column design* *   Left: Categories and Surveys listing
      *   Right: Selected Survey details (initially empty)

## Left Column: Categories and Surveys List

*   Displays all Survey Categories in ascending `display_order`
*   Each Category section includes:* *   Category name as a heading
      *   "+" button adjacent to the name for adding new surveys
      *   List of Surveys within that category, displayed in ascending `display_order`

## Survey Creation

*   Triggered by clicking the "+" button next to a Category name
*   Opens a modal with the following fields:* *   **Name**: Text input field
      *   **Category**: Dropdown menu pre-populated with all existing Survey Categories* *   Default selection is the Category whose "+" button was clicked
      *   **Display Order**: Number input field (default value: 1)
*   Form validation occurs on submission* *   If validation fails, errors are displayed within the modal
      *   If successful:* *   New Survey is created
      *     *   Left panel list is updated to include the new Survey
      *     *   Modal closes automatically
      *     *   Newly created Survey is selected and displayed in the right panel

## Survey Selection and Editing

*   Clicking a Survey name in the left panel selects it and displays its details in the right panel
*   The right panel initially shows:* *   Survey name as a heading
      *   Edit icon next to the heading
*   Clicking the edit icon opens a modal with the same fields as the creation modal:* *   **Name**: Pre-filled with current Survey name
      *   **Category**: Pre-selected with current Survey category
      *   **Display Order**: Pre-filled with current display order value
*   Form validation occurs on submission* *   If validation fails, errors are displayed within the modal
      *   If successful:* *   Survey details are updated
      *     *   Left panel list and right panel are refreshed to reflect changes
      *     *   Modal closes automatically

## Implementation Checklist

### Page Setup and Layout

- [x]    Create route for `/survey_manager` path
- [x]    Design two-column layout structure
- [x]    Implement page title "Survey Manager"

### Data Fetching

- [x]    Fetch all Survey Categories ordered by `display_order` (ascending)
- [x]    Fetch all Surveys ordered by `display_order` (ascending) within each category
- [x]    Implement efficient data loading to minimize page load time

### Left Panel Implementation

- [x]    Render Category headings with proper styling
- [x]    Add "+" button next to each Category heading
- [x]    List Surveys under each Category with proper indentation
- [x]    Implement proper ordering based on display\_order attribute

### Modal Implementation

- [x]    Create reusable modal component
- [x]    Implement "New Survey" modal with required fields
- [x]    Implement "Edit Survey" modal with pre-filled fields
- [x]    Add validation for all form fields

### Survey Creation Functionality

- [x]    Implement handler for "+" button click events
- [x]    Pre-select correct Category in dropdown
- [x]    Set default Display Order to 1
- [x]    Implement form submission and validation
- [x]    Create server-side action to add new Survey to database
- [x]    Refresh left panel upon successful creation
- [x]    Automatically select and display newly created Survey

### Survey Selection Functionality

- [x]    Implement Survey selection on click
- [x]    Display selected Survey name in right panel
- [x]    Add edit icon next to Survey name
- [x]    Maintain selection state across page interactions

### Survey Editing Functionality

- [x]    Implement handler for edit icon click events
- [x]    Pre-fill modal fields with current Survey data
- [x]    Implement form submission and validation
- [x]    Create server-side action to update Survey in database
- [x]    Refresh both panels upon successful update

### UI/UX Enhancements

- [ ]    Add visual indication for selected Survey
- [ ]    Implement smooth transitions between states
- [ ]    Ensure responsive design works on different screen sizes

## Test Cases

### Page Loading Tests

- [ ]    Verify page loads correctly at `/survey_manager` path
- [ ]    Verify all Categories and Surveys are displayed in correct order
- [ ]    Verify right panel is initially empty

### Survey Creation Tests

- [ ]    Verify "+" button opens the creation modal
- [ ]    Verify correct Category is pre-selected in the modal
- [ ]    Test validation by submitting empty form
- [ ]    Test validation by submitting duplicate Survey name
- [ ]    Verify successful creation adds Survey to correct Category
- [ ]    Verify new Survey appears in correct position based on display\_order
- [ ]    Verify newly created Survey is automatically selected and displayed

### Survey Selection Tests

- [ ]    Verify clicking a Survey name selects it and displays it in right panel
- [ ]    Verify visual indication of currently selected Survey

### Survey Editing Tests

- [ ]    Verify edit icon opens edit modal with correct pre-filled data
- [ ]    Test validation by submitting empty fields
- [ ]    Test changing Survey name
- [ ]    Test changing Survey category
- [ ]    Test changing display\_order
- [ ]    Verify changes are reflected in both panels after update

### Edge Cases

- [ ]    Test with empty Categories (no Surveys)
- [ ]    Test with large numbers of Categories and Surveys
- [ ]    Test with very long Category and Survey names
- [ ]    Test with special characters in names
