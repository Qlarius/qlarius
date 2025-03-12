# Qlarius Project Documentation

This document provides a high-level overview of the Qlarius project structure and core modules. The document is primarily meant to be read and updated by LLMs.

## Project Structure

Qlarius is an Elixir/Phoenix application with the following structure:

- `lib/qlarius/` - Core business logic and data models
- `lib/qlarius_web/` - Web interface (Phoenix controllers, views, templates)
- `priv/repo/` - Database migrations and seed data
- `assets/` - Frontend assets (CSS, JavaScript)
- `config/` - Application configuration
- `test/` - Test files
- `docs/` - Documentation

## Core Modules

### Data Models

The application uses the following primary schemas (see `docs/data_model.mmd` for a visual representation):

1. **User Management**
   - `Qlarius.Accounts.User` - User account information
   - `Qlarius.Accounts.UserToken` - Authentication tokens

2. **Financial System**
   - `Qlarius.LedgerHeader` - Main ledger for a user (wallet)
   - `Qlarius.LedgerEntry` - Individual transactions in a ledger

3. **Advertising System**
   - `Qlarius.Campaigns.Campaign` - Advertising campaigns
   - `Qlarius.Marketing.MediaPiece` - Creative content for ads
   - `Qlarius.Campaigns.Target` - Targeting information for campaigns
   - `Qlarius.Campaigns.AdCategory` - Categories for advertisements
   - `Qlarius.Offer` - Offers presented to users

4. **User Attributes**
   - `Qlarius.Traits.Trait` - User characteristics/interests
   - `Qlarius.Traits.TraitCategory` - Categories for organizing traits
   - `Qlarius.Campaigns.TraitGroup` - Groups of related traits for targeting

### Module Relationships

- **Accounts Module** (`Qlarius.Accounts`)
  - Handles user authentication, registration, and profile management
  - Each user has one ledger header (wallet)
  - Users can have multiple traits (many-to-many)

- **Financial Module**
  - `LedgerHeader` represents a user's wallet
  - `LedgerEntry` records individual transactions in the ledger

- **Campaigns Module** (`Qlarius.Campaigns`)
  - Manages advertising campaigns and their components
  - Campaigns have targets (demographic/interest targeting)
  - Campaigns use media pieces for content
  - Trait groups define sets of traits for targeting

- **Traits System** (`Qlarius.Traits`)
  - Manages user characteristics for targeting
  - Traits are organized into categories
  - Trait groups combine related traits for targeting purposes

- **Offers System** (`Qlarius.Offers`)
  - Connects users with media pieces
  - Tracks compensation phases

### Web Interface

The Phoenix web interface is organized as:

- **Controllers** - Traditional request handlers
- **LiveView** - Real-time UI components without JavaScript
  - `AdsLive` - Manages ad viewing experience
  - `WalletLive` - User's financial dashboard
  - `TraitGroupLive` - Management of trait groups
  - `TraitCategoryLive` - Management of trait categories
  - Various authentication-related LiveView modules

## System Flow

Based on the schema relationships, the system appears to:

1. Allow users to register and maintain profiles with traits
2. Enable advertisers to create campaigns with specific targets
3. Match users with relevant ads based on their traits
4. Compensate users through the ledger system for viewing/interacting with ads

## Development Notes

- Recently added campaigns and targeting functionality
- Traits system for user categorization
- Financial ledger system for tracking compensation

## Next steps

- Target management system has been implemented with the following features:
  - Target CRUD operations with validation
  - Automatic creation of "Bullseye" Target Bands when creating a Target
  - HTTP basic auth protection for marketer access
  - Cascading deletion of Target Bands when a Target is deleted

- Media Pieces management system has been implemented with the following features:
  - Media Piece CRUD operations with validation
  - Integration with Ad Categories
  - HTTP basic auth protection for marketer access

- Trait Groups management system has been implemented with the following features:
  - LiveView interface for viewing trait groups
  - Two-column layout with trait groups on the left and trait categories with parent traits on the right
  - Display of trait groups with their associated traits
  - Hierarchical display of trait categories and parent traits
  - No user authentication required to access trait groups page

- Media Sequences management system has been implemented with the following features:
  - Interface for listing all media sequences 
  - Form for creating new media sequences with associated media runs
  - Dynamic generation of sequence titles based on media piece attributes and run parameters
  - Default values for run configuration parameters
  - Integration with Media Pieces for selecting content
  - HTTP basic auth protection for marketer access
  - Creation of both MediaSequence and MediaRun in a transaction

- Trait Categories management system has been implemented with the following features:
  - LiveView interface for listing, creating, editing, and deleting trait categories
  - Table display with columns for name, display order, and actions
  - Modal forms for editing and creating trait categories
  - Confirmation before deletion
  - HTTP basic auth protection for marketer access
  - Categories displayed in order of their display_order attribute

- Trait Manager system has been implemented with the following features:
  - LiveView interface at `/trait_manager` for managing traits and their values
  - Three-column layout: traits list, values list, and add value form
  - Modal form for creating new traits with name, input type, and category selection
  - Ability to select a trait and view its associated values
  - Form for adding new values to a selected trait with name and display order fields
  - Values displayed in order of their display_order attribute
  - HTTP basic auth protection for marketer access
  - Bug fix: Resolved Phoenix.HTML.FormData protocol error by using Phoenix's modern form handling approach with `to_form/1` and the `CoreComponents.input/1` component
  - Added support for trait questions and answers:
    - Optional question field for traits to define a question associated with the trait
    - Optional answer field for trait values to provide answers to trait questions
    - Dynamic UI that shows answer field in trait value form when trait has a question
    - Updated trait values table to show answers column when trait has a question
  - Enhanced trait value management UI:
    - Reordered table columns: display order (no header), name, survey answer, actions
    - Added edit functionality with pencil icon in actions column
    - Added "+" button above values table to switch to add mode
    - Form now switches between "Add value" and "Edit value" modes
    - Edit mode includes Update and Cancel buttons
    - Survey answer column shows "--" for null/blank values

- Survey Manager system has been implemented with the following features:
  - LiveView interface at `/survey_manager` for managing surveys and their categories
  - Two-column layout with survey categories and surveys on the left, selected survey details on the right
  - Display of survey categories with their associated surveys, ordered by display_order
  - Ability to add new surveys via a modal form with name, category, and display order fields
  - Ability to select a survey and view its details in the right panel
  - Ability to edit existing surveys via a modal form
  - Display of survey traits in panels showing:
    - Trait name and question
    - Trait values with checkboxes/radio buttons based on trait type
    - Ability to remove traits from surveys
  - HTTP basic auth protection for marketer access

- MeFile system has been implemented with the following features:
  - LiveView interface at `/me_file` for users to view their trait data
  - Protected route that requires user authentication
  - Display of total trait and tag counts at the top of the page
  - Categories listed in ascending display_order
  - Each category shows number of traits that have values
  - Categories separated by horizontal lines
  - Traits displayed as one-column tables with trait name as header
  - Trait values listed in ascending display_order under each trait
  - Only traits with at least one value are shown
  - Responsive grid layout that adapts to different screen sizes

---

*This document should be updated when significant architectural changes are made to the project.*
