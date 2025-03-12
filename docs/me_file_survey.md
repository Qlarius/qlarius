## Product Requirements Document: MeFile Survey Builder

LiveView page rendered at `/me_file/surveys/:survey_id`.

**Functionality**

- [ ] Page is only accessible to logged-in users.
- [ ] Page shows survey questions (traits) one at a time, in order of trait display_order.
- [ ] Fixed header at top of page showing:
  - [ ] Survey title
  - [ ] Badge showing number of completed questions
  - [ ] Progress dots showing current position in survey
  - [ ] Should remain visible when scrolling
- [ ] Question panel shows:
  - [ ] Trait question as panel heading
  - [ ] Radio buttons for traits with input_type "radio" or "select"
  - [ ] Checkboxes for traits with input_type "checkbox"
  - [ ] Each option shows answer text if present, otherwise shows value name
  - [ ] Only one value can be selected for radio/select traits
  - [ ] Multiple values can be selected for checkbox traits
- [ ] Form submission:
  - [ ] Creates UserTag records linking user to selected trait values
  - [ ] Saves answers immediately when moving to next question
  - [ ] Does not wait for entire survey completion to save
  - [ ] After saving, advances to next trait in survey
  - [ ] After final question, redirects to `/me_file/surveys`
- [ ] Fixed footer at bottom of page showing:
  - [ ] "Done" button
  - [ ] Colored green
  - [ ] When clicked, returns to `/me_file/surveys` without saving current question
  - [ ] Should remain visible when scrolling
- [ ] Component reuse:
  - [ ] Extract shared trait panel component from SurveyManagerLive
  - [ ] Use shared component in both SurveyManagerLive and MeFileSurveyLive
  - [ ] Enable inputs in MeFileSurveyLive but disable in SurveyManagerLive

**Technical Requirements**

- [ ] Create MeFileSurveyLive module
- [ ] Add route to authenticated scope in router
- [ ] Create UserTag schema and migration if not exists
- [ ] Add functions to MeFile context for:
  - [ ] Getting survey with ordered traits
  - [ ] Creating UserTags
  - [ ] Counting completed questions
- [ ] Extract shared trait panel component
- [ ] Add proper error handling for invalid survey IDs
- [ ] Add proper error handling for failed UserTag creation
