- [x] All target routes are protected with HTTP basic auth with username 'marketer', password 'password'
- [x] It is *not* necessary to be logged in as a `User` to access target routes.

Target list:

- [x] A user can see a list of all existing Targets.
- [x] Each Target in the list displays its title.
- [x] Each Target in the list has options to "Edit" and "Delete."

Create a New Target:

- [x] A user can create a new Target.
- [x] A new Target requires a title.
- [x] A new Target can optionally have a description.
- [x] Upon successful creation, the user is informed and redirected to the Target list.
- [x] Upon unsuccessful creation, the user is shown appropriate error messages, and the form is re-displayed with their input.
- [x] When creating a Target it also creates a default "Bullseye" Target Band (@target_band.ex)

Edit an Existing Target:

- [x] A user can edit an existing Target's title and description.
- [x] Upon successful update, the user is informed and redirected to the Target list.
- [x] Upon unsuccessful update, the user sees error messages, and the form is re-displayed.

Delete a Target:

- [x] A user can delete an existing Target.
- [x] A confirmation prompt is displayed before deletion.
- [x] Upon successful deletion, the user is informed and redirected to the Target list.
- [x] Deleting a Target also deletes all associated Target Bands
