- [x] All target routes are protected with HTTP basic auth with username 'marketer', password 'password'
- [x] It is *not* necessary to be logged in as a `User` to access target routes.

## Media Pieces

### List Media Pieces:

- [x] User can view a list of all Media Pieces.
- [x] Each Media Piece shows:
    - Title
    - Ad Category
    - Options to Edit and Delete each Media Piece.

### Create Media Piece:

- [x] User can create a new Media Piece.
- [x] Required Fields:
-     Title (text)
-     Body Copy (textarea)
-     Display URL (text)
-     Jump URL (text)
-     Ad Category (select from existing categories)
- [x] Successful creation redirects to the Media Piece list.
- [x] Validation errors are displayed if creation fails.

### Edit Media Piece:

- [x] User can edit an existing Media Piece.
- [x] All fields from creation are editable.
- [x] Successful update redirects to the Media Piece list.
- [x] Validation errors are displayed if update fails.

### Delete Media Piece:

- [x] User can delete a Media Piece.
- [x] Confirmation is required before deletion.
- [x] Successful deletion redirects to the Media Piece list.
