This document describes the UI for creating and reading trait groups.

## Data model review:

- TraitGroup (`lib/qlarius/traits/trait_group.ex`): Represents a collection of related Traits. Has a title, description, and (importantly) a parent_id.
- Trait (`lib/qlarius/traits/trait.ex`): The individual data points. A Trait can be a "parent trait" (like "Age") or a "child trait" (like "18-24"). parent_id is the key here.
- Traits and TraitGroups have an N-to-N relationship through the join table `traits_trait_groups`.
- TraitCategory: This is used for organization. All traits must belong to a category.

## UI Breakdown and Use Cases

- [x] It is *not* necessary to be logged in as a `User` to access target routes.
- [x] Trait group pages are accessed via the 'browser' and 'marketer' pipelines (add them to the existing block in the router.

### Index page (/trait_groups)

This page is a LiveView.

#### Overall Layout

The page is divided into two main columns:

Left Column: A list of existing Trait Groups. This is where the we see and manage Trait Groups.

Right Column: A hierarchical list of all available TraitCategory and Trait records (specifically, parent traits). This acts as a kind of "palette" or "library" from which the user selects traits to include in their Trait Groups.

#### Left Column: Existing Trait Groups

Table: A table is used to display the existing Trait Groups. The columns are:

- [x] Trait Group Name: The title of the TraitGroup.
- [x] Traits: A comma-separated list of the `name` values of the Traits associated with this TraitGroup, specifically showing the child trait names. The code iterates through trait_group.traits.
- [x] Desc: The TraitGroup's `description`

#### Right Column: Trait Category and Parent Trait List

Hierarchical Structure: The categories and parent traits are displayed in a nested structure.

- [x] The top level is TraitCategory records (e.g., "General Information").
- [x] Under each TraitCategory, the associated parent Trait records are listed (e.g., "Gender", "Age"). I.e. these are Traits
- [x] The trait is displayed with a "+" icon. Make this a no-op for now.
