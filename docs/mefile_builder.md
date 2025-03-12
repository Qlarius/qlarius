## Product Requirements Document: MeFile Surveys Overview

Static page (not a LiveView) rendered at `/me_file/surveys`.

**Functionality**

- [x] Page is only accessible to logged-in users.
- [x] Page has title "MeFile Builder" with subheading "Tag yourself to build up your MeFile."
- [x] A badge below the subheading displays "X traits" where X is the number of traits for which the user has at least one value
- [x] A badge below the subheading displays "Y tags" where Y is the total number of user_tags
- [x] The page lists all surveys grouped by category.
- [x] Each survey category is displayed as a panel. The panel heading is the category name.
- [x] Category panels are arranged in a responsive grid. On narrow screens there's one panel per row; wider screens allow more panels per row.
- [x] Below the category title is a progress bar.
- [x] The progress bar's percentage filled shows the total number of survey questions the current user has answered, as a percentage of the total number of questions that exist within this category. (See below for definition of "questions" and "answered".)
- [x] The progress bar also shows the number complete and total number e.g. "5/17"
- [x] If the progress bar is full then it's colored green.
- [x] If the progress bar is partially full then it's colored orange.
- [x] If the progress bar is empty then it's colored red.
- [x] Below the progress bar, the panel lists the category's surveys in rows.
- [x] Each row shows the survey's name
- [x] Each row shows a badge that shows how many questions the from this survey the current user has completed e.g. "4/5". 
- [x] If the current user has completed all questions in this survey, the badge is green.
- [x] If the current user has completed some but not all questions in this survey, the badge is orange.
- [x] If the current user has completed no questions in this survey, the badge is red.
- [x] Each row has a right chevron on its right (that's currently non-functional.)

Definition of "complete":

A survey contains a list of traits. Each trait within the survey can be thought of as a "question". A user has answered a question within the survey if the user has at least one "TraitValue" (via the `UserTag` join table) for the trait/question.
