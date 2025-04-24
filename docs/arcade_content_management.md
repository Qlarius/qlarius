**Product Requirements Document: Qlarius Creator Content Management**

1. Introduction

This document outlines the functionality for managing Creators and their associated Catalogs within the Qlarius application, specifically focusing on the features accessible under the /creators path.

2. Goals

- Provide a public interface to view all Creators.
- Allow any user (no authentication required) to create, edit, and delete Creators.
- Display the Catalogs associated with each Creator.
- Allow any user (no authentication required) to create, edit, and delete Catalogs associated with a specific Creator.
- Organize Catalogs logically under their respective Creators.

3. Target Audience

Any user or administrator interacting with the Qlarius application. No authentication is required to access or modify Creator and Catalog data via these routes.

4. Functional Requirements

Note: all templates must be wrapped in the 'creators' Layout e.g.:

```heex
<Layouts.creators {assigns}>
  <.header>
    New Content Group
  </.header>

  <.content_group_form changeset={@changeset} action={~p"/creators/content_groups"} />

  <.back navigate={~p"/creators/content_groups"}>Back to content groups</.back>
</Layouts.creators>
```

Context functions belong in Qlarius.Creators (`lib/qlarius/creators.ex)`

4.1. Navigation & Routing

Accessing the base /creators path displays the Creator index page.

All controllers and views are in the QlariusWeb.Creators namespace.

Standard RESTful routes exist for Creator CRUD operations (e.g., /creators, /creators/new, /creators/:id, /creators/:id/edit).

Standard RESTful routes exist for Catalog CRUD operations, nested under creators (e.g., /creators/:creator_id/catalogs/new, /creators/:creator_id/catalogs/:id/edit).

These routes are piped through the :browser pipeline but not the :require_authenticated_user plug. If served by a LiveView then the routes are wrapped in a live_session which calls `:mount_current_scope` on mount.

4.2. Creator Management

4.2.1. Creator Index Page (/creators)

- Displays a list of all existing Creators.
- Creators are listed alphabetically by name.
- Includes a header "Creators".
- Provides a "New Creator" button linking to the new creator form (/creators/new).
- Displays Creators in a table, rendered by `CoreComponents.table/1` with columns:
    - Name (Creator's name)
- Each row in the table is clickable, navigating to the respective Creator's show page (/creators/:id).
- Each row has action links/buttons for:
    - Edit (navigates to edit page /creators/:id/edit)
    - Delete (triggers deletion workflow)

4.2.2. New Creator Page (/creators/new)

- Displays a form to create a new Creator.
- Includes a header "New Creator".
- The form includes a field for:
    - Name (Text input, required)
- Provides a "Save Creator" button.
- Includes a "Back to creators" link navigating to the index page.
- Form submission triggers the create action.

4.2.3. Create Creator Action

Attempts to create a new Creator.

On success:
- Displays an info flash message: "Creator created successfully." (Note: Flash persistence might depend on session state, which isn't required here).
- Redirects to the Creator index page (/creators).

On failure (validation error):
- Re-renders the new page with the changeset containing errors.

4.2.4. Creator Show Page (/creators/:id)

- Displays details for a specific Creator.
- Displays the Creator's name as the header.
- Provides an "Edit" button linking to the edit page (/creators/:id/edit).
- Provides a "Delete" button triggering the delete action for the Creator.
- Includes a section titled "Catalogs".
- Provides an "Add Catalog" button linking to the new catalog form for this creator (/creators/:id/catalogs/new).
- Displays associated Catalogs in a table, ordered alphabetically by name.
- The Catalog table has columns:
    - Name (Catalog name)
    - URL (Catalog url)
    - Type (Catalog type)
- Each Catalog row has action links/buttons for:
    - Edit (navigates to /creators/:creator_id/catalogs/:catalog_id/edit)
    - Delete (triggers deletion workflow for the catalog)
- Includes a "Back to creators" link navigating to the Creator index page.

4.2.5. Edit Creator Page (/creators/:id/edit)

- Displays a form pre-filled with data for a specific Creator.
- Includes a header "Edit Creator".
- The form includes a field for:
    - Name (Text input, required)
- Provides a "Save Creator" button.
- Includes a "Back to creators" link navigating to the index page.
- Form submission triggers the update action.

4.2.6. Update Creator Action

- Attempts to update a specific Creator.
- On success:
    - Displays an info flash message: "Creator updated successfully."
    - Redirects to the Creator index page (/creators).
- On failure (validation error):
    - Re-renders the edit page with the changeset containing errors.

4.2.7. Delete Creator Action

- Requires confirmation ("Are you sure?"). (Use `data-confirm`)
- Attempts to delete a specific Creator.
- On success:
    - Displays an info flash message: "Creator deleted successfully."
    - Redirects to the Creator index page (/creators).

4.3. Catalog Management (within Creator Context)

4.3.1. Context

- Catalogs are listed and managed exclusively through the show page of their associated Creator. There is no global catalog index.

4.3.2. New Catalog Page (/creators/:creator_id/catalogs/new)

- Displays a form to create a new Catalog for a specific Creator.
- Includes a header "New Catalog".
- The Creator context (creator_id) is implicitly passed based on the URL.
- The form includes fields for:
    - Name (Text input, required)
    - URL (Text input, required)
- Type (Select dropdown, required, options: "site", "catalog", "collection", "shows", "curriculum", "semester")
- Provides a "Save Catalog" button.
- Includes a "Back to creator" link navigating to the parent Creator's show page.
- Form submission triggers the create action (nested under the creator).

4.3.3. Create Catalog Action

- Attempts to create a new Catalog associated with the specified creator_id.
- On success:
    - Displays an info flash message: "Catalog created successfully."
    - Redirects to the parent Creator's show page (/creators/:creator_id).
- On failure (validation error):
    - Re-renders the new catalog page with the changeset containing errors.

4.3.4. Edit Catalog Page (/creators/:creator_id/catalogs/:id/edit)

- Displays a form pre-filled with data for a specific Catalog.
- Includes a header "Edit Catalog".
- The form includes fields for Name, URL, and Type (identical to the new form).
- Provides a "Save Catalog" button.
- Includes a "Back to creator" link navigating to the parent Creator's show page.
- Form submission triggers the update action (nested under the creator).

4.3.5. Update Catalog Action

- Attempts to update a specific Catalog.
- On success:
    - Displays an info flash message: "Catalog updated successfully."
    - Redirects to the parent Creator's show page (/creators/:creator_id).
- On failure (validation error):
    - Re-renders the edit catalog page with the changeset containing errors.

4.3.6. Delete Catalog Action

- Triggered from the Creator show page's catalog list.
- Requires confirmation ("Are you sure?").
- Attempts to delete a specific Catalog.
- On success:
    - Displays an info flash message: "Catalog deleted successfully."
    - Redirects back to the parent Creator's show page (/creators/:creator_id).
