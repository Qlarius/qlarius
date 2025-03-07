# Trait Categories Page Requirements

- [x] Create route at `/trait_categories`
- [x] Create a controller or LiveView for trait categories
- [x] Fetch all trait categories sorted by display_order ascending
- [x] Display trait categories in a table using CoreComponents.table/1 with columns:
  - [x] Name
  - [x] Display order
  - [x] Actions column with Edit and Delete buttons
- [x] Implement Edit functionality
  - [x] Create edit form with fields for name and display_order
  - [x] Validate and save changes
- [x] Implement Delete functionality
  - [x] Show confirmation modal before deleting
  - [x] Delete the category on confirmation
- [x] Update documentation in _LOG.md 