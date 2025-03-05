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
   - `Qlarius.Campaigns.MediaPiece` - Creative content for ads
   - `Qlarius.Campaigns.Target` - Targeting information for campaigns
   - `Qlarius.Campaigns.AdCategory` - Categories for advertisements
   - `Qlarius.Offer` - Offers presented to users

4. **User Attributes**
   - `Qlarius.Traits.Trait` - User characteristics/interests

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

- **Offers System** (`Qlarius.Offers`)
  - Connects users with media pieces
  - Tracks compensation phases

### Web Interface

The Phoenix web interface is organized as:

- **Controllers** - Traditional request handlers
- **LiveView** - Real-time UI components without JavaScript
  - `AdsLive` - Manages ad viewing experience
  - `WalletLive` - User's financial dashboard
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

---

*This document should be updated when significant architectural changes are made to the project.*
