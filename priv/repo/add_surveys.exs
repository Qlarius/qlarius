defmodule Seeds do
  alias Qlarius.{
    Repo,
    Surveys.SurveyCategory,
    Surveys.Survey,
    # Surveys.SurveyQuestion,
    # Surveys.SurveyAnswer
  }

  def run do
    # Repo.delete_all(SurveyAnswer)
    # Repo.delete_all(SurveyQuestion)
    Repo.delete_all(Survey)
    Repo.delete_all(SurveyCategory)

    for table <- ~w[survey_categories surveys survey_questions survey_answers] do
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT setval('#{table}_id_seq', (SELECT MAX(id) FROM trait_values) + 1);"
      )
    end

    insert_survey_categories()
    insert_surveys()
    # insert_survey_questions()
    # insert_survey_question_surveys()
    # insert_survey_answers()
  end

  defp insert_survey_categories do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{id: 12, display_order: 5, inserted_at: now, updated_at: now, name: "Attire & Fashion"},
      %{id: 13, display_order: 3, inserted_at: now, updated_at: now, name: "Career/Occupational"},
      %{
        id: 6,
        display_order: 6,
        inserted_at: now,
        updated_at: now,
        name: "Causes and Challenges"
      },
      %{id: 9, display_order: 3, inserted_at: now, updated_at: now, name: "Education"},
      %{id: 3, display_order: 2, inserted_at: now, updated_at: now, name: "Family Life"},
      %{id: 1, display_order: 2, inserted_at: now, updated_at: now, name: "Food and Drink"},
      %{
        id: 7,
        display_order: 5,
        inserted_at: now,
        updated_at: now,
        name: "Health, Beauty, and Body"
      },
      %{
        id: 8,
        display_order: 6,
        inserted_at: now,
        updated_at: now,
        name: "Hobbies and Interests"
      },
      %{id: 14, display_order: 3, inserted_at: now, updated_at: now, name: "Income & Financial"},
      %{
        id: 15,
        display_order: 3,
        inserted_at: now,
        updated_at: now,
        name: "Marital & Relationship"
      },
      %{
        id: 10,
        display_order: 5,
        inserted_at: now,
        updated_at: now,
        name: "Music & Entertainment"
      },
      %{
        id: 11,
        display_order: 4,
        inserted_at: now,
        updated_at: now,
        name: "Opinions and Beliefs"
      },
      %{id: 5, display_order: 5, inserted_at: now, updated_at: now, name: "Pets"},
      %{id: 16, display_order: 4, inserted_at: now, updated_at: now, name: "Politics"},
      %{
        id: 4,
        display_order: 4,
        inserted_at: now,
        updated_at: now,
        name: "Sports, Exercise & Activities"
      },
      %{id: 2, display_order: 1, inserted_at: now, updated_at: now, name: "The Basics"},
      %{id: 17, display_order: 4, inserted_at: now, updated_at: now, name: "Transportation"},
      %{id: 18, display_order: 7, inserted_at: now, updated_at: now, name: "Travel & Vacation"},
      %{id: 19, display_order: 2, inserted_at: now, updated_at: now, name: "Your Home"}
    ]
    |> Enum.each(fn attrs ->
      struct(SurveyCategory, attrs)
      |> Repo.insert!()
    end)
  end

  defp insert_surveys do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{
        id: 1,
        category_id: 1,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Eating Out"
      },
      %{
        id: 2,
        category_id: 2,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "QUICK START",
        display_order: 1
      },
      %{
        id: 3,
        category_id: 3,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Sons & Daughters"
      },
      %{
        id: 4,
        category_id: 4,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Personal Exercise & Activity"
      },
      %{
        id: 5,
        category_id: 5,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Pets & Critters"
      },
      %{
        id: 6,
        category_id: 3,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Child Education"
      },
      %{
        id: 7,
        category_id: 6,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Causes, Struggles, and Challenges"
      },
      %{
        id: 8,
        category_id: 7,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Allergies"
      },
      %{
        id: 9,
        category_id: 8,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Arts and Crafts"
      },
      %{
        id: 10,
        category_id: 9,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "College Life"
      },
      %{
        id: 11,
        category_id: 19,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Your Home"
      },
      %{
        id: 12,
        category_id: 7,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "The Skin You're In"
      },
      %{
        id: 13,
        category_id: 10,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Music - Your Soundtrack"
      },
      %{
        id: 14,
        category_id: 8,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Pastimes"
      },
      %{id: 15, category_id: 7, active: true, inserted_at: now, updated_at: now, name: "Vision"},
      %{
        id: 16,
        category_id: 7,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Your Body"
      },
      %{id: 17, category_id: 1, active: true, inserted_at: now, updated_at: now, name: "Vino"},
      %{
        id: 18,
        category_id: 11,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "How \"Green\" Are You?"
      },
      %{
        id: 19,
        category_id: 8,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Reading Habits"
      },
      %{
        id: 20,
        category_id: 10,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Cultural Events"
      },
      %{
        id: 21,
        category_id: 12,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Clothing Sizes - LADIES"
      },
      %{
        id: 22,
        category_id: 12,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Clothing Sizes - MEN"
      },
      %{
        id: 23,
        category_id: 10,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Video Gaming"
      },
      %{
        id: 24,
        category_id: 11,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Religion"
      },
      %{
        id: 25,
        category_id: 13,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Your Workplace"
      },
      %{
        id: 26,
        category_id: 13,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Occupation & Industry"
      },
      %{
        id: 27,
        category_id: 1,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Diet & Meal Preferences"
      },
      %{
        id: 28,
        category_id: 6,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Volunteering & Donating"
      },
      %{
        id: 29,
        category_id: 14,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Credit & Debt"
      },
      %{
        id: 30,
        category_id: 15,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Love and Marriage"
      },
      %{
        id: 31,
        category_id: 16,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Politics - General"
      },
      %{
        id: 32,
        category_id: 2,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Language"
      },
      %{
        id: 33,
        category_id: 17,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Automobiles & More"
      },
      %{id: 34, category_id: 1, active: true, inserted_at: now, updated_at: now, name: "Coffee"},
      %{
        id: 35,
        category_id: 18,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Ideal Vacation/Getaway"
      },
      %{
        id: 36,
        category_id: 12,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Fashion - Your Clothing Style"
      },
      %{id: 37, category_id: 1, active: true, inserted_at: now, updated_at: now, name: "Beer"},
      %{
        id: 38,
        category_id: 1,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Liquor & Mixed Drinks"
      },
      %{
        id: 39,
        category_id: 9,
        active: true,
        inserted_at: now,
        updated_at: now,
        name: "Education - General"
      },
      %{id: 40, category_id: 14, active: true, inserted_at: now, updated_at: now, name: "Income"}
    ]
    |> Enum.each(fn attrs ->
      struct(Survey, attrs)
      |> Repo.insert!()
    end)
  end

  # defp insert_survey_questions do
  #   now = DateTime.utc_now() |> DateTime.truncate(:second)

  #   [
  #     %{
  #       id: 1,
  #       trait_id: 94,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "About how many times a week do you go out to eat?"
  #     },
  #     %{
  #       id: 5,
  #       trait_id: 4,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "What is your 5-digit home zip code? \n (the place where you  sleep 4 nights of the week)"
  #     },
  #     %{
  #       id: 7,
  #       trait_id: 54,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Marital Status"
  #     },
  #     %{
  #       id: 8,
  #       trait_id: 40,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Employment Status"
  #     },
  #     %{
  #       id: 9,
  #       trait_id: 37,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Student Status \n Are you currently a student?"
  #     },
  #     %{
  #       id: 10,
  #       trait_id: 45,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Educational Level"
  #     },
  #     %{
  #       id: 11,
  #       trait_id: 14,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Race/Ethnicity \nSelect all with which you identify."
  #     },
  #     %{
  #       id: 12,
  #       trait_id: 222,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your Annual Household Income?"
  #     },
  #     %{
  #       id: 13,
  #       trait_id: 6,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your Annual Personal Income?"
  #     },
  #     %{
  #       id: 14,
  #       trait_id: 253,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "In what personal sports and exercise activities do you participate?"
  #     },
  #     %{
  #       id: 15,
  #       trait_id: 161,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What type of pet(s) do you own and care for?"
  #     },
  #     %{
  #       id: 16,
  #       trait_id: 284,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "If you have any children - biological, adopted, or step - or are the legal guardian of any child, please indicate the gender and age range(s) below.  Make multiple selections to indicate multiple children."
  #     },
  #     %{
  #       id: 18,
  #       trait_id: 318,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Check all that apply below to indicate what educational systems your children are currently enrolled."
  #     },
  #     %{
  #       id: 19,
  #       trait_id: 326,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the below conditions and challenges apply to you personally? \n\n NOTE: You are not required to answer. If you choose to answer, only answer to your own comfort level.  This data will never be shared and is for your eyes only."
  #     },
  #     %{
  #       id: 20,
  #       trait_id: 367,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Excluding yourself, which of the below conditions and challenges apply to a loved-one or close friend? \n\n NOTE: You are not required to answer. If you choose to answer, only answer to your own comfort level. This data will never be shared and is for your eyes only."
  #     },
  #     %{
  #       id: 21,
  #       trait_id: 408,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Do you or any of your loved-ones suffer from any of the allergies listed below?\n Select all that apply."
  #     },
  #     %{
  #       id: 22,
  #       trait_id: 431,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Select the arts and crafts activities below that interest you."
  #     },
  #     %{
  #       id: 23,
  #       trait_id: 449,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which college or university did you attend / are you currently attending?"
  #     },
  #     %{
  #       id: 24,
  #       trait_id: 164,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "For your current primary residence, please indicate whether you own or rent."
  #     },
  #     %{
  #       id: 25,
  #       trait_id: 869,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Select any of the below properties below that describe your current home/residence."
  #     },
  #     %{
  #       id: 26,
  #       trait_id: 885,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Indicate the type of your current home/residence."
  #     },
  #     %{
  #       id: 27,
  #       trait_id: 896,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which category best describes your skin tone?"
  #     },
  #     %{
  #       id: 28,
  #       trait_id: 921,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which category best describes your facial skin type?"
  #     },
  #     %{
  #       id: 29,
  #       trait_id: 905,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What skin conditions do you or a loved-one have? \n\nCheck all that apply."
  #     },
  #     %{
  #       id: 30,
  #       trait_id: 60,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How many children do you have total?  Include biological, adoptive, and step."
  #     },
  #     %{
  #       id: 31,
  #       trait_id: 932,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What types or genres of music do you ENJOY? \nClick all that apply."
  #     },
  #     %{
  #       id: 32,
  #       trait_id: 957,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What types or genres of music do you NOT ENJOY or DISLIKE? \nClick all that apply."
  #     },
  #     %{
  #       id: 33,
  #       trait_id: 984,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "If you had to choose one decade that produced the best music, which would it be?"
  #     },
  #     %{
  #       id: 34,
  #       trait_id: 993,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Do you own a music/MP3 player, and if so, what brand?\n(If you own multiple players, choose the brand you favor.)"
  #     },
  #     %{
  #       id: 35,
  #       trait_id: 1016,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Select any pastimes you enjoy below."
  #     },
  #     %{
  #       id: 36,
  #       trait_id: 1037,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Do you currently use any type of corrective lenses? \nIndicate any type of corrective lenses that you currently use."
  #     },
  #     %{
  #       id: 37,
  #       trait_id: 1044,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which answer best describes the current state of your UNAIDED visual acuity.\nOr, how sharply do you see, when NOT wearing corrective lenses?"
  #     },
  #     %{
  #       id: 38,
  #       trait_id: 1049,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "If you wear prescription glasses or contacts, which answer best describes the current state of your AIDED visual acuity?\nOr, how sharply do you see when wearing corrective lenses?"
  #     },
  #     %{
  #       id: 39,
  #       trait_id: 1055,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How long has it been since your last eye exam?"
  #     },
  #     %{
  #       id: 40,
  #       trait_id: 1060,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Have you ever had corrective eye surgery?"
  #     },
  #     %{
  #       id: 41,
  #       trait_id: 1064,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Select any of the following eye or vision conditions that currently challenge you."
  #     },
  #     %{
  #       id: 42,
  #       trait_id: 1075,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your height (rounded to the nearest inch)?"
  #     },
  #     %{
  #       id: 43,
  #       trait_id: 1096,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your current approximate weight? (We promise not to tell.)"
  #     },
  #     %{
  #       id: 44,
  #       trait_id: 1124,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the following categories would you say best describes your current body weight?"
  #     },
  #     %{
  #       id: 45,
  #       trait_id: 1132,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which current goals or wishes do you have regarding your physical condition?"
  #     },
  #     %{
  #       id: 46,
  #       trait_id: 1145,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you drink wine?"
  #     },
  #     %{
  #       id: 47,
  #       trait_id: 1155,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How many bottles of wine to you currently own?"
  #     },
  #     %{
  #       id: 48,
  #       trait_id: 1162,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What types of wine do you prefer?"
  #     },
  #     %{
  #       id: 49,
  #       trait_id: 1182,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "On a scale of 1 to 10, how \"green\" are you?"
  #     },
  #     %{
  #       id: 50,
  #       trait_id: 1193,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Considering your answer to the scale above, how \"green\" do you wish to be, or think you should be?"
  #     },
  #     %{
  #       id: 51,
  #       trait_id: 1199,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "How often do you currently consciously decide to buy a product or service because it is \"green\" or eco-friendly?"
  #     },
  #     %{
  #       id: 52,
  #       trait_id: 1206,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following materials do you routinely recycle?"
  #     },
  #     %{
  #       id: 53,
  #       trait_id: 1215,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How many books have you read in their entirety in the last year?"
  #     },
  #     %{
  #       id: 54,
  #       trait_id: 1222,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What category(ies) of reading material (books, magazines, online) do you enjoy?"
  #     },
  #     %{
  #       id: 55,
  #       trait_id: 1263,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following types of live cultural events do/would you enjoy attending?"
  #     },
  #     %{
  #       id: 56,
  #       trait_id: 1275,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Considering your answers to the above question, how many times per year do you attend a live cultural event?"
  #     },
  #     %{
  #       id: 57,
  #       trait_id: 1283,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your dress size (US)?"
  #     },
  #     %{
  #       id: 58,
  #       trait_id: 1311,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your bust size (inches)?"
  #     },
  #     %{
  #       id: 59,
  #       trait_id: 1319,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your cup size?"
  #     },
  #     %{
  #       id: 60,
  #       trait_id: 1326,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your waist size (inches)?"
  #     },
  #     %{
  #       id: 61,
  #       trait_id: 1342,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your hip size (inches)?"
  #     },
  #     %{
  #       id: 62,
  #       trait_id: 1356,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your shoe size (US)?"
  #     },
  #     %{
  #       id: 63,
  #       trait_id: 1366,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Shoe Width"
  #     },
  #     %{
  #       id: 64,
  #       trait_id: 1371,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What size t-shirt do you usually wear?"
  #     },
  #     %{
  #       id: 65,
  #       trait_id: 1378,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "For dress shirts, what is your approximate neck size (inches)?"
  #     },
  #     %{
  #       id: 66,
  #       trait_id: 1389,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "For dress shirts, what is your approximate sleeve length (inches)?"
  #     },
  #     %{
  #       id: 67,
  #       trait_id: 1399,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your approximate jacket (or chest) size?"
  #     },
  #     %{
  #       id: 68,
  #       trait_id: 1413,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your approximate waist size (inches)?"
  #     },
  #     %{
  #       id: 69,
  #       trait_id: 1425,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your approximate pants length, or inseam (inches)?"
  #     },
  #     %{
  #       id: 70,
  #       trait_id: 1436,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your shoe size (US)?"
  #     },
  #     %{
  #       id: 71,
  #       trait_id: 1366,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Do you wear narrow, standard, or wide sized shoes?"
  #     },
  #     %{
  #       id: 72,
  #       trait_id: 1456,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of these video game console platforms are used regularly by someone in your household?"
  #     },
  #     %{
  #       id: 73,
  #       trait_id: 1469,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of these portable gaming platforms are used regularly by someone in your household?"
  #     },
  #     %{
  #       id: 74,
  #       trait_id: 1489,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How many hours per week do you personally play video games of some sort?"
  #     },
  #     %{
  #       id: 75,
  #       trait_id: 1496,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following video game genres do you most enjoy?"
  #     },
  #     %{
  #       id: 76,
  #       trait_id: 1520,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "With which of the following religious groups do you most identify?"
  #     },
  #     %{
  #       id: 77,
  #       trait_id: 40,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is your current employment status?"
  #     },
  #     %{
  #       id: 78,
  #       trait_id: 1569,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Are you currently \"in the market\" for any type of job or additional income opportunities?"
  #     },
  #     %{
  #       id: 79,
  #       trait_id: 5,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Provide the 5-digit zip code of the main location where you work."
  #     },
  #     %{
  #       id: 80,
  #       trait_id: 1575,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is the size of your company/business in number of employees?"
  #     },
  #     %{
  #       id: 81,
  #       trait_id: 1588,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "At about what hour do you normally begin work, or arrive at your workplace?"
  #     },
  #     %{
  #       id: 82,
  #       trait_id: 1615,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "At about what hour do you normally end work, or leave your workplace?"
  #     },
  #     %{
  #       id: 83,
  #       trait_id: 1642,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Provide your 6-digit Standard Occupational Classification (SOC) code below.\n\nThe US Department of Labor's Bureau of Labor Statistics has created unique codes for 820 occupational categories.  Use one of the following resources to identify your SOC, and enter it below.\n\n<a href=\"http://www.onetcodeconnector.org/\" target=\"_blank\">O*NET Code Connector (Helpful Keyword Search)</a><a href=\"http://www.bls.gov/soc/soc_majo.htm\" target=\"_blank\">\nU.S. DOL - Standard Occupational Classifications (Full List)</a>\n\n<b>Use the format ##-####, including the dash.</b> (Only the first six numbers are needed.)"
  #     },
  #     %{
  #       id: 84,
  #       trait_id: 1643,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Provide your 6-digit Industry Classification (NAICS) code below.\n\nThe North American Industry Classification System contains unique codes for 1175 industry categories. Use one of the links below to search and identify your NAICS code, and enter it in the field below.\n\n<a href=\"http://www.census.gov/epcd/naics07/\" target=\"_blank\">U.S. Census Bureau</a>\n<a href=\"http://www.naics.com/search.htm\" target=\"_blank\">NAICS Association</a>\n\n<b>Use the format ######.</b>"
  #     },
  #     %{
  #       id: 85,
  #       trait_id: 1645,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often per week do you eat fast food?"
  #     },
  #     %{
  #       id: 86,
  #       trait_id: 1653,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Select from the following to indicate your favorite fast foods."
  #     },
  #     %{
  #       id: 87,
  #       trait_id: 1664,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Select from the following to describe your currently typical daily meal."
  #     },
  #     %{
  #       id: 88,
  #       trait_id: 1675,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following do you LIKE?"
  #     },
  #     %{
  #       id: 89,
  #       trait_id: 1691,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following do you DISLIKE?"
  #     },
  #     %{
  #       id: 90,
  #       trait_id: 1707,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following ethnic cuisine types do you LIKE?"
  #     },
  #     %{
  #       id: 91,
  #       trait_id: 1733,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following ethnic cuisine types do you DISLIKE?"
  #     },
  #     %{
  #       id: 92,
  #       trait_id: 1759,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Do you enjoy spicy/hot foods?"
  #     },
  #     %{
  #       id: 93,
  #       trait_id: 1764,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Do you enjoy desserts and sweets?"
  #     },
  #     %{
  #       id: 94,
  #       trait_id: 1781,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "On average, how much TIME per MONTH do you spend volunteering?"
  #     },
  #     %{
  #       id: 95,
  #       trait_id: 1788,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "With what type of organizations do you currently volunteer your time OR donate money? \n(Check all that apply.)"
  #     },
  #     %{
  #       id: 96,
  #       trait_id: 1805,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "On average, how much MONEY per MONTH do you donate to causes, organizations, and charities?"
  #     },
  #     %{
  #       id: 97,
  #       trait_id: 1814,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How is your credit?"
  #     },
  #     %{
  #       id: 98,
  #       trait_id: 1821,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following best describes your sexual orientation?"
  #     },
  #     %{
  #       id: 100,
  #       trait_id: 1827,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the choices below best describes your current political party affiliation or preference?"
  #     },
  #     %{
  #       id: 101,
  #       trait_id: 1835,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Considering today's social issues (eg. gay rights, death penalty, abortion rights, immigration, religion, gun control, drugs, etc.), which position on the political spectrum best describes you?"
  #     },
  #     %{
  #       id: 102,
  #       trait_id: 1842,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Considering today's financial and government spending issues (eg. taxation, government spending, military spending, social security, free trade, health care, etc.), which position on the political spectrum best describes you?"
  #     },
  #     %{
  #       id: 103,
  #       trait_id: 1849,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "What is your primary language?  (What language do you speak at home, dream in, swear in, etc.?)"
  #     },
  #     %{
  #       id: 104,
  #       trait_id: 1876,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "What languages are you FLUENT in?  Select any that apply, including your primary language."
  #     },
  #     %{
  #       id: 105,
  #       trait_id: 1903,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What language(s) are you interested in learning better?"
  #     },
  #     %{
  #       id: 106,
  #       trait_id: 2398,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How many vehicles/automobiles are in regular use by your household?"
  #     },
  #     %{
  #       id: 107,
  #       trait_id: 2405,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "What is the YEAR of your current PRIMARY vehicle/automobile (the one you or your family drives most often)?\n(YYYY)"
  #     },
  #     %{
  #       id: 108,
  #       trait_id: 2406,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What is the MAKE of your current PRIMARY vehicle/automobile?\n(Select one.)"
  #     },
  #     %{
  #       id: 109,
  #       trait_id: 2452,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the following best describes the TYPE of your current PRIMARY vehicle/automobile?\n(Select one.)"
  #     },
  #     %{
  #       id: 110,
  #       trait_id: 2462,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the following best describes the current ownership or financing situation of your current PRIMARY vehicle/automobile?\n(Select one.)"
  #     },
  #     %{
  #       id: 111,
  #       trait_id: 2470,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the following features applies to your current PRIMARY vehicle/automobile?\n(Select all that apply.)"
  #     },
  #     %{
  #       id: 112,
  #       trait_id: 2481,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "When considering your NEXT vehicle/automobile, which features will be most important to you?\n(Select all that apply.)"
  #     },
  #     %{
  #       id: 113,
  #       trait_id: 2504,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "For your next vehicle/automobile, you will likely…\n(Select one.)"
  #     },
  #     %{
  #       id: 114,
  #       trait_id: 2511,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Do you have a purchasing preference between new or used automobiles?\n(Select one.)"
  #     },
  #     %{
  #       id: 115,
  #       trait_id: 2517,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "On average, how many cups of coffee do you consume daily?"
  #     },
  #     %{
  #       id: 116,
  #       trait_id: 2524,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following answers BEST describes your feelings toward coffee?"
  #     },
  #     %{
  #       id: 117,
  #       trait_id: 2534,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following characteristics might your typical cup of coffee have?"
  #     },
  #     %{
  #       id: 118,
  #       trait_id: 2580,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you make your own coffee/coffee drink at home?"
  #     },
  #     %{
  #       id: 119,
  #       trait_id: 2554,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Starting with a fresh cup of hot black coffee (regular or decaf), which of the following are you likely to add? (Select all that apply.)"
  #     },
  #     %{
  #       id: 120,
  #       trait_id: 2569,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following coffee-based drinks do you enjoy? (Select all that apply.)"
  #     },
  #     %{
  #       id: 121,
  #       trait_id: 2586,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you drink coffee/a coffee drink at your office?"
  #     },
  #     %{
  #       id: 122,
  #       trait_id: 2592,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you drink coffee/a coffee drink at a restaurant?"
  #     },
  #     %{
  #       id: 123,
  #       trait_id: 2598,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you drink coffee/a coffee drink at a coffee house or shop?"
  #     },
  #     %{
  #       id: 125,
  #       trait_id: 2699,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the following companions would accompany you on your IDEAL vacation or getaway?  \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 126,
  #       trait_id: 2707,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Desribe the environment of your IDEAL vacation or getaway.  \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 127,
  #       trait_id: 2717,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Desribe the accomodations of your IDEAL vacation or getaway.  \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 128,
  #       trait_id: 2732,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Describe the essential ingredients of your IDEAL vacation or getaway.  \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 129,
  #       trait_id: 2757,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Describe the activities involved in your IDEAL vacation or getaway.  \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 130,
  #       trait_id: 2787,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "What type of destinations might be considered in your IDEAL vacation or getaway?  \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 131,
  #       trait_id: 2803,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Select any of the following that describe your preferred CLOTHING styles or fashions. \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 132,
  #       trait_id: 2839,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Select any of the following that describe your preferred HOME DECORATING styles or fashions. \n(Select all that apply, then click \"Add/Update\" at the bottom.)"
  #     },
  #     %{
  #       id: 133,
  #       trait_id: 2880,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Which of the following payment/credit cards do you use regularly?\n(Select all that apply.)"
  #     },
  #     %{
  #       id: 134,
  #       trait_id: 2892,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What other types of vehicles do you currently own/rent?"
  #     },
  #     %{
  #       id: 135,
  #       trait_id: 2908,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you drink beer?"
  #     },
  #     %{
  #       id: 136,
  #       trait_id: 2918,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "What types of beer do you most enjoy?"
  #     },
  #     %{
  #       id: 137,
  #       trait_id: 2944,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "How often do you drink liquor or mixed drinks?"
  #     },
  #     %{
  #       id: 138,
  #       trait_id: 2955,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "What types of liquor do you enjoy, either \"straight\" or in mixed drinks? (Select all that apply.)"
  #     },
  #     %{
  #       id: 139,
  #       trait_id: 2970,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Considering the various types of liquors or mixed drinks you might consume, how do you enjoy them served? (Select all that apply.)"
  #     },
  #     %{
  #       id: 140,
  #       trait_id: 2985,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text:
  #         "Considering the various types of liquors you might consume, which of the following do you enjoy mixed into your drinks? (Select all that apply.)"
  #     },
  #     %{
  #       id: 142,
  #       trait_id: 1707,
  #       inserted_at: now,
  #       updated_at: now,
  #       active: true,
  #       text: "Which of the following ethnic cuisine types do you LIKE?"
  #     }
  #   ]
  #   |> Enum.each(fn attrs ->
  #     struct(SurveyQuestion, attrs)
  #     |> Repo.insert!()
  #   end)
  # end

  # defp insert_survey_question_surveys do
  #   now = DateTime.utc_now() |> DateTime.truncate(:second)

  #   joins =
  #     [
  #       %{id: 1, question_id: 1, survey_id: 1},
  #       %{id: 2, question_id: 5, survey_id: 11},
  #       %{id: 3, question_id: 7, survey_id: 2},
  #       %{id: 4, question_id: 8, survey_id: 25},
  #       %{id: 5, question_id: 9, survey_id: 39},
  #       %{id: 6, question_id: 10, survey_id: 39},
  #       %{id: 7, question_id: 11, survey_id: 2},
  #       %{id: 8, question_id: 12, survey_id: 40},
  #       %{id: 9, question_id: 13, survey_id: 40},
  #       %{id: 10, question_id: 14, survey_id: 2},
  #       %{id: 11, question_id: 15, survey_id: 2},
  #       %{id: 12, question_id: 16, survey_id: 3},
  #       %{id: 13, question_id: 18, survey_id: 6},
  #       %{id: 14, question_id: 19, survey_id: 7},
  #       %{id: 15, question_id: 20, survey_id: 7},
  #       %{id: 16, question_id: 21, survey_id: 8},
  #       %{id: 17, question_id: 22, survey_id: 9},
  #       %{id: 18, question_id: 23, survey_id: 10},
  #       %{id: 19, question_id: 24, survey_id: 11},
  #       %{id: 20, question_id: 25, survey_id: 11},
  #       %{id: 21, question_id: 26, survey_id: 11},
  #       %{id: 22, question_id: 27, survey_id: 12},
  #       %{id: 23, question_id: 28, survey_id: 12},
  #       %{id: 24, question_id: 29, survey_id: 12},
  #       %{id: 25, question_id: 30, survey_id: 2},
  #       %{id: 26, question_id: 31, survey_id: 13},
  #       %{id: 27, question_id: 32, survey_id: 13},
  #       %{id: 28, question_id: 33, survey_id: 13},
  #       %{id: 29, question_id: 34, survey_id: 13},
  #       %{id: 30, question_id: 35, survey_id: 2},
  #       %{id: 31, question_id: 36, survey_id: 15},
  #       %{id: 32, question_id: 37, survey_id: 15},
  #       %{id: 33, question_id: 38, survey_id: 15},
  #       %{id: 34, question_id: 39, survey_id: 15},
  #       %{id: 35, question_id: 40, survey_id: 15},
  #       %{id: 36, question_id: 41, survey_id: 15},
  #       %{id: 37, question_id: 42, survey_id: 16},
  #       %{id: 38, question_id: 43, survey_id: 16},
  #       %{id: 39, question_id: 44, survey_id: 16},
  #       %{id: 40, question_id: 45, survey_id: 2},
  #       %{id: 41, question_id: 46, survey_id: 17},
  #       %{id: 42, question_id: 47, survey_id: 17},
  #       %{id: 43, question_id: 48, survey_id: 17},
  #       %{id: 44, question_id: 49, survey_id: 18},
  #       %{id: 45, question_id: 50, survey_id: 18},
  #       %{id: 46, question_id: 51, survey_id: 18},
  #       %{id: 47, question_id: 52, survey_id: 18},
  #       %{id: 48, question_id: 53, survey_id: 19},
  #       %{id: 49, question_id: 54, survey_id: 19},
  #       %{id: 50, question_id: 55, survey_id: 20},
  #       %{id: 51, question_id: 56, survey_id: 20},
  #       %{id: 52, question_id: 57, survey_id: 21},
  #       %{id: 53, question_id: 58, survey_id: 21},
  #       %{id: 54, question_id: 59, survey_id: 21},
  #       %{id: 55, question_id: 60, survey_id: 21},
  #       %{id: 56, question_id: 61, survey_id: 21},
  #       %{id: 57, question_id: 62, survey_id: 21},
  #       %{id: 58, question_id: 63, survey_id: 21},
  #       %{id: 59, question_id: 64, survey_id: 22},
  #       %{id: 60, question_id: 65, survey_id: 22},
  #       %{id: 61, question_id: 66, survey_id: 22},
  #       %{id: 62, question_id: 67, survey_id: 22},
  #       %{id: 63, question_id: 68, survey_id: 22},
  #       %{id: 64, question_id: 69, survey_id: 22},
  #       %{id: 65, question_id: 70, survey_id: 22},
  #       %{id: 66, question_id: 71, survey_id: 22},
  #       %{id: 67, question_id: 72, survey_id: 23},
  #       %{id: 68, question_id: 73, survey_id: 23},
  #       %{id: 69, question_id: 74, survey_id: 23},
  #       %{id: 70, question_id: 75, survey_id: 23},
  #       %{id: 71, question_id: 76, survey_id: 24},
  #       %{id: 72, question_id: 77, survey_id: 25},
  #       %{id: 73, question_id: 78, survey_id: 25},
  #       %{id: 74, question_id: 79, survey_id: 25},
  #       %{id: 75, question_id: 80, survey_id: 25},
  #       %{id: 76, question_id: 81, survey_id: 25},
  #       %{id: 77, question_id: 82, survey_id: 25},
  #       %{id: 78, question_id: 83, survey_id: 26},
  #       %{id: 79, question_id: 84, survey_id: 26},
  #       %{id: 80, question_id: 85, survey_id: 1},
  #       %{id: 81, question_id: 86, survey_id: 1},
  #       %{id: 82, question_id: 87, survey_id: 27},
  #       %{id: 83, question_id: 88, survey_id: 27},
  #       %{id: 84, question_id: 89, survey_id: 27},
  #       %{id: 85, question_id: 90, survey_id: 2},
  #       %{id: 86, question_id: 91, survey_id: 27},
  #       %{id: 87, question_id: 92, survey_id: 27},
  #       %{id: 88, question_id: 93, survey_id: 27},
  #       %{id: 89, question_id: 94, survey_id: 28},
  #       %{id: 90, question_id: 95, survey_id: 28},
  #       %{id: 91, question_id: 96, survey_id: 28},
  #       %{id: 92, question_id: 97, survey_id: 29},
  #       %{id: 93, question_id: 98, survey_id: 30},
  #       %{id: 95, question_id: 100, survey_id: 2},
  #       %{id: 96, question_id: 101, survey_id: 31},
  #       %{id: 97, question_id: 102, survey_id: 31},
  #       %{id: 98, question_id: 103, survey_id: 32},
  #       %{id: 99, question_id: 104, survey_id: 32},
  #       %{id: 100, question_id: 105, survey_id: 32},
  #       %{id: 101, question_id: 106, survey_id: 33},
  #       %{id: 102, question_id: 107, survey_id: 33},
  #       %{id: 103, question_id: 108, survey_id: 33},
  #       %{id: 104, question_id: 109, survey_id: 33},
  #       %{id: 105, question_id: 110, survey_id: 33},
  #       %{id: 106, question_id: 111, survey_id: 33},
  #       %{id: 107, question_id: 112, survey_id: 33},
  #       %{id: 108, question_id: 113, survey_id: 33},
  #       %{id: 109, question_id: 114, survey_id: 33},
  #       %{id: 110, question_id: 115, survey_id: 34},
  #       %{id: 111, question_id: 116, survey_id: 34},
  #       %{id: 112, question_id: 117, survey_id: 34},
  #       %{id: 113, question_id: 118, survey_id: 34},
  #       %{id: 114, question_id: 119, survey_id: 34},
  #       %{id: 115, question_id: 120, survey_id: 34},
  #       %{id: 116, question_id: 121, survey_id: 34},
  #       %{id: 117, question_id: 122, survey_id: 34},
  #       %{id: 118, question_id: 123, survey_id: 34},
  #       %{id: 119, question_id: 125, survey_id: 35},
  #       %{id: 120, question_id: 126, survey_id: 35},
  #       %{id: 121, question_id: 127, survey_id: 35},
  #       %{id: 122, question_id: 128, survey_id: 35},
  #       %{id: 123, question_id: 129, survey_id: 35},
  #       %{id: 124, question_id: 130, survey_id: 35},
  #       %{id: 125, question_id: 131, survey_id: 2},
  #       %{id: 126, question_id: 132, survey_id: 2},
  #       %{id: 127, question_id: 133, survey_id: 29},
  #       %{id: 128, question_id: 134, survey_id: 33},
  #       %{id: 129, question_id: 135, survey_id: 37},
  #       %{id: 130, question_id: 136, survey_id: 37},
  #       %{id: 131, question_id: 137, survey_id: 38},
  #       %{id: 132, question_id: 138, survey_id: 38},
  #       %{id: 133, question_id: 139, survey_id: 38},
  #       %{id: 134, question_id: 140, survey_id: 38},
  #       %{id: 137, question_id: 90, survey_id: 27},
  #       %{id: 138, question_id: 7, survey_id: 30},
  #       %{id: 139, question_id: 30, survey_id: 3}
  #     ]
  #     |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

  #   Repo.insert_all("survey_question_surveys", joins)
  # end

  # defp insert_survey_answers do
  #   now = DateTime.utc_now() |> DateTime.truncate(:second)

  #   [
  #     %{
  #       id: 1,
  #       question_id: 1,
  #       trait_value_id: 95,
  #       display_order: 1,
  #       text: "I only eat at home"
  #     },
  #     %{
  #       id: 2,
  #       question_id: 1,
  #       trait_value_id: 96,
  #       display_order: 2,
  #       text: "I rarely go out to eat"
  #     },
  #     %{
  #       id: 3,
  #       question_id: 1,
  #       trait_value_id: 97,
  #       display_order: 3,
  #       text: "1-3 times"
  #     },
  #     %{
  #       id: 4,
  #       question_id: 1,
  #       trait_value_id: 98,
  #       display_order: 4,
  #       text: "4-6 times"
  #     },
  #     %{
  #       id: 5,
  #       question_id: 1,
  #       trait_value_id: 99,
  #       display_order: 5,
  #       text: "7-9 times"
  #     },
  #     %{
  #       id: 6,
  #       question_id: 1,
  #       trait_value_id: 100,
  #       display_order: 6,
  #       text: "More than 10 times"
  #     },
  #     %{
  #       id: 7,
  #       question_id: 1,
  #       trait_value_id: 101,
  #       display_order: 7,
  #       text: "I prefer not to say"
  #     },
  #     %{
  #       id: 33,
  #       question_id: 7,
  #       trait_value_id: 55,
  #       display_order: 1,
  #       text: "Single - Never Married"
  #     },
  #     %{
  #       id: 34,
  #       question_id: 7,
  #       trait_value_id: 56,
  #       display_order: 2,
  #       text: "Engaged"
  #     },
  #     %{
  #       id: 35,
  #       question_id: 7,
  #       trait_value_id: 57,
  #       display_order: 3,
  #       text: "Married"
  #     },
  #     %{
  #       id: 36,
  #       question_id: 7,
  #       trait_value_id: 204,
  #       display_order: 4,
  #       text: "Separated"
  #     },
  #     %{
  #       id: 37,
  #       question_id: 7,
  #       trait_value_id: 58,
  #       display_order: 5,
  #       text: "Divorced"
  #     },
  #     %{
  #       id: 38,
  #       question_id: 7,
  #       trait_value_id: 59,
  #       display_order: 6,
  #       text: "Widowed"
  #     },
  #     %{
  #       id: 39,
  #       question_id: 8,
  #       trait_value_id: 41,
  #       display_order: 1,
  #       text: "Employed, Full-time"
  #     },
  #     %{
  #       id: 40,
  #       question_id: 8,
  #       trait_value_id: 42,
  #       display_order: 2,
  #       text: "Employed, Part-time"
  #     },
  #     %{
  #       id: 41,
  #       question_id: 8,
  #       trait_value_id: 44,
  #       display_order: 7,
  #       text: "Currently Not Employed"
  #     },
  #     %{
  #       id: 42,
  #       question_id: 7,
  #       trait_value_id: 89,
  #       display_order: 7,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 43,
  #       question_id: 8,
  #       trait_value_id: 87,
  #       display_order: 8,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 44,
  #       question_id: 9,
  #       trait_value_id: 39,
  #       display_order: 1,
  #       text: "Currently not a student."
  #     },
  #     %{
  #       id: 45,
  #       question_id: 9,
  #       trait_value_id: 249,
  #       display_order: 2,
  #       text: "Middle or Junior High Student"
  #     },
  #     %{
  #       id: 46,
  #       question_id: 9,
  #       trait_value_id: 248,
  #       display_order: 3,
  #       text: "High School Student"
  #     },
  #     %{
  #       id: 47,
  #       question_id: 9,
  #       trait_value_id: 38,
  #       display_order: 4,
  #       text: "Full-time College Student (inludes Junior College, Grad School, Technical School)"
  #     },
  #     %{
  #       id: 48,
  #       question_id: 9,
  #       trait_value_id: 247,
  #       display_order: 5,
  #       text: "Part-time College Student (inludes Junior College, Grad School, Technical School)"
  #     },
  #     %{
  #       id: 49,
  #       question_id: 9,
  #       trait_value_id: 86,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 50,
  #       question_id: 10,
  #       trait_value_id: 46,
  #       display_order: 1,
  #       text: "Less Than High School"
  #     },
  #     %{
  #       id: 51,
  #       question_id: 10,
  #       trait_value_id: 47,
  #       display_order: 2,
  #       text: "High School Graduate"
  #     },
  #     %{
  #       id: 52,
  #       question_id: 10,
  #       trait_value_id: 48,
  #       display_order: 3,
  #       text: "Some College"
  #     },
  #     %{
  #       id: 53,
  #       question_id: 10,
  #       trait_value_id: 49,
  #       display_order: 4,
  #       text: "2-Year College Degree (Associates)"
  #     },
  #     %{
  #       id: 54,
  #       question_id: 10,
  #       trait_value_id: 50,
  #       display_order: 5,
  #       text: "4-Year College Degree (BA, BS, BBA...)"
  #     },
  #     %{
  #       id: 55,
  #       question_id: 10,
  #       trait_value_id: 51,
  #       display_order: 6,
  #       text: "Masters Degree"
  #     },
  #     %{
  #       id: 56,
  #       question_id: 10,
  #       trait_value_id: 52,
  #       display_order: 7,
  #       text: "Doctoral and/or Professional Degree (Ph.D, MD, JD)"
  #     },
  #     %{
  #       id: 57,
  #       question_id: 10,
  #       trait_value_id: 88,
  #       display_order: 8,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 58,
  #       question_id: 11,
  #       trait_value_id: 205,
  #       display_order: 1,
  #       text: "American Indian or Alaska Native"
  #     },
  #     %{
  #       id: 59,
  #       question_id: 11,
  #       trait_value_id: 15,
  #       display_order: 2,
  #       text: "Black or African American"
  #     },
  #     %{
  #       id: 60,
  #       question_id: 11,
  #       trait_value_id: 16,
  #       display_order: 30,
  #       text: "East Asian - Chinese"
  #     },
  #     %{
  #       id: 61,
  #       question_id: 11,
  #       trait_value_id: 17,
  #       display_order: 30,
  #       text: "East Asian - Japanese"
  #     },
  #     %{
  #       id: 62,
  #       question_id: 11,
  #       trait_value_id: 18,
  #       display_order: 30,
  #       text: "East Asian - Korean"
  #     },
  #     %{
  #       id: 63,
  #       question_id: 11,
  #       trait_value_id: 20,
  #       display_order: 30,
  #       text: "East Asian - Vietnamese"
  #     },
  #     %{
  #       id: 64,
  #       question_id: 11,
  #       trait_value_id: 19,
  #       display_order: 31,
  #       text: "East Asian - Other"
  #     },
  #     %{
  #       id: 65,
  #       question_id: 11,
  #       trait_value_id: 206,
  #       display_order: 40,
  #       text: "Hispanic - Cuban"
  #     },
  #     %{
  #       id: 66,
  #       question_id: 11,
  #       trait_value_id: 207,
  #       display_order: 40,
  #       text: "Hispanic - Mexican, Mexican-American, Chicano"
  #     },
  #     %{
  #       id: 67,
  #       question_id: 11,
  #       trait_value_id: 208,
  #       display_order: 40,
  #       text: "Hispanic - Caribbean"
  #     },
  #     %{
  #       id: 68,
  #       question_id: 11,
  #       trait_value_id: 210,
  #       display_order: 40,
  #       text: "Hispanic - Puerto Rican"
  #     },
  #     %{
  #       id: 69,
  #       question_id: 11,
  #       trait_value_id: 209,
  #       display_order: 41,
  #       text: "Hispanic - Other Central/South American"
  #     },
  #     %{
  #       id: 70,
  #       question_id: 11,
  #       trait_value_id: 211,
  #       display_order: 50,
  #       text: "Middle Eastern"
  #     },
  #     %{
  #       id: 71,
  #       question_id: 11,
  #       trait_value_id: 212,
  #       display_order: 60,
  #       text: "Native Hawaiian"
  #     },
  #     %{
  #       id: 72,
  #       question_id: 11,
  #       trait_value_id: 250,
  #       display_order: 70,
  #       text: "Pacific Islander - Philippines"
  #     },
  #     %{
  #       id: 73,
  #       question_id: 11,
  #       trait_value_id: 213,
  #       display_order: 71,
  #       text: "Pacific Islander - Other"
  #     },
  #     %{
  #       id: 74,
  #       question_id: 11,
  #       trait_value_id: 214,
  #       display_order: 90,
  #       text: "South Asian - Indian"
  #     },
  #     %{
  #       id: 75,
  #       question_id: 11,
  #       trait_value_id: 215,
  #       display_order: 91,
  #       text: "South Asian - Other"
  #     },
  #     %{
  #       id: 76,
  #       question_id: 11,
  #       trait_value_id: 216,
  #       display_order: 100,
  #       text: "White or Caucasian"
  #     },
  #     %{
  #       id: 77,
  #       question_id: 11,
  #       trait_value_id: 217,
  #       display_order: 110,
  #       text: "Other - Not Listed Here"
  #     },
  #     %{
  #       id: 78,
  #       question_id: 13,
  #       trait_value_id: 7,
  #       display_order: 1,
  #       text: "$0 - 14,999"
  #     },
  #     %{
  #       id: 79,
  #       question_id: 13,
  #       trait_value_id: 8,
  #       display_order: 2,
  #       text: "$15,000 - 29,999"
  #     },
  #     %{
  #       id: 80,
  #       question_id: 13,
  #       trait_value_id: 9,
  #       display_order: 3,
  #       text: "$30,000 - 44,999"
  #     },
  #     %{
  #       id: 81,
  #       question_id: 13,
  #       trait_value_id: 10,
  #       display_order: 4,
  #       text: "$45,000 - 59,999"
  #     },
  #     %{
  #       id: 82,
  #       question_id: 13,
  #       trait_value_id: 11,
  #       display_order: 5,
  #       text: "$60,000 - 79,999"
  #     },
  #     %{
  #       id: 83,
  #       question_id: 13,
  #       trait_value_id: 12,
  #       display_order: 6,
  #       text: "$80,000 - 99,999"
  #     },
  #     %{
  #       id: 84,
  #       question_id: 13,
  #       trait_value_id: 13,
  #       display_order: 7,
  #       text: "$100,000 - 149,999"
  #     },
  #     %{
  #       id: 85,
  #       question_id: 13,
  #       trait_value_id: 84,
  #       display_order: 8,
  #       text: "$150,000 - 199,999"
  #     },
  #     %{
  #       id: 86,
  #       question_id: 13,
  #       trait_value_id: 218,
  #       display_order: 9,
  #       text: "$200,000 - 249,999"
  #     },
  #     %{
  #       id: 87,
  #       question_id: 13,
  #       trait_value_id: 219,
  #       display_order: 10,
  #       text: "$250,000 - 499,999"
  #     },
  #     %{
  #       id: 88,
  #       question_id: 13,
  #       trait_value_id: 220,
  #       display_order: 11,
  #       text: "$500,000 +"
  #     },
  #     %{
  #       id: 89,
  #       question_id: 13,
  #       trait_value_id: 221,
  #       display_order: 12,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 90,
  #       question_id: 11,
  #       trait_value_id: 251,
  #       display_order: 120,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 91,
  #       question_id: 12,
  #       trait_value_id: 223,
  #       display_order: 1,
  #       text: "$0 - 14,999"
  #     },
  #     %{
  #       id: 92,
  #       question_id: 12,
  #       trait_value_id: 224,
  #       display_order: 2,
  #       text: "$15,000 - 29,999"
  #     },
  #     %{
  #       id: 93,
  #       question_id: 12,
  #       trait_value_id: 225,
  #       display_order: 3,
  #       text: "$30,000 - 44,999"
  #     },
  #     %{
  #       id: 94,
  #       question_id: 12,
  #       trait_value_id: 226,
  #       display_order: 4,
  #       text: "$45,000 - 59,999"
  #     },
  #     %{
  #       id: 95,
  #       question_id: 12,
  #       trait_value_id: 227,
  #       display_order: 5,
  #       text: "$60,000 - 79,999"
  #     },
  #     %{
  #       id: 96,
  #       question_id: 12,
  #       trait_value_id: 228,
  #       display_order: 6,
  #       text: "$80,000 - 99,999"
  #     },
  #     %{
  #       id: 97,
  #       question_id: 12,
  #       trait_value_id: 229,
  #       display_order: 7,
  #       text: "$100,000 - 149,999"
  #     },
  #     %{
  #       id: 98,
  #       question_id: 12,
  #       trait_value_id: 230,
  #       display_order: 8,
  #       text: "$150,000 - 199,999"
  #     },
  #     %{
  #       id: 99,
  #       question_id: 12,
  #       trait_value_id: 231,
  #       display_order: 9,
  #       text: "$200,000 - 249,999"
  #     },
  #     %{
  #       id: 100,
  #       question_id: 12,
  #       trait_value_id: 232,
  #       display_order: 10,
  #       text: "$250,000 - 499,999"
  #     },
  #     %{
  #       id: 101,
  #       question_id: 12,
  #       trait_value_id: 233,
  #       display_order: 11,
  #       text: "$500,000+"
  #     },
  #     %{
  #       id: 102,
  #       question_id: 12,
  #       trait_value_id: 234,
  #       display_order: 12,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 103,
  #       question_id: 8,
  #       trait_value_id: 252,
  #       display_order: 5,
  #       text: "Retired"
  #     },
  #     %{
  #       id: 104,
  #       question_id: 14,
  #       trait_value_id: 271,
  #       display_order: 1,
  #       text: "Swimming"
  #     },
  #     %{
  #       id: 105,
  #       question_id: 14,
  #       trait_value_id: 264,
  #       display_order: 1,
  #       text: "Martial Arts"
  #     },
  #     %{
  #       id: 106,
  #       question_id: 14,
  #       trait_value_id: 265,
  #       display_order: 1,
  #       text: "Mountain Biking"
  #     },
  #     %{
  #       id: 107,
  #       question_id: 14,
  #       trait_value_id: 266,
  #       display_order: 1,
  #       text: "Pilates"
  #     },
  #     %{
  #       id: 108,
  #       question_id: 14,
  #       trait_value_id: 267,
  #       display_order: 1,
  #       text: "Racquetball"
  #     },
  #     %{
  #       id: 109,
  #       question_id: 14,
  #       trait_value_id: 268,
  #       display_order: 1,
  #       text: "Rock Climbing"
  #     },
  #     %{
  #       id: 110,
  #       question_id: 14,
  #       trait_value_id: 254,
  #       display_order: 1,
  #       text: "Aerobics"
  #     },
  #     %{
  #       id: 111,
  #       question_id: 14,
  #       trait_value_id: 255,
  #       display_order: 1,
  #       text: "Baseball"
  #     },
  #     %{
  #       id: 112,
  #       question_id: 14,
  #       trait_value_id: 256,
  #       display_order: 1,
  #       text: "Basketball"
  #     },
  #     %{
  #       id: 113,
  #       question_id: 14,
  #       trait_value_id: 257,
  #       display_order: 1,
  #       text: "Camping"
  #     },
  #     %{
  #       id: 114,
  #       question_id: 14,
  #       trait_value_id: 270,
  #       display_order: 1,
  #       text: "Softball"
  #     },
  #     %{
  #       id: 115,
  #       question_id: 14,
  #       trait_value_id: 263,
  #       display_order: 1,
  #       text: "Hunting"
  #     },
  #     %{
  #       id: 116,
  #       question_id: 14,
  #       trait_value_id: 269,
  #       display_order: 1,
  #       text: "Running/Jogging"
  #     },
  #     %{
  #       id: 117,
  #       question_id: 14,
  #       trait_value_id: 272,
  #       display_order: 1,
  #       text: "Tennis"
  #     },
  #     %{
  #       id: 118,
  #       question_id: 14,
  #       trait_value_id: 273,
  #       display_order: 1,
  #       text: "Ultimate (Disc)"
  #     },
  #     %{
  #       id: 119,
  #       question_id: 14,
  #       trait_value_id: 274,
  #       display_order: 1,
  #       text: "Volleyball"
  #     },
  #     %{
  #       id: 120,
  #       question_id: 14,
  #       trait_value_id: 275,
  #       display_order: 1,
  #       text: "Walking"
  #     },
  #     %{
  #       id: 121,
  #       question_id: 14,
  #       trait_value_id: 276,
  #       display_order: 1,
  #       text: "Weight Lifting"
  #     },
  #     %{
  #       id: 122,
  #       question_id: 14,
  #       trait_value_id: 258,
  #       display_order: 1,
  #       text: "Cycling"
  #     },
  #     %{
  #       id: 123,
  #       question_id: 14,
  #       trait_value_id: 259,
  #       display_order: 1,
  #       text: "Disc Golf"
  #     },
  #     %{
  #       id: 124,
  #       question_id: 14,
  #       trait_value_id: 260,
  #       display_order: 1,
  #       text: "Fishing"
  #     },
  #     %{
  #       id: 125,
  #       question_id: 14,
  #       trait_value_id: 261,
  #       display_order: 1,
  #       text: "Golf"
  #     },
  #     %{
  #       id: 126,
  #       question_id: 14,
  #       trait_value_id: 262,
  #       display_order: 1,
  #       text: "Hiking"
  #     },
  #     %{
  #       id: 127,
  #       question_id: 14,
  #       trait_value_id: 277,
  #       display_order: 1,
  #       text: "Yoga"
  #     },
  #     %{
  #       id: 128,
  #       question_id: 15,
  #       trait_value_id: 162,
  #       display_order: 1,
  #       text: "Dog"
  #     },
  #     %{
  #       id: 129,
  #       question_id: 15,
  #       trait_value_id: 163,
  #       display_order: 2,
  #       text: "Cat"
  #     },
  #     %{
  #       id: 130,
  #       question_id: 15,
  #       trait_value_id: 195,
  #       display_order: 3,
  #       text: "Fish"
  #     },
  #     %{
  #       id: 131,
  #       question_id: 15,
  #       trait_value_id: 196,
  #       display_order: 4,
  #       text: "Bird"
  #     },
  #     %{
  #       id: 132,
  #       question_id: 15,
  #       trait_value_id: 278,
  #       display_order: 5,
  #       text: "Rodent (Hamster, Gerbil, Mouse, etc.)"
  #     },
  #     %{
  #       id: 133,
  #       question_id: 15,
  #       trait_value_id: 279,
  #       display_order: 6,
  #       text: "Snake"
  #     },
  #     %{
  #       id: 134,
  #       question_id: 15,
  #       trait_value_id: 280,
  #       display_order: 7,
  #       text: "Turtle"
  #     },
  #     %{
  #       id: 135,
  #       question_id: 15,
  #       trait_value_id: 282,
  #       display_order: 8,
  #       text: "Other - Reptile"
  #     },
  #     %{
  #       id: 136,
  #       question_id: 15,
  #       trait_value_id: 197,
  #       display_order: 9,
  #       text: "Other - Exotic"
  #     },
  #     %{
  #       id: 137,
  #       question_id: 15,
  #       trait_value_id: 283,
  #       display_order: 10,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 138,
  #       question_id: 15,
  #       trait_value_id: 198,
  #       display_order: 11,
  #       text: "No Pets"
  #     },
  #     %{
  #       id: 139,
  #       question_id: 15,
  #       trait_value_id: 281,
  #       display_order: 12,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 140,
  #       question_id: 16,
  #       trait_value_id: 285,
  #       display_order: 101,
  #       text: "Boy: None"
  #     },
  #     %{
  #       id: 141,
  #       question_id: 16,
  #       trait_value_id: 286,
  #       display_order: 102,
  #       text: "Boy: Expecting/Pregnant"
  #     },
  #     %{
  #       id: 142,
  #       question_id: 16,
  #       trait_value_id: 287,
  #       display_order: 103,
  #       text: "Boy: 0-5 mos"
  #     },
  #     %{
  #       id: 143,
  #       question_id: 16,
  #       trait_value_id: 288,
  #       display_order: 104,
  #       text: "Boy: 6-11 mos"
  #     },
  #     %{
  #       id: 144,
  #       question_id: 16,
  #       trait_value_id: 289,
  #       display_order: 105,
  #       text: "Boy: 12-17 mos"
  #     },
  #     %{
  #       id: 145,
  #       question_id: 16,
  #       trait_value_id: 290,
  #       display_order: 106,
  #       text: "Boy: 18-23 mos"
  #     },
  #     %{
  #       id: 146,
  #       question_id: 16,
  #       trait_value_id: 291,
  #       display_order: 107,
  #       text: "Boy: 2-3 yrs"
  #     },
  #     %{
  #       id: 147,
  #       question_id: 16,
  #       trait_value_id: 292,
  #       display_order: 108,
  #       text: "Boy: 4-6 yrs"
  #     },
  #     %{
  #       id: 148,
  #       question_id: 16,
  #       trait_value_id: 293,
  #       display_order: 109,
  #       text: "Boy: 7-9 yrs"
  #     },
  #     %{
  #       id: 149,
  #       question_id: 16,
  #       trait_value_id: 294,
  #       display_order: 110,
  #       text: "Boy: 10-12 yrs"
  #     },
  #     %{
  #       id: 150,
  #       question_id: 16,
  #       trait_value_id: 295,
  #       display_order: 111,
  #       text: "Boy: 13-15 yrs"
  #     },
  #     %{
  #       id: 151,
  #       question_id: 16,
  #       trait_value_id: 296,
  #       display_order: 112,
  #       text: "Boy: 16-17 yrs"
  #     },
  #     %{
  #       id: 152,
  #       question_id: 16,
  #       trait_value_id: 297,
  #       display_order: 113,
  #       text: "Boy: 18-20 yrs"
  #     },
  #     %{
  #       id: 153,
  #       question_id: 16,
  #       trait_value_id: 298,
  #       display_order: 114,
  #       text: "Boy: 21-24 yrs"
  #     },
  #     %{
  #       id: 154,
  #       question_id: 16,
  #       trait_value_id: 299,
  #       display_order: 115,
  #       text: "Boy: 25+ yrs"
  #     },
  #     %{
  #       id: 155,
  #       question_id: 16,
  #       trait_value_id: 300,
  #       display_order: 200,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 156,
  #       question_id: 16,
  #       trait_value_id: 302,
  #       display_order: 1,
  #       text: "Girl: None"
  #     },
  #     %{
  #       id: 157,
  #       question_id: 16,
  #       trait_value_id: 303,
  #       display_order: 2,
  #       text: "Girl: Expecting/Pregnant"
  #     },
  #     %{
  #       id: 158,
  #       question_id: 16,
  #       trait_value_id: 304,
  #       display_order: 3,
  #       text: "Girl: 0-5 mos"
  #     },
  #     %{
  #       id: 159,
  #       question_id: 16,
  #       trait_value_id: 305,
  #       display_order: 4,
  #       text: "Girl: 6-11 mos"
  #     },
  #     %{
  #       id: 160,
  #       question_id: 16,
  #       trait_value_id: 306,
  #       display_order: 5,
  #       text: "Girl: 12-17 mos"
  #     },
  #     %{
  #       id: 161,
  #       question_id: 16,
  #       trait_value_id: 307,
  #       display_order: 6,
  #       text: "Girl: 18-23 mos"
  #     },
  #     %{
  #       id: 162,
  #       question_id: 16,
  #       trait_value_id: 308,
  #       display_order: 7,
  #       text: "Girl: 2-3 yrs"
  #     },
  #     %{
  #       id: 163,
  #       question_id: 16,
  #       trait_value_id: 309,
  #       display_order: 8,
  #       text: "Girl: 4-6 yrs"
  #     },
  #     %{
  #       id: 164,
  #       question_id: 16,
  #       trait_value_id: 310,
  #       display_order: 9,
  #       text: "Girl: 7-9 yrs"
  #     },
  #     %{
  #       id: 165,
  #       question_id: 16,
  #       trait_value_id: 311,
  #       display_order: 10,
  #       text: "Girl: 10-12 yrs"
  #     },
  #     %{
  #       id: 166,
  #       question_id: 16,
  #       trait_value_id: 312,
  #       display_order: 11,
  #       text: "Girl: 13-15 yrs"
  #     },
  #     %{
  #       id: 167,
  #       question_id: 16,
  #       trait_value_id: 313,
  #       display_order: 12,
  #       text: "Girl: 16-17 yrs"
  #     },
  #     %{
  #       id: 168,
  #       question_id: 16,
  #       trait_value_id: 314,
  #       display_order: 13,
  #       text: "Girl: 18-20 yrs"
  #     },
  #     %{
  #       id: 169,
  #       question_id: 16,
  #       trait_value_id: 315,
  #       display_order: 14,
  #       text: "Girl: 21-24 yrs"
  #     },
  #     %{
  #       id: 170,
  #       question_id: 16,
  #       trait_value_id: 316,
  #       display_order: 15,
  #       text: "Girl: 25+ yrs"
  #     },
  #     %{
  #       id: 172,
  #       question_id: 18,
  #       trait_value_id: 319,
  #       display_order: 1,
  #       text: "Homeschool"
  #     },
  #     %{
  #       id: 173,
  #       question_id: 18,
  #       trait_value_id: 320,
  #       display_order: 2,
  #       text: "Day Care"
  #     },
  #     %{
  #       id: 174,
  #       question_id: 18,
  #       trait_value_id: 321,
  #       display_order: 3,
  #       text: "Montessori Methods/Systems"
  #     },
  #     %{
  #       id: 175,
  #       question_id: 18,
  #       trait_value_id: 322,
  #       display_order: 4,
  #       text: "Private School (K-12)"
  #     },
  #     %{
  #       id: 176,
  #       question_id: 18,
  #       trait_value_id: 323,
  #       display_order: 5,
  #       text: "Public School (K-12)"
  #     },
  #     %{
  #       id: 177,
  #       question_id: 18,
  #       trait_value_id: 324,
  #       display_order: 6,
  #       text: "Community or Junior College"
  #     },
  #     %{
  #       id: 178,
  #       question_id: 18,
  #       trait_value_id: 325,
  #       display_order: 7,
  #       text: "College or University (4-year)"
  #     },
  #     %{
  #       id: 179,
  #       question_id: 19,
  #       trait_value_id: 327,
  #       display_order: 1,
  #       text: "AIDS"
  #     },
  #     %{
  #       id: 180,
  #       question_id: 19,
  #       trait_value_id: 366,
  #       display_order: 1,
  #       text: "ADD/ADHD"
  #     },
  #     %{
  #       id: 181,
  #       question_id: 19,
  #       trait_value_id: 328,
  #       display_order: 1,
  #       text: "Alzheimer's disease"
  #     },
  #     %{
  #       id: 182,
  #       question_id: 19,
  #       trait_value_id: 329,
  #       display_order: 1,
  #       text: "Arthritis"
  #     },
  #     %{
  #       id: 183,
  #       question_id: 19,
  #       trait_value_id: 330,
  #       display_order: 1,
  #       text: "Asthma"
  #     },
  #     %{
  #       id: 184,
  #       question_id: 19,
  #       trait_value_id: 331,
  #       display_order: 1,
  #       text: "Autism"
  #     },
  #     %{
  #       id: 185,
  #       question_id: 19,
  #       trait_value_id: 332,
  #       display_order: 1,
  #       text: "Addiction"
  #     },
  #     %{
  #       id: 186,
  #       question_id: 19,
  #       trait_value_id: 333,
  #       display_order: 1,
  #       text: "Bipolar disorder"
  #     },
  #     %{
  #       id: 187,
  #       question_id: 19,
  #       trait_value_id: 334,
  #       display_order: 1,
  #       text: "Blindness"
  #     },
  #     %{
  #       id: 188,
  #       question_id: 19,
  #       trait_value_id: 335,
  #       display_order: 1,
  #       text: "Cancer"
  #     },
  #     %{
  #       id: 189,
  #       question_id: 19,
  #       trait_value_id: 336,
  #       display_order: 1,
  #       text: "Cerebral palsy"
  #     },
  #     %{
  #       id: 190,
  #       question_id: 19,
  #       trait_value_id: 337,
  #       display_order: 1,
  #       text: "Chronic fatigue syndrome"
  #     },
  #     %{
  #       id: 191,
  #       question_id: 19,
  #       trait_value_id: 338,
  #       display_order: 1,
  #       text: "Colitis"
  #     },
  #     %{
  #       id: 192,
  #       question_id: 19,
  #       trait_value_id: 339,
  #       display_order: 1,
  #       text: "Crohn's disease"
  #     },
  #     %{
  #       id: 193,
  #       question_id: 19,
  #       trait_value_id: 340,
  #       display_order: 1,
  #       text: "Cystic fibrosis"
  #     },
  #     %{
  #       id: 194,
  #       question_id: 19,
  #       trait_value_id: 341,
  #       display_order: 1,
  #       text: "Deafness"
  #     },
  #     %{
  #       id: 195,
  #       question_id: 19,
  #       trait_value_id: 342,
  #       display_order: 1,
  #       text: "Depression"
  #     },
  #     %{
  #       id: 196,
  #       question_id: 19,
  #       trait_value_id: 343,
  #       display_order: 1,
  #       text: "Diabetes"
  #     },
  #     %{
  #       id: 197,
  #       question_id: 19,
  #       trait_value_id: 344,
  #       display_order: 1,
  #       text: "Down syndrome"
  #     },
  #     %{
  #       id: 198,
  #       question_id: 19,
  #       trait_value_id: 345,
  #       display_order: 1,
  #       text: "Eating disorder"
  #     },
  #     %{
  #       id: 199,
  #       question_id: 19,
  #       trait_value_id: 346,
  #       display_order: 1,
  #       text: "Epilepsy"
  #     },
  #     %{
  #       id: 200,
  #       question_id: 19,
  #       trait_value_id: 347,
  #       display_order: 1,
  #       text: "High cholesterol"
  #     },
  #     %{
  #       id: 201,
  #       question_id: 19,
  #       trait_value_id: 348,
  #       display_order: 1,
  #       text: "Hypertension"
  #     },
  #     %{
  #       id: 202,
  #       question_id: 19,
  #       trait_value_id: 349,
  #       display_order: 1,
  #       text: "Heart disease"
  #     },
  #     %{
  #       id: 203,
  #       question_id: 19,
  #       trait_value_id: 350,
  #       display_order: 1,
  #       text: "HIV"
  #     },
  #     %{
  #       id: 204,
  #       question_id: 19,
  #       trait_value_id: 351,
  #       display_order: 1,
  #       text: "Leukemia"
  #     },
  #     %{
  #       id: 205,
  #       question_id: 19,
  #       trait_value_id: 352,
  #       display_order: 1,
  #       text: "Lung disease"
  #     },
  #     %{
  #       id: 206,
  #       question_id: 19,
  #       trait_value_id: 353,
  #       display_order: 1,
  #       text: "Lupus"
  #     },
  #     %{
  #       id: 207,
  #       question_id: 19,
  #       trait_value_id: 354,
  #       display_order: 1,
  #       text: "Lyme disease"
  #     },
  #     %{
  #       id: 208,
  #       question_id: 19,
  #       trait_value_id: 355,
  #       display_order: 1,
  #       text: "Migraines"
  #     },
  #     %{
  #       id: 209,
  #       question_id: 19,
  #       trait_value_id: 356,
  #       display_order: 1,
  #       text: "Multiple sclerosis"
  #     },
  #     %{
  #       id: 210,
  #       question_id: 19,
  #       trait_value_id: 357,
  #       display_order: 1,
  #       text: "Muscular dystrophy"
  #     },
  #     %{
  #       id: 211,
  #       question_id: 19,
  #       trait_value_id: 358,
  #       display_order: 1,
  #       text: "Obsessive-compulsive disorder"
  #     },
  #     %{
  #       id: 212,
  #       question_id: 19,
  #       trait_value_id: 359,
  #       display_order: 1,
  #       text: "Obesity"
  #     },
  #     %{
  #       id: 213,
  #       question_id: 19,
  #       trait_value_id: 360,
  #       display_order: 1,
  #       text: "Parkinson's disease"
  #     },
  #     %{
  #       id: 214,
  #       question_id: 19,
  #       trait_value_id: 361,
  #       display_order: 1,
  #       text: "Repetitive strain injury (RSI)"
  #     },
  #     %{
  #       id: 215,
  #       question_id: 19,
  #       trait_value_id: 362,
  #       display_order: 1,
  #       text: "Shingles"
  #     },
  #     %{
  #       id: 216,
  #       question_id: 19,
  #       trait_value_id: 363,
  #       display_order: 1,
  #       text: "Sickle-cell anemia"
  #     },
  #     %{
  #       id: 217,
  #       question_id: 19,
  #       trait_value_id: 364,
  #       display_order: 1,
  #       text: "Sleep apnea"
  #     },
  #     %{
  #       id: 218,
  #       question_id: 19,
  #       trait_value_id: 365,
  #       display_order: 1,
  #       text: "Tinnitus"
  #     },
  #     %{
  #       id: 219,
  #       question_id: 20,
  #       trait_value_id: 368,
  #       display_order: 1,
  #       text: "AIDS"
  #     },
  #     %{
  #       id: 220,
  #       question_id: 20,
  #       trait_value_id: 369,
  #       display_order: 1,
  #       text: "ADD/ADHD"
  #     },
  #     %{
  #       id: 221,
  #       question_id: 20,
  #       trait_value_id: 370,
  #       display_order: 1,
  #       text: "Alzheimer's disease"
  #     },
  #     %{
  #       id: 222,
  #       question_id: 20,
  #       trait_value_id: 371,
  #       display_order: 1,
  #       text: "Arthritis"
  #     },
  #     %{
  #       id: 223,
  #       question_id: 20,
  #       trait_value_id: 372,
  #       display_order: 1,
  #       text: "Asthma"
  #     },
  #     %{
  #       id: 224,
  #       question_id: 20,
  #       trait_value_id: 373,
  #       display_order: 1,
  #       text: "Autism"
  #     },
  #     %{
  #       id: 225,
  #       question_id: 20,
  #       trait_value_id: 374,
  #       display_order: 1,
  #       text: "Addiction"
  #     },
  #     %{
  #       id: 226,
  #       question_id: 20,
  #       trait_value_id: 375,
  #       display_order: 1,
  #       text: "Bipolar disorder"
  #     },
  #     %{
  #       id: 227,
  #       question_id: 20,
  #       trait_value_id: 376,
  #       display_order: 1,
  #       text: "Blindness"
  #     },
  #     %{
  #       id: 228,
  #       question_id: 20,
  #       trait_value_id: 377,
  #       display_order: 1,
  #       text: "Cancer"
  #     },
  #     %{
  #       id: 229,
  #       question_id: 20,
  #       trait_value_id: 378,
  #       display_order: 1,
  #       text: "Cerebral palsy"
  #     },
  #     %{
  #       id: 230,
  #       question_id: 20,
  #       trait_value_id: 379,
  #       display_order: 1,
  #       text: "Chronic fatigue syndrome"
  #     },
  #     %{
  #       id: 231,
  #       question_id: 20,
  #       trait_value_id: 380,
  #       display_order: 1,
  #       text: "Colitis"
  #     },
  #     %{
  #       id: 232,
  #       question_id: 20,
  #       trait_value_id: 381,
  #       display_order: 1,
  #       text: "Crohn's disease"
  #     },
  #     %{
  #       id: 233,
  #       question_id: 20,
  #       trait_value_id: 382,
  #       display_order: 1,
  #       text: "Cystic fibrosis"
  #     },
  #     %{
  #       id: 234,
  #       question_id: 20,
  #       trait_value_id: 383,
  #       display_order: 1,
  #       text: "Deafness"
  #     },
  #     %{
  #       id: 235,
  #       question_id: 20,
  #       trait_value_id: 384,
  #       display_order: 1,
  #       text: "Depression"
  #     },
  #     %{
  #       id: 236,
  #       question_id: 20,
  #       trait_value_id: 385,
  #       display_order: 1,
  #       text: "Diabetes"
  #     },
  #     %{
  #       id: 237,
  #       question_id: 20,
  #       trait_value_id: 386,
  #       display_order: 1,
  #       text: "Down syndrome"
  #     },
  #     %{
  #       id: 238,
  #       question_id: 20,
  #       trait_value_id: 387,
  #       display_order: 1,
  #       text: "Eating disorder"
  #     },
  #     %{
  #       id: 239,
  #       question_id: 20,
  #       trait_value_id: 388,
  #       display_order: 1,
  #       text: "Epilepsy"
  #     },
  #     %{
  #       id: 240,
  #       question_id: 20,
  #       trait_value_id: 389,
  #       display_order: 1,
  #       text: "High cholesterol"
  #     },
  #     %{
  #       id: 241,
  #       question_id: 20,
  #       trait_value_id: 390,
  #       display_order: 1,
  #       text: "Hypertension"
  #     },
  #     %{
  #       id: 242,
  #       question_id: 20,
  #       trait_value_id: 391,
  #       display_order: 1,
  #       text: "Heart disease"
  #     },
  #     %{
  #       id: 243,
  #       question_id: 20,
  #       trait_value_id: 392,
  #       display_order: 1,
  #       text: "HIV"
  #     },
  #     %{
  #       id: 244,
  #       question_id: 20,
  #       trait_value_id: 393,
  #       display_order: 1,
  #       text: "Leukemia"
  #     },
  #     %{
  #       id: 245,
  #       question_id: 20,
  #       trait_value_id: 394,
  #       display_order: 1,
  #       text: "Lung disease"
  #     },
  #     %{
  #       id: 246,
  #       question_id: 20,
  #       trait_value_id: 395,
  #       display_order: 1,
  #       text: "Lupus"
  #     },
  #     %{
  #       id: 247,
  #       question_id: 20,
  #       trait_value_id: 396,
  #       display_order: 1,
  #       text: "Lyme disease"
  #     },
  #     %{
  #       id: 248,
  #       question_id: 20,
  #       trait_value_id: 397,
  #       display_order: 1,
  #       text: "Migraines"
  #     },
  #     %{
  #       id: 249,
  #       question_id: 20,
  #       trait_value_id: 398,
  #       display_order: 1,
  #       text: "Multiple sclerosis"
  #     },
  #     %{
  #       id: 250,
  #       question_id: 20,
  #       trait_value_id: 399,
  #       display_order: 1,
  #       text: "Muscular dystrophy"
  #     },
  #     %{
  #       id: 251,
  #       question_id: 20,
  #       trait_value_id: 400,
  #       display_order: 1,
  #       text: "Obsessive-compulsive disorder"
  #     },
  #     %{
  #       id: 252,
  #       question_id: 20,
  #       trait_value_id: 401,
  #       display_order: 1,
  #       text: "Obesity"
  #     },
  #     %{
  #       id: 253,
  #       question_id: 20,
  #       trait_value_id: 402,
  #       display_order: 1,
  #       text: "Parkinson's disease"
  #     },
  #     %{
  #       id: 254,
  #       question_id: 20,
  #       trait_value_id: 403,
  #       display_order: 1,
  #       text: "Repetitive strain injury (RSI)"
  #     },
  #     %{
  #       id: 255,
  #       question_id: 20,
  #       trait_value_id: 404,
  #       display_order: 1,
  #       text: "Shingles"
  #     },
  #     %{
  #       id: 256,
  #       question_id: 20,
  #       trait_value_id: 405,
  #       display_order: 1,
  #       text: "Sickle-cell anemia"
  #     },
  #     %{
  #       id: 257,
  #       question_id: 20,
  #       trait_value_id: 406,
  #       display_order: 1,
  #       text: "Sleep apnea"
  #     },
  #     %{
  #       id: 258,
  #       question_id: 20,
  #       trait_value_id: 407,
  #       display_order: 1,
  #       text: "Tinnitus"
  #     },
  #     %{
  #       id: 259,
  #       question_id: 21,
  #       trait_value_id: 409,
  #       display_order: 1,
  #       text: "Animal dander"
  #     },
  #     %{
  #       id: 260,
  #       question_id: 21,
  #       trait_value_id: 410,
  #       display_order: 1,
  #       text: "Dust mites"
  #     },
  #     %{
  #       id: 261,
  #       question_id: 21,
  #       trait_value_id: 411,
  #       display_order: 1,
  #       text: "Eggs"
  #     },
  #     %{
  #       id: 262,
  #       question_id: 21,
  #       trait_value_id: 412,
  #       display_order: 1,
  #       text: "Fish"
  #     },
  #     %{
  #       id: 263,
  #       question_id: 21,
  #       trait_value_id: 413,
  #       display_order: 1,
  #       text: "Gluten (Celiac disease)"
  #     },
  #     %{
  #       id: 264,
  #       question_id: 21,
  #       trait_value_id: 414,
  #       display_order: 1,
  #       text: "Grass/Weeds"
  #     },
  #     %{
  #       id: 265,
  #       question_id: 21,
  #       trait_value_id: 415,
  #       display_order: 1,
  #       text: "Insect bites/venom"
  #     },
  #     %{
  #       id: 266,
  #       question_id: 21,
  #       trait_value_id: 416,
  #       display_order: 1,
  #       text: "Jewelry (Nickel)"
  #     },
  #     %{
  #       id: 267,
  #       question_id: 21,
  #       trait_value_id: 417,
  #       display_order: 1,
  #       text: "Latex"
  #     },
  #     %{
  #       id: 268,
  #       question_id: 21,
  #       trait_value_id: 418,
  #       display_order: 1,
  #       text: "Milk/Lactose intolerance"
  #     },
  #     %{
  #       id: 269,
  #       question_id: 21,
  #       trait_value_id: 419,
  #       display_order: 1,
  #       text: "Mold"
  #     },
  #     %{
  #       id: 270,
  #       question_id: 21,
  #       trait_value_id: 420,
  #       display_order: 1,
  #       text: "Peanuts"
  #     },
  #     %{
  #       id: 271,
  #       question_id: 21,
  #       trait_value_id: 421,
  #       display_order: 1,
  #       text: "Penicillin"
  #     },
  #     %{
  #       id: 272,
  #       question_id: 21,
  #       trait_value_id: 422,
  #       display_order: 1,
  #       text: "Poison Ivy/Oak"
  #     },
  #     %{
  #       id: 273,
  #       question_id: 21,
  #       trait_value_id: 423,
  #       display_order: 1,
  #       text: "Pollen"
  #     },
  #     %{
  #       id: 274,
  #       question_id: 21,
  #       trait_value_id: 424,
  #       display_order: 1,
  #       text: "Shellfish"
  #     },
  #     %{
  #       id: 276,
  #       question_id: 21,
  #       trait_value_id: 425,
  #       display_order: 1,
  #       text: "Soy"
  #     },
  #     %{
  #       id: 277,
  #       question_id: 21,
  #       trait_value_id: 426,
  #       display_order: 1,
  #       text: "Spider bites/venom"
  #     },
  #     %{
  #       id: 278,
  #       question_id: 21,
  #       trait_value_id: 427,
  #       display_order: 1,
  #       text: "Tree nut (walnut, cashew, etc.)"
  #     },
  #     %{
  #       id: 279,
  #       question_id: 21,
  #       trait_value_id: 428,
  #       display_order: 1,
  #       text: "Wheat"
  #     },
  #     %{
  #       id: 280,
  #       question_id: 21,
  #       trait_value_id: 429,
  #       display_order: 2,
  #       text: "No known allergies"
  #     },
  #     %{
  #       id: 281,
  #       question_id: 21,
  #       trait_value_id: 430,
  #       display_order: 3,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 282,
  #       question_id: 22,
  #       trait_value_id: 432,
  #       display_order: 1,
  #       text: "Beadwork"
  #     },
  #     %{
  #       id: 283,
  #       question_id: 22,
  #       trait_value_id: 433,
  #       display_order: 1,
  #       text: "Candle Making"
  #     },
  #     %{
  #       id: 284,
  #       question_id: 22,
  #       trait_value_id: 434,
  #       display_order: 1,
  #       text: "Crochet"
  #     },
  #     %{
  #       id: 285,
  #       question_id: 22,
  #       trait_value_id: 435,
  #       display_order: 1,
  #       text: "Cross-Stitch"
  #     },
  #     %{
  #       id: 286,
  #       question_id: 22,
  #       trait_value_id: 436,
  #       display_order: 1,
  #       text: "Drawing / Sketching"
  #     },
  #     %{
  #       id: 287,
  #       question_id: 22,
  #       trait_value_id: 437,
  #       display_order: 1,
  #       text: "Jewelry Making"
  #     },
  #     %{
  #       id: 288,
  #       question_id: 22,
  #       trait_value_id: 438,
  #       display_order: 1,
  #       text: "Knitting"
  #     },
  #     %{
  #       id: 289,
  #       question_id: 22,
  #       trait_value_id: 439,
  #       display_order: 1,
  #       text: "Needlepoint"
  #     },
  #     %{
  #       id: 290,
  #       question_id: 22,
  #       trait_value_id: 440,
  #       display_order: 1,
  #       text: "Painting"
  #     },
  #     %{
  #       id: 291,
  #       question_id: 22,
  #       trait_value_id: 441,
  #       display_order: 1,
  #       text: "Pottery"
  #     },
  #     %{
  #       id: 292,
  #       question_id: 22,
  #       trait_value_id: 442,
  #       display_order: 1,
  #       text: "Quilting"
  #     },
  #     %{
  #       id: 293,
  #       question_id: 22,
  #       trait_value_id: 443,
  #       display_order: 1,
  #       text: "Rubber Stamping"
  #     },
  #     %{
  #       id: 294,
  #       question_id: 22,
  #       trait_value_id: 444,
  #       display_order: 1,
  #       text: "Scrapbooking"
  #     },
  #     %{
  #       id: 295,
  #       question_id: 22,
  #       trait_value_id: 445,
  #       display_order: 1,
  #       text: "Sewing"
  #     },
  #     %{
  #       id: 296,
  #       question_id: 22,
  #       trait_value_id: 446,
  #       display_order: 1,
  #       text: "Soap Making"
  #     },
  #     %{
  #       id: 297,
  #       question_id: 22,
  #       trait_value_id: 447,
  #       display_order: 1,
  #       text: "Woodworking"
  #     },
  #     %{
  #       id: 298,
  #       question_id: 22,
  #       trait_value_id: 448,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 299,
  #       question_id: 23,
  #       trait_value_id: 450,
  #       display_order: 8,
  #       text: "Allan Hancock College"
  #     },
  #     %{
  #       id: 300,
  #       question_id: 23,
  #       trait_value_id: 451,
  #       display_order: 9,
  #       text: "Alvin Community College"
  #     },
  #     %{
  #       id: 301,
  #       question_id: 23,
  #       trait_value_id: 452,
  #       display_order: 10,
  #       text: "Amarillo College"
  #     },
  #     %{
  #       id: 302,
  #       question_id: 23,
  #       trait_value_id: 453,
  #       display_order: 14,
  #       text: "American River College"
  #     },
  #     %{
  #       id: 303,
  #       question_id: 23,
  #       trait_value_id: 454,
  #       display_order: 17,
  #       text: "Angelo State University"
  #     },
  #     %{
  #       id: 304,
  #       question_id: 23,
  #       trait_value_id: 455,
  #       display_order: 18,
  #       text: "Antelope Valley College"
  #     },
  #     %{
  #       id: 305,
  #       question_id: 23,
  #       trait_value_id: 456,
  #       display_order: 22,
  #       text: "Arizona State University"
  #     },
  #     %{
  #       id: 306,
  #       question_id: 23,
  #       trait_value_id: 457,
  #       display_order: 25,
  #       text: "Arkansas State University"
  #     },
  #     %{
  #       id: 307,
  #       question_id: 23,
  #       trait_value_id: 458,
  #       display_order: 38,
  #       text: "Auburn University"
  #     },
  #     %{
  #       id: 308,
  #       question_id: 23,
  #       trait_value_id: 459,
  #       display_order: 42,
  #       text: "Austin Community College"
  #     },
  #     %{
  #       id: 309,
  #       question_id: 23,
  #       trait_value_id: 460,
  #       display_order: 45,
  #       text: "Azusa Pacific University"
  #     },
  #     %{
  #       id: 310,
  #       question_id: 23,
  #       trait_value_id: 461,
  #       display_order: 47,
  #       text: "Bakersfield College"
  #     },
  #     %{
  #       id: 311,
  #       question_id: 23,
  #       trait_value_id: 462,
  #       display_order: 48,
  #       text: "Ball State University"
  #     },
  #     %{
  #       id: 312,
  #       question_id: 23,
  #       trait_value_id: 463,
  #       display_order: 52,
  #       text: "Baruch College"
  #     },
  #     %{
  #       id: 313,
  #       question_id: 23,
  #       trait_value_id: 464,
  #       display_order: 55,
  #       text: "Baylor University"
  #     },
  #     %{
  #       id: 314,
  #       question_id: 23,
  #       trait_value_id: 465,
  #       display_order: 62,
  #       text: "Bergen Community College"
  #     },
  #     %{
  #       id: 315,
  #       question_id: 23,
  #       trait_value_id: 466,
  #       display_order: 71,
  #       text: "Blinn College"
  #     },
  #     %{
  #       id: 316,
  #       question_id: 23,
  #       trait_value_id: 467,
  #       display_order: 73,
  #       text: "Bluefield State College"
  #     },
  #     %{
  #       id: 317,
  #       question_id: 23,
  #       trait_value_id: 468,
  #       display_order: 76,
  #       text: "Boise State University"
  #     },
  #     %{
  #       id: 318,
  #       question_id: 23,
  #       trait_value_id: 469,
  #       display_order: 77,
  #       text: "Boston University"
  #     },
  #     %{
  #       id: 319,
  #       question_id: 23,
  #       trait_value_id: 470,
  #       display_order: 79,
  #       text: "Bowling Green State University"
  #     },
  #     %{
  #       id: 320,
  #       question_id: 23,
  #       trait_value_id: 471,
  #       display_order: 85,
  #       text: "Brigham Young University, Provo"
  #     },
  #     %{
  #       id: 321,
  #       question_id: 23,
  #       trait_value_id: 472,
  #       display_order: 86,
  #       text: "Brookdale Community College"
  #     },
  #     %{
  #       id: 322,
  #       question_id: 23,
  #       trait_value_id: 473,
  #       display_order: 88,
  #       text: "Broward Community College"
  #     },
  #     %{
  #       id: 323,
  #       question_id: 23,
  #       trait_value_id: 474,
  #       display_order: 90,
  #       text: "California Institute of Technology"
  #     },
  #     %{
  #       id: 324,
  #       question_id: 23,
  #       trait_value_id: 475,
  #       display_order: 91,
  #       text: "California Maritime Academy"
  #     },
  #     %{
  #       id: 325,
  #       question_id: 23,
  #       trait_value_id: 476,
  #       display_order: 92,
  #       text: "California Polytechnic State University, San Luis Obispo"
  #     },
  #     %{
  #       id: 326,
  #       question_id: 23,
  #       trait_value_id: 477,
  #       display_order: 93,
  #       text: "California State Polytechnic University, Pomona"
  #     },
  #     %{
  #       id: 327,
  #       question_id: 23,
  #       trait_value_id: 478,
  #       display_order: 94,
  #       text: "California State University, Bakersfield"
  #     },
  #     %{
  #       id: 328,
  #       question_id: 23,
  #       trait_value_id: 479,
  #       display_order: 95,
  #       text: "California State University, Channel Islands"
  #     },
  #     %{
  #       id: 329,
  #       question_id: 23,
  #       trait_value_id: 480,
  #       display_order: 96,
  #       text: "California State University, Chico"
  #     },
  #     %{
  #       id: 330,
  #       question_id: 23,
  #       trait_value_id: 481,
  #       display_order: 97,
  #       text: "California State University, Dominguez Hills"
  #     },
  #     %{
  #       id: 331,
  #       question_id: 23,
  #       trait_value_id: 482,
  #       display_order: 98,
  #       text: "California State University, East Bay"
  #     },
  #     %{
  #       id: 332,
  #       question_id: 23,
  #       trait_value_id: 483,
  #       display_order: 99,
  #       text: "California State University, Fresno"
  #     },
  #     %{
  #       id: 333,
  #       question_id: 23,
  #       trait_value_id: 484,
  #       display_order: 100,
  #       text: "California State University, Fullerton"
  #     },
  #     %{
  #       id: 334,
  #       question_id: 23,
  #       trait_value_id: 485,
  #       display_order: 101,
  #       text: "California State University, Long Beach"
  #     },
  #     %{
  #       id: 335,
  #       question_id: 23,
  #       trait_value_id: 486,
  #       display_order: 102,
  #       text: "California State University, Los Angeles"
  #     },
  #     %{
  #       id: 336,
  #       question_id: 23,
  #       trait_value_id: 487,
  #       display_order: 103,
  #       text: "California State University, Monterey Bay"
  #     },
  #     %{
  #       id: 758,
  #       question_id: 29,
  #       trait_value_id: 918,
  #       display_order: 1,
  #       text: "Ringworm"
  #     },
  #     %{
  #       id: 337,
  #       question_id: 23,
  #       trait_value_id: 488,
  #       display_order: 104,
  #       text: "California State University, Northridge"
  #     },
  #     %{
  #       id: 338,
  #       question_id: 23,
  #       trait_value_id: 489,
  #       display_order: 105,
  #       text: "California State University, Sacramento"
  #     },
  #     %{
  #       id: 339,
  #       question_id: 23,
  #       trait_value_id: 490,
  #       display_order: 106,
  #       text: "California State University, San Bernardino"
  #     },
  #     %{
  #       id: 340,
  #       question_id: 23,
  #       trait_value_id: 491,
  #       display_order: 107,
  #       text: "California State University, San Marcos"
  #     },
  #     %{
  #       id: 341,
  #       question_id: 23,
  #       trait_value_id: 492,
  #       display_order: 108,
  #       text: "California State University, Stanislaus"
  #     },
  #     %{
  #       id: 342,
  #       question_id: 23,
  #       trait_value_id: 493,
  #       display_order: 110,
  #       text: "Canada College"
  #     },
  #     %{
  #       id: 343,
  #       question_id: 23,
  #       trait_value_id: 494,
  #       display_order: 112,
  #       text: "Carnegie Mellon University"
  #     },
  #     %{
  #       id: 344,
  #       question_id: 23,
  #       trait_value_id: 495,
  #       display_order: 114,
  #       text: "Case Western Reserve University"
  #     },
  #     %{
  #       id: 345,
  #       question_id: 23,
  #       trait_value_id: 496,
  #       display_order: 116,
  #       text: "Central Connecticut State University"
  #     },
  #     %{
  #       id: 346,
  #       question_id: 23,
  #       trait_value_id: 497,
  #       display_order: 120,
  #       text: "Central Michigan University"
  #     },
  #     %{
  #       id: 347,
  #       question_id: 23,
  #       trait_value_id: 498,
  #       display_order: 121,
  #       text: "Central Texas College"
  #     },
  #     %{
  #       id: 348,
  #       question_id: 23,
  #       trait_value_id: 499,
  #       display_order: 122,
  #       text: "Central Washington University"
  #     },
  #     %{
  #       id: 349,
  #       question_id: 23,
  #       trait_value_id: 500,
  #       display_order: 124,
  #       text: "Chabot College"
  #     },
  #     %{
  #       id: 350,
  #       question_id: 23,
  #       trait_value_id: 501,
  #       display_order: 125,
  #       text: "Chaffey College"
  #     },
  #     %{
  #       id: 351,
  #       question_id: 23,
  #       trait_value_id: 502,
  #       display_order: 132,
  #       text: "Cincinnati State Technical and Community College"
  #     },
  #     %{
  #       id: 352,
  #       question_id: 23,
  #       trait_value_id: 503,
  #       display_order: 133,
  #       text: "Citrus College"
  #     },
  #     %{
  #       id: 353,
  #       question_id: 23,
  #       trait_value_id: 504,
  #       display_order: 134,
  #       text: "City College of San Francisco"
  #     },
  #     %{
  #       id: 354,
  #       question_id: 23,
  #       trait_value_id: 505,
  #       display_order: 135,
  #       text: "City University of New York, Hunter College"
  #     },
  #     %{
  #       id: 355,
  #       question_id: 23,
  #       trait_value_id: 506,
  #       display_order: 140,
  #       text: "Clemson University"
  #     },
  #     %{
  #       id: 356,
  #       question_id: 23,
  #       trait_value_id: 507,
  #       display_order: 143,
  #       text: "Coastal Carolina University"
  #     },
  #     %{
  #       id: 357,
  #       question_id: 23,
  #       trait_value_id: 508,
  #       display_order: 144,
  #       text: "Coastline Community College"
  #     },
  #     %{
  #       id: 358,
  #       question_id: 23,
  #       trait_value_id: 509,
  #       display_order: 145,
  #       text: "College of Alameda"
  #     },
  #     %{
  #       id: 359,
  #       question_id: 23,
  #       trait_value_id: 510,
  #       display_order: 146,
  #       text: "College of Charleston"
  #     },
  #     %{
  #       id: 360,
  #       question_id: 23,
  #       trait_value_id: 511,
  #       display_order: 149,
  #       text: "College of Southern Idaho"
  #     },
  #     %{
  #       id: 361,
  #       question_id: 23,
  #       trait_value_id: 512,
  #       display_order: 151,
  #       text: "College of the Desert"
  #     },
  #     %{
  #       id: 362,
  #       question_id: 23,
  #       trait_value_id: 513,
  #       display_order: 152,
  #       text: "College of the Mainland"
  #     },
  #     %{
  #       id: 363,
  #       question_id: 23,
  #       trait_value_id: 514,
  #       display_order: 153,
  #       text: "College of the San Mateo"
  #     },
  #     %{
  #       id: 364,
  #       question_id: 23,
  #       trait_value_id: 515,
  #       display_order: 154,
  #       text: "College of the Sequoias"
  #     },
  #     %{
  #       id: 365,
  #       question_id: 23,
  #       trait_value_id: 516,
  #       display_order: 155,
  #       text: "Collin County Community College"
  #     },
  #     %{
  #       id: 366,
  #       question_id: 23,
  #       trait_value_id: 517,
  #       display_order: 157,
  #       text: "Colorado State University"
  #     },
  #     %{
  #       id: 367,
  #       question_id: 23,
  #       trait_value_id: 518,
  #       display_order: 160,
  #       text: "Columbus State Community College"
  #     },
  #     %{
  #       id: 368,
  #       question_id: 23,
  #       trait_value_id: 519,
  #       display_order: 163,
  #       text: "Community College of Denver"
  #     },
  #     %{
  #       id: 369,
  #       question_id: 23,
  #       trait_value_id: 520,
  #       display_order: 164,
  #       text: "Contra Costa College"
  #     },
  #     %{
  #       id: 370,
  #       question_id: 23,
  #       trait_value_id: 521,
  #       display_order: 167,
  #       text: "Cornell University, Ithaca"
  #     },
  #     %{
  #       id: 371,
  #       question_id: 23,
  #       trait_value_id: 522,
  #       display_order: 169,
  #       text: "Cosumnes River College"
  #     },
  #     %{
  #       id: 372,
  #       question_id: 23,
  #       trait_value_id: 523,
  #       display_order: 175,
  #       text: "Cuyamaca College"
  #     },
  #     %{
  #       id: 373,
  #       question_id: 23,
  #       trait_value_id: 524,
  #       display_order: 176,
  #       text: "Cypress College"
  #     },
  #     %{
  #       id: 374,
  #       question_id: 23,
  #       trait_value_id: 525,
  #       display_order: 179,
  #       text: "Dallas County Community College"
  #     },
  #     %{
  #       id: 375,
  #       question_id: 23,
  #       trait_value_id: 526,
  #       display_order: 182,
  #       text: "Dartmouth College"
  #     },
  #     %{
  #       id: 376,
  #       question_id: 23,
  #       trait_value_id: 527,
  #       display_order: 185,
  #       text: "Daytona Beach Community College"
  #     },
  #     %{
  #       id: 377,
  #       question_id: 23,
  #       trait_value_id: 528,
  #       display_order: 187,
  #       text: "DeAnza College"
  #     },
  #     %{
  #       id: 378,
  #       question_id: 23,
  #       trait_value_id: 529,
  #       display_order: 189,
  #       text: "Del Mar College"
  #     },
  #     %{
  #       id: 379,
  #       question_id: 23,
  #       trait_value_id: 530,
  #       display_order: 192,
  #       text: "Diablo Valley College"
  #     },
  #     %{
  #       id: 380,
  #       question_id: 23,
  #       trait_value_id: 531,
  #       display_order: 194,
  #       text: "Dickinson State University"
  #     },
  #     %{
  #       id: 381,
  #       question_id: 23,
  #       trait_value_id: 532,
  #       display_order: 198,
  #       text: "Duke University"
  #     },
  #     %{
  #       id: 382,
  #       question_id: 23,
  #       trait_value_id: 533,
  #       display_order: 201,
  #       text: "East Carolina University"
  #     },
  #     %{
  #       id: 383,
  #       question_id: 23,
  #       trait_value_id: 534,
  #       display_order: 207,
  #       text: "Eastern Kentucky University"
  #     },
  #     %{
  #       id: 384,
  #       question_id: 23,
  #       trait_value_id: 535,
  #       display_order: 208,
  #       text: "Eastern Michigan University"
  #     },
  #     %{
  #       id: 385,
  #       question_id: 23,
  #       trait_value_id: 536,
  #       display_order: 210,
  #       text: "Eastern Washington University"
  #     },
  #     %{
  #       id: 386,
  #       question_id: 23,
  #       trait_value_id: 537,
  #       display_order: 204,
  #       text: "East Los Angeles College"
  #     },
  #     %{
  #       id: 387,
  #       question_id: 23,
  #       trait_value_id: 538,
  #       display_order: 212,
  #       text: "Edison College"
  #     },
  #     %{
  #       id: 388,
  #       question_id: 23,
  #       trait_value_id: 539,
  #       display_order: 216,
  #       text: "El Paso Community College"
  #     },
  #     %{
  #       id: 389,
  #       question_id: 23,
  #       trait_value_id: 540,
  #       display_order: 226,
  #       text: "Evergreen Valley College"
  #     },
  #     %{
  #       id: 390,
  #       question_id: 23,
  #       trait_value_id: 541,
  #       display_order: 227,
  #       text: "Fairmont State University"
  #     },
  #     %{
  #       id: 391,
  #       question_id: 23,
  #       trait_value_id: 542,
  #       display_order: 230,
  #       text: "Ferris State University"
  #     },
  #     %{
  #       id: 392,
  #       question_id: 23,
  #       trait_value_id: 543,
  #       display_order: 233,
  #       text: "Florida A&M University"
  #     },
  #     %{
  #       id: 393,
  #       question_id: 23,
  #       trait_value_id: 544,
  #       display_order: 234,
  #       text: "Florida Atlantic University"
  #     },
  #     %{
  #       id: 394,
  #       question_id: 23,
  #       trait_value_id: 545,
  #       display_order: 240,
  #       text: "Florida Community College, Jacksonville"
  #     },
  #     %{
  #       id: 395,
  #       question_id: 23,
  #       trait_value_id: 546,
  #       display_order: 245,
  #       text: "Florida International University"
  #     },
  #     %{
  #       id: 396,
  #       question_id: 23,
  #       trait_value_id: 547,
  #       display_order: 249,
  #       text: "Florida State University"
  #     },
  #     %{
  #       id: 397,
  #       question_id: 23,
  #       trait_value_id: 548,
  #       display_order: 252,
  #       text: "Folsom Lake College"
  #     },
  #     %{
  #       id: 398,
  #       question_id: 23,
  #       trait_value_id: 549,
  #       display_order: 253,
  #       text: "Foothill College"
  #     },
  #     %{
  #       id: 399,
  #       question_id: 23,
  #       trait_value_id: 550,
  #       display_order: 255,
  #       text: "Fort Hays State University"
  #     },
  #     %{
  #       id: 400,
  #       question_id: 23,
  #       trait_value_id: 551,
  #       display_order: 262,
  #       text: "Fresno City College"
  #     },
  #     %{
  #       id: 401,
  #       question_id: 23,
  #       trait_value_id: 552,
  #       display_order: 263,
  #       text: "Frostburg State University"
  #     },
  #     %{
  #       id: 402,
  #       question_id: 23,
  #       trait_value_id: 553,
  #       display_order: 264,
  #       text: "Fullerton College"
  #     },
  #     %{
  #       id: 403,
  #       question_id: 23,
  #       trait_value_id: 554,
  #       display_order: 269,
  #       text: "George Mason University"
  #     },
  #     %{
  #       id: 404,
  #       question_id: 23,
  #       trait_value_id: 555,
  #       display_order: 271,
  #       text: "Georgia College and State University"
  #     },
  #     %{
  #       id: 405,
  #       question_id: 23,
  #       trait_value_id: 556,
  #       display_order: 274,
  #       text: "Georgia Institute of Technology"
  #     },
  #     %{
  #       id: 406,
  #       question_id: 23,
  #       trait_value_id: 557,
  #       display_order: 276,
  #       text: "Georgia Perimeter College"
  #     },
  #     %{
  #       id: 407,
  #       question_id: 23,
  #       trait_value_id: 558,
  #       display_order: 277,
  #       text: "Georgia Southern University"
  #     },
  #     %{
  #       id: 408,
  #       question_id: 23,
  #       trait_value_id: 559,
  #       display_order: 279,
  #       text: "Georgia State University"
  #     },
  #     %{
  #       id: 409,
  #       question_id: 23,
  #       trait_value_id: 560,
  #       display_order: 280,
  #       text: "Glendale Community College"
  #     },
  #     %{
  #       id: 410,
  #       question_id: 23,
  #       trait_value_id: 561,
  #       display_order: 282,
  #       text: "Grand Rapids Community College"
  #     },
  #     %{
  #       id: 411,
  #       question_id: 23,
  #       trait_value_id: 562,
  #       display_order: 283,
  #       text: "Grand Valley State University"
  #     },
  #     %{
  #       id: 412,
  #       question_id: 23,
  #       trait_value_id: 563,
  #       display_order: 285,
  #       text: "Grayson County College"
  #     },
  #     %{
  #       id: 413,
  #       question_id: 23,
  #       trait_value_id: 564,
  #       display_order: 287,
  #       text: "Greenville Technical College"
  #     },
  #     %{
  #       id: 414,
  #       question_id: 23,
  #       trait_value_id: 565,
  #       display_order: 289,
  #       text: "Grossmont College"
  #     },
  #     %{
  #       id: 415,
  #       question_id: 23,
  #       trait_value_id: 566,
  #       display_order: 295,
  #       text: "Harold Washington College - CCC"
  #     },
  #     %{
  #       id: 416,
  #       question_id: 23,
  #       trait_value_id: 567,
  #       display_order: 296,
  #       text: "Harry S. Truman College - CCC"
  #     },
  #     %{
  #       id: 417,
  #       question_id: 23,
  #       trait_value_id: 568,
  #       display_order: 303,
  #       text: "Hillsborough Community College"
  #     },
  #     %{
  #       id: 418,
  #       question_id: 23,
  #       trait_value_id: 569,
  #       display_order: 312,
  #       text: "Houston Community College"
  #     },
  #     %{
  #       id: 419,
  #       question_id: 23,
  #       trait_value_id: 570,
  #       display_order: 313,
  #       text: "Humboldt State University"
  #     },
  #     %{
  #       id: 420,
  #       question_id: 23,
  #       trait_value_id: 571,
  #       display_order: 315,
  #       text: "Idaho State University"
  #     },
  #     %{
  #       id: 421,
  #       question_id: 23,
  #       trait_value_id: 572,
  #       display_order: 316,
  #       text: "Illinois State University"
  #     },
  #     %{
  #       id: 422,
  #       question_id: 23,
  #       trait_value_id: 573,
  #       display_order: 318,
  #       text: "Imperial Valley College"
  #     },
  #     %{
  #       id: 423,
  #       question_id: 23,
  #       trait_value_id: 574,
  #       display_order: 320,
  #       text: "Indiana University Bloomington"
  #     },
  #     %{
  #       id: 424,
  #       question_id: 23,
  #       trait_value_id: 575,
  #       display_order: 321,
  #       text: "Indiana University Purdue University, Fort Wayne"
  #     },
  #     %{
  #       id: 425,
  #       question_id: 23,
  #       trait_value_id: 576,
  #       display_order: 322,
  #       text: "Indiana University Purdue University, Indianapolis"
  #     },
  #     %{
  #       id: 426,
  #       question_id: 23,
  #       trait_value_id: 577,
  #       display_order: 327,
  #       text: "Iowa State University"
  #     },
  #     %{
  #       id: 427,
  #       question_id: 23,
  #       trait_value_id: 578,
  #       display_order: 328,
  #       text: "Irvine Valley College"
  #     },
  #     %{
  #       id: 428,
  #       question_id: 23,
  #       trait_value_id: 579,
  #       display_order: 332,
  #       text: "Jackson State University"
  #     },
  #     %{
  #       id: 429,
  #       question_id: 23,
  #       trait_value_id: 580,
  #       display_order: 334,
  #       text: "James Madison University"
  #     },
  #     %{
  #       id: 430,
  #       question_id: 23,
  #       trait_value_id: 581,
  #       display_order: 337,
  #       text: "Jefferson Community and Technical College"
  #     },
  #     %{
  #       id: 431,
  #       question_id: 23,
  #       trait_value_id: 582,
  #       display_order: 343,
  #       text: "John Jay College of Criminal Justice"
  #     },
  #     %{
  #       id: 432,
  #       question_id: 23,
  #       trait_value_id: 583,
  #       display_order: 349,
  #       text: "Kansas State University"
  #     },
  #     %{
  #       id: 433,
  #       question_id: 23,
  #       trait_value_id: 584,
  #       display_order: 350,
  #       text: "Keene State College"
  #     },
  #     %{
  #       id: 434,
  #       question_id: 23,
  #       trait_value_id: 585,
  #       display_order: 353,
  #       text: "Kennedy-King College"
  #     },
  #     %{
  #       id: 435,
  #       question_id: 23,
  #       trait_value_id: 586,
  #       display_order: 354,
  #       text: "Kennesaw State University"
  #     },
  #     %{
  #       id: 436,
  #       question_id: 23,
  #       trait_value_id: 587,
  #       display_order: 355,
  #       text: "Kent State University"
  #     },
  #     %{
  #       id: 437,
  #       question_id: 23,
  #       trait_value_id: 588,
  #       display_order: 362,
  #       text: "Kirkwood Community College"
  #     },
  #     %{
  #       id: 438,
  #       question_id: 23,
  #       trait_value_id: 589,
  #       display_order: 368,
  #       text: "Lamar University"
  #     },
  #     %{
  #       id: 439,
  #       question_id: 23,
  #       trait_value_id: 590,
  #       display_order: 372,
  #       text: "Lane Community College"
  #     },
  #     %{
  #       id: 440,
  #       question_id: 23,
  #       trait_value_id: 591,
  #       display_order: 373,
  #       text: "Laney College"
  #     },
  #     %{
  #       id: 441,
  #       question_id: 23,
  #       trait_value_id: 592,
  #       display_order: 375,
  #       text: "Lansing Community College"
  #     },
  #     %{
  #       id: 442,
  #       question_id: 23,
  #       trait_value_id: 593,
  #       display_order: 376,
  #       text: "Las Positas College"
  #     },
  #     %{
  #       id: 443,
  #       question_id: 23,
  #       trait_value_id: 594,
  #       display_order: 379,
  #       text: "Lehigh University"
  #     },
  #     %{
  #       id: 444,
  #       question_id: 23,
  #       trait_value_id: 595,
  #       display_order: 388,
  #       text: "Los Angeles City College"
  #     },
  #     %{
  #       id: 445,
  #       question_id: 23,
  #       trait_value_id: 596,
  #       display_order: 389,
  #       text: "Los Angeles Harbor College"
  #     },
  #     %{
  #       id: 446,
  #       question_id: 23,
  #       trait_value_id: 597,
  #       display_order: 390,
  #       text: "Los Angeles Pierce College"
  #     },
  #     %{
  #       id: 447,
  #       question_id: 23,
  #       trait_value_id: 598,
  #       display_order: 391,
  #       text: "Los Angeles Southwest College"
  #     },
  #     %{
  #       id: 448,
  #       question_id: 23,
  #       trait_value_id: 599,
  #       display_order: 392,
  #       text: "Los Angeles Trade-Tech College"
  #     },
  #     %{
  #       id: 449,
  #       question_id: 23,
  #       trait_value_id: 600,
  #       display_order: 393,
  #       text: "Los Angeles Valley College"
  #     },
  #     %{
  #       id: 450,
  #       question_id: 23,
  #       trait_value_id: 601,
  #       display_order: 394,
  #       text: "Los Medanos College"
  #     },
  #     %{
  #       id: 451,
  #       question_id: 23,
  #       trait_value_id: 602,
  #       display_order: 395,
  #       text: "Louisiana State University"
  #     },
  #     %{
  #       id: 452,
  #       question_id: 23,
  #       trait_value_id: 603,
  #       display_order: 403,
  #       text: "Macomb Community College"
  #     },
  #     %{
  #       id: 453,
  #       question_id: 23,
  #       trait_value_id: 604,
  #       display_order: 407,
  #       text: "Malcolm X College - CCC"
  #     },
  #     %{
  #       id: 454,
  #       question_id: 23,
  #       trait_value_id: 605,
  #       display_order: 410,
  #       text: "Marquette University"
  #     },
  #     %{
  #       id: 455,
  #       question_id: 23,
  #       trait_value_id: 606,
  #       display_order: 411,
  #       text: "Marshall University"
  #     },
  #     %{
  #       id: 456,
  #       question_id: 23,
  #       trait_value_id: 607,
  #       display_order: 417,
  #       text: "McLennan Community College"
  #     },
  #     %{
  #       id: 457,
  #       question_id: 23,
  #       trait_value_id: 608,
  #       display_order: 425,
  #       text: "Merritt College"
  #     },
  #     %{
  #       id: 458,
  #       question_id: 23,
  #       trait_value_id: 609,
  #       display_order: 426,
  #       text: "Metropolitan State College of Denver"
  #     },
  #     %{
  #       id: 459,
  #       question_id: 23,
  #       trait_value_id: 610,
  #       display_order: 427,
  #       text: "Miami Dade College"
  #     },
  #     %{
  #       id: 460,
  #       question_id: 23,
  #       trait_value_id: 611,
  #       display_order: 429,
  #       text: "Miami University"
  #     },
  #     %{
  #       id: 461,
  #       question_id: 23,
  #       trait_value_id: 612,
  #       display_order: 430,
  #       text: "Michigan State University"
  #     },
  #     %{
  #       id: 462,
  #       question_id: 23,
  #       trait_value_id: 613,
  #       display_order: 431,
  #       text: "Michigan Technological University"
  #     },
  #     %{
  #       id: 463,
  #       question_id: 23,
  #       trait_value_id: 614,
  #       display_order: 438,
  #       text: "Middlesex County College"
  #     },
  #     %{
  #       id: 464,
  #       question_id: 23,
  #       trait_value_id: 615,
  #       display_order: 436,
  #       text: "Middle Tennessee State University"
  #     },
  #     %{
  #       id: 465,
  #       question_id: 23,
  #       trait_value_id: 616,
  #       display_order: 440,
  #       text: "Midwestern State University"
  #     },
  #     %{
  #       id: 466,
  #       question_id: 23,
  #       trait_value_id: 617,
  #       display_order: 445,
  #       text: "Minnesota State University, Mankato"
  #     },
  #     %{
  #       id: 467,
  #       question_id: 23,
  #       trait_value_id: 618,
  #       display_order: 446,
  #       text: "Minot State University"
  #     },
  #     %{
  #       id: 468,
  #       question_id: 23,
  #       trait_value_id: 619,
  #       display_order: 449,
  #       text: "Mississippi Gulf Coast Community College"
  #     },
  #     %{
  #       id: 469,
  #       question_id: 23,
  #       trait_value_id: 620,
  #       display_order: 453,
  #       text: "Missouri State University"
  #     },
  #     %{
  #       id: 470,
  #       question_id: 23,
  #       trait_value_id: 621,
  #       display_order: 454,
  #       text: "Missouri University of Science and Technology"
  #     },
  #     %{
  #       id: 471,
  #       question_id: 23,
  #       trait_value_id: 622,
  #       display_order: 455,
  #       text: "Montana State University, Bozeman"
  #     },
  #     %{
  #       id: 472,
  #       question_id: 23,
  #       trait_value_id: 623,
  #       display_order: 456,
  #       text: "Moorpark College"
  #     },
  #     %{
  #       id: 473,
  #       question_id: 23,
  #       trait_value_id: 624,
  #       display_order: 462,
  #       text: "Mt. San Antonio College"
  #     },
  #     %{
  #       id: 474,
  #       question_id: 23,
  #       trait_value_id: 625,
  #       display_order: 467,
  #       text: "Navarro College"
  #     },
  #     %{
  #       id: 475,
  #       question_id: 23,
  #       trait_value_id: 626,
  #       display_order: 469,
  #       text: "New Mexico Junior College"
  #     },
  #     %{
  #       id: 476,
  #       question_id: 23,
  #       trait_value_id: 627,
  #       display_order: 471,
  #       text: "New York City College of Technology (CUNY)"
  #     },
  #     %{
  #       id: 477,
  #       question_id: 23,
  #       trait_value_id: 628,
  #       display_order: 472,
  #       text: "New York University"
  #     },
  #     %{
  #       id: 478,
  #       question_id: 23,
  #       trait_value_id: 629,
  #       display_order: 474,
  #       text: "North Carolina State University, Raleigh"
  #     },
  #     %{
  #       id: 479,
  #       question_id: 23,
  #       trait_value_id: 630,
  #       display_order: 475,
  #       text: "North Dakota State University"
  #     },
  #     %{
  #       id: 480,
  #       question_id: 23,
  #       trait_value_id: 631,
  #       display_order: 484,
  #       text: "Northeast Lakeview College"
  #     },
  #     %{
  #       id: 481,
  #       question_id: 23,
  #       trait_value_id: 632,
  #       display_order: 488,
  #       text: "Northern Arizona University"
  #     },
  #     %{
  #       id: 482,
  #       question_id: 23,
  #       trait_value_id: 633,
  #       display_order: 489,
  #       text: "Northern Illinois University"
  #     },
  #     %{
  #       id: 483,
  #       question_id: 23,
  #       trait_value_id: 634,
  #       display_order: 491,
  #       text: "Northern Michigan University"
  #     },
  #     %{
  #       id: 484,
  #       question_id: 23,
  #       trait_value_id: 635,
  #       display_order: 477,
  #       text: "North Georgia College & State University"
  #     },
  #     %{
  #       id: 485,
  #       question_id: 23,
  #       trait_value_id: 636,
  #       display_order: 479,
  #       text: "North Harris Montgomery Community College"
  #     },
  #     %{
  #       id: 486,
  #       question_id: 23,
  #       trait_value_id: 637,
  #       display_order: 480,
  #       text: "North Idaho College"
  #     },
  #     %{
  #       id: 487,
  #       question_id: 23,
  #       trait_value_id: 638,
  #       display_order: 499,
  #       text: "Northwestern State University"
  #     },
  #     %{
  #       id: 488,
  #       question_id: 23,
  #       trait_value_id: 639,
  #       display_order: 496,
  #       text: "Northwest Missouri State University"
  #     },
  #     %{
  #       id: 489,
  #       question_id: 23,
  #       trait_value_id: 640,
  #       display_order: 497,
  #       text: "Northwest Vista College"
  #     },
  #     %{
  #       id: 490,
  #       question_id: 23,
  #       trait_value_id: 641,
  #       display_order: 506,
  #       text: "Oakland Community College"
  #     },
  #     %{
  #       id: 491,
  #       question_id: 23,
  #       trait_value_id: 642,
  #       display_order: 507,
  #       text: "Oakland University"
  #     },
  #     %{
  #       id: 492,
  #       question_id: 23,
  #       trait_value_id: 643,
  #       display_order: 512,
  #       text: "Ohio State University, Columbus"
  #     },
  #     %{
  #       id: 493,
  #       question_id: 23,
  #       trait_value_id: 644,
  #       display_order: 513,
  #       text: "Ohio University, Athens"
  #     },
  #     %{
  #       id: 494,
  #       question_id: 23,
  #       trait_value_id: 645,
  #       display_order: 514,
  #       text: "Ohlone College"
  #     },
  #     %{
  #       id: 495,
  #       question_id: 23,
  #       trait_value_id: 646,
  #       display_order: 515,
  #       text: "Oklahoma City Community College"
  #     },
  #     %{
  #       id: 496,
  #       question_id: 23,
  #       trait_value_id: 647,
  #       display_order: 516,
  #       text: "Oklahoma State University"
  #     },
  #     %{
  #       id: 497,
  #       question_id: 23,
  #       trait_value_id: 648,
  #       display_order: 517,
  #       text: "Old Dominion University"
  #     },
  #     %{
  #       id: 498,
  #       question_id: 23,
  #       trait_value_id: 649,
  #       display_order: 518,
  #       text: "Olive-Harvey College - CCC"
  #     },
  #     %{
  #       id: 499,
  #       question_id: 23,
  #       trait_value_id: 650,
  #       display_order: 519,
  #       text: "Orange Coast College"
  #     },
  #     %{
  #       id: 500,
  #       question_id: 23,
  #       trait_value_id: 651,
  #       display_order: 520,
  #       text: "Oregon State University"
  #     },
  #     %{
  #       id: 501,
  #       question_id: 23,
  #       trait_value_id: 652,
  #       display_order: 525,
  #       text: "Owens Community College"
  #     },
  #     %{
  #       id: 502,
  #       question_id: 23,
  #       trait_value_id: 653,
  #       display_order: 527,
  #       text: "Oxnard College"
  #     },
  #     %{
  #       id: 503,
  #       question_id: 23,
  #       trait_value_id: 654,
  #       display_order: 529,
  #       text: "Pace University"
  #     },
  #     %{
  #       id: 504,
  #       question_id: 23,
  #       trait_value_id: 655,
  #       display_order: 534,
  #       text: "Palo Alto College"
  #     },
  #     %{
  #       id: 505,
  #       question_id: 23,
  #       trait_value_id: 656,
  #       display_order: 536,
  #       text: "Palomar College"
  #     },
  #     %{
  #       id: 506,
  #       question_id: 23,
  #       trait_value_id: 657,
  #       display_order: 535,
  #       text: "Palo Verde College"
  #     },
  #     %{
  #       id: 507,
  #       question_id: 23,
  #       trait_value_id: 658,
  #       display_order: 537,
  #       text: "Pasadena City College"
  #     },
  #     %{
  #       id: 508,
  #       question_id: 23,
  #       trait_value_id: 659,
  #       display_order: 538,
  #       text: "Pasco-Hernando Community College"
  #     },
  #     %{
  #       id: 509,
  #       question_id: 23,
  #       trait_value_id: 660,
  #       display_order: 543,
  #       text: "Pennsylvania State University"
  #     },
  #     %{
  #       id: 510,
  #       question_id: 23,
  #       trait_value_id: 661,
  #       display_order: 551,
  #       text: "Pima Community College"
  #     },
  #     %{
  #       id: 511,
  #       question_id: 23,
  #       trait_value_id: 662,
  #       display_order: 553,
  #       text: "Portland Community College"
  #     },
  #     %{
  #       id: 512,
  #       question_id: 23,
  #       trait_value_id: 663,
  #       display_order: 554,
  #       text: "Portland State University"
  #     },
  #     %{
  #       id: 513,
  #       question_id: 23,
  #       trait_value_id: 664,
  #       display_order: 555,
  #       text: "Prairie View A&M University"
  #     },
  #     %{
  #       id: 514,
  #       question_id: 23,
  #       trait_value_id: 665,
  #       display_order: 558,
  #       text: "Purdue University"
  #     },
  #     %{
  #       id: 515,
  #       question_id: 23,
  #       trait_value_id: 666,
  #       display_order: 559,
  #       text: "Purdue University Calumet"
  #     },
  #     %{
  #       id: 516,
  #       question_id: 23,
  #       trait_value_id: 667,
  #       display_order: 560,
  #       text: "Queens College"
  #     },
  #     %{
  #       id: 517,
  #       question_id: 23,
  #       trait_value_id: 668,
  #       display_order: 564,
  #       text: "Rensselaer Polytechnic Institute"
  #     },
  #     %{
  #       id: 518,
  #       question_id: 23,
  #       trait_value_id: 669,
  #       display_order: 568,
  #       text: "Richard J. Daley College - CCC"
  #     },
  #     %{
  #       id: 519,
  #       question_id: 23,
  #       trait_value_id: 670,
  #       display_order: 570,
  #       text: "Rider University"
  #     },
  #     %{
  #       id: 520,
  #       question_id: 23,
  #       trait_value_id: 671,
  #       display_order: 572,
  #       text: "Rio Hondo College"
  #     },
  #     %{
  #       id: 521,
  #       question_id: 23,
  #       trait_value_id: 672,
  #       display_order: 576,
  #       text: "Rutgers, New Brunswick"
  #     },
  #     %{
  #       id: 522,
  #       question_id: 23,
  #       trait_value_id: 673,
  #       display_order: 578,
  #       text: "Saddleback College"
  #     },
  #     %{
  #       id: 523,
  #       question_id: 23,
  #       trait_value_id: 674,
  #       display_order: 579,
  #       text: "Saginaw Valley State University"
  #     },
  #     %{
  #       id: 524,
  #       question_id: 23,
  #       trait_value_id: 675,
  #       display_order: 581,
  #       text: "Saint Charles Community College"
  #     },
  #     %{
  #       id: 525,
  #       question_id: 23,
  #       trait_value_id: 676,
  #       display_order: 582,
  #       text: "Saint Cloud State University"
  #     },
  #     %{
  #       id: 526,
  #       question_id: 23,
  #       trait_value_id: 677,
  #       display_order: 586,
  #       text: "Saint Louis Community College"
  #     },
  #     %{
  #       id: 527,
  #       question_id: 23,
  #       trait_value_id: 678,
  #       display_order: 587,
  #       text: "Saint Louis University"
  #     },
  #     %{
  #       id: 528,
  #       question_id: 23,
  #       trait_value_id: 679,
  #       display_order: 592,
  #       text: "Salisbury University"
  #     },
  #     %{
  #       id: 529,
  #       question_id: 23,
  #       trait_value_id: 680,
  #       display_order: 593,
  #       text: "Salt Lake Community College"
  #     },
  #     %{
  #       id: 530,
  #       question_id: 23,
  #       trait_value_id: 681,
  #       display_order: 594,
  #       text: "Sam Houston State University"
  #     },
  #     %{
  #       id: 531,
  #       question_id: 23,
  #       trait_value_id: 682,
  #       display_order: 596,
  #       text: "San Antonio College"
  #     },
  #     %{
  #       id: 532,
  #       question_id: 23,
  #       trait_value_id: 683,
  #       display_order: 597,
  #       text: "San Bernardino Valley College"
  #     },
  #     %{
  #       id: 533,
  #       question_id: 23,
  #       trait_value_id: 684,
  #       display_order: 598,
  #       text: "San Diego State University"
  #     },
  #     %{
  #       id: 534,
  #       question_id: 23,
  #       trait_value_id: 685,
  #       display_order: 599,
  #       text: "San Francisco State University"
  #     },
  #     %{
  #       id: 535,
  #       question_id: 23,
  #       trait_value_id: 686,
  #       display_order: 600,
  #       text: "San Jacinto College"
  #     },
  #     %{
  #       id: 536,
  #       question_id: 23,
  #       trait_value_id: 687,
  #       display_order: 601,
  #       text: "San Jose City College"
  #     },
  #     %{
  #       id: 537,
  #       question_id: 23,
  #       trait_value_id: 688,
  #       display_order: 602,
  #       text: "San Jose State University"
  #     },
  #     %{
  #       id: 538,
  #       question_id: 23,
  #       trait_value_id: 689,
  #       display_order: 603,
  #       text: "Santa Ana College"
  #     },
  #     %{
  #       id: 539,
  #       question_id: 23,
  #       trait_value_id: 690,
  #       display_order: 604,
  #       text: "Santa Barbara City College"
  #     },
  #     %{
  #       id: 540,
  #       question_id: 23,
  #       trait_value_id: 691,
  #       display_order: 606,
  #       text: "Santa Monica College"
  #     },
  #     %{
  #       id: 541,
  #       question_id: 23,
  #       trait_value_id: 692,
  #       display_order: 607,
  #       text: "Santa Rosa Junior College"
  #     },
  #     %{
  #       id: 542,
  #       question_id: 23,
  #       trait_value_id: 693,
  #       display_order: 614,
  #       text: "Shasta College"
  #     },
  #     %{
  #       id: 543,
  #       question_id: 23,
  #       trait_value_id: 694,
  #       display_order: 617,
  #       text: "Sierra College"
  #     },
  #     %{
  #       id: 544,
  #       question_id: 23,
  #       trait_value_id: 695,
  #       display_order: 619,
  #       text: "Skyline College"
  #     },
  #     %{
  #       id: 545,
  #       question_id: 23,
  #       trait_value_id: 696,
  #       display_order: 621,
  #       text: "SMU - Cox School of Business"
  #     },
  #     %{
  #       id: 546,
  #       question_id: 23,
  #       trait_value_id: 697,
  #       display_order: 623,
  #       text: "Solano Community College"
  #     },
  #     %{
  #       id: 547,
  #       question_id: 23,
  #       trait_value_id: 698,
  #       display_order: 625,
  #       text: "Sonoma State University"
  #     },
  #     %{
  #       id: 548,
  #       question_id: 23,
  #       trait_value_id: 699,
  #       display_order: 637,
  #       text: "Southeastern Louisiana University"
  #     },
  #     %{
  #       id: 549,
  #       question_id: 23,
  #       trait_value_id: 700,
  #       display_order: 644,
  #       text: "Southern Connecticut State University"
  #     },
  #     %{
  #       id: 550,
  #       question_id: 23,
  #       trait_value_id: 701,
  #       display_order: 645,
  #       text: "Southern Illinois University, Carbondale"
  #     },
  #     %{
  #       id: 551,
  #       question_id: 23,
  #       trait_value_id: 702,
  #       display_order: 646,
  #       text: "Southern Illinois University, Edwardsville"
  #     },
  #     %{
  #       id: 552,
  #       question_id: 23,
  #       trait_value_id: 703,
  #       display_order: 647,
  #       text: "Southern Methodist University"
  #     },
  #     %{
  #       id: 553,
  #       question_id: 23,
  #       trait_value_id: 704,
  #       display_order: 648,
  #       text: "Southern Oregon University"
  #     },
  #     %{
  #       id: 554,
  #       question_id: 23,
  #       trait_value_id: 705,
  #       display_order: 652,
  #       text: "Southern Utah University"
  #     },
  #     %{
  #       id: 555,
  #       question_id: 23,
  #       trait_value_id: 706,
  #       display_order: 632,
  #       text: "South Plains College"
  #     },
  #     %{
  #       id: 556,
  #       question_id: 23,
  #       trait_value_id: 707,
  #       display_order: 660,
  #       text: "Southwestern University"
  #     },
  #     %{
  #       id: 557,
  #       question_id: 23,
  #       trait_value_id: 708,
  #       display_order: 657,
  #       text: "Southwest Texas Junior College"
  #     },
  #     %{
  #       id: 558,
  #       question_id: 23,
  #       trait_value_id: 709,
  #       display_order: 664,
  #       text: "Spokane Falls Community College"
  #     },
  #     %{
  #       id: 559,
  #       question_id: 23,
  #       trait_value_id: 710,
  #       display_order: 669,
  #       text: "State University of New York, Stony Brook"
  #     },
  #     %{
  #       id: 560,
  #       question_id: 23,
  #       trait_value_id: 711,
  #       display_order: 666,
  #       text: "St. Edwards University"
  #     },
  #     %{
  #       id: 561,
  #       question_id: 23,
  #       trait_value_id: 712,
  #       display_order: 671,
  #       text: "Stephen F. Austin State University"
  #     },
  #     %{
  #       id: 562,
  #       question_id: 23,
  #       trait_value_id: 713,
  #       display_order: 667,
  #       text: "St. Petersburg College"
  #     },
  #     %{
  #       id: 563,
  #       question_id: 23,
  #       trait_value_id: 714,
  #       display_order: 668,
  #       text: "St. Philips College"
  #     },
  #     %{
  #       id: 564,
  #       question_id: 23,
  #       trait_value_id: 715,
  #       display_order: 675,
  #       text: "Syracuse University; Syracuse"
  #     },
  #     %{
  #       id: 565,
  #       question_id: 23,
  #       trait_value_id: 716,
  #       display_order: 677,
  #       text: "Tallahassee Community College"
  #     },
  #     %{
  #       id: 566,
  #       question_id: 23,
  #       trait_value_id: 717,
  #       display_order: 679,
  #       text: "Tarleton State University"
  #     },
  #     %{
  #       id: 567,
  #       question_id: 23,
  #       trait_value_id: 718,
  #       display_order: 680,
  #       text: "Tarrant County College"
  #     },
  #     %{
  #       id: 568,
  #       question_id: 23,
  #       trait_value_id: 719,
  #       display_order: 682,
  #       text: "Temple University"
  #     },
  #     %{
  #       id: 569,
  #       question_id: 23,
  #       trait_value_id: 720,
  #       display_order: 688,
  #       text: "Texas A&M University - Commerce"
  #     },
  #     %{
  #       id: 570,
  #       question_id: 23,
  #       trait_value_id: 721,
  #       display_order: 687,
  #       text: "Texas A&M University"
  #     },
  #     %{
  #       id: 571,
  #       question_id: 23,
  #       trait_value_id: 722,
  #       display_order: 689,
  #       text: "Texas A&M University, Corpus Christi"
  #     },
  #     %{
  #       id: 572,
  #       question_id: 23,
  #       trait_value_id: 723,
  #       display_order: 690,
  #       text: "Texas A&M University, Kingsville"
  #     },
  #     %{
  #       id: 573,
  #       question_id: 23,
  #       trait_value_id: 724,
  #       display_order: 692,
  #       text: "Texas State University, San Marcos"
  #     },
  #     %{
  #       id: 574,
  #       question_id: 23,
  #       trait_value_id: 725,
  #       display_order: 693,
  #       text: "Texas Tech University"
  #     },
  #     %{
  #       id: 575,
  #       question_id: 23,
  #       trait_value_id: 726,
  #       display_order: 696,
  #       text: "The College of New Jersey"
  #     },
  #     %{
  #       id: 576,
  #       question_id: 23,
  #       trait_value_id: 727,
  #       display_order: 703,
  #       text: "Towson University"
  #     },
  #     %{
  #       id: 577,
  #       question_id: 23,
  #       trait_value_id: 728,
  #       display_order: 708,
  #       text: "Trinity Valley Community College"
  #     },
  #     %{
  #       id: 578,
  #       question_id: 23,
  #       trait_value_id: 729,
  #       display_order: 713,
  #       text: "Tulane University"
  #     },
  #     %{
  #       id: 579,
  #       question_id: 23,
  #       trait_value_id: 730,
  #       display_order: 714,
  #       text: "Tulsa Community College"
  #     },
  #     %{
  #       id: 580,
  #       question_id: 23,
  #       trait_value_id: 731,
  #       display_order: 717,
  #       text: "Tyler Junior College"
  #     },
  #     %{
  #       id: 581,
  #       question_id: 23,
  #       trait_value_id: 732,
  #       display_order: 720,
  #       text: "University of Akron"
  #     },
  #     %{
  #       id: 582,
  #       question_id: 23,
  #       trait_value_id: 733,
  #       display_order: 721,
  #       text: "University of Alabama"
  #     },
  #     %{
  #       id: 583,
  #       question_id: 23,
  #       trait_value_id: 734,
  #       display_order: 723,
  #       text: "University of Alaska, Anchorage"
  #     },
  #     %{
  #       id: 584,
  #       question_id: 23,
  #       trait_value_id: 735,
  #       display_order: 724,
  #       text: "University of Alaska, Fairbanks"
  #     },
  #     %{
  #       id: 585,
  #       question_id: 23,
  #       trait_value_id: 736,
  #       display_order: 725,
  #       text: "University of Alaska, Southeast"
  #     },
  #     %{
  #       id: 586,
  #       question_id: 23,
  #       trait_value_id: 737,
  #       display_order: 726,
  #       text: "University of Arizona"
  #     },
  #     %{
  #       id: 587,
  #       question_id: 23,
  #       trait_value_id: 738,
  #       display_order: 731,
  #       text: "University of Arkansas Main Campus"
  #     },
  #     %{
  #       id: 588,
  #       question_id: 23,
  #       trait_value_id: 739,
  #       display_order: 733,
  #       text: "University of California, Berkeley"
  #     },
  #     %{
  #       id: 589,
  #       question_id: 23,
  #       trait_value_id: 740,
  #       display_order: 734,
  #       text: "University of California, Davis"
  #     },
  #     %{
  #       id: 590,
  #       question_id: 23,
  #       trait_value_id: 741,
  #       display_order: 735,
  #       text: "University of California, Irvine"
  #     },
  #     %{
  #       id: 591,
  #       question_id: 23,
  #       trait_value_id: 742,
  #       display_order: 736,
  #       text: "University of California, Los Angeles"
  #     },
  #     %{
  #       id: 592,
  #       question_id: 23,
  #       trait_value_id: 743,
  #       display_order: 737,
  #       text: "University of California, Merced"
  #     },
  #     %{
  #       id: 593,
  #       question_id: 23,
  #       trait_value_id: 744,
  #       display_order: 738,
  #       text: "University of California, Riverside"
  #     },
  #     %{
  #       id: 594,
  #       question_id: 23,
  #       trait_value_id: 745,
  #       display_order: 739,
  #       text: "University of California, San Diego"
  #     },
  #     %{
  #       id: 595,
  #       question_id: 23,
  #       trait_value_id: 746,
  #       display_order: 740,
  #       text: "University of California, Santa Barbara"
  #     },
  #     %{
  #       id: 596,
  #       question_id: 23,
  #       trait_value_id: 747,
  #       display_order: 741,
  #       text: "University of California, Santa Cruz"
  #     },
  #     %{
  #       id: 597,
  #       question_id: 23,
  #       trait_value_id: 748,
  #       display_order: 743,
  #       text: "University of Central Florida"
  #     },
  #     %{
  #       id: 598,
  #       question_id: 23,
  #       trait_value_id: 749,
  #       display_order: 744,
  #       text: "University of Central Oklahoma"
  #     },
  #     %{
  #       id: 599,
  #       question_id: 23,
  #       trait_value_id: 750,
  #       display_order: 745,
  #       text: "University of Cincinnati"
  #     },
  #     %{
  #       id: 600,
  #       question_id: 23,
  #       trait_value_id: 751,
  #       display_order: 746,
  #       text: "University of Colorado, Boulder"
  #     },
  #     %{
  #       id: 601,
  #       question_id: 23,
  #       trait_value_id: 752,
  #       display_order: 747,
  #       text: "University of Colorado, Colorado Springs"
  #     },
  #     %{
  #       id: 602,
  #       question_id: 23,
  #       trait_value_id: 753,
  #       display_order: 748,
  #       text: "University of Colorado, Denver"
  #     },
  #     %{
  #       id: 603,
  #       question_id: 23,
  #       trait_value_id: 754,
  #       display_order: 749,
  #       text: "University of Connecticut"
  #     },
  #     %{
  #       id: 604,
  #       question_id: 23,
  #       trait_value_id: 755,
  #       display_order: 752,
  #       text: "University of Delaware"
  #     },
  #     %{
  #       id: 605,
  #       question_id: 23,
  #       trait_value_id: 756,
  #       display_order: 754,
  #       text: "University of Florida"
  #     },
  #     %{
  #       id: 606,
  #       question_id: 23,
  #       trait_value_id: 757,
  #       display_order: 755,
  #       text: "University of Georgia"
  #     },
  #     %{
  #       id: 607,
  #       question_id: 23,
  #       trait_value_id: 758,
  #       display_order: 756,
  #       text: "University of Hawaii - Hilo"
  #     },
  #     %{
  #       id: 608,
  #       question_id: 23,
  #       trait_value_id: 759,
  #       display_order: 757,
  #       text: "University of Hawaii, Manoa"
  #     },
  #     %{
  #       id: 609,
  #       question_id: 23,
  #       trait_value_id: 760,
  #       display_order: 758,
  #       text: "University of Houston"
  #     },
  #     %{
  #       id: 610,
  #       question_id: 23,
  #       trait_value_id: 761,
  #       display_order: 759,
  #       text: "University of Houston, Clear Lake"
  #     },
  #     %{
  #       id: 611,
  #       question_id: 23,
  #       trait_value_id: 762,
  #       display_order: 760,
  #       text: "University of Houston, Downtown"
  #     },
  #     %{
  #       id: 612,
  #       question_id: 23,
  #       trait_value_id: 763,
  #       display_order: 761,
  #       text: "University of Houston, Victoria"
  #     },
  #     %{
  #       id: 613,
  #       question_id: 23,
  #       trait_value_id: 764,
  #       display_order: 762,
  #       text: "University of Idaho"
  #     },
  #     %{
  #       id: 614,
  #       question_id: 23,
  #       trait_value_id: 765,
  #       display_order: 764,
  #       text: "University of Illinois, Chicago"
  #     },
  #     %{
  #       id: 615,
  #       question_id: 23,
  #       trait_value_id: 766,
  #       display_order: 763,
  #       text: "University of Illinois - Springfield"
  #     },
  #     %{
  #       id: 616,
  #       question_id: 23,
  #       trait_value_id: 767,
  #       display_order: 765,
  #       text: "University of Illinois, Urbana Champaign"
  #     },
  #     %{
  #       id: 617,
  #       question_id: 23,
  #       trait_value_id: 768,
  #       display_order: 766,
  #       text: "University of Iowa"
  #     },
  #     %{
  #       id: 618,
  #       question_id: 23,
  #       trait_value_id: 769,
  #       display_order: 767,
  #       text: "University of Kansas"
  #     },
  #     %{
  #       id: 619,
  #       question_id: 23,
  #       trait_value_id: 770,
  #       display_order: 768,
  #       text: "University of Kentucky"
  #     },
  #     %{
  #       id: 620,
  #       question_id: 23,
  #       trait_value_id: 771,
  #       display_order: 769,
  #       text: "University of Louisiana, Lafayette"
  #     },
  #     %{
  #       id: 621,
  #       question_id: 23,
  #       trait_value_id: 772,
  #       display_order: 770,
  #       text: "University of Louisiana, Monroe"
  #     },
  #     %{
  #       id: 622,
  #       question_id: 23,
  #       trait_value_id: 773,
  #       display_order: 771,
  #       text: "University of Louisville"
  #     },
  #     %{
  #       id: 623,
  #       question_id: 23,
  #       trait_value_id: 774,
  #       display_order: 772,
  #       text: "University of Maine"
  #     },
  #     %{
  #       id: 624,
  #       question_id: 23,
  #       trait_value_id: 775,
  #       display_order: 773,
  #       text: "University of Maryland - Baltimore County"
  #     },
  #     %{
  #       id: 625,
  #       question_id: 23,
  #       trait_value_id: 776,
  #       display_order: 774,
  #       text: "University of Maryland, College Park"
  #     },
  #     %{
  #       id: 626,
  #       question_id: 23,
  #       trait_value_id: 777,
  #       display_order: 775,
  #       text: "University of Massachusetts, Amherst"
  #     },
  #     %{
  #       id: 627,
  #       question_id: 23,
  #       trait_value_id: 778,
  #       display_order: 776,
  #       text: "University of Memphis"
  #     },
  #     %{
  #       id: 628,
  #       question_id: 23,
  #       trait_value_id: 779,
  #       display_order: 777,
  #       text: "University of Miami"
  #     },
  #     %{
  #       id: 629,
  #       question_id: 23,
  #       trait_value_id: 780,
  #       display_order: 778,
  #       text: "University of Michigan, Ann Arbor"
  #     },
  #     %{
  #       id: 630,
  #       question_id: 23,
  #       trait_value_id: 781,
  #       display_order: 779,
  #       text: "University of Michigan, Dearborn"
  #     },
  #     %{
  #       id: 631,
  #       question_id: 23,
  #       trait_value_id: 782,
  #       display_order: 780,
  #       text: "University of Minnesota, Twin Cities"
  #     },
  #     %{
  #       id: 632,
  #       question_id: 23,
  #       trait_value_id: 783,
  #       display_order: 781,
  #       text: "University of Mississippi"
  #     },
  #     %{
  #       id: 633,
  #       question_id: 23,
  #       trait_value_id: 784,
  #       display_order: 782,
  #       text: "University of Missouri, Columbia"
  #     },
  #     %{
  #       id: 634,
  #       question_id: 23,
  #       trait_value_id: 785,
  #       display_order: 783,
  #       text: "University of Missouri, Kansas City"
  #     },
  #     %{
  #       id: 635,
  #       question_id: 23,
  #       trait_value_id: 786,
  #       display_order: 784,
  #       text: "University of Missouri, St. Louis"
  #     },
  #     %{
  #       id: 636,
  #       question_id: 23,
  #       trait_value_id: 787,
  #       display_order: 786,
  #       text: "University of Montana"
  #     },
  #     %{
  #       id: 637,
  #       question_id: 23,
  #       trait_value_id: 788,
  #       display_order: 788,
  #       text: "University of Nebraska, Kearney"
  #     },
  #     %{
  #       id: 638,
  #       question_id: 23,
  #       trait_value_id: 789,
  #       display_order: 789,
  #       text: "University of Nebraska, Lincoln"
  #     },
  #     %{
  #       id: 639,
  #       question_id: 23,
  #       trait_value_id: 790,
  #       display_order: 791,
  #       text: "University of Nevada, Las Vegas"
  #     },
  #     %{
  #       id: 640,
  #       question_id: 23,
  #       trait_value_id: 791,
  #       display_order: 790,
  #       text: "University of Nevada - Reno"
  #     },
  #     %{
  #       id: 641,
  #       question_id: 23,
  #       trait_value_id: 792,
  #       display_order: 792,
  #       text: "University of New Hampshire"
  #     },
  #     %{
  #       id: 642,
  #       question_id: 23,
  #       trait_value_id: 793,
  #       display_order: 793,
  #       text: "University of New Mexico"
  #     },
  #     %{
  #       id: 643,
  #       question_id: 23,
  #       trait_value_id: 794,
  #       display_order: 795,
  #       text: "University of North Carolina, Chapel Hill"
  #     },
  #     %{
  #       id: 644,
  #       question_id: 23,
  #       trait_value_id: 795,
  #       display_order: 796,
  #       text: "University of North Carolina, Charlotte"
  #     },
  #     %{
  #       id: 645,
  #       question_id: 23,
  #       trait_value_id: 796,
  #       display_order: 797,
  #       text: "University of North Carolina, Greensboro"
  #     },
  #     %{
  #       id: 646,
  #       question_id: 23,
  #       trait_value_id: 797,
  #       display_order: 798,
  #       text: "University of North Carolina, Pembroke"
  #     },
  #     %{
  #       id: 647,
  #       question_id: 23,
  #       trait_value_id: 798,
  #       display_order: 799,
  #       text: "University of North Carolina, Wilmington"
  #     },
  #     %{
  #       id: 648,
  #       question_id: 23,
  #       trait_value_id: 799,
  #       display_order: 800,
  #       text: "University of North Dakota"
  #     },
  #     %{
  #       id: 649,
  #       question_id: 23,
  #       trait_value_id: 800,
  #       display_order: 803,
  #       text: "University of Northern Iowa"
  #     },
  #     %{
  #       id: 650,
  #       question_id: 23,
  #       trait_value_id: 801,
  #       display_order: 801,
  #       text: "University of North Florida"
  #     },
  #     %{
  #       id: 651,
  #       question_id: 23,
  #       trait_value_id: 802,
  #       display_order: 802,
  #       text: "University of North Texas"
  #     },
  #     %{
  #       id: 652,
  #       question_id: 23,
  #       trait_value_id: 803,
  #       display_order: 804,
  #       text: "University of Notre Dame"
  #     },
  #     %{
  #       id: 653,
  #       question_id: 23,
  #       trait_value_id: 804,
  #       display_order: 805,
  #       text: "University of Oklahoma"
  #     },
  #     %{
  #       id: 654,
  #       question_id: 23,
  #       trait_value_id: 805,
  #       display_order: 806,
  #       text: "University of Oregon"
  #     },
  #     %{
  #       id: 655,
  #       question_id: 23,
  #       trait_value_id: 806,
  #       display_order: 807,
  #       text: "University of Pittsburgh"
  #     },
  #     %{
  #       id: 656,
  #       question_id: 23,
  #       trait_value_id: 807,
  #       display_order: 809,
  #       text: "University of South Alabama"
  #     },
  #     %{
  #       id: 657,
  #       question_id: 23,
  #       trait_value_id: 808,
  #       display_order: 810,
  #       text: "University of South Carolina, Columbia"
  #     },
  #     %{
  #       id: 658,
  #       question_id: 23,
  #       trait_value_id: 809,
  #       display_order: 812,
  #       text: "University of South Dakota"
  #     },
  #     %{
  #       id: 659,
  #       question_id: 23,
  #       trait_value_id: 810,
  #       display_order: 814,
  #       text: "University of Southern California"
  #     },
  #     %{
  #       id: 660,
  #       question_id: 23,
  #       trait_value_id: 811,
  #       display_order: 815,
  #       text: "University of Southern Mississippi"
  #     },
  #     %{
  #       id: 661,
  #       question_id: 23,
  #       trait_value_id: 812,
  #       display_order: 813,
  #       text: "University of South Florida"
  #     },
  #     %{
  #       id: 662,
  #       question_id: 23,
  #       trait_value_id: 813,
  #       display_order: 819,
  #       text: "University of Tennessee, Knoxville"
  #     },
  #     %{
  #       id: 663,
  #       question_id: 23,
  #       trait_value_id: 814,
  #       display_order: 823,
  #       text: "University of Texas, Arlington"
  #     },
  #     %{
  #       id: 664,
  #       question_id: 23,
  #       trait_value_id: 815,
  #       display_order: 824,
  #       text: "University of Texas, Austin"
  #     },
  #     %{
  #       id: 665,
  #       question_id: 23,
  #       trait_value_id: 816,
  #       display_order: 825,
  #       text: "University of Texas, Brownsville"
  #     },
  #     %{
  #       id: 666,
  #       question_id: 23,
  #       trait_value_id: 817,
  #       display_order: 826,
  #       text: "University of Texas, Dallas"
  #     },
  #     %{
  #       id: 667,
  #       question_id: 23,
  #       trait_value_id: 818,
  #       display_order: 827,
  #       text: "University of Texas, El Paso"
  #     },
  #     %{
  #       id: 668,
  #       question_id: 23,
  #       trait_value_id: 819,
  #       display_order: 828,
  #       text: "University of Texas, Pan American"
  #     },
  #     %{
  #       id: 669,
  #       question_id: 23,
  #       trait_value_id: 820,
  #       display_order: 829,
  #       text: "University of Texas, Permian Basin"
  #     },
  #     %{
  #       id: 670,
  #       question_id: 23,
  #       trait_value_id: 821,
  #       display_order: 830,
  #       text: "University of Texas, San Antonio"
  #     },
  #     %{
  #       id: 671,
  #       question_id: 23,
  #       trait_value_id: 822,
  #       display_order: 831,
  #       text: "University of Texas-Tyler"
  #     },
  #     %{
  #       id: 672,
  #       question_id: 23,
  #       trait_value_id: 823,
  #       display_order: 836,
  #       text: "University of Toledo"
  #     },
  #     %{
  #       id: 673,
  #       question_id: 23,
  #       trait_value_id: 824,
  #       display_order: 837,
  #       text: "University of Utah"
  #     },
  #     %{
  #       id: 674,
  #       question_id: 23,
  #       trait_value_id: 825,
  #       display_order: 838,
  #       text: "University of Virginia, Main Campus"
  #     },
  #     %{
  #       id: 675,
  #       question_id: 23,
  #       trait_value_id: 826,
  #       display_order: 839,
  #       text: "University of Washington"
  #     },
  #     %{
  #       id: 676,
  #       question_id: 23,
  #       trait_value_id: 827,
  #       display_order: 841,
  #       text: "University of West Florida"
  #     },
  #     %{
  #       id: 677,
  #       question_id: 23,
  #       trait_value_id: 828,
  #       display_order: 842,
  #       text: "University of West Georgia"
  #     },
  #     %{
  #       id: 678,
  #       question_id: 23,
  #       trait_value_id: 829,
  #       display_order: 843,
  #       text: "University of Wisconsin - Green Bay"
  #     },
  #     %{
  #       id: 679,
  #       question_id: 23,
  #       trait_value_id: 830,
  #       display_order: 845,
  #       text: "University of Wisconsin, Madison"
  #     },
  #     %{
  #       id: 680,
  #       question_id: 23,
  #       trait_value_id: 831,
  #       display_order: 846,
  #       text: "University of Wisconsin, Milwaukee"
  #     },
  #     %{
  #       id: 681,
  #       question_id: 23,
  #       trait_value_id: 832,
  #       display_order: 848,
  #       text: "University of Wisconsin-Oshkosh"
  #     },
  #     %{
  #       id: 682,
  #       question_id: 23,
  #       trait_value_id: 833,
  #       display_order: 844,
  #       text: "University of Wisconsin - Parkside"
  #     },
  #     %{
  #       id: 683,
  #       question_id: 23,
  #       trait_value_id: 834,
  #       display_order: 847,
  #       text: "University of Wisconsin, Whitewater"
  #     },
  #     %{
  #       id: 684,
  #       question_id: 23,
  #       trait_value_id: 835,
  #       display_order: 849,
  #       text: "University of Wyoming"
  #     },
  #     %{
  #       id: 685,
  #       question_id: 23,
  #       trait_value_id: 836,
  #       display_order: 850,
  #       text: "Utah State University"
  #     },
  #     %{
  #       id: 686,
  #       question_id: 23,
  #       trait_value_id: 837,
  #       display_order: 851,
  #       text: "Utah Valley State College"
  #     },
  #     %{
  #       id: 687,
  #       question_id: 23,
  #       trait_value_id: 838,
  #       display_order: 852,
  #       text: "Valdosta State University"
  #     },
  #     %{
  #       id: 688,
  #       question_id: 23,
  #       trait_value_id: 839,
  #       display_order: 853,
  #       text: "Valencia Community College"
  #     },
  #     %{
  #       id: 689,
  #       question_id: 23,
  #       trait_value_id: 840,
  #       display_order: 854,
  #       text: "Vanderbilt University"
  #     },
  #     %{
  #       id: 690,
  #       question_id: 23,
  #       trait_value_id: 841,
  #       display_order: 855,
  #       text: "Ventura College"
  #     },
  #     %{
  #       id: 691,
  #       question_id: 23,
  #       trait_value_id: 842,
  #       display_order: 859,
  #       text: "Virginia Commonwealth University"
  #     },
  #     %{
  #       id: 692,
  #       question_id: 23,
  #       trait_value_id: 843,
  #       display_order: 860,
  #       text: "Virginia Tech"
  #     },
  #     %{
  #       id: 693,
  #       question_id: 23,
  #       trait_value_id: 844,
  #       display_order: 863,
  #       text: "Wake Forest University"
  #     },
  #     %{
  #       id: 694,
  #       question_id: 23,
  #       trait_value_id: 845,
  #       display_order: 870,
  #       text: "Washington State University"
  #     },
  #     %{
  #       id: 695,
  #       question_id: 23,
  #       trait_value_id: 846,
  #       display_order: 871,
  #       text: "Washington University"
  #     },
  #     %{
  #       id: 696,
  #       question_id: 23,
  #       trait_value_id: 847,
  #       display_order: 875,
  #       text: "Weber State University"
  #     },
  #     %{
  #       id: 697,
  #       question_id: 23,
  #       trait_value_id: 848,
  #       display_order: 886,
  #       text: "Western Carolina University"
  #     },
  #     %{
  #       id: 698,
  #       question_id: 23,
  #       trait_value_id: 849,
  #       display_order: 887,
  #       text: "Western Kentucky University"
  #     },
  #     %{
  #       id: 699,
  #       question_id: 23,
  #       trait_value_id: 850,
  #       display_order: 888,
  #       text: "Western Michigan University"
  #     },
  #     %{
  #       id: 700,
  #       question_id: 23,
  #       trait_value_id: 851,
  #       display_order: 889,
  #       text: "Western Nevada College"
  #     },
  #     %{
  #       id: 701,
  #       question_id: 23,
  #       trait_value_id: 852,
  #       display_order: 890,
  #       text: "Western Washington University"
  #     },
  #     %{
  #       id: 702,
  #       question_id: 23,
  #       trait_value_id: 853,
  #       display_order: 883,
  #       text: "West Texas A&M University"
  #     },
  #     %{
  #       id: 703,
  #       question_id: 23,
  #       trait_value_id: 854,
  #       display_order: 884,
  #       text: "West Valley College"
  #     },
  #     %{
  #       id: 704,
  #       question_id: 23,
  #       trait_value_id: 855,
  #       display_order: 885,
  #       text: "West Virginia University"
  #     },
  #     %{
  #       id: 705,
  #       question_id: 23,
  #       trait_value_id: 856,
  #       display_order: 891,
  #       text: "Wharton County Junior College"
  #     },
  #     %{
  #       id: 706,
  #       question_id: 23,
  #       trait_value_id: 857,
  #       display_order: 892,
  #       text: "Wichita State University"
  #     },
  #     %{
  #       id: 707,
  #       question_id: 23,
  #       trait_value_id: 858,
  #       display_order: 893,
  #       text: "Wilfrid Laurier University"
  #     },
  #     %{
  #       id: 708,
  #       question_id: 23,
  #       trait_value_id: 859,
  #       display_order: 897,
  #       text: "Winthrop University"
  #     },
  #     %{
  #       id: 709,
  #       question_id: 23,
  #       trait_value_id: 860,
  #       display_order: 898,
  #       text: "Worcester Polytechnic Institute"
  #     },
  #     %{
  #       id: 710,
  #       question_id: 23,
  #       trait_value_id: 861,
  #       display_order: 899,
  #       text: "Wright State University"
  #     },
  #     %{
  #       id: 711,
  #       question_id: 23,
  #       trait_value_id: 862,
  #       display_order: 903,
  #       text: "Youngstown State University"
  #     },
  #     %{
  #       id: 712,
  #       question_id: 23,
  #       trait_value_id: 863,
  #       display_order: 904,
  #       text: "Yuba College"
  #     },
  #     %{
  #       id: 713,
  #       question_id: 23,
  #       trait_value_id: 865,
  #       display_order: 335,
  #       text: "Jamestown College"
  #     },
  #     %{
  #       id: 714,
  #       question_id: 23,
  #       trait_value_id: 866,
  #       display_order: 864,
  #       text: "Walla Walla Community College"
  #     },
  #     %{
  #       id: 715,
  #       question_id: 23,
  #       trait_value_id: 864,
  #       display_order: 577,
  #       text: "Sacramento City College"
  #     },
  #     %{
  #       id: 716,
  #       question_id: 24,
  #       trait_value_id: 165,
  #       display_order: 1,
  #       text: "Own"
  #     },
  #     %{
  #       id: 717,
  #       question_id: 24,
  #       trait_value_id: 166,
  #       display_order: 2,
  #       text: "Rent"
  #     },
  #     %{
  #       id: 718,
  #       question_id: 24,
  #       trait_value_id: 167,
  #       display_order: 3,
  #       text: "Live on campus"
  #     },
  #     %{
  #       id: 719,
  #       question_id: 24,
  #       trait_value_id: 868,
  #       display_order: 9,
  #       text: "Other - none listed apply"
  #     },
  #     %{
  #       id: 720,
  #       question_id: 24,
  #       trait_value_id: 867,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 723,
  #       question_id: 25,
  #       trait_value_id: 881,
  #       display_order: 3,
  #       text: "Fireplace - Wood burning"
  #     },
  #     %{
  #       id: 724,
  #       question_id: 25,
  #       trait_value_id: 880,
  #       display_order: 3,
  #       text: "Monitored/private security alarm"
  #     },
  #     %{
  #       id: 725,
  #       question_id: 25,
  #       trait_value_id: 879,
  #       display_order: 3,
  #       text: "Basement"
  #     },
  #     %{
  #       id: 726,
  #       question_id: 25,
  #       trait_value_id: 878,
  #       display_order: 3,
  #       text: "Central Heat/AC"
  #     },
  #     %{
  #       id: 727,
  #       question_id: 25,
  #       trait_value_id: 876,
  #       display_order: 3,
  #       text: "Garage"
  #     },
  #     %{
  #       id: 728,
  #       question_id: 25,
  #       trait_value_id: 882,
  #       display_order: 3,
  #       text: "Fireplace - Gas"
  #     },
  #     %{
  #       id: 729,
  #       question_id: 25,
  #       trait_value_id: 873,
  #       display_order: 5,
  #       text: "Hot tub / Spa"
  #     },
  #     %{
  #       id: 730,
  #       question_id: 25,
  #       trait_value_id: 872,
  #       display_order: 5,
  #       text: "Swimming pool"
  #     },
  #     %{
  #       id: 733,
  #       question_id: 25,
  #       trait_value_id: 894,
  #       display_order: 1,
  #       text: "Multi-story"
  #     },
  #     %{
  #       id: 734,
  #       question_id: 26,
  #       trait_value_id: 886,
  #       display_order: 1,
  #       text: "Dormitory"
  #     },
  #     %{
  #       id: 735,
  #       question_id: 26,
  #       trait_value_id: 887,
  #       display_order: 2,
  #       text: "Apartment"
  #     },
  #     %{
  #       id: 736,
  #       question_id: 26,
  #       trait_value_id: 888,
  #       display_order: 3,
  #       text: "Condominium"
  #     },
  #     %{
  #       id: 737,
  #       question_id: 26,
  #       trait_value_id: 893,
  #       display_order: 4,
  #       text: "Duplex / Multi-family house"
  #     },
  #     %{
  #       id: 738,
  #       question_id: 26,
  #       trait_value_id: 889,
  #       display_order: 5,
  #       text: "Townhouse"
  #     },
  #     %{
  #       id: 739,
  #       question_id: 26,
  #       trait_value_id: 891,
  #       display_order: 6,
  #       text: "House (Single-Family)"
  #     },
  #     %{
  #       id: 740,
  #       question_id: 27,
  #       trait_value_id: 897,
  #       display_order: 1,
  #       text:
  #         "I - Very light, Celtic. Often burns, rarely tans. Tends to have freckles, red or blond hair, blue or green eyes."
  #     },
  #     %{
  #       id: 741,
  #       question_id: 27,
  #       trait_value_id: 898,
  #       display_order: 2,
  #       text:
  #         "II - Light, Light-skinned European. Usually burns, sometimes tans. Tends to have light hair, blue or brown eyes."
  #     },
  #     %{
  #       id: 742,
  #       question_id: 27,
  #       trait_value_id: 899,
  #       display_order: 3,
  #       text:
  #         "III - Light intermediate, Dark-skinned European, Average Caucasian. Sometimes burns, usually tans. Tends to have brown hair and eyes."
  #     },
  #     %{
  #       id: 743,
  #       question_id: 27,
  #       trait_value_id: 900,
  #       display_order: 4,
  #       text:
  #         "IV - Dark intermediate, Mediterranean, Olive. Sometimes burns, often tans. Tends to have dark brown eyes and hair."
  #     },
  #     %{
  #       id: 744,
  #       question_id: 27,
  #       trait_value_id: 901,
  #       display_order: 5,
  #       text: "V - Dark, Brown. Naturally black-brown skin. Often has dark brown eyes and hair."
  #     },
  #     %{
  #       id: 745,
  #       question_id: 27,
  #       trait_value_id: 902,
  #       display_order: 6,
  #       text:
  #         "VI - Very dark, Black. Naturally black-brown skin. Usually has black-brown eyes and hair."
  #     },
  #     %{
  #       id: 746,
  #       question_id: 27,
  #       trait_value_id: 903,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 747,
  #       question_id: 27,
  #       trait_value_id: 904,
  #       display_order: 9,
  #       text: "Other - none listed apply"
  #     },
  #     %{
  #       id: 748,
  #       question_id: 28,
  #       trait_value_id: 922,
  #       display_order: 1,
  #       text: "Dry"
  #     },
  #     %{
  #       id: 749,
  #       question_id: 28,
  #       trait_value_id: 923,
  #       display_order: 2,
  #       text: "Normal"
  #     },
  #     %{
  #       id: 750,
  #       question_id: 28,
  #       trait_value_id: 924,
  #       display_order: 3,
  #       text: "Oily"
  #     },
  #     %{
  #       id: 751,
  #       question_id: 28,
  #       trait_value_id: 925,
  #       display_order: 4,
  #       text: "Combination (Dry & Oily)"
  #     },
  #     %{
  #       id: 752,
  #       question_id: 28,
  #       trait_value_id: 926,
  #       display_order: 5,
  #       text: "Sensitive"
  #     },
  #     %{
  #       id: 753,
  #       question_id: 28,
  #       trait_value_id: 927,
  #       display_order: 6,
  #       text: "Other - none listed apply"
  #     },
  #     %{
  #       id: 754,
  #       question_id: 28,
  #       trait_value_id: 928,
  #       display_order: 9,
  #       text: "I do not know my facial skin type."
  #     },
  #     %{
  #       id: 755,
  #       question_id: 28,
  #       trait_value_id: 929,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 756,
  #       question_id: 29,
  #       trait_value_id: 906,
  #       display_order: 1,
  #       text: "Acne - Facial"
  #     },
  #     %{
  #       id: 757,
  #       question_id: 29,
  #       trait_value_id: 919,
  #       display_order: 1,
  #       text: "Athlete's Foot"
  #     },
  #     %{
  #       id: 759,
  #       question_id: 29,
  #       trait_value_id: 917,
  #       display_order: 1,
  #       text: "Acrochordon (Skin tags)"
  #     },
  #     %{
  #       id: 760,
  #       question_id: 29,
  #       trait_value_id: 916,
  #       display_order: 1,
  #       text: "Warts"
  #     },
  #     %{
  #       id: 761,
  #       question_id: 29,
  #       trait_value_id: 915,
  #       display_order: 1,
  #       text: "Scabies"
  #     },
  #     %{
  #       id: 762,
  #       question_id: 29,
  #       trait_value_id: 914,
  #       display_order: 1,
  #       text: "Impetigo"
  #     },
  #     %{
  #       id: 763,
  #       question_id: 29,
  #       trait_value_id: 913,
  #       display_order: 1,
  #       text: "Skin cancer"
  #     },
  #     %{
  #       id: 764,
  #       question_id: 29,
  #       trait_value_id: 912,
  #       display_order: 1,
  #       text: "Keratosis pilaris"
  #     },
  #     %{
  #       id: 765,
  #       question_id: 29,
  #       trait_value_id: 911,
  #       display_order: 1,
  #       text: "Vitiligo"
  #     },
  #     %{
  #       id: 766,
  #       question_id: 29,
  #       trait_value_id: 910,
  #       display_order: 1,
  #       text: "Sensitivity to soap/detergents"
  #     },
  #     %{
  #       id: 767,
  #       question_id: 29,
  #       trait_value_id: 909,
  #       display_order: 1,
  #       text: "Psoriasis"
  #     },
  #     %{
  #       id: 768,
  #       question_id: 29,
  #       trait_value_id: 908,
  #       display_order: 1,
  #       text: "Eczema"
  #     },
  #     %{
  #       id: 769,
  #       question_id: 29,
  #       trait_value_id: 907,
  #       display_order: 1,
  #       text: "Acne - Body"
  #     },
  #     %{
  #       id: 770,
  #       question_id: 29,
  #       trait_value_id: 920,
  #       display_order: 1,
  #       text: "Age/Sun/Liver Spots"
  #     },
  #     %{
  #       id: 771,
  #       question_id: 29,
  #       trait_value_id: 930,
  #       display_order: 9,
  #       text: "Other - none listed apply"
  #     },
  #     %{
  #       id: 772,
  #       question_id: 29,
  #       trait_value_id: 931,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 773,
  #       question_id: 30,
  #       trait_value_id: 61,
  #       display_order: 1,
  #       text: "0"
  #     },
  #     %{
  #       id: 774,
  #       question_id: 30,
  #       trait_value_id: 62,
  #       display_order: 1,
  #       text: "1"
  #     },
  #     %{
  #       id: 775,
  #       question_id: 30,
  #       trait_value_id: 63,
  #       display_order: 1,
  #       text: "2"
  #     },
  #     %{
  #       id: 776,
  #       question_id: 30,
  #       trait_value_id: 64,
  #       display_order: 1,
  #       text: "3"
  #     },
  #     %{
  #       id: 777,
  #       question_id: 30,
  #       trait_value_id: 65,
  #       display_order: 1,
  #       text: "4 or more"
  #     },
  #     %{
  #       id: 778,
  #       question_id: 30,
  #       trait_value_id: 90,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 779,
  #       question_id: 31,
  #       trait_value_id: 933,
  #       display_order: 1,
  #       text: "Classic Rock"
  #     },
  #     %{
  #       id: 780,
  #       question_id: 31,
  #       trait_value_id: 934,
  #       display_order: 2,
  #       text: "Hard Rock/Metal"
  #     },
  #     %{
  #       id: 781,
  #       question_id: 31,
  #       trait_value_id: 935,
  #       display_order: 3,
  #       text: "Punk"
  #     },
  #     %{
  #       id: 782,
  #       question_id: 31,
  #       trait_value_id: 936,
  #       display_order: 4,
  #       text: "Alternative"
  #     },
  #     %{
  #       id: 783,
  #       question_id: 31,
  #       trait_value_id: 937,
  #       display_order: 5,
  #       text: "Pop"
  #     },
  #     %{
  #       id: 784,
  #       question_id: 31,
  #       trait_value_id: 938,
  #       display_order: 6,
  #       text: "Easy Listening"
  #     },
  #     %{
  #       id: 785,
  #       question_id: 31,
  #       trait_value_id: 939,
  #       display_order: 7,
  #       text: "Folk"
  #     },
  #     %{
  #       id: 786,
  #       question_id: 31,
  #       trait_value_id: 940,
  #       display_order: 8,
  #       text: "Blues"
  #     },
  #     %{
  #       id: 787,
  #       question_id: 31,
  #       trait_value_id: 941,
  #       display_order: 9,
  #       text: "R&B"
  #     },
  #     %{
  #       id: 788,
  #       question_id: 31,
  #       trait_value_id: 942,
  #       display_order: 10,
  #       text: "Soul"
  #     },
  #     %{
  #       id: 789,
  #       question_id: 31,
  #       trait_value_id: 943,
  #       display_order: 11,
  #       text: "Rap & Hip-Hop"
  #     },
  #     %{
  #       id: 790,
  #       question_id: 31,
  #       trait_value_id: 944,
  #       display_order: 12,
  #       text: "Reggae"
  #     },
  #     %{
  #       id: 791,
  #       question_id: 31,
  #       trait_value_id: 945,
  #       display_order: 13,
  #       text: "Jazz - Classic"
  #     },
  #     %{
  #       id: 792,
  #       question_id: 31,
  #       trait_value_id: 946,
  #       display_order: 14,
  #       text: "Jazz - Latin"
  #     },
  #     %{
  #       id: 793,
  #       question_id: 31,
  #       trait_value_id: 947,
  #       display_order: 15,
  #       text: "Swing"
  #     },
  #     %{
  #       id: 794,
  #       question_id: 31,
  #       trait_value_id: 948,
  #       display_order: 16,
  #       text: "Big Band"
  #     },
  #     %{
  #       id: 795,
  #       question_id: 31,
  #       trait_value_id: 949,
  #       display_order: 17,
  #       text: "Dance"
  #     },
  #     %{
  #       id: 796,
  #       question_id: 31,
  #       trait_value_id: 950,
  #       display_order: 18,
  #       text: "Electronic"
  #     },
  #     %{
  #       id: 797,
  #       question_id: 31,
  #       trait_value_id: 951,
  #       display_order: 19,
  #       text: "World"
  #     },
  #     %{
  #       id: 798,
  #       question_id: 31,
  #       trait_value_id: 952,
  #       display_order: 20,
  #       text: "Country / Western"
  #     },
  #     %{
  #       id: 799,
  #       question_id: 31,
  #       trait_value_id: 953,
  #       display_order: 21,
  #       text: "Classical"
  #     },
  #     %{
  #       id: 800,
  #       question_id: 31,
  #       trait_value_id: 954,
  #       display_order: 22,
  #       text: "Latin (Pop, Rock en Espanol, Mexican, Tejano, etc.)"
  #     },
  #     %{
  #       id: 801,
  #       question_id: 31,
  #       trait_value_id: 955,
  #       display_order: 23,
  #       text: "Modern Christian"
  #     },
  #     %{
  #       id: 802,
  #       question_id: 31,
  #       trait_value_id: 956,
  #       display_order: 24,
  #       text: "Gospel"
  #     },
  #     %{
  #       id: 803,
  #       question_id: 32,
  #       trait_value_id: 958,
  #       display_order: 1,
  #       text: "Classic Rock"
  #     },
  #     %{
  #       id: 804,
  #       question_id: 32,
  #       trait_value_id: 959,
  #       display_order: 2,
  #       text: "Hard Rock/Metal"
  #     },
  #     %{
  #       id: 805,
  #       question_id: 32,
  #       trait_value_id: 960,
  #       display_order: 3,
  #       text: "Punk"
  #     },
  #     %{
  #       id: 806,
  #       question_id: 32,
  #       trait_value_id: 961,
  #       display_order: 4,
  #       text: "Alternative"
  #     },
  #     %{
  #       id: 807,
  #       question_id: 32,
  #       trait_value_id: 963,
  #       display_order: 5,
  #       text: "Easy Listening"
  #     },
  #     %{
  #       id: 808,
  #       question_id: 32,
  #       trait_value_id: 964,
  #       display_order: 6,
  #       text: "Folk"
  #     },
  #     %{
  #       id: 809,
  #       question_id: 32,
  #       trait_value_id: 965,
  #       display_order: 7,
  #       text: "Blues"
  #     },
  #     %{
  #       id: 810,
  #       question_id: 32,
  #       trait_value_id: 966,
  #       display_order: 8,
  #       text: "R&B"
  #     },
  #     %{
  #       id: 811,
  #       question_id: 32,
  #       trait_value_id: 967,
  #       display_order: 9,
  #       text: "Soul"
  #     },
  #     %{
  #       id: 812,
  #       question_id: 32,
  #       trait_value_id: 968,
  #       display_order: 10,
  #       text: "Rap & Hip-Hop"
  #     },
  #     %{
  #       id: 813,
  #       question_id: 32,
  #       trait_value_id: 969,
  #       display_order: 11,
  #       text: "Reggae"
  #     },
  #     %{
  #       id: 814,
  #       question_id: 32,
  #       trait_value_id: 970,
  #       display_order: 12,
  #       text: "Jazz - Classic"
  #     },
  #     %{
  #       id: 815,
  #       question_id: 32,
  #       trait_value_id: 971,
  #       display_order: 13,
  #       text: "Jazz - Latin"
  #     },
  #     %{
  #       id: 816,
  #       question_id: 32,
  #       trait_value_id: 972,
  #       display_order: 14,
  #       text: "Swing"
  #     },
  #     %{
  #       id: 817,
  #       question_id: 32,
  #       trait_value_id: 973,
  #       display_order: 15,
  #       text: "Big Band"
  #     },
  #     %{
  #       id: 818,
  #       question_id: 32,
  #       trait_value_id: 974,
  #       display_order: 16,
  #       text: "Dance"
  #     },
  #     %{
  #       id: 819,
  #       question_id: 32,
  #       trait_value_id: 975,
  #       display_order: 17,
  #       text: "Electronic"
  #     },
  #     %{
  #       id: 820,
  #       question_id: 32,
  #       trait_value_id: 976,
  #       display_order: 18,
  #       text: "World"
  #     },
  #     %{
  #       id: 821,
  #       question_id: 32,
  #       trait_value_id: 977,
  #       display_order: 19,
  #       text: "Country/Western"
  #     },
  #     %{
  #       id: 822,
  #       question_id: 32,
  #       trait_value_id: 978,
  #       display_order: 20,
  #       text: "Classical"
  #     },
  #     %{
  #       id: 823,
  #       question_id: 32,
  #       trait_value_id: 979,
  #       display_order: 21,
  #       text: "Latin (Pop, Rock en Espanol, Mexican, Tejano, etc.)"
  #     },
  #     %{
  #       id: 824,
  #       question_id: 32,
  #       trait_value_id: 980,
  #       display_order: 22,
  #       text: "Modern Christian"
  #     },
  #     %{
  #       id: 825,
  #       question_id: 32,
  #       trait_value_id: 981,
  #       display_order: 24,
  #       text: "Gospel"
  #     },
  #     %{
  #       id: 826,
  #       question_id: 32,
  #       trait_value_id: 983,
  #       display_order: 50,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 827,
  #       question_id: 33,
  #       trait_value_id: 985,
  #       display_order: 1,
  #       text: "50's or earlier"
  #     },
  #     %{
  #       id: 828,
  #       question_id: 33,
  #       trait_value_id: 986,
  #       display_order: 2,
  #       text: "60's"
  #     },
  #     %{
  #       id: 829,
  #       question_id: 33,
  #       trait_value_id: 987,
  #       display_order: 3,
  #       text: "70's"
  #     },
  #     %{
  #       id: 830,
  #       question_id: 33,
  #       trait_value_id: 988,
  #       display_order: 4,
  #       text: "80's"
  #     },
  #     %{
  #       id: 831,
  #       question_id: 33,
  #       trait_value_id: 989,
  #       display_order: 5,
  #       text: "90's"
  #     },
  #     %{
  #       id: 832,
  #       question_id: 33,
  #       trait_value_id: 990,
  #       display_order: 6,
  #       text: "Current music"
  #     },
  #     %{
  #       id: 833,
  #       question_id: 33,
  #       trait_value_id: 991,
  #       display_order: 7,
  #       text: "Not able to choose one"
  #     },
  #     %{
  #       id: 834,
  #       question_id: 33,
  #       trait_value_id: 992,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 835,
  #       question_id: 34,
  #       trait_value_id: 994,
  #       display_order: 1,
  #       text: "iPod/iPhone (Apple)"
  #     },
  #     %{
  #       id: 836,
  #       question_id: 34,
  #       trait_value_id: 995,
  #       display_order: 2,
  #       text: "Zune"
  #     },
  #     %{
  #       id: 837,
  #       question_id: 34,
  #       trait_value_id: 996,
  #       display_order: 3,
  #       text: "Sony"
  #     },
  #     %{
  #       id: 838,
  #       question_id: 34,
  #       trait_value_id: 997,
  #       display_order: 4,
  #       text: "Creative"
  #     },
  #     %{
  #       id: 839,
  #       question_id: 34,
  #       trait_value_id: 998,
  #       display_order: 5,
  #       text: "Samsung"
  #     },
  #     %{
  #       id: 840,
  #       question_id: 34,
  #       trait_value_id: 999,
  #       display_order: 6,
  #       text: "SanDisk"
  #     },
  #     %{
  #       id: 841,
  #       question_id: 34,
  #       trait_value_id: 1000,
  #       display_order: 7,
  #       text: "Sansa"
  #     },
  #     %{
  #       id: 842,
  #       question_id: 34,
  #       trait_value_id: 1001,
  #       display_order: 8,
  #       text: "Other - My brand not listed"
  #     },
  #     %{
  #       id: 843,
  #       question_id: 34,
  #       trait_value_id: 1003,
  #       display_order: 9,
  #       text: "None - Do not own a player"
  #     },
  #     %{
  #       id: 844,
  #       question_id: 34,
  #       trait_value_id: 1002,
  #       display_order: 20,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 845,
  #       question_id: 23,
  #       trait_value_id: 1004,
  #       display_order: 197,
  #       text: "Drake University"
  #     },
  #     %{
  #       id: 846,
  #       question_id: 23,
  #       trait_value_id: 1005,
  #       display_order: 753,
  #       text: "University of Denver"
  #     },
  #     %{
  #       id: 847,
  #       question_id: 18,
  #       trait_value_id: 1006,
  #       display_order: 9,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 848,
  #       question_id: 18,
  #       trait_value_id: 1007,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 849,
  #       question_id: 23,
  #       trait_value_id: 1008,
  #       display_order: 258,
  #       text: "Franklin & Marshall College"
  #     },
  #     %{
  #       id: 850,
  #       question_id: 23,
  #       trait_value_id: 1009,
  #       display_order: 698,
  #       text: "The George Washington University"
  #     },
  #     %{
  #       id: 851,
  #       question_id: 23,
  #       trait_value_id: 1010,
  #       display_order: 732,
  #       text: "University of Baltimore"
  #     },
  #     %{
  #       id: 852,
  #       question_id: 23,
  #       trait_value_id: 1011,
  #       display_order: 613,
  #       text: "Seton Hall University"
  #     },
  #     %{
  #       id: 853,
  #       question_id: 23,
  #       trait_value_id: 1012,
  #       display_order: 254,
  #       text: "Fordham University"
  #     },
  #     %{
  #       id: 854,
  #       question_id: 23,
  #       trait_value_id: 1014,
  #       display_order: 566,
  #       text: "Rice University"
  #     },
  #     %{
  #       id: 855,
  #       question_id: 23,
  #       trait_value_id: 1015,
  #       display_order: 311,
  #       text: "Houston Baptist University"
  #     },
  #     %{
  #       id: 856,
  #       question_id: 35,
  #       trait_value_id: 1017,
  #       display_order: 1,
  #       text: "Birding / Wild Birds"
  #     },
  #     %{
  #       id: 857,
  #       question_id: 35,
  #       trait_value_id: 1018,
  #       display_order: 2,
  #       text: "Casino Gambling"
  #     },
  #     %{
  #       id: 858,
  #       question_id: 35,
  #       trait_value_id: 1019,
  #       display_order: 3,
  #       text: "Cigars"
  #     },
  #     %{
  #       id: 859,
  #       question_id: 35,
  #       trait_value_id: 1020,
  #       display_order: 4,
  #       text: "Contests & Sweepstakes"
  #     },
  #     %{
  #       id: 860,
  #       question_id: 35,
  #       trait_value_id: 1021,
  #       display_order: 5,
  #       text: "Dance"
  #     },
  #     %{
  #       id: 861,
  #       question_id: 35,
  #       trait_value_id: 1022,
  #       display_order: 6,
  #       text: "Freshwater Aquariums"
  #     },
  #     %{
  #       id: 862,
  #       question_id: 35,
  #       trait_value_id: 1023,
  #       display_order: 7,
  #       text: "Gardening"
  #     },
  #     %{
  #       id: 863,
  #       question_id: 35,
  #       trait_value_id: 1024,
  #       display_order: 8,
  #       text: "Genealogy"
  #     },
  #     %{
  #       id: 864,
  #       question_id: 35,
  #       trait_value_id: 1025,
  #       display_order: 9,
  #       text: "Guitar"
  #     },
  #     %{
  #       id: 865,
  #       question_id: 35,
  #       trait_value_id: 1026,
  #       display_order: 10,
  #       text: "HAM/Amateur Radio"
  #     },
  #     %{
  #       id: 866,
  #       question_id: 35,
  #       trait_value_id: 1027,
  #       display_order: 11,
  #       text: "Magic & Illusion"
  #     },
  #     %{
  #       id: 867,
  #       question_id: 35,
  #       trait_value_id: 1028,
  #       display_order: 12,
  #       text: "Model Railroad Trains"
  #     },
  #     %{
  #       id: 868,
  #       question_id: 35,
  #       trait_value_id: 1029,
  #       display_order: 13,
  #       text: "Models - Other"
  #     },
  #     %{
  #       id: 869,
  #       question_id: 35,
  #       trait_value_id: 1030,
  #       display_order: 14,
  #       text: "Motorcycles"
  #     },
  #     %{
  #       id: 870,
  #       question_id: 35,
  #       trait_value_id: 1031,
  #       display_order: 15,
  #       text: "Photography"
  #     },
  #     %{
  #       id: 871,
  #       question_id: 35,
  #       trait_value_id: 1032,
  #       display_order: 16,
  #       text: "Piano"
  #     },
  #     %{
  #       id: 872,
  #       question_id: 35,
  #       trait_value_id: 1033,
  #       display_order: 17,
  #       text: "Radio Controlled Vehicles"
  #     },
  #     %{
  #       id: 873,
  #       question_id: 35,
  #       trait_value_id: 1034,
  #       display_order: 18,
  #       text: "Saltwater Aquariums"
  #     },
  #     %{
  #       id: 874,
  #       question_id: 35,
  #       trait_value_id: 1035,
  #       display_order: 19,
  #       text: "Sports Gambling"
  #     },
  #     %{
  #       id: 875,
  #       question_id: 35,
  #       trait_value_id: 1036,
  #       display_order: 100,
  #       text: "Ignore / Prefer not to say"
  #     },
  #     %{
  #       id: 876,
  #       question_id: 36,
  #       trait_value_id: 1038,
  #       display_order: 1,
  #       text: "Prescription glasses"
  #     },
  #     %{
  #       id: 877,
  #       question_id: 36,
  #       trait_value_id: 1039,
  #       display_order: 2,
  #       text: "Contact lenses"
  #     },
  #     %{
  #       id: 878,
  #       question_id: 36,
  #       trait_value_id: 1040,
  #       display_order: 3,
  #       text: "Non-prescription (reading/magnifying) glasses"
  #     },
  #     %{
  #       id: 879,
  #       question_id: 36,
  #       trait_value_id: 1041,
  #       display_order: 4,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 880,
  #       question_id: 36,
  #       trait_value_id: 1042,
  #       display_order: 5,
  #       text: "None, currently do not wear corrective lenses."
  #     },
  #     %{
  #       id: 881,
  #       question_id: 36,
  #       trait_value_id: 1043,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 882,
  #       question_id: 37,
  #       trait_value_id: 1045,
  #       display_order: 1,
  #       text: "Perfect or near-perfect vision"
  #     },
  #     %{
  #       id: 883,
  #       question_id: 37,
  #       trait_value_id: 1046,
  #       display_order: 2,
  #       text: "Slight blurriness, either up close or at a distance"
  #     },
  #     %{
  #       id: 884,
  #       question_id: 37,
  #       trait_value_id: 1047,
  #       display_order: 3,
  #       text: "Moderate-to-severe blurriness, either up close or at a distance"
  #     },
  #     %{
  #       id: 885,
  #       question_id: 37,
  #       trait_value_id: 1048,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 886,
  #       question_id: 38,
  #       trait_value_id: 1050,
  #       display_order: 1,
  #       text: "Perfect/near-perfect vision"
  #     },
  #     %{
  #       id: 887,
  #       question_id: 38,
  #       trait_value_id: 1051,
  #       display_order: 2,
  #       text: "Slight blurriness, either up close or at a distance"
  #     },
  #     %{
  #       id: 888,
  #       question_id: 38,
  #       trait_value_id: 1052,
  #       display_order: 3,
  #       text: "Moderate-to-severe blurriness, either up close or at a distance"
  #     },
  #     %{
  #       id: 889,
  #       question_id: 38,
  #       trait_value_id: 1053,
  #       display_order: 4,
  #       text: "Not applicable - I do not wear corrective lenses."
  #     },
  #     %{
  #       id: 890,
  #       question_id: 38,
  #       trait_value_id: 1054,
  #       display_order: 5,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 891,
  #       question_id: 39,
  #       trait_value_id: 1056,
  #       display_order: 1,
  #       text: "Less than 12 months"
  #     },
  #     %{
  #       id: 892,
  #       question_id: 39,
  #       trait_value_id: 1057,
  #       display_order: 2,
  #       text: "Over 12 months"
  #     },
  #     %{
  #       id: 893,
  #       question_id: 39,
  #       trait_value_id: 1058,
  #       display_order: 3,
  #       text: "I have never had an eye exam."
  #     },
  #     %{
  #       id: 894,
  #       question_id: 39,
  #       trait_value_id: 1059,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 895,
  #       question_id: 40,
  #       trait_value_id: 1061,
  #       display_order: 1,
  #       text: "Yes"
  #     },
  #     %{
  #       id: 896,
  #       question_id: 40,
  #       trait_value_id: 1062,
  #       display_order: 2,
  #       text: "No"
  #     },
  #     %{
  #       id: 897,
  #       question_id: 40,
  #       trait_value_id: 1061,
  #       display_order: 3,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 898,
  #       question_id: 41,
  #       trait_value_id: 1065,
  #       display_order: 1,
  #       text: "Cataracts"
  #     },
  #     %{
  #       id: 899,
  #       question_id: 41,
  #       trait_value_id: 1066,
  #       display_order: 2,
  #       text: "Dry Eye"
  #     },
  #     %{
  #       id: 900,
  #       question_id: 41,
  #       trait_value_id: 1067,
  #       display_order: 3,
  #       text: "Glaucoma"
  #     },
  #     %{
  #       id: 901,
  #       question_id: 41,
  #       trait_value_id: 1068,
  #       display_order: 4,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 902,
  #       question_id: 41,
  #       trait_value_id: 1069,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 903,
  #       question_id: 41,
  #       trait_value_id: 1070,
  #       display_order: 9,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 904,
  #       question_id: 19,
  #       trait_value_id: 1071,
  #       display_order: 90,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 905,
  #       question_id: 19,
  #       trait_value_id: 1072,
  #       display_order: 100,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 906,
  #       question_id: 20,
  #       trait_value_id: 1073,
  #       display_order: 90,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 907,
  #       question_id: 20,
  #       trait_value_id: 1074,
  #       display_order: 100,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 908,
  #       question_id: 42,
  #       trait_value_id: 1076,
  #       display_order: 1,
  #       text: "4'0\" or under"
  #     },
  #     %{
  #       id: 909,
  #       question_id: 42,
  #       trait_value_id: 1077,
  #       display_order: 2,
  #       text: "4'1\" - 4'6\""
  #     },
  #     %{
  #       id: 910,
  #       question_id: 42,
  #       trait_value_id: 1078,
  #       display_order: 3,
  #       text: "4'7\" - 5'0\""
  #     },
  #     %{
  #       id: 911,
  #       question_id: 42,
  #       trait_value_id: 1079,
  #       display_order: 4,
  #       text: "5'1\""
  #     },
  #     %{
  #       id: 912,
  #       question_id: 42,
  #       trait_value_id: 1080,
  #       display_order: 5,
  #       text: "5'2\""
  #     },
  #     %{
  #       id: 913,
  #       question_id: 42,
  #       trait_value_id: 1081,
  #       display_order: 6,
  #       text: "5'3\""
  #     },
  #     %{
  #       id: 914,
  #       question_id: 42,
  #       trait_value_id: 1082,
  #       display_order: 7,
  #       text: "5'4\""
  #     },
  #     %{
  #       id: 915,
  #       question_id: 42,
  #       trait_value_id: 1083,
  #       display_order: 8,
  #       text: "5'5\""
  #     },
  #     %{
  #       id: 916,
  #       question_id: 42,
  #       trait_value_id: 1084,
  #       display_order: 9,
  #       text: "5'6\""
  #     },
  #     %{
  #       id: 917,
  #       question_id: 42,
  #       trait_value_id: 1085,
  #       display_order: 10,
  #       text: "5'7\""
  #     },
  #     %{
  #       id: 918,
  #       question_id: 42,
  #       trait_value_id: 1086,
  #       display_order: 11,
  #       text: "5'8\""
  #     },
  #     %{
  #       id: 919,
  #       question_id: 42,
  #       trait_value_id: 1087,
  #       display_order: 12,
  #       text: "5'9\""
  #     },
  #     %{
  #       id: 920,
  #       question_id: 42,
  #       trait_value_id: 1088,
  #       display_order: 13,
  #       text: "5'10\""
  #     },
  #     %{
  #       id: 921,
  #       question_id: 42,
  #       trait_value_id: 1089,
  #       display_order: 14,
  #       text: "5'11\""
  #     },
  #     %{
  #       id: 922,
  #       question_id: 42,
  #       trait_value_id: 1090,
  #       display_order: 15,
  #       text: "6'0\""
  #     },
  #     %{
  #       id: 923,
  #       question_id: 42,
  #       trait_value_id: 1091,
  #       display_order: 16,
  #       text: "6'1\" - 6'3\""
  #     },
  #     %{
  #       id: 924,
  #       question_id: 42,
  #       trait_value_id: 1092,
  #       display_order: 17,
  #       text: "6'4\" - 6'6\""
  #     },
  #     %{
  #       id: 925,
  #       question_id: 42,
  #       trait_value_id: 1093,
  #       display_order: 18,
  #       text: "6'7\" - 6'9\""
  #     },
  #     %{
  #       id: 926,
  #       question_id: 42,
  #       trait_value_id: 1094,
  #       display_order: 19,
  #       text: "7'0\" and above"
  #     },
  #     %{
  #       id: 927,
  #       question_id: 42,
  #       trait_value_id: 1095,
  #       display_order: 20,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 928,
  #       question_id: 43,
  #       trait_value_id: 1097,
  #       display_order: 1,
  #       text: "70 lbs or less"
  #     },
  #     %{
  #       id: 929,
  #       question_id: 43,
  #       trait_value_id: 1098,
  #       display_order: 2,
  #       text: "71 - 80 lbs"
  #     },
  #     %{
  #       id: 930,
  #       question_id: 43,
  #       trait_value_id: 1099,
  #       display_order: 3,
  #       text: "81 - 90 lbs"
  #     },
  #     %{
  #       id: 931,
  #       question_id: 43,
  #       trait_value_id: 1100,
  #       display_order: 4,
  #       text: "91 - 100 lbs"
  #     },
  #     %{
  #       id: 932,
  #       question_id: 43,
  #       trait_value_id: 1101,
  #       display_order: 5,
  #       text: "101 - 110 lbs"
  #     },
  #     %{
  #       id: 933,
  #       question_id: 43,
  #       trait_value_id: 1102,
  #       display_order: 6,
  #       text: "111 - 120 lbs"
  #     },
  #     %{
  #       id: 934,
  #       question_id: 43,
  #       trait_value_id: 1103,
  #       display_order: 7,
  #       text: "121 - 130 lbs"
  #     },
  #     %{
  #       id: 935,
  #       question_id: 43,
  #       trait_value_id: 1104,
  #       display_order: 8,
  #       text: "131 - 140 lbs"
  #     },
  #     %{
  #       id: 936,
  #       question_id: 43,
  #       trait_value_id: 1105,
  #       display_order: 9,
  #       text: "141 - 150 lbs"
  #     },
  #     %{
  #       id: 937,
  #       question_id: 43,
  #       trait_value_id: 1106,
  #       display_order: 10,
  #       text: "151 - 160 lbs"
  #     },
  #     %{
  #       id: 938,
  #       question_id: 43,
  #       trait_value_id: 1107,
  #       display_order: 11,
  #       text: "161 - 170 lbs"
  #     },
  #     %{
  #       id: 939,
  #       question_id: 43,
  #       trait_value_id: 1108,
  #       display_order: 12,
  #       text: "171 - 180 lbs"
  #     },
  #     %{
  #       id: 940,
  #       question_id: 43,
  #       trait_value_id: 1109,
  #       display_order: 13,
  #       text: "181 - 190 lbs"
  #     },
  #     %{
  #       id: 941,
  #       question_id: 43,
  #       trait_value_id: 1110,
  #       display_order: 14,
  #       text: "191 - 200 lbs"
  #     },
  #     %{
  #       id: 942,
  #       question_id: 43,
  #       trait_value_id: 1111,
  #       display_order: 15,
  #       text: "201 - 210 lbs"
  #     },
  #     %{
  #       id: 943,
  #       question_id: 43,
  #       trait_value_id: 1112,
  #       display_order: 16,
  #       text: "211 - 220 lbs"
  #     },
  #     %{
  #       id: 944,
  #       question_id: 43,
  #       trait_value_id: 1113,
  #       display_order: 17,
  #       text: "221 - 230 lbs"
  #     },
  #     %{
  #       id: 945,
  #       question_id: 43,
  #       trait_value_id: 1114,
  #       display_order: 18,
  #       text: "231 - 240 lbs"
  #     },
  #     %{
  #       id: 946,
  #       question_id: 43,
  #       trait_value_id: 1115,
  #       display_order: 19,
  #       text: "241 - 250 lbs"
  #     },
  #     %{
  #       id: 947,
  #       question_id: 43,
  #       trait_value_id: 1116,
  #       display_order: 20,
  #       text: "251 - 275 lbs"
  #     },
  #     %{
  #       id: 948,
  #       question_id: 43,
  #       trait_value_id: 1117,
  #       display_order: 21,
  #       text: "276 - 300 lbs"
  #     },
  #     %{
  #       id: 949,
  #       question_id: 43,
  #       trait_value_id: 1118,
  #       display_order: 22,
  #       text: "301 - 325 lbs"
  #     },
  #     %{
  #       id: 950,
  #       question_id: 43,
  #       trait_value_id: 1119,
  #       display_order: 23,
  #       text: "326 - 350 lbs"
  #     },
  #     %{
  #       id: 951,
  #       question_id: 43,
  #       trait_value_id: 1120,
  #       display_order: 24,
  #       text: "351 - 375 lbs"
  #     },
  #     %{
  #       id: 952,
  #       question_id: 43,
  #       trait_value_id: 1121,
  #       display_order: 25,
  #       text: "376 - 400 lbs"
  #     },
  #     %{
  #       id: 953,
  #       question_id: 43,
  #       trait_value_id: 1122,
  #       display_order: 26,
  #       text: "401 lbs or more"
  #     },
  #     %{
  #       id: 954,
  #       question_id: 43,
  #       trait_value_id: 1123,
  #       display_order: 27,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 955,
  #       question_id: 44,
  #       trait_value_id: 1125,
  #       display_order: 1,
  #       text: "Severely underweight"
  #     },
  #     %{
  #       id: 956,
  #       question_id: 44,
  #       trait_value_id: 1126,
  #       display_order: 2,
  #       text: "Slightly underweight"
  #     },
  #     %{
  #       id: 957,
  #       question_id: 44,
  #       trait_value_id: 1127,
  #       display_order: 3,
  #       text: "Average"
  #     },
  #     %{
  #       id: 958,
  #       question_id: 44,
  #       trait_value_id: 1128,
  #       display_order: 4,
  #       text: "Slightly overweight"
  #     },
  #     %{
  #       id: 959,
  #       question_id: 44,
  #       trait_value_id: 1129,
  #       display_order: 5,
  #       text: "Moderately overweight"
  #     },
  #     %{
  #       id: 960,
  #       question_id: 44,
  #       trait_value_id: 1130,
  #       display_order: 6,
  #       text: "Severely overweight"
  #     },
  #     %{
  #       id: 961,
  #       question_id: 44,
  #       trait_value_id: 1131,
  #       display_order: 7,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 962,
  #       question_id: 45,
  #       trait_value_id: 1133,
  #       display_order: 1,
  #       text: "Gain weight"
  #     },
  #     %{
  #       id: 963,
  #       question_id: 45,
  #       trait_value_id: 1134,
  #       display_order: 2,
  #       text: "Lose weight"
  #     },
  #     %{
  #       id: 964,
  #       question_id: 45,
  #       trait_value_id: 1135,
  #       display_order: 3,
  #       text: "Maintain current weight"
  #     },
  #     %{
  #       id: 965,
  #       question_id: 45,
  #       trait_value_id: 1136,
  #       display_order: 4,
  #       text: "Build muscle"
  #     },
  #     %{
  #       id: 966,
  #       question_id: 45,
  #       trait_value_id: 1137,
  #       display_order: 5,
  #       text: "Firm up"
  #     },
  #     %{
  #       id: 967,
  #       question_id: 45,
  #       trait_value_id: 1138,
  #       display_order: 6,
  #       text: "Gain strength"
  #     },
  #     %{
  #       id: 968,
  #       question_id: 45,
  #       trait_value_id: 1139,
  #       display_order: 7,
  #       text: "Increase aerobic stamina"
  #     },
  #     %{
  #       id: 969,
  #       question_id: 45,
  #       trait_value_id: 1140,
  #       display_order: 8,
  #       text: "Increase flexibility"
  #     },
  #     %{
  #       id: 970,
  #       question_id: 45,
  #       trait_value_id: 1141,
  #       display_order: 9,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 971,
  #       question_id: 45,
  #       trait_value_id: 1142,
  #       display_order: 10,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 972,
  #       question_id: 16,
  #       trait_value_id: 1143,
  #       display_order: 199,
  #       text: "No children"
  #     },
  #     %{
  #       id: 973,
  #       question_id: 23,
  #       trait_value_id: 1144,
  #       display_order: 751,
  #       text: "University of Dayton"
  #     },
  #     %{
  #       id: 974,
  #       question_id: 46,
  #       trait_value_id: 1146,
  #       display_order: 1,
  #       text: "Every day"
  #     },
  #     %{
  #       id: 975,
  #       question_id: 46,
  #       trait_value_id: 1147,
  #       display_order: 2,
  #       text: "A few times a week"
  #     },
  #     %{
  #       id: 976,
  #       question_id: 46,
  #       trait_value_id: 1148,
  #       display_order: 3,
  #       text: "Once a week"
  #     },
  #     %{
  #       id: 977,
  #       question_id: 46,
  #       trait_value_id: 1149,
  #       display_order: 4,
  #       text: "2-3 times a month"
  #     },
  #     %{
  #       id: 978,
  #       question_id: 46,
  #       trait_value_id: 1150,
  #       display_order: 5,
  #       text: "Once a month"
  #     },
  #     %{
  #       id: 979,
  #       question_id: 46,
  #       trait_value_id: 1151,
  #       display_order: 6,
  #       text: "Once every 2-3 months"
  #     },
  #     %{
  #       id: 980,
  #       question_id: 46,
  #       trait_value_id: 1152,
  #       display_order: 7,
  #       text: "Less than once every 2-3 months"
  #     },
  #     %{
  #       id: 981,
  #       question_id: 46,
  #       trait_value_id: 1153,
  #       display_order: 8,
  #       text: "Never"
  #     },
  #     %{
  #       id: 982,
  #       question_id: 46,
  #       trait_value_id: 1154,
  #       display_order: 9,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 983,
  #       question_id: 47,
  #       trait_value_id: 1156,
  #       display_order: 1,
  #       text: "None"
  #     },
  #     %{
  #       id: 984,
  #       question_id: 47,
  #       trait_value_id: 1157,
  #       display_order: 2,
  #       text: "1 - 12"
  #     },
  #     %{
  #       id: 985,
  #       question_id: 47,
  #       trait_value_id: 1158,
  #       display_order: 3,
  #       text: "13 - 50"
  #     },
  #     %{
  #       id: 986,
  #       question_id: 47,
  #       trait_value_id: 1159,
  #       display_order: 4,
  #       text: "51 - 100"
  #     },
  #     %{
  #       id: 987,
  #       question_id: 47,
  #       trait_value_id: 1160,
  #       display_order: 5,
  #       text: "Over 100"
  #     },
  #     %{
  #       id: 988,
  #       question_id: 47,
  #       trait_value_id: 1161,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 989,
  #       question_id: 48,
  #       trait_value_id: 1163,
  #       display_order: 1,
  #       text: "Cabernet Sauvignon"
  #     },
  #     %{
  #       id: 990,
  #       question_id: 48,
  #       trait_value_id: 1164,
  #       display_order: 2,
  #       text: "Merlot"
  #     },
  #     %{
  #       id: 991,
  #       question_id: 48,
  #       trait_value_id: 1165,
  #       display_order: 3,
  #       text: "Pinot Noir"
  #     },
  #     %{
  #       id: 992,
  #       question_id: 48,
  #       trait_value_id: 1166,
  #       display_order: 4,
  #       text: "Red Zinfandel"
  #     },
  #     %{
  #       id: 993,
  #       question_id: 48,
  #       trait_value_id: 1167,
  #       display_order: 5,
  #       text: "Syrah/Shiraz"
  #     },
  #     %{
  #       id: 994,
  #       question_id: 48,
  #       trait_value_id: 1168,
  #       display_order: 6,
  #       text: "Sangiovese"
  #     },
  #     %{
  #       id: 995,
  #       question_id: 48,
  #       trait_value_id: 1169,
  #       display_order: 7,
  #       text: "Chardonnay"
  #     },
  #     %{
  #       id: 996,
  #       question_id: 48,
  #       trait_value_id: 1170,
  #       display_order: 8,
  #       text: "Chablis"
  #     },
  #     %{
  #       id: 997,
  #       question_id: 48,
  #       trait_value_id: 1171,
  #       display_order: 9,
  #       text: "Sauvignon Blanc"
  #     },
  #     %{
  #       id: 998,
  #       question_id: 48,
  #       trait_value_id: 1172,
  #       display_order: 10,
  #       text: "Semillon"
  #     },
  #     %{
  #       id: 999,
  #       question_id: 48,
  #       trait_value_id: 1173,
  #       display_order: 11,
  #       text: "Rieslings"
  #     },
  #     %{
  #       id: 1000,
  #       question_id: 48,
  #       trait_value_id: 1174,
  #       display_order: 12,
  #       text: "Pinot Grigio/Pinot Gris"
  #     },
  #     %{
  #       id: 1001,
  #       question_id: 48,
  #       trait_value_id: 1175,
  #       display_order: 13,
  #       text: "White Zinfandel"
  #     },
  #     %{
  #       id: 1002,
  #       question_id: 48,
  #       trait_value_id: 1176,
  #       display_order: 14,
  #       text: "Champagne"
  #     },
  #     %{
  #       id: 1003,
  #       question_id: 48,
  #       trait_value_id: 1177,
  #       display_order: 15,
  #       text: "Port"
  #     },
  #     %{
  #       id: 1004,
  #       question_id: 48,
  #       trait_value_id: 1178,
  #       display_order: 16,
  #       text: "Sherry"
  #     },
  #     %{
  #       id: 1005,
  #       question_id: 48,
  #       trait_value_id: 1179,
  #       display_order: 17,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 1006,
  #       question_id: 48,
  #       trait_value_id: 1180,
  #       display_order: 18,
  #       text: "No preference - none of the above"
  #     },
  #     %{
  #       id: 1007,
  #       question_id: 48,
  #       trait_value_id: 1181,
  #       display_order: 19,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1008,
  #       question_id: 49,
  #       trait_value_id: 1183,
  #       display_order: 1,
  #       text: "1 - I can't be bothered to recycle or anything."
  #     },
  #     %{
  #       id: 1009,
  #       question_id: 49,
  #       trait_value_id: 1184,
  #       display_order: 2,
  #       text: "2"
  #     },
  #     %{
  #       id: 1010,
  #       question_id: 49,
  #       trait_value_id: 1185,
  #       display_order: 3,
  #       text: "3"
  #     },
  #     %{
  #       id: 1011,
  #       question_id: 49,
  #       trait_value_id: 1186,
  #       display_order: 4,
  #       text: "4 - I recycle."
  #     },
  #     %{
  #       id: 1012,
  #       question_id: 49,
  #       trait_value_id: 1187,
  #       display_order: 5,
  #       text: "5"
  #     },
  #     %{
  #       id: 1013,
  #       question_id: 49,
  #       trait_value_id: 1188,
  #       display_order: 6,
  #       text: "6"
  #     },
  #     %{
  #       id: 1014,
  #       question_id: 49,
  #       trait_value_id: 1189,
  #       display_order: 7,
  #       text:
  #         "7 - I only use green cleaning products and have energy-saving light bulbs. That said, I could always be better."
  #     },
  #     %{
  #       id: 1015,
  #       question_id: 49,
  #       trait_value_id: 1190,
  #       display_order: 8,
  #       text: "8"
  #     },
  #     %{
  #       id: 1016,
  #       question_id: 49,
  #       trait_value_id: 1191,
  #       display_order: 9,
  #       text: "9"
  #     },
  #     %{
  #       id: 1017,
  #       question_id: 49,
  #       trait_value_id: 1192,
  #       display_order: 10,
  #       text:
  #         "10 - I rely on solar or wind energy, own only eco-furniture, compost, and own a hybrid car."
  #     },
  #     %{
  #       id: 1018,
  #       question_id: 50,
  #       trait_value_id: 1194,
  #       display_order: 1,
  #       text: "Less green than now"
  #     },
  #     %{
  #       id: 1019,
  #       question_id: 50,
  #       trait_value_id: 1195,
  #       display_order: 2,
  #       text: "Same as now"
  #     },
  #     %{
  #       id: 1020,
  #       question_id: 50,
  #       trait_value_id: 1196,
  #       display_order: 3,
  #       text: "More green than now"
  #     },
  #     %{
  #       id: 1021,
  #       question_id: 50,
  #       trait_value_id: 1197,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1022,
  #       question_id: 49,
  #       trait_value_id: 1198,
  #       display_order: 100,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1023,
  #       question_id: 51,
  #       trait_value_id: 1200,
  #       display_order: 1,
  #       text: "Always"
  #     },
  #     %{
  #       id: 1024,
  #       question_id: 51,
  #       trait_value_id: 1201,
  #       display_order: 2,
  #       text: "Often"
  #     },
  #     %{
  #       id: 1025,
  #       question_id: 51,
  #       trait_value_id: 1202,
  #       display_order: 3,
  #       text: "Sometimes"
  #     },
  #     %{
  #       id: 1026,
  #       question_id: 51,
  #       trait_value_id: 1203,
  #       display_order: 4,
  #       text: "Rarely"
  #     },
  #     %{
  #       id: 1027,
  #       question_id: 51,
  #       trait_value_id: 1204,
  #       display_order: 5,
  #       text: "Never"
  #     },
  #     %{
  #       id: 1028,
  #       question_id: 51,
  #       trait_value_id: 1205,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1029,
  #       question_id: 52,
  #       trait_value_id: 1207,
  #       display_order: 1,
  #       text: "Glass"
  #     },
  #     %{
  #       id: 1030,
  #       question_id: 52,
  #       trait_value_id: 1208,
  #       display_order: 2,
  #       text: "Plastics"
  #     },
  #     %{
  #       id: 1031,
  #       question_id: 52,
  #       trait_value_id: 1209,
  #       display_order: 3,
  #       text: "Paper"
  #     },
  #     %{
  #       id: 1032,
  #       question_id: 52,
  #       trait_value_id: 1210,
  #       display_order: 4,
  #       text: "Aluminum (cans)"
  #     },
  #     %{
  #       id: 1033,
  #       question_id: 52,
  #       trait_value_id: 1211,
  #       display_order: 5,
  #       text: "Plant matter (compost)"
  #     },
  #     %{
  #       id: 1034,
  #       question_id: 52,
  #       trait_value_id: 1212,
  #       display_order: 6,
  #       text: "Batteries"
  #     },
  #     %{
  #       id: 1035,
  #       question_id: 52,
  #       trait_value_id: 1213,
  #       display_order: 7,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 1036,
  #       question_id: 52,
  #       trait_value_id: 1214,
  #       display_order: 8,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1037,
  #       question_id: 53,
  #       trait_value_id: 1216,
  #       display_order: 1,
  #       text: "None"
  #     },
  #     %{
  #       id: 1038,
  #       question_id: 53,
  #       trait_value_id: 1217,
  #       display_order: 2,
  #       text: "1-3"
  #     },
  #     %{
  #       id: 1039,
  #       question_id: 53,
  #       trait_value_id: 1218,
  #       display_order: 3,
  #       text: "4-12"
  #     },
  #     %{
  #       id: 1040,
  #       question_id: 53,
  #       trait_value_id: 1219,
  #       display_order: 4,
  #       text: "13-20"
  #     },
  #     %{
  #       id: 1041,
  #       question_id: 53,
  #       trait_value_id: 1220,
  #       display_order: 5,
  #       text: "21+"
  #     },
  #     %{
  #       id: 1042,
  #       question_id: 53,
  #       trait_value_id: 1221,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1043,
  #       question_id: 54,
  #       trait_value_id: 1223,
  #       display_order: 1,
  #       text: "Arts, Theatre, & Cinema"
  #     },
  #     %{
  #       id: 1044,
  #       question_id: 54,
  #       trait_value_id: 1224,
  #       display_order: 2,
  #       text: "Biographies & Memoirs"
  #     },
  #     %{
  #       id: 1045,
  #       question_id: 54,
  #       trait_value_id: 1225,
  #       display_order: 3,
  #       text: "Business & Investing"
  #     },
  #     %{
  #       id: 1046,
  #       question_id: 54,
  #       trait_value_id: 1226,
  #       display_order: 4,
  #       text: "Children/Young Adult Books"
  #     },
  #     %{
  #       id: 1047,
  #       question_id: 54,
  #       trait_value_id: 1227,
  #       display_order: 5,
  #       text: "Christian Books"
  #     },
  #     %{
  #       id: 1048,
  #       question_id: 54,
  #       trait_value_id: 1228,
  #       display_order: 6,
  #       text: "Classic Literature"
  #     },
  #     %{
  #       id: 1049,
  #       question_id: 54,
  #       trait_value_id: 1229,
  #       display_order: 7,
  #       text: "Comics & Graphic Novels"
  #     },
  #     %{
  #       id: 1050,
  #       question_id: 54,
  #       trait_value_id: 1230,
  #       display_order: 8,
  #       text: "Computers & Internet"
  #     },
  #     %{
  #       id: 1051,
  #       question_id: 54,
  #       trait_value_id: 1231,
  #       display_order: 9,
  #       text: "Cooking, Food & Wine"
  #     },
  #     %{
  #       id: 1052,
  #       question_id: 54,
  #       trait_value_id: 1232,
  #       display_order: 10,
  #       text: "Crafts & Hobbies"
  #     },
  #     %{
  #       id: 1053,
  #       question_id: 54,
  #       trait_value_id: 1233,
  #       display_order: 11,
  #       text: "Economics"
  #     },
  #     %{
  #       id: 1054,
  #       question_id: 54,
  #       trait_value_id: 1234,
  #       display_order: 12,
  #       text: "Entertainment/Movies/Music"
  #     },
  #     %{
  #       id: 1055,
  #       question_id: 54,
  #       trait_value_id: 1235,
  #       display_order: 13,
  #       text: "Erotica"
  #     },
  #     %{
  #       id: 1056,
  #       question_id: 54,
  #       trait_value_id: 1236,
  #       display_order: 14,
  #       text: "Gay & Lesbian"
  #     },
  #     %{
  #       id: 1057,
  #       question_id: 54,
  #       trait_value_id: 1237,
  #       display_order: 15,
  #       text: "Health, Mind & Body"
  #     },
  #     %{
  #       id: 1058,
  #       question_id: 54,
  #       trait_value_id: 1238,
  #       display_order: 16,
  #       text: "History"
  #     },
  #     %{
  #       id: 1059,
  #       question_id: 54,
  #       trait_value_id: 1239,
  #       display_order: 17,
  #       text: "Historical Fiction"
  #     },
  #     %{
  #       id: 1060,
  #       question_id: 54,
  #       trait_value_id: 1240,
  #       display_order: 18,
  #       text: "Home & Garden"
  #     },
  #     %{
  #       id: 1061,
  #       question_id: 54,
  #       trait_value_id: 1241,
  #       display_order: 19,
  #       text: "Horror"
  #     },
  #     %{
  #       id: 1062,
  #       question_id: 54,
  #       trait_value_id: 1242,
  #       display_order: 20,
  #       text: "How-To/Do-It-Yourself"
  #     },
  #     %{
  #       id: 1063,
  #       question_id: 54,
  #       trait_value_id: 1243,
  #       display_order: 21,
  #       text: "Humor/Satire"
  #     },
  #     %{
  #       id: 1064,
  #       question_id: 54,
  #       trait_value_id: 1244,
  #       display_order: 22,
  #       text: "Marketing"
  #     },
  #     %{
  #       id: 1065,
  #       question_id: 54,
  #       trait_value_id: 1245,
  #       display_order: 23,
  #       text: "Medicine & Nutrition"
  #     },
  #     %{
  #       id: 1066,
  #       question_id: 54,
  #       trait_value_id: 1246,
  #       display_order: 24,
  #       text: "Mystery & Thrillers"
  #     },
  #     %{
  #       id: 1067,
  #       question_id: 54,
  #       trait_value_id: 1247,
  #       display_order: 25,
  #       text: "Nonfiction"
  #     },
  #     %{
  #       id: 1068,
  #       question_id: 54,
  #       trait_value_id: 1248,
  #       display_order: 26,
  #       text: "Outdoors & Nature"
  #     },
  #     %{
  #       id: 1069,
  #       question_id: 54,
  #       trait_value_id: 1249,
  #       display_order: 27,
  #       text: "Parenting & Families"
  #     },
  #     %{
  #       id: 1070,
  #       question_id: 54,
  #       trait_value_id: 1250,
  #       display_order: 28,
  #       text: "Philosophy"
  #     },
  #     %{
  #       id: 1071,
  #       question_id: 54,
  #       trait_value_id: 1251,
  #       display_order: 29,
  #       text: "Photography"
  #     },
  #     %{
  #       id: 1072,
  #       question_id: 54,
  #       trait_value_id: 1252,
  #       display_order: 30,
  #       text: "Poetry"
  #     },
  #     %{
  #       id: 1073,
  #       question_id: 54,
  #       trait_value_id: 1253,
  #       display_order: 31,
  #       text: "Politics"
  #     },
  #     %{
  #       id: 1074,
  #       question_id: 54,
  #       trait_value_id: 1254,
  #       display_order: 32,
  #       text: "Professional & Technical"
  #     },
  #     %{
  #       id: 1075,
  #       question_id: 54,
  #       trait_value_id: 1255,
  #       display_order: 33,
  #       text: "Religion & Spirituality"
  #     },
  #     %{
  #       id: 1076,
  #       question_id: 54,
  #       trait_value_id: 1256,
  #       display_order: 34,
  #       text: "Romance"
  #     },
  #     %{
  #       id: 1077,
  #       question_id: 54,
  #       trait_value_id: 1257,
  #       display_order: 35,
  #       text: "Science"
  #     },
  #     %{
  #       id: 1078,
  #       question_id: 54,
  #       trait_value_id: 1258,
  #       display_order: 36,
  #       text: "Science Fiction & Fantasy"
  #     },
  #     %{
  #       id: 1079,
  #       question_id: 54,
  #       trait_value_id: 1259,
  #       display_order: 37,
  #       text: "Self-Help"
  #     },
  #     %{
  #       id: 1080,
  #       question_id: 54,
  #       trait_value_id: 1260,
  #       display_order: 38,
  #       text: "Sports"
  #     },
  #     %{
  #       id: 1081,
  #       question_id: 54,
  #       trait_value_id: 1261,
  #       display_order: 39,
  #       text: "Textbooks"
  #     },
  #     %{
  #       id: 1082,
  #       question_id: 54,
  #       trait_value_id: 1262,
  #       display_order: 40,
  #       text: "Travel"
  #     },
  #     %{
  #       id: 1083,
  #       question_id: 55,
  #       trait_value_id: 1264,
  #       display_order: 1,
  #       text: "Ballet"
  #     },
  #     %{
  #       id: 1084,
  #       question_id: 55,
  #       trait_value_id: 1265,
  #       display_order: 2,
  #       text: "Chamber Music Performance"
  #     },
  #     %{
  #       id: 1085,
  #       question_id: 55,
  #       trait_value_id: 1266,
  #       display_order: 3,
  #       text: "Dinner Theatre"
  #     },
  #     %{
  #       id: 1086,
  #       question_id: 55,
  #       trait_value_id: 1267,
  #       display_order: 4,
  #       text: "Lectures"
  #     },
  #     %{
  #       id: 1087,
  #       question_id: 55,
  #       trait_value_id: 1268,
  #       display_order: 5,
  #       text: "Modern Dance"
  #     },
  #     %{
  #       id: 1088,
  #       question_id: 55,
  #       trait_value_id: 1269,
  #       display_order: 6,
  #       text: "Opera"
  #     },
  #     %{
  #       id: 1089,
  #       question_id: 55,
  #       trait_value_id: 1270,
  #       display_order: 7,
  #       text: "Orchestral Performance/Symphony"
  #     },
  #     %{
  #       id: 1090,
  #       question_id: 55,
  #       trait_value_id: 1271,
  #       display_order: 8,
  #       text: "Poetry Reading"
  #     },
  #     %{
  #       id: 1091,
  #       question_id: 55,
  #       trait_value_id: 1272,
  #       display_order: 9,
  #       text: "Theatre/Play - Comedy"
  #     },
  #     %{
  #       id: 1092,
  #       question_id: 55,
  #       trait_value_id: 1273,
  #       display_order: 10,
  #       text: "Theatre/Play - Dramatic"
  #     },
  #     %{
  #       id: 1093,
  #       question_id: 55,
  #       trait_value_id: 1274,
  #       display_order: 11,
  #       text: "Theatre/Play - Musical"
  #     },
  #     %{
  #       id: 1094,
  #       question_id: 56,
  #       trait_value_id: 1276,
  #       display_order: 1,
  #       text: "Never"
  #     },
  #     %{
  #       id: 1095,
  #       question_id: 56,
  #       trait_value_id: 1277,
  #       display_order: 2,
  #       text: "1-2"
  #     },
  #     %{
  #       id: 1096,
  #       question_id: 56,
  #       trait_value_id: 1278,
  #       display_order: 3,
  #       text: "3-10"
  #     },
  #     %{
  #       id: 1097,
  #       question_id: 56,
  #       trait_value_id: 1279,
  #       display_order: 4,
  #       text: "11+"
  #     },
  #     %{
  #       id: 1098,
  #       question_id: 23,
  #       trait_value_id: 1281,
  #       display_order: 286,
  #       text: "Green River Community College"
  #     },
  #     %{
  #       id: 1099,
  #       question_id: 23,
  #       trait_value_id: 1282,
  #       display_order: 415,
  #       text: "Massachusetts Institute of Technology"
  #     },
  #     %{
  #       id: 1100,
  #       question_id: 57,
  #       trait_value_id: 1284,
  #       display_order: 1,
  #       text: "2 Petite"
  #     },
  #     %{
  #       id: 1101,
  #       question_id: 57,
  #       trait_value_id: 1285,
  #       display_order: 2,
  #       text: "4 Petite"
  #     },
  #     %{
  #       id: 1102,
  #       question_id: 57,
  #       trait_value_id: 1286,
  #       display_order: 3,
  #       text: "6 Petite"
  #     },
  #     %{
  #       id: 1103,
  #       question_id: 57,
  #       trait_value_id: 1287,
  #       display_order: 4,
  #       text: "8 Petite"
  #     },
  #     %{
  #       id: 1104,
  #       question_id: 57,
  #       trait_value_id: 1288,
  #       display_order: 5,
  #       text: "10 Petite"
  #     },
  #     %{
  #       id: 1105,
  #       question_id: 57,
  #       trait_value_id: 1289,
  #       display_order: 6,
  #       text: "12 Petite"
  #     },
  #     %{
  #       id: 1106,
  #       question_id: 57,
  #       trait_value_id: 1290,
  #       display_order: 7,
  #       text: "14 Petite"
  #     },
  #     %{
  #       id: 1107,
  #       question_id: 57,
  #       trait_value_id: 1291,
  #       display_order: 8,
  #       text: "0"
  #     },
  #     %{
  #       id: 1108,
  #       question_id: 57,
  #       trait_value_id: 1292,
  #       display_order: 9,
  #       text: "2"
  #     },
  #     %{
  #       id: 1109,
  #       question_id: 57,
  #       trait_value_id: 1293,
  #       display_order: 10,
  #       text: "4"
  #     },
  #     %{
  #       id: 1110,
  #       question_id: 57,
  #       trait_value_id: 1294,
  #       display_order: 11,
  #       text: "6"
  #     },
  #     %{
  #       id: 1111,
  #       question_id: 57,
  #       trait_value_id: 1295,
  #       display_order: 12,
  #       text: "8"
  #     },
  #     %{
  #       id: 1112,
  #       question_id: 57,
  #       trait_value_id: 1296,
  #       display_order: 13,
  #       text: "10"
  #     },
  #     %{
  #       id: 1113,
  #       question_id: 57,
  #       trait_value_id: 1297,
  #       display_order: 14,
  #       text: "12"
  #     },
  #     %{
  #       id: 1114,
  #       question_id: 57,
  #       trait_value_id: 1298,
  #       display_order: 15,
  #       text: "14"
  #     },
  #     %{
  #       id: 1115,
  #       question_id: 57,
  #       trait_value_id: 1299,
  #       display_order: 16,
  #       text: "16"
  #     },
  #     %{
  #       id: 1116,
  #       question_id: 57,
  #       trait_value_id: 1300,
  #       display_order: 17,
  #       text: "18"
  #     },
  #     %{
  #       id: 1117,
  #       question_id: 57,
  #       trait_value_id: 1301,
  #       display_order: 18,
  #       text: "20"
  #     },
  #     %{
  #       id: 1118,
  #       question_id: 57,
  #       trait_value_id: 1302,
  #       display_order: 19,
  #       text: "22"
  #     },
  #     %{
  #       id: 1119,
  #       question_id: 57,
  #       trait_value_id: 1303,
  #       display_order: 20,
  #       text: "24"
  #     },
  #     %{
  #       id: 1120,
  #       question_id: 57,
  #       trait_value_id: 1304,
  #       display_order: 21,
  #       text: "14 Plus"
  #     },
  #     %{
  #       id: 1121,
  #       question_id: 57,
  #       trait_value_id: 1305,
  #       display_order: 22,
  #       text: "16 Plus"
  #     },
  #     %{
  #       id: 1122,
  #       question_id: 57,
  #       trait_value_id: 1306,
  #       display_order: 23,
  #       text: "18 Plus"
  #     },
  #     %{
  #       id: 1123,
  #       question_id: 57,
  #       trait_value_id: 1307,
  #       display_order: 24,
  #       text: "20 Plus"
  #     },
  #     %{
  #       id: 1124,
  #       question_id: 57,
  #       trait_value_id: 1308,
  #       display_order: 25,
  #       text: "22 Plus"
  #     },
  #     %{
  #       id: 1125,
  #       question_id: 57,
  #       trait_value_id: 1309,
  #       display_order: 26,
  #       text: "24 Plus"
  #     },
  #     %{
  #       id: 1126,
  #       question_id: 57,
  #       trait_value_id: 1310,
  #       display_order: 27,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1127,
  #       question_id: 58,
  #       trait_value_id: 1312,
  #       display_order: 1,
  #       text: "30 or less"
  #     },
  #     %{
  #       id: 1128,
  #       question_id: 58,
  #       trait_value_id: 1313,
  #       display_order: 2,
  #       text: "32"
  #     },
  #     %{
  #       id: 1129,
  #       question_id: 58,
  #       trait_value_id: 1314,
  #       display_order: 3,
  #       text: "34"
  #     },
  #     %{
  #       id: 1130,
  #       question_id: 58,
  #       trait_value_id: 1315,
  #       display_order: 4,
  #       text: "36"
  #     },
  #     %{
  #       id: 1131,
  #       question_id: 58,
  #       trait_value_id: 1316,
  #       display_order: 5,
  #       text: "38"
  #     },
  #     %{
  #       id: 1132,
  #       question_id: 58,
  #       trait_value_id: 1317,
  #       display_order: 6,
  #       text: "40 and over"
  #     },
  #     %{
  #       id: 1133,
  #       question_id: 58,
  #       trait_value_id: 1318,
  #       display_order: 7,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1134,
  #       question_id: 59,
  #       trait_value_id: 1320,
  #       display_order: 1,
  #       text: "A"
  #     },
  #     %{
  #       id: 1135,
  #       question_id: 59,
  #       trait_value_id: 1321,
  #       display_order: 2,
  #       text: "B"
  #     },
  #     %{
  #       id: 1136,
  #       question_id: 59,
  #       trait_value_id: 1322,
  #       display_order: 3,
  #       text: "C"
  #     },
  #     %{
  #       id: 1137,
  #       question_id: 59,
  #       trait_value_id: 1323,
  #       display_order: 4,
  #       text: "D"
  #     },
  #     %{
  #       id: 1138,
  #       question_id: 59,
  #       trait_value_id: 1324,
  #       display_order: 5,
  #       text: "DD+"
  #     },
  #     %{
  #       id: 1139,
  #       question_id: 59,
  #       trait_value_id: 1325,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1140,
  #       question_id: 60,
  #       trait_value_id: 1327,
  #       display_order: 1,
  #       text: "23 or less"
  #     },
  #     %{
  #       id: 1141,
  #       question_id: 60,
  #       trait_value_id: 1328,
  #       display_order: 2,
  #       text: "24"
  #     },
  #     %{
  #       id: 1142,
  #       question_id: 60,
  #       trait_value_id: 1329,
  #       display_order: 3,
  #       text: "25"
  #     },
  #     %{
  #       id: 1143,
  #       question_id: 60,
  #       trait_value_id: 1330,
  #       display_order: 4,
  #       text: "26"
  #     },
  #     %{
  #       id: 1144,
  #       question_id: 60,
  #       trait_value_id: 1331,
  #       display_order: 5,
  #       text: "27"
  #     },
  #     %{
  #       id: 1145,
  #       question_id: 60,
  #       trait_value_id: 1332,
  #       display_order: 6,
  #       text: "28"
  #     },
  #     %{
  #       id: 1146,
  #       question_id: 60,
  #       trait_value_id: 1333,
  #       display_order: 7,
  #       text: "29"
  #     },
  #     %{
  #       id: 1147,
  #       question_id: 60,
  #       trait_value_id: 1334,
  #       display_order: 8,
  #       text: "30"
  #     },
  #     %{
  #       id: 1148,
  #       question_id: 60,
  #       trait_value_id: 1335,
  #       display_order: 9,
  #       text: "31"
  #     },
  #     %{
  #       id: 1149,
  #       question_id: 60,
  #       trait_value_id: 1336,
  #       display_order: 10,
  #       text: "32"
  #     },
  #     %{
  #       id: 1150,
  #       question_id: 60,
  #       trait_value_id: 1337,
  #       display_order: 11,
  #       text: "33"
  #     },
  #     %{
  #       id: 1151,
  #       question_id: 60,
  #       trait_value_id: 1338,
  #       display_order: 12,
  #       text: "34"
  #     },
  #     %{
  #       id: 1152,
  #       question_id: 60,
  #       trait_value_id: 1339,
  #       display_order: 13,
  #       text: "35"
  #     },
  #     %{
  #       id: 1153,
  #       question_id: 60,
  #       trait_value_id: 1340,
  #       display_order: 14,
  #       text: "36 and over"
  #     },
  #     %{
  #       id: 1154,
  #       question_id: 60,
  #       trait_value_id: 1341,
  #       display_order: 15,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1155,
  #       question_id: 61,
  #       trait_value_id: 1343,
  #       display_order: 1,
  #       text: "33 or less"
  #     },
  #     %{
  #       id: 1156,
  #       question_id: 61,
  #       trait_value_id: 1344,
  #       display_order: 2,
  #       text: "34"
  #     },
  #     %{
  #       id: 1157,
  #       question_id: 61,
  #       trait_value_id: 1345,
  #       display_order: 3,
  #       text: "35"
  #     },
  #     %{
  #       id: 1158,
  #       question_id: 61,
  #       trait_value_id: 1346,
  #       display_order: 4,
  #       text: "36"
  #     },
  #     %{
  #       id: 1159,
  #       question_id: 61,
  #       trait_value_id: 1347,
  #       display_order: 5,
  #       text: "37"
  #     },
  #     %{
  #       id: 1160,
  #       question_id: 61,
  #       trait_value_id: 1348,
  #       display_order: 6,
  #       text: "38"
  #     },
  #     %{
  #       id: 1161,
  #       question_id: 61,
  #       trait_value_id: 1349,
  #       display_order: 7,
  #       text: "39"
  #     },
  #     %{
  #       id: 1162,
  #       question_id: 61,
  #       trait_value_id: 1350,
  #       display_order: 8,
  #       text: "40"
  #     },
  #     %{
  #       id: 1163,
  #       question_id: 61,
  #       trait_value_id: 1351,
  #       display_order: 9,
  #       text: "41"
  #     },
  #     %{
  #       id: 1164,
  #       question_id: 61,
  #       trait_value_id: 1352,
  #       display_order: 10,
  #       text: "42"
  #     },
  #     %{
  #       id: 1165,
  #       question_id: 61,
  #       trait_value_id: 1353,
  #       display_order: 11,
  #       text: "43"
  #     },
  #     %{
  #       id: 1166,
  #       question_id: 61,
  #       trait_value_id: 1354,
  #       display_order: 12,
  #       text: "44 or more"
  #     },
  #     %{
  #       id: 1167,
  #       question_id: 61,
  #       trait_value_id: 1355,
  #       display_order: 13,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1168,
  #       question_id: 62,
  #       trait_value_id: 1357,
  #       display_order: 1,
  #       text: "4.5 or smaller"
  #     },
  #     %{
  #       id: 1169,
  #       question_id: 62,
  #       trait_value_id: 1358,
  #       display_order: 2,
  #       text: "5-5.5"
  #     },
  #     %{
  #       id: 1170,
  #       question_id: 62,
  #       trait_value_id: 1359,
  #       display_order: 3,
  #       text: "6-6.5"
  #     },
  #     %{
  #       id: 1171,
  #       question_id: 62,
  #       trait_value_id: 1360,
  #       display_order: 4,
  #       text: "7-7.5"
  #     },
  #     %{
  #       id: 1172,
  #       question_id: 62,
  #       trait_value_id: 1361,
  #       display_order: 5,
  #       text: "8-8.5"
  #     },
  #     %{
  #       id: 1173,
  #       question_id: 62,
  #       trait_value_id: 1362,
  #       display_order: 6,
  #       text: "9-9.5"
  #     },
  #     %{
  #       id: 1174,
  #       question_id: 62,
  #       trait_value_id: 1363,
  #       display_order: 7,
  #       text: "10-10.5"
  #     },
  #     %{
  #       id: 1175,
  #       question_id: 62,
  #       trait_value_id: 1364,
  #       display_order: 8,
  #       text: "11 or larger"
  #     },
  #     %{
  #       id: 1176,
  #       question_id: 62,
  #       trait_value_id: 1365,
  #       display_order: 9,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1177,
  #       question_id: 63,
  #       trait_value_id: 1367,
  #       display_order: 1,
  #       text: "Narrow"
  #     },
  #     %{
  #       id: 1178,
  #       question_id: 63,
  #       trait_value_id: 1368,
  #       display_order: 2,
  #       text: "Standard"
  #     },
  #     %{
  #       id: 1179,
  #       question_id: 63,
  #       trait_value_id: 1369,
  #       display_order: 3,
  #       text: "Wide"
  #     },
  #     %{
  #       id: 1180,
  #       question_id: 63,
  #       trait_value_id: 1370,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1181,
  #       question_id: 64,
  #       trait_value_id: 1372,
  #       display_order: 1,
  #       text: "Small"
  #     },
  #     %{
  #       id: 1182,
  #       question_id: 64,
  #       trait_value_id: 1373,
  #       display_order: 2,
  #       text: "Medium"
  #     },
  #     %{
  #       id: 1183,
  #       question_id: 64,
  #       trait_value_id: 1374,
  #       display_order: 3,
  #       text: "Large"
  #     },
  #     %{
  #       id: 1184,
  #       question_id: 64,
  #       trait_value_id: 1375,
  #       display_order: 4,
  #       text: "X-Large"
  #     },
  #     %{
  #       id: 1185,
  #       question_id: 64,
  #       trait_value_id: 1376,
  #       display_order: 5,
  #       text: "XXL or larger"
  #     },
  #     %{
  #       id: 1186,
  #       question_id: 64,
  #       trait_value_id: 1377,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1187,
  #       question_id: 65,
  #       trait_value_id: 1379,
  #       display_order: 1,
  #       text: "13-13.5 or smaller"
  #     },
  #     %{
  #       id: 1188,
  #       question_id: 65,
  #       trait_value_id: 1380,
  #       display_order: 2,
  #       text: "14-14.5"
  #     },
  #     %{
  #       id: 1189,
  #       question_id: 65,
  #       trait_value_id: 1381,
  #       display_order: 3,
  #       text: "15-15.5"
  #     },
  #     %{
  #       id: 1190,
  #       question_id: 65,
  #       trait_value_id: 1382,
  #       display_order: 4,
  #       text: "16-16.5"
  #     },
  #     %{
  #       id: 1191,
  #       question_id: 65,
  #       trait_value_id: 1383,
  #       display_order: 5,
  #       text: "17-17.5"
  #     },
  #     %{
  #       id: 1192,
  #       question_id: 65,
  #       trait_value_id: 1384,
  #       display_order: 6,
  #       text: "18-18.5"
  #     },
  #     %{
  #       id: 1193,
  #       question_id: 65,
  #       trait_value_id: 1385,
  #       display_order: 7,
  #       text: "19-19.5"
  #     },
  #     %{
  #       id: 1194,
  #       question_id: 65,
  #       trait_value_id: 1386,
  #       display_order: 8,
  #       text: "20-20.5 or larger"
  #     },
  #     %{
  #       id: 1195,
  #       question_id: 65,
  #       trait_value_id: 1387,
  #       display_order: 9,
  #       text: "I don't know"
  #     },
  #     %{
  #       id: 1196,
  #       question_id: 65,
  #       trait_value_id: 1388,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1197,
  #       question_id: 66,
  #       trait_value_id: 1390,
  #       display_order: 1,
  #       text: "32 or smaller"
  #     },
  #     %{
  #       id: 1198,
  #       question_id: 66,
  #       trait_value_id: 1391,
  #       display_order: 2,
  #       text: "33"
  #     },
  #     %{
  #       id: 1199,
  #       question_id: 66,
  #       trait_value_id: 1392,
  #       display_order: 3,
  #       text: "34"
  #     },
  #     %{
  #       id: 1200,
  #       question_id: 66,
  #       trait_value_id: 1393,
  #       display_order: 4,
  #       text: "35"
  #     },
  #     %{
  #       id: 1201,
  #       question_id: 66,
  #       trait_value_id: 1394,
  #       display_order: 5,
  #       text: "36"
  #     },
  #     %{
  #       id: 1202,
  #       question_id: 66,
  #       trait_value_id: 1395,
  #       display_order: 6,
  #       text: "37"
  #     },
  #     %{
  #       id: 1203,
  #       question_id: 66,
  #       trait_value_id: 1396,
  #       display_order: 7,
  #       text: "38 or larger"
  #     },
  #     %{
  #       id: 1204,
  #       question_id: 66,
  #       trait_value_id: 1397,
  #       display_order: 8,
  #       text: "I don't know"
  #     },
  #     %{
  #       id: 1205,
  #       question_id: 66,
  #       trait_value_id: 1398,
  #       display_order: 9,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1206,
  #       question_id: 67,
  #       trait_value_id: 1400,
  #       display_order: 1,
  #       text: "32 or smaller"
  #     },
  #     %{
  #       id: 1207,
  #       question_id: 67,
  #       trait_value_id: 1401,
  #       display_order: 2,
  #       text: "34"
  #     },
  #     %{
  #       id: 1208,
  #       question_id: 67,
  #       trait_value_id: 1402,
  #       display_order: 3,
  #       text: "36"
  #     },
  #     %{
  #       id: 1209,
  #       question_id: 67,
  #       trait_value_id: 1403,
  #       display_order: 4,
  #       text: "38"
  #     },
  #     %{
  #       id: 1210,
  #       question_id: 67,
  #       trait_value_id: 1404,
  #       display_order: 5,
  #       text: "40"
  #     },
  #     %{
  #       id: 1211,
  #       question_id: 67,
  #       trait_value_id: 1405,
  #       display_order: 6,
  #       text: "42"
  #     },
  #     %{
  #       id: 1212,
  #       question_id: 67,
  #       trait_value_id: 1406,
  #       display_order: 7,
  #       text: "44"
  #     },
  #     %{
  #       id: 1213,
  #       question_id: 67,
  #       trait_value_id: 1407,
  #       display_order: 8,
  #       text: "46"
  #     },
  #     %{
  #       id: 1214,
  #       question_id: 67,
  #       trait_value_id: 1408,
  #       display_order: 9,
  #       text: "48"
  #     },
  #     %{
  #       id: 1215,
  #       question_id: 67,
  #       trait_value_id: 1409,
  #       display_order: 10,
  #       text: "50"
  #     },
  #     %{
  #       id: 1216,
  #       question_id: 67,
  #       trait_value_id: 1410,
  #       display_order: 11,
  #       text: "52 or larger"
  #     },
  #     %{
  #       id: 1217,
  #       question_id: 67,
  #       trait_value_id: 1411,
  #       display_order: 12,
  #       text: "I don't know"
  #     },
  #     %{
  #       id: 1218,
  #       question_id: 67,
  #       trait_value_id: 1412,
  #       display_order: 13,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1219,
  #       question_id: 68,
  #       trait_value_id: 1414,
  #       display_order: 1,
  #       text: "28 or smaller"
  #     },
  #     %{
  #       id: 1220,
  #       question_id: 68,
  #       trait_value_id: 1415,
  #       display_order: 2,
  #       text: "30"
  #     },
  #     %{
  #       id: 1221,
  #       question_id: 68,
  #       trait_value_id: 1416,
  #       display_order: 3,
  #       text: "32"
  #     },
  #     %{
  #       id: 1222,
  #       question_id: 68,
  #       trait_value_id: 1417,
  #       display_order: 4,
  #       text: "34"
  #     },
  #     %{
  #       id: 1223,
  #       question_id: 68,
  #       trait_value_id: 1418,
  #       display_order: 5,
  #       text: "36"
  #     },
  #     %{
  #       id: 1224,
  #       question_id: 68,
  #       trait_value_id: 1419,
  #       display_order: 6,
  #       text: "38"
  #     },
  #     %{
  #       id: 1225,
  #       question_id: 68,
  #       trait_value_id: 1420,
  #       display_order: 7,
  #       text: "40"
  #     },
  #     %{
  #       id: 1226,
  #       question_id: 68,
  #       trait_value_id: 1421,
  #       display_order: 8,
  #       text: "42"
  #     },
  #     %{
  #       id: 1227,
  #       question_id: 68,
  #       trait_value_id: 1422,
  #       display_order: 9,
  #       text: "44"
  #     },
  #     %{
  #       id: 1228,
  #       question_id: 68,
  #       trait_value_id: 1423,
  #       display_order: 10,
  #       text: "46 or larger"
  #     },
  #     %{
  #       id: 1229,
  #       question_id: 68,
  #       trait_value_id: 1424,
  #       display_order: 11,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1230,
  #       question_id: 69,
  #       trait_value_id: 1426,
  #       display_order: 1,
  #       text: "26 or smaller"
  #     },
  #     %{
  #       id: 1231,
  #       question_id: 69,
  #       trait_value_id: 1427,
  #       display_order: 2,
  #       text: "28"
  #     },
  #     %{
  #       id: 1232,
  #       question_id: 69,
  #       trait_value_id: 1428,
  #       display_order: 3,
  #       text: "30"
  #     },
  #     %{
  #       id: 1233,
  #       question_id: 69,
  #       trait_value_id: 1429,
  #       display_order: 4,
  #       text: "32"
  #     },
  #     %{
  #       id: 1234,
  #       question_id: 69,
  #       trait_value_id: 1430,
  #       display_order: 5,
  #       text: "34"
  #     },
  #     %{
  #       id: 1235,
  #       question_id: 69,
  #       trait_value_id: 1431,
  #       display_order: 6,
  #       text: "36"
  #     },
  #     %{
  #       id: 1236,
  #       question_id: 69,
  #       trait_value_id: 1432,
  #       display_order: 7,
  #       text: "38"
  #     },
  #     %{
  #       id: 1237,
  #       question_id: 69,
  #       trait_value_id: 1433,
  #       display_order: 8,
  #       text: "40"
  #     },
  #     %{
  #       id: 1238,
  #       question_id: 69,
  #       trait_value_id: 1434,
  #       display_order: 9,
  #       text: "42 or larger"
  #     },
  #     %{
  #       id: 1239,
  #       question_id: 69,
  #       trait_value_id: 1435,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1240,
  #       question_id: 70,
  #       trait_value_id: 1437,
  #       display_order: 1,
  #       text: "Smaller than 6"
  #     },
  #     %{
  #       id: 1241,
  #       question_id: 70,
  #       trait_value_id: 1438,
  #       display_order: 2,
  #       text: "6-6.5"
  #     },
  #     %{
  #       id: 1242,
  #       question_id: 70,
  #       trait_value_id: 1439,
  #       display_order: 3,
  #       text: "7-7.5"
  #     },
  #     %{
  #       id: 1243,
  #       question_id: 70,
  #       trait_value_id: 1440,
  #       display_order: 4,
  #       text: "8-8.5"
  #     },
  #     %{
  #       id: 1244,
  #       question_id: 70,
  #       trait_value_id: 1441,
  #       display_order: 5,
  #       text: "9-9.5"
  #     },
  #     %{
  #       id: 1245,
  #       question_id: 70,
  #       trait_value_id: 1442,
  #       display_order: 6,
  #       text: "10-10.5"
  #     },
  #     %{
  #       id: 1246,
  #       question_id: 70,
  #       trait_value_id: 1443,
  #       display_order: 7,
  #       text: "11-11.5"
  #     },
  #     %{
  #       id: 1247,
  #       question_id: 70,
  #       trait_value_id: 1444,
  #       display_order: 8,
  #       text: "12-12.5"
  #     },
  #     %{
  #       id: 1248,
  #       question_id: 70,
  #       trait_value_id: 1445,
  #       display_order: 9,
  #       text: "13-13.5"
  #     },
  #     %{
  #       id: 1249,
  #       question_id: 70,
  #       trait_value_id: 1446,
  #       display_order: 10,
  #       text: "14 or larger"
  #     },
  #     %{
  #       id: 1250,
  #       question_id: 70,
  #       trait_value_id: 1447,
  #       display_order: 11,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1251,
  #       question_id: 71,
  #       trait_value_id: 1367,
  #       display_order: 1,
  #       text: "Narrow"
  #     },
  #     %{
  #       id: 1252,
  #       question_id: 71,
  #       trait_value_id: 1368,
  #       display_order: 2,
  #       text: "Standard"
  #     },
  #     %{
  #       id: 1253,
  #       question_id: 71,
  #       trait_value_id: 1369,
  #       display_order: 3,
  #       text: "Wide"
  #     },
  #     %{
  #       id: 1254,
  #       question_id: 71,
  #       trait_value_id: 1370,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1255,
  #       question_id: 23,
  #       trait_value_id: 1448,
  #       display_order: 51,
  #       text: "Barry University"
  #     },
  #     %{
  #       id: 1256,
  #       question_id: 23,
  #       trait_value_id: 1449,
  #       display_order: 218,
  #       text: "Embry-Riddle Aeronautical University"
  #     },
  #     %{
  #       id: 1257,
  #       question_id: 23,
  #       trait_value_id: 1450,
  #       display_order: 413,
  #       text: "Marymount University"
  #     },
  #     %{
  #       id: 1258,
  #       question_id: 23,
  #       trait_value_id: 1451,
  #       display_order: 492,
  #       text: "Northern Virginia Community College"
  #     },
  #     %{
  #       id: 1259,
  #       question_id: 23,
  #       trait_value_id: 1452,
  #       display_order: 44,
  #       text: "Axia College of University of Phoenix"
  #     },
  #     %{
  #       id: 1260,
  #       question_id: 23,
  #       trait_value_id: 1453,
  #       display_order: 548,
  #       text: "Phillips University"
  #     },
  #     %{
  #       id: 1261,
  #       question_id: 23,
  #       trait_value_id: 1454,
  #       display_order: 80,
  #       text: "Bradley University"
  #     },
  #     %{
  #       id: 1262,
  #       question_id: 23,
  #       trait_value_id: 1455,
  #       display_order: 209,
  #       text: "Eastern University"
  #     },
  #     %{
  #       id: 1263,
  #       question_id: 72,
  #       trait_value_id: 1457,
  #       display_order: 1,
  #       text: "PlayStation 2"
  #     },
  #     %{
  #       id: 1264,
  #       question_id: 72,
  #       trait_value_id: 1458,
  #       display_order: 2,
  #       text: "PlayStation 3"
  #     },
  #     %{
  #       id: 1265,
  #       question_id: 72,
  #       trait_value_id: 1459,
  #       display_order: 3,
  #       text: "XBox 360"
  #     },
  #     %{
  #       id: 1266,
  #       question_id: 72,
  #       trait_value_id: 1460,
  #       display_order: 4,
  #       text: "XBox Original"
  #     },
  #     %{
  #       id: 1267,
  #       question_id: 72,
  #       trait_value_id: 1461,
  #       display_order: 5,
  #       text: "Nintendo Wii"
  #     },
  #     %{
  #       id: 1268,
  #       question_id: 72,
  #       trait_value_id: 1462,
  #       display_order: 6,
  #       text: "Nintendo GameCube"
  #     },
  #     %{
  #       id: 1269,
  #       question_id: 72,
  #       trait_value_id: 1463,
  #       display_order: 7,
  #       text: "PC"
  #     },
  #     %{
  #       id: 1270,
  #       question_id: 72,
  #       trait_value_id: 1464,
  #       display_order: 8,
  #       text: "Mac"
  #     },
  #     %{
  #       id: 1271,
  #       question_id: 72,
  #       trait_value_id: 1465,
  #       display_order: 9,
  #       text: "Other - \"Retro\" Consoles"
  #     },
  #     %{
  #       id: 1272,
  #       question_id: 72,
  #       trait_value_id: 1466,
  #       display_order: 10,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 1273,
  #       question_id: 72,
  #       trait_value_id: 1467,
  #       display_order: 11,
  #       text: "None"
  #     },
  #     %{
  #       id: 1274,
  #       question_id: 72,
  #       trait_value_id: 1468,
  #       display_order: 12,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1275,
  #       question_id: 73,
  #       trait_value_id: 1482,
  #       display_order: 1,
  #       text: "PlayStation Portable (PSP)"
  #     },
  #     %{
  #       id: 1276,
  #       question_id: 73,
  #       trait_value_id: 1483,
  #       display_order: 2,
  #       text: "Nintendo DS"
  #     },
  #     %{
  #       id: 1277,
  #       question_id: 73,
  #       trait_value_id: 1484,
  #       display_order: 3,
  #       text: "Apple iPhone"
  #     },
  #     %{
  #       id: 1278,
  #       question_id: 73,
  #       trait_value_id: 1485,
  #       display_order: 4,
  #       text: "Other - Cellular Device"
  #     },
  #     %{
  #       id: 1279,
  #       question_id: 73,
  #       trait_value_id: 1486,
  #       display_order: 5,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 1280,
  #       question_id: 73,
  #       trait_value_id: 1487,
  #       display_order: 6,
  #       text: "None"
  #     },
  #     %{
  #       id: 1281,
  #       question_id: 73,
  #       trait_value_id: 1488,
  #       display_order: 7,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1282,
  #       question_id: 74,
  #       trait_value_id: 1490,
  #       display_order: 1,
  #       text: "0 (Zero)"
  #     },
  #     %{
  #       id: 1283,
  #       question_id: 74,
  #       trait_value_id: 1491,
  #       display_order: 2,
  #       text: "1-3"
  #     },
  #     %{
  #       id: 1284,
  #       question_id: 74,
  #       trait_value_id: 1492,
  #       display_order: 3,
  #       text: "4-9"
  #     },
  #     %{
  #       id: 1285,
  #       question_id: 74,
  #       trait_value_id: 1493,
  #       display_order: 4,
  #       text: "10-20"
  #     },
  #     %{
  #       id: 1286,
  #       question_id: 74,
  #       trait_value_id: 1494,
  #       display_order: 5,
  #       text: "21+"
  #     },
  #     %{
  #       id: 1287,
  #       question_id: 74,
  #       trait_value_id: 1495,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1288,
  #       question_id: 75,
  #       trait_value_id: 1497,
  #       display_order: 1,
  #       text: "Action"
  #     },
  #     %{
  #       id: 1289,
  #       question_id: 75,
  #       trait_value_id: 1498,
  #       display_order: 2,
  #       text: "Action-adventure"
  #     },
  #     %{
  #       id: 1290,
  #       question_id: 75,
  #       trait_value_id: 1499,
  #       display_order: 3,
  #       text: "Adventure"
  #     },
  #     %{
  #       id: 1291,
  #       question_id: 75,
  #       trait_value_id: 1500,
  #       display_order: 4,
  #       text: "Shooter"
  #     },
  #     %{
  #       id: 1292,
  #       question_id: 75,
  #       trait_value_id: 1501,
  #       display_order: 5,
  #       text: "FPS (First Person Shooter)"
  #     },
  #     %{
  #       id: 1293,
  #       question_id: 75,
  #       trait_value_id: 1502,
  #       display_order: 6,
  #       text: "MMOFPS (Massively-Multiplayer Online First Person Shooter)"
  #     },
  #     %{
  #       id: 1294,
  #       question_id: 75,
  #       trait_value_id: 1503,
  #       display_order: 7,
  #       text: "RPG (Role Playing Games)"
  #     },
  #     %{
  #       id: 1295,
  #       question_id: 75,
  #       trait_value_id: 1504,
  #       display_order: 8,
  #       text: "MMORPG (Massively-Multiplayer Online Role Playing Games)"
  #     },
  #     %{
  #       id: 1296,
  #       question_id: 75,
  #       trait_value_id: 1505,
  #       display_order: 9,
  #       text: "RTS (Real-Time Strategy)"
  #     },
  #     %{
  #       id: 1297,
  #       question_id: 75,
  #       trait_value_id: 1506,
  #       display_order: 10,
  #       text: "MMORTS (Massively-Multiplayer Online Real-Time Strategy)"
  #     },
  #     %{
  #       id: 1298,
  #       question_id: 75,
  #       trait_value_id: 1507,
  #       display_order: 11,
  #       text: "Strategy/Tactics"
  #     },
  #     %{
  #       id: 1299,
  #       question_id: 75,
  #       trait_value_id: 1508,
  #       display_order: 12,
  #       text: "Dance/Rhythm/Music"
  #     },
  #     %{
  #       id: 1300,
  #       question_id: 75,
  #       trait_value_id: 1509,
  #       display_order: 13,
  #       text: "Fighting"
  #     },
  #     %{
  #       id: 1301,
  #       question_id: 75,
  #       trait_value_id: 1510,
  #       display_order: 14,
  #       text: "Simulation - Life"
  #     },
  #     %{
  #       id: 1302,
  #       question_id: 75,
  #       trait_value_id: 1511,
  #       display_order: 15,
  #       text: "Simulation - Vehicle/Flight"
  #     },
  #     %{
  #       id: 1303,
  #       question_id: 75,
  #       trait_value_id: 1512,
  #       display_order: 16,
  #       text: "Puzzles"
  #     },
  #     %{
  #       id: 1304,
  #       question_id: 75,
  #       trait_value_id: 1513,
  #       display_order: 17,
  #       text: "Casual"
  #     },
  #     %{
  #       id: 1305,
  #       question_id: 75,
  #       trait_value_id: 1514,
  #       display_order: 18,
  #       text: "Online Board Games"
  #     },
  #     %{
  #       id: 1306,
  #       question_id: 75,
  #       trait_value_id: 1515,
  #       display_order: 19,
  #       text: "Social Media Games"
  #     },
  #     %{
  #       id: 1307,
  #       question_id: 75,
  #       trait_value_id: 1516,
  #       display_order: 20,
  #       text: "Racing"
  #     },
  #     %{
  #       id: 1308,
  #       question_id: 75,
  #       trait_value_id: 1517,
  #       display_order: 21,
  #       text: "Sports"
  #     },
  #     %{
  #       id: 1309,
  #       question_id: 75,
  #       trait_value_id: 1518,
  #       display_order: 22,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 1310,
  #       question_id: 75,
  #       trait_value_id: 1519,
  #       display_order: 23,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1311,
  #       question_id: 76,
  #       trait_value_id: 1521,
  #       display_order: 1,
  #       text: "Agnostic"
  #     },
  #     %{
  #       id: 1312,
  #       question_id: 76,
  #       trait_value_id: 1522,
  #       display_order: 2,
  #       text: "Atheism"
  #     },
  #     %{
  #       id: 1313,
  #       question_id: 76,
  #       trait_value_id: 1523,
  #       display_order: 3,
  #       text: "Bahai"
  #     },
  #     %{
  #       id: 1314,
  #       question_id: 76,
  #       trait_value_id: 1524,
  #       display_order: 4,
  #       text: "Buddhism"
  #     },
  #     %{
  #       id: 1315,
  #       question_id: 76,
  #       trait_value_id: 1525,
  #       display_order: 5,
  #       text: "Candomble"
  #     },
  #     %{
  #       id: 1316,
  #       question_id: 76,
  #       trait_value_id: 1526,
  #       display_order: 6,
  #       text: "Christian - Assemblies of God"
  #     },
  #     %{
  #       id: 1317,
  #       question_id: 76,
  #       trait_value_id: 1527,
  #       display_order: 7,
  #       text: "Christian - Baptist"
  #     },
  #     %{
  #       id: 1318,
  #       question_id: 76,
  #       trait_value_id: 1528,
  #       display_order: 8,
  #       text: "Christian - Catholic"
  #     },
  #     %{
  #       id: 1319,
  #       question_id: 76,
  #       trait_value_id: 1529,
  #       display_order: 9,
  #       text: "Christian - Church of God"
  #     },
  #     %{
  #       id: 1320,
  #       question_id: 76,
  #       trait_value_id: 1530,
  #       display_order: 10,
  #       text: "Christian - Churches of Christ"
  #     },
  #     %{
  #       id: 1399,
  #       question_id: 81,
  #       trait_value_id: 1604,
  #       display_order: 16,
  #       text: "03:00 PM"
  #     },
  #     %{
  #       id: 1321,
  #       question_id: 76,
  #       trait_value_id: 1531,
  #       display_order: 11,
  #       text: "Christian - Episcopalian/Anglican"
  #     },
  #     %{
  #       id: 1322,
  #       question_id: 76,
  #       trait_value_id: 1532,
  #       display_order: 12,
  #       text: "Christian - Evangelical/Born Again"
  #     },
  #     %{
  #       id: 1323,
  #       question_id: 76,
  #       trait_value_id: 1533,
  #       display_order: 13,
  #       text: "Christian - Jehovah's Witness"
  #     },
  #     %{
  #       id: 1324,
  #       question_id: 76,
  #       trait_value_id: 1534,
  #       display_order: 14,
  #       text: "Christian - Lutheran"
  #     },
  #     %{
  #       id: 1325,
  #       question_id: 76,
  #       trait_value_id: 1535,
  #       display_order: 15,
  #       text: "Christian - Non-denominational"
  #     },
  #     %{
  #       id: 1326,
  #       question_id: 76,
  #       trait_value_id: 1536,
  #       display_order: 16,
  #       text: "Christian - Methodist"
  #     },
  #     %{
  #       id: 1327,
  #       question_id: 76,
  #       trait_value_id: 1537,
  #       display_order: 17,
  #       text: "Christian - Pentecostal (Unspecified)"
  #     },
  #     %{
  #       id: 1328,
  #       question_id: 76,
  #       trait_value_id: 1538,
  #       display_order: 18,
  #       text: "Christian - Presbyterian"
  #     },
  #     %{
  #       id: 1329,
  #       question_id: 76,
  #       trait_value_id: 1539,
  #       display_order: 19,
  #       text: "Christian - Protestant (Unspecified)"
  #     },
  #     %{
  #       id: 1330,
  #       question_id: 76,
  #       trait_value_id: 1540,
  #       display_order: 20,
  #       text: "Christian - Seventh-Day Adventist"
  #     },
  #     %{
  #       id: 1331,
  #       question_id: 76,
  #       trait_value_id: 1541,
  #       display_order: 21,
  #       text: "Christian - United Church of Christ"
  #     },
  #     %{
  #       id: 1332,
  #       question_id: 76,
  #       trait_value_id: 1542,
  #       display_order: 22,
  #       text: "Christian - Unspecified"
  #     },
  #     %{
  #       id: 1333,
  #       question_id: 76,
  #       trait_value_id: 1543,
  #       display_order: 23,
  #       text: "Christian - Other/Not listed"
  #     },
  #     %{
  #       id: 1334,
  #       question_id: 76,
  #       trait_value_id: 1544,
  #       display_order: 24,
  #       text: "Humanist"
  #     },
  #     %{
  #       id: 1335,
  #       question_id: 76,
  #       trait_value_id: 1545,
  #       display_order: 25,
  #       text: "Hinduism"
  #     },
  #     %{
  #       id: 1336,
  #       question_id: 76,
  #       trait_value_id: 1546,
  #       display_order: 26,
  #       text: "Islam"
  #     },
  #     %{
  #       id: 1337,
  #       question_id: 76,
  #       trait_value_id: 1547,
  #       display_order: 27,
  #       text: "Jainism"
  #     },
  #     %{
  #       id: 1338,
  #       question_id: 76,
  #       trait_value_id: 1548,
  #       display_order: 28,
  #       text: "Jehovah's Witnesses"
  #     },
  #     %{
  #       id: 1339,
  #       question_id: 76,
  #       trait_value_id: 1549,
  #       display_order: 29,
  #       text: "Judaism"
  #     },
  #     %{
  #       id: 1340,
  #       question_id: 76,
  #       trait_value_id: 1550,
  #       display_order: 30,
  #       text: "Mormonism"
  #     },
  #     %{
  #       id: 1341,
  #       question_id: 76,
  #       trait_value_id: 1551,
  #       display_order: 31,
  #       text: "Native American Religion"
  #     },
  #     %{
  #       id: 1342,
  #       question_id: 76,
  #       trait_value_id: 1552,
  #       display_order: 32,
  #       text: "New Age"
  #     },
  #     %{
  #       id: 1343,
  #       question_id: 76,
  #       trait_value_id: 1553,
  #       display_order: 33,
  #       text: "Paganism (Wiccan/Pagan/Druid)"
  #     },
  #     %{
  #       id: 1344,
  #       question_id: 76,
  #       trait_value_id: 1554,
  #       display_order: 34,
  #       text: "Rastafari"
  #     },
  #     %{
  #       id: 1345,
  #       question_id: 76,
  #       trait_value_id: 1555,
  #       display_order: 35,
  #       text: "Santeria"
  #     },
  #     %{
  #       id: 1346,
  #       question_id: 76,
  #       trait_value_id: 1556,
  #       display_order: 36,
  #       text: "Scientology"
  #     },
  #     %{
  #       id: 1347,
  #       question_id: 76,
  #       trait_value_id: 1557,
  #       display_order: 37,
  #       text: "Shinto"
  #     },
  #     %{
  #       id: 1348,
  #       question_id: 76,
  #       trait_value_id: 1558,
  #       display_order: 38,
  #       text: "Sikhism"
  #     },
  #     %{
  #       id: 1349,
  #       question_id: 76,
  #       trait_value_id: 1559,
  #       display_order: 39,
  #       text: "Spiritualist"
  #     },
  #     %{
  #       id: 1350,
  #       question_id: 76,
  #       trait_value_id: 1560,
  #       display_order: 40,
  #       text: "Taoism"
  #     },
  #     %{
  #       id: 1351,
  #       question_id: 76,
  #       trait_value_id: 1561,
  #       display_order: 41,
  #       text: "Unitarian Universalism"
  #     },
  #     %{
  #       id: 1352,
  #       question_id: 76,
  #       trait_value_id: 1562,
  #       display_order: 42,
  #       text: "Zoroastrianism"
  #     },
  #     %{
  #       id: 1353,
  #       question_id: 76,
  #       trait_value_id: 1563,
  #       display_order: 43,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 1354,
  #       question_id: 76,
  #       trait_value_id: 1564,
  #       display_order: 44,
  #       text: "None - No Religious Identification"
  #     },
  #     %{
  #       id: 1355,
  #       question_id: 76,
  #       trait_value_id: 1565,
  #       display_order: 45,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1356,
  #       question_id: 8,
  #       trait_value_id: 1567,
  #       display_order: 3,
  #       text: "Self-Employed, Full-time"
  #     },
  #     %{
  #       id: 1357,
  #       question_id: 8,
  #       trait_value_id: 1568,
  #       display_order: 4,
  #       text: "Self-Employed, Part-time"
  #     },
  #     %{
  #       id: 1358,
  #       question_id: 8,
  #       trait_value_id: 1566,
  #       display_order: 6,
  #       text: "Stay-at-home Parent"
  #     },
  #     %{
  #       id: 1359,
  #       question_id: 77,
  #       trait_value_id: 41,
  #       display_order: 1,
  #       text: "Employed, Full-time"
  #     },
  #     %{
  #       id: 1360,
  #       question_id: 77,
  #       trait_value_id: 42,
  #       display_order: 2,
  #       text: "Employed, Part-time"
  #     },
  #     %{
  #       id: 1361,
  #       question_id: 77,
  #       trait_value_id: 1567,
  #       display_order: 3,
  #       text: "Self-Employed, Full-time"
  #     },
  #     %{
  #       id: 1362,
  #       question_id: 77,
  #       trait_value_id: 1568,
  #       display_order: 4,
  #       text: "Self-Employed, Part-time"
  #     },
  #     %{
  #       id: 1363,
  #       question_id: 77,
  #       trait_value_id: 87,
  #       display_order: 9,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1364,
  #       question_id: 77,
  #       trait_value_id: 252,
  #       display_order: 6,
  #       text: "Retried"
  #     },
  #     %{
  #       id: 1365,
  #       question_id: 77,
  #       trait_value_id: 1566,
  #       display_order: 7,
  #       text: "Stay-at-home parent"
  #     },
  #     %{
  #       id: 1366,
  #       question_id: 77,
  #       trait_value_id: 44,
  #       display_order: 8,
  #       text: "Not Currently Employed"
  #     },
  #     %{
  #       id: 1367,
  #       question_id: 78,
  #       trait_value_id: 1570,
  #       display_order: 1,
  #       text: "Full-time"
  #     },
  #     %{
  #       id: 1368,
  #       question_id: 78,
  #       trait_value_id: 1571,
  #       display_order: 2,
  #       text: "Part-time"
  #     },
  #     %{
  #       id: 1369,
  #       question_id: 78,
  #       trait_value_id: 1572,
  #       display_order: 3,
  #       text: "Work-at-home"
  #     },
  #     %{
  #       id: 1370,
  #       question_id: 78,
  #       trait_value_id: 1573,
  #       display_order: 4,
  #       text: "Not looking"
  #     },
  #     %{
  #       id: 1371,
  #       question_id: 78,
  #       trait_value_id: 1574,
  #       display_order: 5,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1372,
  #       question_id: 80,
  #       trait_value_id: 1576,
  #       display_order: 1,
  #       text: "Less than 5"
  #     },
  #     %{
  #       id: 1373,
  #       question_id: 80,
  #       trait_value_id: 1577,
  #       display_order: 2,
  #       text: "5-10"
  #     },
  #     %{
  #       id: 1374,
  #       question_id: 80,
  #       trait_value_id: 1578,
  #       display_order: 3,
  #       text: "11-50"
  #     },
  #     %{
  #       id: 1375,
  #       question_id: 80,
  #       trait_value_id: 1579,
  #       display_order: 4,
  #       text: "51-100"
  #     },
  #     %{
  #       id: 1376,
  #       question_id: 80,
  #       trait_value_id: 1580,
  #       display_order: 5,
  #       text: "101-500"
  #     },
  #     %{
  #       id: 1377,
  #       question_id: 80,
  #       trait_value_id: 1581,
  #       display_order: 6,
  #       text: "501-2,000"
  #     },
  #     %{
  #       id: 1378,
  #       question_id: 80,
  #       trait_value_id: 1582,
  #       display_order: 7,
  #       text: "2,001-5,000"
  #     },
  #     %{
  #       id: 1379,
  #       question_id: 80,
  #       trait_value_id: 1583,
  #       display_order: 8,
  #       text: "5,001-20,000"
  #     },
  #     %{
  #       id: 1380,
  #       question_id: 80,
  #       trait_value_id: 1584,
  #       display_order: 9,
  #       text: "20,001-40,000"
  #     },
  #     %{
  #       id: 1381,
  #       question_id: 80,
  #       trait_value_id: 1585,
  #       display_order: 10,
  #       text: "40,001+"
  #     },
  #     %{
  #       id: 1382,
  #       question_id: 80,
  #       trait_value_id: 1586,
  #       display_order: 11,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 1383,
  #       question_id: 80,
  #       trait_value_id: 1587,
  #       display_order: 12,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1384,
  #       question_id: 81,
  #       trait_value_id: 1589,
  #       display_order: 1,
  #       text: "12:00 AM (Midnight)"
  #     },
  #     %{
  #       id: 1385,
  #       question_id: 81,
  #       trait_value_id: 1590,
  #       display_order: 2,
  #       text: "01:00 AM"
  #     },
  #     %{
  #       id: 1386,
  #       question_id: 81,
  #       trait_value_id: 1591,
  #       display_order: 3,
  #       text: "02:00 AM"
  #     },
  #     %{
  #       id: 1387,
  #       question_id: 81,
  #       trait_value_id: 1592,
  #       display_order: 4,
  #       text: "03:00 AM"
  #     },
  #     %{
  #       id: 1388,
  #       question_id: 81,
  #       trait_value_id: 1593,
  #       display_order: 5,
  #       text: "04:00 AM"
  #     },
  #     %{
  #       id: 1389,
  #       question_id: 81,
  #       trait_value_id: 1594,
  #       display_order: 6,
  #       text: "05:00 AM"
  #     },
  #     %{
  #       id: 1390,
  #       question_id: 81,
  #       trait_value_id: 1595,
  #       display_order: 7,
  #       text: "06:00 AM"
  #     },
  #     %{
  #       id: 1391,
  #       question_id: 81,
  #       trait_value_id: 1596,
  #       display_order: 8,
  #       text: "07:00 AM"
  #     },
  #     %{
  #       id: 1392,
  #       question_id: 81,
  #       trait_value_id: 1597,
  #       display_order: 9,
  #       text: "08:00 AM"
  #     },
  #     %{
  #       id: 1393,
  #       question_id: 81,
  #       trait_value_id: 1598,
  #       display_order: 10,
  #       text: "09:00 AM"
  #     },
  #     %{
  #       id: 1394,
  #       question_id: 81,
  #       trait_value_id: 1599,
  #       display_order: 11,
  #       text: "10:00 AM"
  #     },
  #     %{
  #       id: 1395,
  #       question_id: 81,
  #       trait_value_id: 1600,
  #       display_order: 12,
  #       text: "11:00 AM"
  #     },
  #     %{
  #       id: 1396,
  #       question_id: 81,
  #       trait_value_id: 1601,
  #       display_order: 13,
  #       text: "12:00 PM (Noon)"
  #     },
  #     %{
  #       id: 1397,
  #       question_id: 81,
  #       trait_value_id: 1602,
  #       display_order: 14,
  #       text: "01:00 PM"
  #     },
  #     %{
  #       id: 1398,
  #       question_id: 81,
  #       trait_value_id: 1603,
  #       display_order: 15,
  #       text: "02:00 PM"
  #     },
  #     %{
  #       id: 1400,
  #       question_id: 81,
  #       trait_value_id: 1605,
  #       display_order: 17,
  #       text: "04:00 PM"
  #     },
  #     %{
  #       id: 1401,
  #       question_id: 81,
  #       trait_value_id: 1606,
  #       display_order: 18,
  #       text: "05:00 PM"
  #     },
  #     %{
  #       id: 1402,
  #       question_id: 81,
  #       trait_value_id: 1607,
  #       display_order: 19,
  #       text: "06:00 PM"
  #     },
  #     %{
  #       id: 1403,
  #       question_id: 81,
  #       trait_value_id: 1608,
  #       display_order: 20,
  #       text: "07:00 PM"
  #     },
  #     %{
  #       id: 1404,
  #       question_id: 81,
  #       trait_value_id: 1609,
  #       display_order: 21,
  #       text: "08:00 PM"
  #     },
  #     %{
  #       id: 1405,
  #       question_id: 81,
  #       trait_value_id: 1610,
  #       display_order: 22,
  #       text: "09:00 PM"
  #     },
  #     %{
  #       id: 1406,
  #       question_id: 81,
  #       trait_value_id: 1611,
  #       display_order: 23,
  #       text: "10:00 PM"
  #     },
  #     %{
  #       id: 1407,
  #       question_id: 81,
  #       trait_value_id: 1612,
  #       display_order: 24,
  #       text: "11:00 PM"
  #     },
  #     %{
  #       id: 1408,
  #       question_id: 81,
  #       trait_value_id: 1613,
  #       display_order: 25,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 1409,
  #       question_id: 81,
  #       trait_value_id: 1614,
  #       display_order: 26,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1410,
  #       question_id: 82,
  #       trait_value_id: 1616,
  #       display_order: 1,
  #       text: "12:00 AM (Midnight)"
  #     },
  #     %{
  #       id: 1411,
  #       question_id: 82,
  #       trait_value_id: 1617,
  #       display_order: 2,
  #       text: "01:00 AM"
  #     },
  #     %{
  #       id: 1412,
  #       question_id: 82,
  #       trait_value_id: 1618,
  #       display_order: 3,
  #       text: "02:00 AM"
  #     },
  #     %{
  #       id: 1413,
  #       question_id: 82,
  #       trait_value_id: 1619,
  #       display_order: 4,
  #       text: "03:00 AM"
  #     },
  #     %{
  #       id: 1414,
  #       question_id: 82,
  #       trait_value_id: 1620,
  #       display_order: 5,
  #       text: "04:00 AM"
  #     },
  #     %{
  #       id: 1415,
  #       question_id: 82,
  #       trait_value_id: 1621,
  #       display_order: 6,
  #       text: "05:00 AM"
  #     },
  #     %{
  #       id: 1416,
  #       question_id: 82,
  #       trait_value_id: 1622,
  #       display_order: 7,
  #       text: "06:00 AM"
  #     },
  #     %{
  #       id: 1417,
  #       question_id: 82,
  #       trait_value_id: 1623,
  #       display_order: 8,
  #       text: "07:00 AM"
  #     },
  #     %{
  #       id: 1418,
  #       question_id: 82,
  #       trait_value_id: 1624,
  #       display_order: 9,
  #       text: "08:00 AM"
  #     },
  #     %{
  #       id: 1419,
  #       question_id: 82,
  #       trait_value_id: 1625,
  #       display_order: 10,
  #       text: "09:00 AM"
  #     },
  #     %{
  #       id: 1420,
  #       question_id: 82,
  #       trait_value_id: 1626,
  #       display_order: 11,
  #       text: "10:00 AM"
  #     },
  #     %{
  #       id: 1421,
  #       question_id: 82,
  #       trait_value_id: 1627,
  #       display_order: 12,
  #       text: "11:00 AM"
  #     },
  #     %{
  #       id: 1422,
  #       question_id: 82,
  #       trait_value_id: 1628,
  #       display_order: 13,
  #       text: "12:00 PM (Noon)"
  #     },
  #     %{
  #       id: 1423,
  #       question_id: 82,
  #       trait_value_id: 1629,
  #       display_order: 14,
  #       text: "01:00 PM"
  #     },
  #     %{
  #       id: 1424,
  #       question_id: 82,
  #       trait_value_id: 1630,
  #       display_order: 15,
  #       text: "02:00 PM"
  #     },
  #     %{
  #       id: 1425,
  #       question_id: 82,
  #       trait_value_id: 1631,
  #       display_order: 16,
  #       text: "03:00 PM"
  #     },
  #     %{
  #       id: 1426,
  #       question_id: 82,
  #       trait_value_id: 1632,
  #       display_order: 17,
  #       text: "04:00 PM"
  #     },
  #     %{
  #       id: 1427,
  #       question_id: 82,
  #       trait_value_id: 1633,
  #       display_order: 18,
  #       text: "05:00 PM"
  #     },
  #     %{
  #       id: 1428,
  #       question_id: 82,
  #       trait_value_id: 1634,
  #       display_order: 19,
  #       text: "06:00 PM"
  #     },
  #     %{
  #       id: 1429,
  #       question_id: 82,
  #       trait_value_id: 1635,
  #       display_order: 20,
  #       text: "07:00 PM"
  #     },
  #     %{
  #       id: 1430,
  #       question_id: 82,
  #       trait_value_id: 1636,
  #       display_order: 21,
  #       text: "08:00 PM"
  #     },
  #     %{
  #       id: 1431,
  #       question_id: 82,
  #       trait_value_id: 1637,
  #       display_order: 22,
  #       text: "09:00 PM"
  #     },
  #     %{
  #       id: 1432,
  #       question_id: 82,
  #       trait_value_id: 1638,
  #       display_order: 23,
  #       text: "10:00 PM"
  #     },
  #     %{
  #       id: 1433,
  #       question_id: 82,
  #       trait_value_id: 1639,
  #       display_order: 24,
  #       text: "11:00 PM"
  #     },
  #     %{
  #       id: 1434,
  #       question_id: 82,
  #       trait_value_id: 1640,
  #       display_order: 25,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 1435,
  #       question_id: 82,
  #       trait_value_id: 1641,
  #       display_order: 26,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1436,
  #       question_id: 23,
  #       trait_value_id: 1644,
  #       display_order: 223,
  #       text: "Everest College"
  #     },
  #     %{
  #       id: 1437,
  #       question_id: 85,
  #       trait_value_id: 1646,
  #       display_order: 1,
  #       text: "Never"
  #     },
  #     %{
  #       id: 1438,
  #       question_id: 85,
  #       trait_value_id: 1647,
  #       display_order: 2,
  #       text: "Rarely"
  #     },
  #     %{
  #       id: 1439,
  #       question_id: 85,
  #       trait_value_id: 1648,
  #       display_order: 3,
  #       text: "1-3 times"
  #     },
  #     %{
  #       id: 1440,
  #       question_id: 85,
  #       trait_value_id: 1649,
  #       display_order: 4,
  #       text: "4-6 times"
  #     },
  #     %{
  #       id: 1441,
  #       question_id: 85,
  #       trait_value_id: 1650,
  #       display_order: 5,
  #       text: "7-9 times"
  #     },
  #     %{
  #       id: 1442,
  #       question_id: 85,
  #       trait_value_id: 1651,
  #       display_order: 6,
  #       text: "10+ times"
  #     },
  #     %{
  #       id: 1443,
  #       question_id: 85,
  #       trait_value_id: 1652,
  #       display_order: 7,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1444,
  #       question_id: 86,
  #       trait_value_id: 1654,
  #       display_order: 1,
  #       text: "Hamburgers"
  #     },
  #     %{
  #       id: 1445,
  #       question_id: 86,
  #       trait_value_id: 1655,
  #       display_order: 2,
  #       text: "Hot Dogs"
  #     },
  #     %{
  #       id: 1446,
  #       question_id: 86,
  #       trait_value_id: 1656,
  #       display_order: 3,
  #       text: "Pizza"
  #     },
  #     %{
  #       id: 1447,
  #       question_id: 86,
  #       trait_value_id: 1657,
  #       display_order: 4,
  #       text: "Submarine Sandwiches"
  #     },
  #     %{
  #       id: 1448,
  #       question_id: 86,
  #       trait_value_id: 1658,
  #       display_order: 5,
  #       text: "Tacos/Burritos"
  #     },
  #     %{
  #       id: 1449,
  #       question_id: 86,
  #       trait_value_id: 1659,
  #       display_order: 6,
  #       text: "Chicken"
  #     },
  #     %{
  #       id: 1450,
  #       question_id: 86,
  #       trait_value_id: 1660,
  #       display_order: 7,
  #       text: "Chinese"
  #     },
  #     %{
  #       id: 1451,
  #       question_id: 86,
  #       trait_value_id: 1661,
  #       display_order: 8,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 1452,
  #       question_id: 86,
  #       trait_value_id: 1662,
  #       display_order: 9,
  #       text: "None Listed"
  #     },
  #     %{
  #       id: 1453,
  #       question_id: 86,
  #       trait_value_id: 1663,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1454,
  #       question_id: 87,
  #       trait_value_id: 1665,
  #       display_order: 1,
  #       text: "Vegan"
  #     },
  #     %{
  #       id: 1455,
  #       question_id: 87,
  #       trait_value_id: 1666,
  #       display_order: 2,
  #       text: "Vegetarian"
  #     },
  #     %{
  #       id: 1456,
  #       question_id: 87,
  #       trait_value_id: 1667,
  #       display_order: 3,
  #       text: "Omnivore"
  #     },
  #     %{
  #       id: 1457,
  #       question_id: 87,
  #       trait_value_id: 1668,
  #       display_order: 4,
  #       text: "Meat & Potatoes"
  #     },
  #     %{
  #       id: 1458,
  #       question_id: 87,
  #       trait_value_id: 1669,
  #       display_order: 5,
  #       text: "Organic"
  #     },
  #     %{
  #       id: 1459,
  #       question_id: 87,
  #       trait_value_id: 1670,
  #       display_order: 6,
  #       text: "Fresh and Light"
  #     },
  #     %{
  #       id: 1460,
  #       question_id: 87,
  #       trait_value_id: 1671,
  #       display_order: 7,
  #       text: "Low Carb"
  #     },
  #     %{
  #       id: 1461,
  #       question_id: 87,
  #       trait_value_id: 1672,
  #       display_order: 8,
  #       text: "High Fiber"
  #     },
  #     %{
  #       id: 1462,
  #       question_id: 87,
  #       trait_value_id: 1673,
  #       display_order: 9,
  #       text: "Low Fat"
  #     },
  #     %{
  #       id: 1463,
  #       question_id: 87,
  #       trait_value_id: 1674,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1464,
  #       question_id: 88,
  #       trait_value_id: 1676,
  #       display_order: 1,
  #       text: "Fish"
  #     },
  #     %{
  #       id: 1465,
  #       question_id: 88,
  #       trait_value_id: 1677,
  #       display_order: 2,
  #       text: "Crab"
  #     },
  #     %{
  #       id: 1466,
  #       question_id: 88,
  #       trait_value_id: 1678,
  #       display_order: 3,
  #       text: "Lobster"
  #     },
  #     %{
  #       id: 1467,
  #       question_id: 88,
  #       trait_value_id: 1679,
  #       display_order: 4,
  #       text: "Shrimp"
  #     },
  #     %{
  #       id: 1468,
  #       question_id: 88,
  #       trait_value_id: 1680,
  #       display_order: 5,
  #       text: "Oysters"
  #     },
  #     %{
  #       id: 1469,
  #       question_id: 88,
  #       trait_value_id: 1681,
  #       display_order: 6,
  #       text: "Crawfish"
  #     },
  #     %{
  #       id: 1470,
  #       question_id: 88,
  #       trait_value_id: 1682,
  #       display_order: 7,
  #       text: "Sushi"
  #     },
  #     %{
  #       id: 1471,
  #       question_id: 88,
  #       trait_value_id: 1683,
  #       display_order: 8,
  #       text: "Steak (Beef)"
  #     },
  #     %{
  #       id: 1472,
  #       question_id: 88,
  #       trait_value_id: 1684,
  #       display_order: 9,
  #       text: "Chicken"
  #     },
  #     %{
  #       id: 1473,
  #       question_id: 88,
  #       trait_value_id: 1685,
  #       display_order: 10,
  #       text: "Pork"
  #     },
  #     %{
  #       id: 1474,
  #       question_id: 88,
  #       trait_value_id: 1686,
  #       display_order: 11,
  #       text: "Lamb"
  #     },
  #     %{
  #       id: 1475,
  #       question_id: 88,
  #       trait_value_id: 1687,
  #       display_order: 12,
  #       text: "Wild Game"
  #     },
  #     %{
  #       id: 1476,
  #       question_id: 88,
  #       trait_value_id: 1688,
  #       display_order: 13,
  #       text: "Veal"
  #     },
  #     %{
  #       id: 1477,
  #       question_id: 88,
  #       trait_value_id: 1689,
  #       display_order: 14,
  #       text: "None Listed"
  #     },
  #     %{
  #       id: 1478,
  #       question_id: 88,
  #       trait_value_id: 1690,
  #       display_order: 15,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1479,
  #       question_id: 89,
  #       trait_value_id: 1692,
  #       display_order: 1,
  #       text: "Fish"
  #     },
  #     %{
  #       id: 1480,
  #       question_id: 89,
  #       trait_value_id: 1693,
  #       display_order: 2,
  #       text: "Crab"
  #     },
  #     %{
  #       id: 1481,
  #       question_id: 89,
  #       trait_value_id: 1694,
  #       display_order: 3,
  #       text: "Lobster"
  #     },
  #     %{
  #       id: 1482,
  #       question_id: 89,
  #       trait_value_id: 1695,
  #       display_order: 4,
  #       text: "Shrimp"
  #     },
  #     %{
  #       id: 1483,
  #       question_id: 89,
  #       trait_value_id: 1696,
  #       display_order: 5,
  #       text: "Oysters"
  #     },
  #     %{
  #       id: 1484,
  #       question_id: 89,
  #       trait_value_id: 1697,
  #       display_order: 6,
  #       text: "Crawfish"
  #     },
  #     %{
  #       id: 1485,
  #       question_id: 89,
  #       trait_value_id: 1698,
  #       display_order: 7,
  #       text: "Sushi"
  #     },
  #     %{
  #       id: 1486,
  #       question_id: 89,
  #       trait_value_id: 1699,
  #       display_order: 8,
  #       text: "Steak (Beef)"
  #     },
  #     %{
  #       id: 1487,
  #       question_id: 89,
  #       trait_value_id: 1700,
  #       display_order: 9,
  #       text: "Chicken"
  #     },
  #     %{
  #       id: 1488,
  #       question_id: 89,
  #       trait_value_id: 1701,
  #       display_order: 10,
  #       text: "Pork"
  #     },
  #     %{
  #       id: 1489,
  #       question_id: 89,
  #       trait_value_id: 1702,
  #       display_order: 11,
  #       text: "Lamb"
  #     },
  #     %{
  #       id: 1490,
  #       question_id: 89,
  #       trait_value_id: 1703,
  #       display_order: 12,
  #       text: "Wild Game"
  #     },
  #     %{
  #       id: 1491,
  #       question_id: 89,
  #       trait_value_id: 1704,
  #       display_order: 13,
  #       text: "Veal"
  #     },
  #     %{
  #       id: 1492,
  #       question_id: 89,
  #       trait_value_id: 1705,
  #       display_order: 14,
  #       text: "None Listed"
  #     },
  #     %{
  #       id: 1493,
  #       question_id: 89,
  #       trait_value_id: 1706,
  #       display_order: 15,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1494,
  #       question_id: 90,
  #       trait_value_id: 1708,
  #       display_order: 1,
  #       text: "Italian"
  #     },
  #     %{
  #       id: 1495,
  #       question_id: 90,
  #       trait_value_id: 1709,
  #       display_order: 2,
  #       text: "German"
  #     },
  #     %{
  #       id: 1496,
  #       question_id: 90,
  #       trait_value_id: 1710,
  #       display_order: 3,
  #       text: "French"
  #     },
  #     %{
  #       id: 1497,
  #       question_id: 90,
  #       trait_value_id: 1711,
  #       display_order: 4,
  #       text: "Greek"
  #     },
  #     %{
  #       id: 1498,
  #       question_id: 90,
  #       trait_value_id: 1712,
  #       display_order: 5,
  #       text: "Chinese"
  #     },
  #     %{
  #       id: 1499,
  #       question_id: 90,
  #       trait_value_id: 1713,
  #       display_order: 6,
  #       text: "Korean"
  #     },
  #     %{
  #       id: 1500,
  #       question_id: 90,
  #       trait_value_id: 1714,
  #       display_order: 7,
  #       text: "Japanese"
  #     },
  #     %{
  #       id: 1501,
  #       question_id: 90,
  #       trait_value_id: 1715,
  #       display_order: 8,
  #       text: "Indian"
  #     },
  #     %{
  #       id: 1502,
  #       question_id: 90,
  #       trait_value_id: 1716,
  #       display_order: 9,
  #       text: "Thai"
  #     },
  #     %{
  #       id: 1503,
  #       question_id: 90,
  #       trait_value_id: 1717,
  #       display_order: 10,
  #       text: "Vietnamese"
  #     },
  #     %{
  #       id: 1504,
  #       question_id: 90,
  #       trait_value_id: 1718,
  #       display_order: 11,
  #       text: "Mexican"
  #     },
  #     %{
  #       id: 1505,
  #       question_id: 90,
  #       trait_value_id: 1719,
  #       display_order: 12,
  #       text: "Tex-Mex"
  #     },
  #     %{
  #       id: 1506,
  #       question_id: 90,
  #       trait_value_id: 1720,
  #       display_order: 13,
  #       text: "Lebanese"
  #     },
  #     %{
  #       id: 1507,
  #       question_id: 90,
  #       trait_value_id: 1721,
  #       display_order: 14,
  #       text: "Mediterranean"
  #     },
  #     %{
  #       id: 1508,
  #       question_id: 90,
  #       trait_value_id: 1722,
  #       display_order: 15,
  #       text: "South Western"
  #     },
  #     %{
  #       id: 1509,
  #       question_id: 90,
  #       trait_value_id: 1723,
  #       display_order: 16,
  #       text: "Southern & Soul"
  #     },
  #     %{
  #       id: 1510,
  #       question_id: 90,
  #       trait_value_id: 1724,
  #       display_order: 17,
  #       text: "Middle Eastern"
  #     },
  #     %{
  #       id: 1511,
  #       question_id: 90,
  #       trait_value_id: 1725,
  #       display_order: 18,
  #       text: "Cuban"
  #     },
  #     %{
  #       id: 1512,
  #       question_id: 90,
  #       trait_value_id: 1726,
  #       display_order: 19,
  #       text: "Spanish"
  #     },
  #     %{
  #       id: 1513,
  #       question_id: 90,
  #       trait_value_id: 1727,
  #       display_order: 20,
  #       text: "Portuguese"
  #     },
  #     %{
  #       id: 1514,
  #       question_id: 90,
  #       trait_value_id: 1728,
  #       display_order: 21,
  #       text: "Caribbean"
  #     },
  #     %{
  #       id: 1515,
  #       question_id: 90,
  #       trait_value_id: 1729,
  #       display_order: 22,
  #       text: "Brazilian"
  #     },
  #     %{
  #       id: 1516,
  #       question_id: 90,
  #       trait_value_id: 1730,
  #       display_order: 23,
  #       text: "Cajun & Creole"
  #     },
  #     %{
  #       id: 1517,
  #       question_id: 90,
  #       trait_value_id: 1731,
  #       display_order: 24,
  #       text: "Other - Not listed"
  #     },
  #     %{
  #       id: 1518,
  #       question_id: 90,
  #       trait_value_id: 1732,
  #       display_order: 25,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1519,
  #       question_id: 91,
  #       trait_value_id: 1734,
  #       display_order: 1,
  #       text: "Italian"
  #     },
  #     %{
  #       id: 1520,
  #       question_id: 91,
  #       trait_value_id: 1735,
  #       display_order: 2,
  #       text: "German"
  #     },
  #     %{
  #       id: 1521,
  #       question_id: 91,
  #       trait_value_id: 1736,
  #       display_order: 3,
  #       text: "French"
  #     },
  #     %{
  #       id: 1522,
  #       question_id: 91,
  #       trait_value_id: 1737,
  #       display_order: 4,
  #       text: "Greek"
  #     },
  #     %{
  #       id: 1523,
  #       question_id: 91,
  #       trait_value_id: 1738,
  #       display_order: 5,
  #       text: "Chinese"
  #     },
  #     %{
  #       id: 1524,
  #       question_id: 91,
  #       trait_value_id: 1739,
  #       display_order: 6,
  #       text: "Korean"
  #     },
  #     %{
  #       id: 1525,
  #       question_id: 91,
  #       trait_value_id: 1740,
  #       display_order: 7,
  #       text: "Japanese"
  #     },
  #     %{
  #       id: 1526,
  #       question_id: 91,
  #       trait_value_id: 1741,
  #       display_order: 8,
  #       text: "Indian"
  #     },
  #     %{
  #       id: 1527,
  #       question_id: 91,
  #       trait_value_id: 1742,
  #       display_order: 9,
  #       text: "Thai"
  #     },
  #     %{
  #       id: 1528,
  #       question_id: 91,
  #       trait_value_id: 1743,
  #       display_order: 10,
  #       text: "Vietnamese"
  #     },
  #     %{
  #       id: 1529,
  #       question_id: 91,
  #       trait_value_id: 1744,
  #       display_order: 11,
  #       text: "Mexican"
  #     },
  #     %{
  #       id: 1530,
  #       question_id: 91,
  #       trait_value_id: 1745,
  #       display_order: 12,
  #       text: "Tex-Mex"
  #     },
  #     %{
  #       id: 1531,
  #       question_id: 91,
  #       trait_value_id: 1746,
  #       display_order: 13,
  #       text: "Lebanese"
  #     },
  #     %{
  #       id: 1532,
  #       question_id: 91,
  #       trait_value_id: 1747,
  #       display_order: 14,
  #       text: "Mediterranean"
  #     },
  #     %{
  #       id: 1533,
  #       question_id: 91,
  #       trait_value_id: 1748,
  #       display_order: 15,
  #       text: "South Western"
  #     },
  #     %{
  #       id: 1534,
  #       question_id: 91,
  #       trait_value_id: 1749,
  #       display_order: 16,
  #       text: "Southern & Soul"
  #     },
  #     %{
  #       id: 1535,
  #       question_id: 91,
  #       trait_value_id: 1750,
  #       display_order: 17,
  #       text: "Middle Eastern"
  #     },
  #     %{
  #       id: 1536,
  #       question_id: 91,
  #       trait_value_id: 1751,
  #       display_order: 18,
  #       text: "Cuban"
  #     },
  #     %{
  #       id: 1537,
  #       question_id: 91,
  #       trait_value_id: 1752,
  #       display_order: 19,
  #       text: "Spanish"
  #     },
  #     %{
  #       id: 1538,
  #       question_id: 91,
  #       trait_value_id: 1753,
  #       display_order: 20,
  #       text: "Portuguese"
  #     },
  #     %{
  #       id: 1539,
  #       question_id: 91,
  #       trait_value_id: 1754,
  #       display_order: 21,
  #       text: "Caribbean"
  #     },
  #     %{
  #       id: 1540,
  #       question_id: 91,
  #       trait_value_id: 1755,
  #       display_order: 22,
  #       text: "Brazilian"
  #     },
  #     %{
  #       id: 1541,
  #       question_id: 91,
  #       trait_value_id: 1756,
  #       display_order: 23,
  #       text: "Cajun & Creole"
  #     },
  #     %{
  #       id: 1542,
  #       question_id: 91,
  #       trait_value_id: 1757,
  #       display_order: 24,
  #       text: "Other - Not listed"
  #     },
  #     %{
  #       id: 1543,
  #       question_id: 91,
  #       trait_value_id: 1758,
  #       display_order: 25,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1544,
  #       question_id: 92,
  #       trait_value_id: 1760,
  #       display_order: 1,
  #       text: "Hot - The hotter, the better."
  #     },
  #     %{
  #       id: 1545,
  #       question_id: 92,
  #       trait_value_id: 1761,
  #       display_order: 2,
  #       text: "Medium - A little spice is nice."
  #     },
  #     %{
  #       id: 1546,
  #       question_id: 92,
  #       trait_value_id: 1762,
  #       display_order: 3,
  #       text: "Mild - Must have mild."
  #     },
  #     %{
  #       id: 1547,
  #       question_id: 92,
  #       trait_value_id: 1763,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1548,
  #       question_id: 93,
  #       trait_value_id: 1765,
  #       display_order: 1,
  #       text: "Yes - I gotta have sweets."
  #     },
  #     %{
  #       id: 1549,
  #       question_id: 93,
  #       trait_value_id: 1766,
  #       display_order: 2,
  #       text: "Moderate - I can take it or leave it."
  #     },
  #     %{
  #       id: 1550,
  #       question_id: 93,
  #       trait_value_id: 1767,
  #       display_order: 3,
  #       text: "No - I dislike sweets."
  #     },
  #     %{
  #       id: 1551,
  #       question_id: 93,
  #       trait_value_id: 1768,
  #       display_order: 4,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1552,
  #       question_id: 23,
  #       trait_value_id: 1769,
  #       display_order: 53,
  #       text: "Bates College"
  #     },
  #     %{
  #       id: 1553,
  #       question_id: 23,
  #       trait_value_id: 1770,
  #       display_order: 150,
  #       text: "College of the Atlantic"
  #     },
  #     %{
  #       id: 1554,
  #       question_id: 23,
  #       trait_value_id: 1771,
  #       display_order: 156,
  #       text: "Colorado College"
  #     },
  #     %{
  #       id: 1555,
  #       question_id: 23,
  #       trait_value_id: 1772,
  #       display_order: 193,
  #       text: "Dickinson College"
  #     },
  #     %{
  #       id: 1556,
  #       question_id: 23,
  #       trait_value_id: 1773,
  #       display_order: 697,
  #       text: "The Evergreen State College"
  #     },
  #     %{
  #       id: 1557,
  #       question_id: 23,
  #       trait_value_id: 1774,
  #       display_order: 437,
  #       text: "Middlebury College"
  #     },
  #     %{
  #       id: 1558,
  #       question_id: 23,
  #       trait_value_id: 1775,
  #       display_order: 487,
  #       text: "Northeastern University"
  #     },
  #     %{
  #       id: 1559,
  #       question_id: 23,
  #       trait_value_id: 1776,
  #       display_order: 69,
  #       text: "Binghamton University"
  #     },
  #     %{
  #       id: 1560,
  #       question_id: 23,
  #       trait_value_id: 1777,
  #       display_order: 901,
  #       text: "Yale University"
  #     },
  #     %{
  #       id: 1561,
  #       question_id: 23,
  #       trait_value_id: 1778,
  #       display_order: 556,
  #       text: "Princeton University"
  #     },
  #     %{
  #       id: 1562,
  #       question_id: 23,
  #       trait_value_id: 1779,
  #       display_order: 297,
  #       text: "Harvard University"
  #     },
  #     %{
  #       id: 1563,
  #       question_id: 23,
  #       trait_value_id: 1780,
  #       display_order: 41,
  #       text: "Austin College"
  #     },
  #     %{
  #       id: 1564,
  #       question_id: 94,
  #       trait_value_id: 1782,
  #       display_order: 1,
  #       text: "A few times a year"
  #     },
  #     %{
  #       id: 1565,
  #       question_id: 94,
  #       trait_value_id: 1783,
  #       display_order: 2,
  #       text: "1-5 hours"
  #     },
  #     %{
  #       id: 1566,
  #       question_id: 94,
  #       trait_value_id: 1784,
  #       display_order: 3,
  #       text: "6-10 hours"
  #     },
  #     %{
  #       id: 1567,
  #       question_id: 94,
  #       trait_value_id: 1785,
  #       display_order: 4,
  #       text: "11-15 hours"
  #     },
  #     %{
  #       id: 1568,
  #       question_id: 94,
  #       trait_value_id: 1786,
  #       display_order: 5,
  #       text: "16-20 hours"
  #     },
  #     %{
  #       id: 1569,
  #       question_id: 94,
  #       trait_value_id: 1787,
  #       display_order: 6,
  #       text: "21+ hours"
  #     },
  #     %{
  #       id: 1570,
  #       question_id: 95,
  #       trait_value_id: 1789,
  #       display_order: 1,
  #       text: "Art-Related"
  #     },
  #     %{
  #       id: 1571,
  #       question_id: 95,
  #       trait_value_id: 1790,
  #       display_order: 2,
  #       text: "Children-Related (Non-sports)"
  #     },
  #     %{
  #       id: 1572,
  #       question_id: 95,
  #       trait_value_id: 1791,
  #       display_order: 3,
  #       text: "Children's Sports/Coaching"
  #     },
  #     %{
  #       id: 1573,
  #       question_id: 95,
  #       trait_value_id: 1792,
  #       display_order: 4,
  #       text: "Company-Sponsored"
  #     },
  #     %{
  #       id: 1574,
  #       question_id: 95,
  #       trait_value_id: 1793,
  #       display_order: 5,
  #       text: "Elderly-Related"
  #     },
  #     %{
  #       id: 1575,
  #       question_id: 95,
  #       trait_value_id: 1794,
  #       display_order: 6,
  #       text: "Environmental"
  #     },
  #     %{
  #       id: 1576,
  #       question_id: 95,
  #       trait_value_id: 1795,
  #       display_order: 7,
  #       text: "Fund Raisers"
  #     },
  #     %{
  #       id: 1577,
  #       question_id: 95,
  #       trait_value_id: 1796,
  #       display_order: 8,
  #       text: "Health-Related"
  #     },
  #     %{
  #       id: 1578,
  #       question_id: 95,
  #       trait_value_id: 1797,
  #       display_order: 9,
  #       text: "Humanitarian"
  #     },
  #     %{
  #       id: 1579,
  #       question_id: 95,
  #       trait_value_id: 1798,
  #       display_order: 10,
  #       text: "Political"
  #     },
  #     %{
  #       id: 1580,
  #       question_id: 95,
  #       trait_value_id: 1799,
  #       display_order: 11,
  #       text: "Religious/Church"
  #     },
  #     %{
  #       id: 1581,
  #       question_id: 95,
  #       trait_value_id: 1800,
  #       display_order: 12,
  #       text: "School-Related/PTA/PTO"
  #     },
  #     %{
  #       id: 1582,
  #       question_id: 95,
  #       trait_value_id: 1801,
  #       display_order: 13,
  #       text: "United Way"
  #     },
  #     %{
  #       id: 1583,
  #       question_id: 95,
  #       trait_value_id: 1802,
  #       display_order: 14,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 1584,
  #       question_id: 95,
  #       trait_value_id: 1803,
  #       display_order: 15,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1585,
  #       question_id: 94,
  #       trait_value_id: 1804,
  #       display_order: 10,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1586,
  #       question_id: 96,
  #       trait_value_id: 1806,
  #       display_order: 1,
  #       text: "Less than $10/mo"
  #     },
  #     %{
  #       id: 1587,
  #       question_id: 96,
  #       trait_value_id: 1807,
  #       display_order: 2,
  #       text: "$11-25/mo"
  #     },
  #     %{
  #       id: 1588,
  #       question_id: 96,
  #       trait_value_id: 1808,
  #       display_order: 3,
  #       text: "$26-50/mo"
  #     },
  #     %{
  #       id: 1589,
  #       question_id: 96,
  #       trait_value_id: 1809,
  #       display_order: 4,
  #       text: "$51-100/mo"
  #     },
  #     %{
  #       id: 1590,
  #       question_id: 96,
  #       trait_value_id: 1810,
  #       display_order: 5,
  #       text: "$101-250/mo"
  #     },
  #     %{
  #       id: 1591,
  #       question_id: 96,
  #       trait_value_id: 1811,
  #       display_order: 6,
  #       text: "$251-500/mo"
  #     },
  #     %{
  #       id: 1592,
  #       question_id: 96,
  #       trait_value_id: 1812,
  #       display_order: 7,
  #       text: "$501+/mo"
  #     },
  #     %{
  #       id: 1593,
  #       question_id: 96,
  #       trait_value_id: 1813,
  #       display_order: 8,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1594,
  #       question_id: 97,
  #       trait_value_id: 1815,
  #       display_order: 1,
  #       text: "Excellent"
  #     },
  #     %{
  #       id: 1595,
  #       question_id: 97,
  #       trait_value_id: 1816,
  #       display_order: 2,
  #       text: "Good"
  #     },
  #     %{
  #       id: 1596,
  #       question_id: 97,
  #       trait_value_id: 1817,
  #       display_order: 3,
  #       text: "Fair"
  #     },
  #     %{
  #       id: 1597,
  #       question_id: 97,
  #       trait_value_id: 1818,
  #       display_order: 4,
  #       text: "Bad"
  #     },
  #     %{
  #       id: 1598,
  #       question_id: 97,
  #       trait_value_id: 1819,
  #       display_order: 5,
  #       text: "Don't know"
  #     },
  #     %{
  #       id: 1599,
  #       question_id: 97,
  #       trait_value_id: 1820,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1600,
  #       question_id: 98,
  #       trait_value_id: 1822,
  #       display_order: 1,
  #       text: "Heterosexual"
  #     },
  #     %{
  #       id: 1601,
  #       question_id: 98,
  #       trait_value_id: 1823,
  #       display_order: 2,
  #       text: "Homosexual"
  #     },
  #     %{
  #       id: 1602,
  #       question_id: 98,
  #       trait_value_id: 1824,
  #       display_order: 3,
  #       text: "Bisexual"
  #     },
  #     %{
  #       id: 1604,
  #       question_id: 98,
  #       trait_value_id: 1826,
  #       display_order: 5,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1612,
  #       question_id: 10,
  #       trait_value_id: 1828,
  #       display_order: 1,
  #       text: "Democratic Party"
  #     },
  #     %{
  #       id: 1613,
  #       question_id: 10,
  #       trait_value_id: 1829,
  #       display_order: 2,
  #       text: "Green Party"
  #     },
  #     %{
  #       id: 1614,
  #       question_id: 10,
  #       trait_value_id: 1830,
  #       display_order: 3,
  #       text: "Libertarian Party"
  #     },
  #     %{
  #       id: 1615,
  #       question_id: 10,
  #       trait_value_id: 1831,
  #       display_order: 4,
  #       text: "Republican Party"
  #     },
  #     %{
  #       id: 1616,
  #       question_id: 10,
  #       trait_value_id: 1832,
  #       display_order: 5,
  #       text: "Other party (not listed)"
  #     },
  #     %{
  #       id: 1617,
  #       question_id: 10,
  #       trait_value_id: 1833,
  #       display_order: 6,
  #       text: "No party affiliation (independent)"
  #     },
  #     %{
  #       id: 1618,
  #       question_id: 10,
  #       trait_value_id: 1834,
  #       display_order: 7,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1619,
  #       question_id: 10,
  #       trait_value_id: 1836,
  #       display_order: 1,
  #       text: "Far Left/Liberal"
  #     },
  #     %{
  #       id: 1620,
  #       question_id: 10,
  #       trait_value_id: 1837,
  #       display_order: 2,
  #       text: "Moderate Left/Liberal"
  #     },
  #     %{
  #       id: 1621,
  #       question_id: 10,
  #       trait_value_id: 1838,
  #       display_order: 3,
  #       text: "Moderate"
  #     },
  #     %{
  #       id: 1622,
  #       question_id: 10,
  #       trait_value_id: 1839,
  #       display_order: 4,
  #       text: "Moderate Right/Conservative"
  #     },
  #     %{
  #       id: 1623,
  #       question_id: 10,
  #       trait_value_id: 1840,
  #       display_order: 5,
  #       text: "Far Right/Conservative"
  #     },
  #     %{
  #       id: 1624,
  #       question_id: 10,
  #       trait_value_id: 1841,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1625,
  #       question_id: 10,
  #       trait_value_id: 1843,
  #       display_order: 1,
  #       text: "Far Left/Liberal"
  #     },
  #     %{
  #       id: 1626,
  #       question_id: 10,
  #       trait_value_id: 1844,
  #       display_order: 2,
  #       text: "Moderate Left/Liberal"
  #     },
  #     %{
  #       id: 1627,
  #       question_id: 10,
  #       trait_value_id: 1845,
  #       display_order: 3,
  #       text: "Moderate"
  #     },
  #     %{
  #       id: 1628,
  #       question_id: 10,
  #       trait_value_id: 1846,
  #       display_order: 4,
  #       text: "Moderate Right/Conservative"
  #     },
  #     %{
  #       id: 1629,
  #       question_id: 10,
  #       trait_value_id: 1847,
  #       display_order: 5,
  #       text: "Far Right/Conservative"
  #     },
  #     %{
  #       id: 1630,
  #       question_id: 10,
  #       trait_value_id: 1848,
  #       display_order: 6,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 1631,
  #       question_id: 10,
  #       trait_value_id: 1850,
  #       display_order: 1,
  #       text: "English"
  #     },
  #     %{
  #       id: 1632,
  #       question_id: 10,
  #       trait_value_id: 1851,
  #       display_order: 2,
  #       text: "Spanish"
  #     },
  #     %{
  #       id: 1633,
  #       question_id: 10,
  #       trait_value_id: 1852,
  #       display_order: 3,
  #       text: "Arabic"
  #     },
  #     %{
  #       id: 1634,
  #       question_id: 10,
  #       trait_value_id: 1853,
  #       display_order: 4,
  #       text: "Armenian"
  #     },
  #     %{
  #       id: 1635,
  #       question_id: 10,
  #       trait_value_id: 1854,
  #       display_order: 5,
  #       text: "Chinese - Cantonese"
  #     },
  #     %{
  #       id: 1636,
  #       question_id: 10,
  #       trait_value_id: 1855,
  #       display_order: 6,
  #       text: "Chinese - Mandarin"
  #     },
  #     %{
  #       id: 1637,
  #       question_id: 10,
  #       trait_value_id: 1856,
  #       display_order: 7,
  #       text: "French"
  #     },
  #     %{
  #       id: 1638,
  #       question_id: 10,
  #       trait_value_id: 1857,
  #       display_order: 8,
  #       text: "French Creole"
  #     },
  #     %{
  #       id: 1639,
  #       question_id: 10,
  #       trait_value_id: 1858,
  #       display_order: 9,
  #       text: "German"
  #     },
  #     %{
  #       id: 1640,
  #       question_id: 10,
  #       trait_value_id: 1859,
  #       display_order: 10,
  #       text: "Greek"
  #     },
  #     %{
  #       id: 1641,
  #       question_id: 10,
  #       trait_value_id: 1860,
  #       display_order: 11,
  #       text: "Gujarati"
  #     },
  #     %{
  #       id: 1642,
  #       question_id: 10,
  #       trait_value_id: 1861,
  #       display_order: 12,
  #       text: "Hindi"
  #     },
  #     %{
  #       id: 1643,
  #       question_id: 10,
  #       trait_value_id: 1862,
  #       display_order: 13,
  #       text: "Italian"
  #     },
  #     %{
  #       id: 1644,
  #       question_id: 10,
  #       trait_value_id: 1863,
  #       display_order: 14,
  #       text: "Japanese"
  #     },
  #     %{
  #       id: 1645,
  #       question_id: 10,
  #       trait_value_id: 1864,
  #       display_order: 15,
  #       text: "Korean"
  #     },
  #     %{
  #       id: 1646,
  #       question_id: 10,
  #       trait_value_id: 1865,
  #       display_order: 16,
  #       text: "Persian"
  #     },
  #     %{
  #       id: 1647,
  #       question_id: 10,
  #       trait_value_id: 1866,
  #       display_order: 17,
  #       text: "Polish"
  #     },
  #     %{
  #       id: 1648,
  #       question_id: 10,
  #       trait_value_id: 1867,
  #       display_order: 18,
  #       text: "Portuguese"
  #     },
  #     %{
  #       id: 1649,
  #       question_id: 10,
  #       trait_value_id: 1868,
  #       display_order: 19,
  #       text: "Russian"
  #     },
  #     %{
  #       id: 1650,
  #       question_id: 10,
  #       trait_value_id: 1869,
  #       display_order: 20,
  #       text: "Tagalog"
  #     },
  #     %{
  #       id: 1651,
  #       question_id: 10,
  #       trait_value_id: 1870,
  #       display_order: 21,
  #       text: "Thai"
  #     },
  #     %{
  #       id: 1652,
  #       question_id: 10,
  #       trait_value_id: 1871,
  #       display_order: 22,
  #       text: "Urdu"
  #     },
  #     %{
  #       id: 1653,
  #       question_id: 10,
  #       trait_value_id: 1872,
  #       display_order: 23,
  #       text: "Vietnamese"
  #     },
  #     %{
  #       id: 1654,
  #       question_id: 10,
  #       trait_value_id: 1873,
  #       display_order: 24,
  #       text: "Yiddish"
  #     },
  #     %{
  #       id: 1655,
  #       question_id: 10,
  #       trait_value_id: 1874,
  #       display_order: 25,
  #       text: "Other - Not listed"
  #     },
  #     %{
  #       id: 1656,
  #       question_id: 10,
  #       trait_value_id: 1875,
  #       display_order: 26,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1657,
  #       question_id: 10,
  #       trait_value_id: 1877,
  #       display_order: 1,
  #       text: "English"
  #     },
  #     %{
  #       id: 1658,
  #       question_id: 10,
  #       trait_value_id: 1878,
  #       display_order: 2,
  #       text: "Spanish"
  #     },
  #     %{
  #       id: 1659,
  #       question_id: 10,
  #       trait_value_id: 1879,
  #       display_order: 3,
  #       text: "Arabic"
  #     },
  #     %{
  #       id: 1660,
  #       question_id: 10,
  #       trait_value_id: 1880,
  #       display_order: 4,
  #       text: "Armenian"
  #     },
  #     %{
  #       id: 1661,
  #       question_id: 10,
  #       trait_value_id: 1881,
  #       display_order: 5,
  #       text: "Chinese - Cantonese"
  #     },
  #     %{
  #       id: 1662,
  #       question_id: 10,
  #       trait_value_id: 1882,
  #       display_order: 6,
  #       text: "Chinese - Mandarin"
  #     },
  #     %{
  #       id: 1663,
  #       question_id: 10,
  #       trait_value_id: 1883,
  #       display_order: 7,
  #       text: "French"
  #     },
  #     %{
  #       id: 1664,
  #       question_id: 10,
  #       trait_value_id: 1884,
  #       display_order: 8,
  #       text: "French Creole"
  #     },
  #     %{
  #       id: 1665,
  #       question_id: 10,
  #       trait_value_id: 1885,
  #       display_order: 9,
  #       text: "German"
  #     },
  #     %{
  #       id: 1666,
  #       question_id: 10,
  #       trait_value_id: 1886,
  #       display_order: 10,
  #       text: "Greek"
  #     },
  #     %{
  #       id: 1667,
  #       question_id: 10,
  #       trait_value_id: 1887,
  #       display_order: 11,
  #       text: "Gujarati"
  #     },
  #     %{
  #       id: 1668,
  #       question_id: 10,
  #       trait_value_id: 1888,
  #       display_order: 12,
  #       text: "Hindi"
  #     },
  #     %{
  #       id: 1669,
  #       question_id: 10,
  #       trait_value_id: 1889,
  #       display_order: 13,
  #       text: "Italian"
  #     },
  #     %{
  #       id: 1670,
  #       question_id: 10,
  #       trait_value_id: 1890,
  #       display_order: 14,
  #       text: "Japanese"
  #     },
  #     %{
  #       id: 1671,
  #       question_id: 10,
  #       trait_value_id: 1891,
  #       display_order: 15,
  #       text: "Korean"
  #     },
  #     %{
  #       id: 1672,
  #       question_id: 10,
  #       trait_value_id: 1892,
  #       display_order: 16,
  #       text: "Persian"
  #     },
  #     %{
  #       id: 1673,
  #       question_id: 10,
  #       trait_value_id: 1893,
  #       display_order: 17,
  #       text: "Polish"
  #     },
  #     %{
  #       id: 1674,
  #       question_id: 10,
  #       trait_value_id: 1894,
  #       display_order: 18,
  #       text: "Portuguese"
  #     },
  #     %{
  #       id: 1675,
  #       question_id: 10,
  #       trait_value_id: 1895,
  #       display_order: 19,
  #       text: "Russian"
  #     },
  #     %{
  #       id: 1676,
  #       question_id: 10,
  #       trait_value_id: 1896,
  #       display_order: 20,
  #       text: "Tagalog"
  #     },
  #     %{
  #       id: 1677,
  #       question_id: 10,
  #       trait_value_id: 1897,
  #       display_order: 21,
  #       text: "Thai"
  #     },
  #     %{
  #       id: 1678,
  #       question_id: 10,
  #       trait_value_id: 1898,
  #       display_order: 22,
  #       text: "Urdu"
  #     },
  #     %{
  #       id: 1679,
  #       question_id: 10,
  #       trait_value_id: 1899,
  #       display_order: 23,
  #       text: "Vietnamese"
  #     },
  #     %{
  #       id: 1680,
  #       question_id: 10,
  #       trait_value_id: 1900,
  #       display_order: 24,
  #       text: "Yiddish"
  #     },
  #     %{
  #       id: 1681,
  #       question_id: 10,
  #       trait_value_id: 1901,
  #       display_order: 25,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 1682,
  #       question_id: 10,
  #       trait_value_id: 1902,
  #       display_order: 26,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1683,
  #       question_id: 10,
  #       trait_value_id: 1904,
  #       display_order: 1,
  #       text: "English"
  #     },
  #     %{
  #       id: 1684,
  #       question_id: 10,
  #       trait_value_id: 1905,
  #       display_order: 2,
  #       text: "Spanish"
  #     },
  #     %{
  #       id: 1685,
  #       question_id: 10,
  #       trait_value_id: 1906,
  #       display_order: 3,
  #       text: "Arabic"
  #     },
  #     %{
  #       id: 1686,
  #       question_id: 10,
  #       trait_value_id: 1907,
  #       display_order: 4,
  #       text: "Armenian"
  #     },
  #     %{
  #       id: 1687,
  #       question_id: 10,
  #       trait_value_id: 1908,
  #       display_order: 5,
  #       text: "Chinese - Cantonese"
  #     },
  #     %{
  #       id: 1688,
  #       question_id: 10,
  #       trait_value_id: 1909,
  #       display_order: 6,
  #       text: "Chinese - Mandarin"
  #     },
  #     %{
  #       id: 1689,
  #       question_id: 10,
  #       trait_value_id: 1910,
  #       display_order: 7,
  #       text: "French"
  #     },
  #     %{
  #       id: 1690,
  #       question_id: 10,
  #       trait_value_id: 1911,
  #       display_order: 8,
  #       text: "French Creole"
  #     },
  #     %{
  #       id: 1691,
  #       question_id: 10,
  #       trait_value_id: 1912,
  #       display_order: 9,
  #       text: "German"
  #     },
  #     %{
  #       id: 1692,
  #       question_id: 10,
  #       trait_value_id: 1913,
  #       display_order: 10,
  #       text: "Greek"
  #     },
  #     %{
  #       id: 1693,
  #       question_id: 10,
  #       trait_value_id: 1914,
  #       display_order: 11,
  #       text: "Gujarati"
  #     },
  #     %{
  #       id: 1694,
  #       question_id: 10,
  #       trait_value_id: 1915,
  #       display_order: 12,
  #       text: "Hindi"
  #     },
  #     %{
  #       id: 1695,
  #       question_id: 10,
  #       trait_value_id: 1916,
  #       display_order: 13,
  #       text: "Italian"
  #     },
  #     %{
  #       id: 1696,
  #       question_id: 10,
  #       trait_value_id: 1917,
  #       display_order: 14,
  #       text: "Japanese"
  #     },
  #     %{
  #       id: 1697,
  #       question_id: 10,
  #       trait_value_id: 1918,
  #       display_order: 15,
  #       text: "Korean"
  #     },
  #     %{
  #       id: 1698,
  #       question_id: 10,
  #       trait_value_id: 1919,
  #       display_order: 16,
  #       text: "Persian"
  #     },
  #     %{
  #       id: 1699,
  #       question_id: 10,
  #       trait_value_id: 1920,
  #       display_order: 17,
  #       text: "Polish"
  #     },
  #     %{
  #       id: 1700,
  #       question_id: 10,
  #       trait_value_id: 1921,
  #       display_order: 18,
  #       text: "Portuguese"
  #     },
  #     %{
  #       id: 1701,
  #       question_id: 10,
  #       trait_value_id: 1922,
  #       display_order: 19,
  #       text: "Russian"
  #     },
  #     %{
  #       id: 1702,
  #       question_id: 10,
  #       trait_value_id: 1923,
  #       display_order: 20,
  #       text: "Tagalog"
  #     },
  #     %{
  #       id: 1703,
  #       question_id: 10,
  #       trait_value_id: 1924,
  #       display_order: 21,
  #       text: "Thai"
  #     },
  #     %{
  #       id: 1704,
  #       question_id: 10,
  #       trait_value_id: 1925,
  #       display_order: 22,
  #       text: "Urdu"
  #     },
  #     %{
  #       id: 1705,
  #       question_id: 10,
  #       trait_value_id: 1926,
  #       display_order: 23,
  #       text: "Vietnamese"
  #     },
  #     %{
  #       id: 1706,
  #       question_id: 10,
  #       trait_value_id: 1927,
  #       display_order: 24,
  #       text: "Yiddish"
  #     },
  #     %{
  #       id: 1707,
  #       question_id: 10,
  #       trait_value_id: 1928,
  #       display_order: 25,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 1708,
  #       question_id: 23,
  #       trait_value_id: 1929,
  #       display_order: 326,
  #       text: "Iowa Lakes Community College"
  #     },
  #     %{
  #       id: 1709,
  #       question_id: 23,
  #       trait_value_id: 1930,
  #       display_order: 11,
  #       text: "American Baptist College"
  #     },
  #     %{
  #       id: 1710,
  #       question_id: 23,
  #       trait_value_id: 1931,
  #       display_order: 173,
  #       text: "Crowley's Ridge College"
  #     },
  #     %{
  #       id: 1711,
  #       question_id: 23,
  #       trait_value_id: 1932,
  #       display_order: 20,
  #       text: "Aquinas College"
  #     },
  #     %{
  #       id: 1712,
  #       question_id: 23,
  #       trait_value_id: 1933,
  #       display_order: 43,
  #       text: "Austin Peay State University"
  #     },
  #     %{
  #       id: 1713,
  #       question_id: 23,
  #       trait_value_id: 1934,
  #       display_order: 50,
  #       text: "Baptist College of Health Sciences"
  #     },
  #     %{
  #       id: 1714,
  #       question_id: 23,
  #       trait_value_id: 1935,
  #       display_order: 60,
  #       text: "Belmont University"
  #     },
  #     %{
  #       id: 1715,
  #       question_id: 23,
  #       trait_value_id: 1936,
  #       display_order: 64,
  #       text: "Bethel University"
  #     },
  #     %{
  #       id: 1716,
  #       question_id: 23,
  #       trait_value_id: 1937,
  #       display_order: 89,
  #       text: "Bryan College"
  #     },
  #     %{
  #       id: 1717,
  #       question_id: 23,
  #       trait_value_id: 1938,
  #       display_order: 113,
  #       text: "Carson-Newman College"
  #     },
  #     %{
  #       id: 1718,
  #       question_id: 23,
  #       trait_value_id: 1939,
  #       display_order: 127,
  #       text: "Chattanooga State Technical Community College"
  #     },
  #     %{
  #       id: 1719,
  #       question_id: 23,
  #       trait_value_id: 1940,
  #       display_order: 130,
  #       text: "Christian Brothers University"
  #     },
  #     %{
  #       id: 1720,
  #       question_id: 23,
  #       trait_value_id: 1941,
  #       display_order: 131,
  #       text: "Church of God Theological Seminary"
  #     },
  #     %{
  #       id: 1721,
  #       question_id: 23,
  #       trait_value_id: 1942,
  #       display_order: 141,
  #       text: "Cleveland State Community College"
  #     },
  #     %{
  #       id: 1722,
  #       question_id: 23,
  #       trait_value_id: 1943,
  #       display_order: 158,
  #       text: "Columbia State Community College"
  #     },
  #     %{
  #       id: 1723,
  #       question_id: 23,
  #       trait_value_id: 1944,
  #       display_order: 171,
  #       text: "Crichton College"
  #     },
  #     %{
  #       id: 1724,
  #       question_id: 23,
  #       trait_value_id: 1945,
  #       display_order: 174,
  #       text: "Cumberland University"
  #     },
  #     %{
  #       id: 1725,
  #       question_id: 23,
  #       trait_value_id: 1946,
  #       display_order: 199,
  #       text: "Dyersburg State Community College"
  #     },
  #     %{
  #       id: 1726,
  #       question_id: 23,
  #       trait_value_id: 1947,
  #       display_order: 206,
  #       text: "East Tennessee State University"
  #     },
  #     %{
  #       id: 1727,
  #       question_id: 23,
  #       trait_value_id: 1948,
  #       display_order: 220,
  #       text: "Emmanuel School of Religion"
  #     },
  #     %{
  #       id: 1728,
  #       question_id: 23,
  #       trait_value_id: 1949,
  #       display_order: 231,
  #       text: "Fisk University"
  #     },
  #     %{
  #       id: 1729,
  #       question_id: 23,
  #       trait_value_id: 1950,
  #       display_order: 257,
  #       text: "Fountainhead College of Technology"
  #     },
  #     %{
  #       id: 1730,
  #       question_id: 23,
  #       trait_value_id: 1951,
  #       display_order: 259,
  #       text: "Free Will Baptist Bible College"
  #     },
  #     %{
  #       id: 1731,
  #       question_id: 23,
  #       trait_value_id: 1952,
  #       display_order: 260,
  #       text: "Freed-Hardeman University"
  #     },
  #     %{
  #       id: 1732,
  #       question_id: 23,
  #       trait_value_id: 1953,
  #       display_order: 294,
  #       text: "Harding University Graduate School of Religion"
  #     },
  #     %{
  #       id: 1733,
  #       question_id: 23,
  #       trait_value_id: 1954,
  #       display_order: 305,
  #       text: "Hiwassee College"
  #     },
  #     %{
  #       id: 1734,
  #       question_id: 23,
  #       trait_value_id: 1955,
  #       display_order: 331,
  #       text: "Jackson State Community College"
  #     },
  #     %{
  #       id: 1735,
  #       question_id: 23,
  #       trait_value_id: 1956,
  #       display_order: 341,
  #       text: "John A. Gupton College"
  #     },
  #     %{
  #       id: 1736,
  #       question_id: 23,
  #       trait_value_id: 1957,
  #       display_order: 346,
  #       text: "Johnson Bible College"
  #     },
  #     %{
  #       id: 1737,
  #       question_id: 23,
  #       trait_value_id: 1958,
  #       display_order: 361,
  #       text: "King College"
  #     },
  #     %{
  #       id: 1738,
  #       question_id: 23,
  #       trait_value_id: 1959,
  #       display_order: 364,
  #       text: "Knoxville College"
  #     },
  #     %{
  #       id: 1739,
  #       question_id: 23,
  #       trait_value_id: 1960,
  #       display_order: 369,
  #       text: "Lambuth University"
  #     },
  #     %{
  #       id: 1740,
  #       question_id: 23,
  #       trait_value_id: 1961,
  #       display_order: 371,
  #       text: "Lane College"
  #     },
  #     %{
  #       id: 1741,
  #       question_id: 23,
  #       trait_value_id: 1962,
  #       display_order: 378,
  #       text: "Lee University"
  #     },
  #     %{
  #       id: 1742,
  #       question_id: 23,
  #       trait_value_id: 1963,
  #       display_order: 380,
  #       text: "Lemoyne-Owen College"
  #     },
  #     %{
  #       id: 1743,
  #       question_id: 23,
  #       trait_value_id: 1964,
  #       display_order: 385,
  #       text: "Lincoln Memorial University"
  #     },
  #     %{
  #       id: 1744,
  #       question_id: 23,
  #       trait_value_id: 1965,
  #       display_order: 387,
  #       text: "Lipscomb University"
  #     },
  #     %{
  #       id: 1745,
  #       question_id: 23,
  #       trait_value_id: 1966,
  #       display_order: 412,
  #       text: "Martin Methodist College"
  #     },
  #     %{
  #       id: 1746,
  #       question_id: 23,
  #       trait_value_id: 1967,
  #       display_order: 414,
  #       text: "Maryville College"
  #     },
  #     %{
  #       id: 1747,
  #       question_id: 23,
  #       trait_value_id: 1968,
  #       display_order: 420,
  #       text: "Meharry Medical College"
  #     },
  #     %{
  #       id: 1748,
  #       question_id: 23,
  #       trait_value_id: 1969,
  #       display_order: 421,
  #       text: "Memphis College of Art"
  #     },
  #     %{
  #       id: 1749,
  #       question_id: 23,
  #       trait_value_id: 1970,
  #       display_order: 422,
  #       text: "Memphis Theological Seminary"
  #     },
  #     %{
  #       id: 1750,
  #       question_id: 23,
  #       trait_value_id: 1971,
  #       display_order: 432,
  #       text: "Mid-America Baptist Theological Seminary"
  #     },
  #     %{
  #       id: 1751,
  #       question_id: 23,
  #       trait_value_id: 1972,
  #       display_order: 442,
  #       text: "Miller-Motte Technical College"
  #     },
  #     %{
  #       id: 1752,
  #       question_id: 23,
  #       trait_value_id: 1973,
  #       display_order: 443,
  #       text: "Milligan College"
  #     },
  #     %{
  #       id: 1753,
  #       question_id: 23,
  #       trait_value_id: 1974,
  #       display_order: 461,
  #       text: "Motlow State Community College"
  #     },
  #     %{
  #       id: 1754,
  #       question_id: 23,
  #       trait_value_id: 1975,
  #       display_order: 464,
  #       text: "Nashville State Technical Community College"
  #     },
  #     %{
  #       id: 1755,
  #       question_id: 23,
  #       trait_value_id: 1976,
  #       display_order: 465,
  #       text: "National College of Business & Technology"
  #     },
  #     %{
  #       id: 1756,
  #       question_id: 23,
  #       trait_value_id: 1977,
  #       display_order: 486,
  #       text: "Northeast State Technical Community College"
  #     },
  #     %{
  #       id: 1757,
  #       question_id: 23,
  #       trait_value_id: 1978,
  #       display_order: 505,
  #       text: "O'more College of Design"
  #     },
  #     %{
  #       id: 1758,
  #       question_id: 23,
  #       trait_value_id: 1979,
  #       display_order: 542,
  #       text: "Pellissippi State Technical Community College"
  #     },
  #     %{
  #       id: 1759,
  #       question_id: 23,
  #       trait_value_id: 1980,
  #       display_order: 565,
  #       text: "Rhodes College"
  #     },
  #     %{
  #       id: 1760,
  #       question_id: 23,
  #       trait_value_id: 1981,
  #       display_order: 573,
  #       text: "Roane State Community College"
  #     },
  #     %{
  #       id: 1761,
  #       question_id: 23,
  #       trait_value_id: 1982,
  #       display_order: 627,
  #       text: "South College"
  #     },
  #     %{
  #       id: 1762,
  #       question_id: 23,
  #       trait_value_id: 1983,
  #       display_order: 639,
  #       text: "Southern Adventist University"
  #     },
  #     %{
  #       id: 1763,
  #       question_id: 23,
  #       trait_value_id: 1984,
  #       display_order: 643,
  #       text: "Southern College of Optometry"
  #     },
  #     %{
  #       id: 1764,
  #       question_id: 23,
  #       trait_value_id: 1985,
  #       display_order: 656,
  #       text: "Southwest Tennessee Community College"
  #     },
  #     %{
  #       id: 1765,
  #       question_id: 23,
  #       trait_value_id: 1986,
  #       display_order: 681,
  #       text: "Temple Baptist Seminary"
  #     },
  #     %{
  #       id: 1766,
  #       question_id: 23,
  #       trait_value_id: 1987,
  #       display_order: 683,
  #       text: "Tennessee State University"
  #     },
  #     %{
  #       id: 1767,
  #       question_id: 23,
  #       trait_value_id: 1988,
  #       display_order: 684,
  #       text: "Tennessee Technological University"
  #     },
  #     %{
  #       id: 1768,
  #       question_id: 23,
  #       trait_value_id: 1989,
  #       display_order: 685,
  #       text: "Tennessee Temple University"
  #     },
  #     %{
  #       id: 1769,
  #       question_id: 23,
  #       trait_value_id: 1990,
  #       display_order: 686,
  #       text: "Tennessee Wesleyan College"
  #     },
  #     %{
  #       id: 1770,
  #       question_id: 23,
  #       trait_value_id: 1991,
  #       display_order: 705,
  #       text: "Trevecca Nazarene University"
  #     },
  #     %{
  #       id: 1771,
  #       question_id: 23,
  #       trait_value_id: 1992,
  #       display_order: 715,
  #       text: "Tusculum College"
  #     },
  #     %{
  #       id: 1772,
  #       question_id: 23,
  #       trait_value_id: 1993,
  #       display_order: 719,
  #       text: "Union University"
  #     },
  #     %{
  #       id: 1774,
  #       question_id: 23,
  #       trait_value_id: 1995,
  #       display_order: 818,
  #       text: "University of Tennessee Space Institute, The"
  #     },
  #     %{
  #       id: 1775,
  #       question_id: 23,
  #       trait_value_id: 1996,
  #       display_order: 820,
  #       text: "University of Tennessee-Chattanooga"
  #     },
  #     %{
  #       id: 1776,
  #       question_id: 23,
  #       trait_value_id: 1997,
  #       display_order: 821,
  #       text: "University of Tennessee-Martin"
  #     },
  #     %{
  #       id: 1777,
  #       question_id: 23,
  #       trait_value_id: 1998,
  #       display_order: 822,
  #       text: "University of Tennessee-Memphis"
  #     },
  #     %{
  #       id: 1778,
  #       question_id: 23,
  #       trait_value_id: 1999,
  #       display_order: 835,
  #       text: "University of the South, The"
  #     },
  #     %{
  #       id: 1780,
  #       question_id: 23,
  #       trait_value_id: 2001,
  #       display_order: 861,
  #       text: "Volunteer State Community College"
  #     },
  #     %{
  #       id: 1781,
  #       question_id: 23,
  #       trait_value_id: 2002,
  #       display_order: 868,
  #       text: "Walters State Community College"
  #     },
  #     %{
  #       id: 1782,
  #       question_id: 23,
  #       trait_value_id: 2003,
  #       display_order: 872,
  #       text: "Watkins College of Art & Design"
  #     },
  #     %{
  #       id: 1783,
  #       question_id: 23,
  #       trait_value_id: 2004,
  #       display_order: 896,
  #       text: "Williamson Christian College"
  #     },
  #     %{
  #       id: 1784,
  #       question_id: 23,
  #       trait_value_id: 2005,
  #       display_order: 1,
  #       text: "Abraham Baldwin Agricultural College"
  #     },
  #     %{
  #       id: 1785,
  #       question_id: 23,
  #       trait_value_id: 2006,
  #       display_order: 2,
  #       text: "Agnes Scott College"
  #     },
  #     %{
  #       id: 1786,
  #       question_id: 23,
  #       trait_value_id: 2007,
  #       display_order: 4,
  #       text: "Albany State University"
  #     },
  #     %{
  #       id: 1787,
  #       question_id: 23,
  #       trait_value_id: 2008,
  #       display_order: 5,
  #       text: "Albany Technical College"
  #     },
  #     %{
  #       id: 1788,
  #       question_id: 23,
  #       trait_value_id: 2009,
  #       display_order: 13,
  #       text: "American InterContinental University - Buckhead"
  #     },
  #     %{
  #       id: 1789,
  #       question_id: 23,
  #       trait_value_id: 2010,
  #       display_order: 16,
  #       text: "Andrew College"
  #     },
  #     %{
  #       id: 1790,
  #       question_id: 23,
  #       trait_value_id: 2011,
  #       display_order: 30,
  #       text: "Armstrong Atlantic State University"
  #     },
  #     %{
  #       id: 1791,
  #       question_id: 23,
  #       trait_value_id: 2012,
  #       display_order: 35,
  #       text: "Athens Technical College"
  #     },
  #     %{
  #       id: 1792,
  #       question_id: 23,
  #       trait_value_id: 2013,
  #       display_order: 36,
  #       text: "Atlanta Christian College"
  #     },
  #     %{
  #       id: 1793,
  #       question_id: 23,
  #       trait_value_id: 2014,
  #       display_order: 37,
  #       text: "Atlanta Metropolitan College"
  #     },
  #     %{
  #       id: 1794,
  #       question_id: 23,
  #       trait_value_id: 2015,
  #       display_order: 39,
  #       text: "Augusta State University"
  #     },
  #     %{
  #       id: 1795,
  #       question_id: 23,
  #       trait_value_id: 2016,
  #       display_order: 40,
  #       text: "Augusta Technical College"
  #     },
  #     %{
  #       id: 1796,
  #       question_id: 23,
  #       trait_value_id: 2017,
  #       display_order: 46,
  #       text: "Bainbridge College"
  #     },
  #     %{
  #       id: 1797,
  #       question_id: 23,
  #       trait_value_id: 2018,
  #       display_order: 54,
  #       text: "Bauder College"
  #     },
  #     %{
  #       id: 1798,
  #       question_id: 23,
  #       trait_value_id: 2019,
  #       display_order: 57,
  #       text: "Beacon College & Graduate School"
  #     },
  #     %{
  #       id: 1799,
  #       question_id: 23,
  #       trait_value_id: 2020,
  #       display_order: 63,
  #       text: "Berry College"
  #     },
  #     %{
  #       id: 1800,
  #       question_id: 23,
  #       trait_value_id: 2021,
  #       display_order: 66,
  #       text: "Beulah Heights Bible College"
  #     },
  #     %{
  #       id: 1801,
  #       question_id: 23,
  #       trait_value_id: 2022,
  #       display_order: 81,
  #       text: "Brenau University"
  #     },
  #     %{
  #       id: 1802,
  #       question_id: 23,
  #       trait_value_id: 2023,
  #       display_order: 84,
  #       text: "Brewton Parker College"
  #     },
  #     %{
  #       id: 1803,
  #       question_id: 23,
  #       trait_value_id: 2024,
  #       display_order: 118,
  #       text: "Central Georgia Technical College"
  #     },
  #     %{
  #       id: 1804,
  #       question_id: 23,
  #       trait_value_id: 2025,
  #       display_order: 126,
  #       text: "Chattahoochee Technical College"
  #     },
  #     %{
  #       id: 1805,
  #       question_id: 23,
  #       trait_value_id: 2026,
  #       display_order: 129,
  #       text: "Christ College"
  #     },
  #     %{
  #       id: 1806,
  #       question_id: 23,
  #       trait_value_id: 2027,
  #       display_order: 136,
  #       text: "Clark Atlanta University"
  #     },
  #     %{
  #       id: 1807,
  #       question_id: 23,
  #       trait_value_id: 2028,
  #       display_order: 137,
  #       text: "Clayton College & State University"
  #     },
  #     %{
  #       id: 1808,
  #       question_id: 23,
  #       trait_value_id: 2029,
  #       display_order: 147,
  #       text: "College of Coastal Georgia"
  #     },
  #     %{
  #       id: 1809,
  #       question_id: 23,
  #       trait_value_id: 2030,
  #       display_order: 159,
  #       text: "Columbia Theological Seminary"
  #     },
  #     %{
  #       id: 1810,
  #       question_id: 23,
  #       trait_value_id: 2031,
  #       display_order: 161,
  #       text: "Columbus State University"
  #     },
  #     %{
  #       id: 1811,
  #       question_id: 23,
  #       trait_value_id: 2032,
  #       display_order: 162,
  #       text: "Columbus Technical College"
  #     },
  #     %{
  #       id: 1812,
  #       question_id: 23,
  #       trait_value_id: 2033,
  #       display_order: 165,
  #       text: "Coosa Valley Technical College"
  #     },
  #     %{
  #       id: 1813,
  #       question_id: 23,
  #       trait_value_id: 2034,
  #       display_order: 170,
  #       text: "Covenant College"
  #     },
  #     %{
  #       id: 1814,
  #       question_id: 23,
  #       trait_value_id: 2035,
  #       display_order: 181,
  #       text: "Dalton State College"
  #     },
  #     %{
  #       id: 1815,
  #       question_id: 23,
  #       trait_value_id: 2036,
  #       display_order: 183,
  #       text: "Darton College"
  #     },
  #     %{
  #       id: 1816,
  #       question_id: 23,
  #       trait_value_id: 2037,
  #       display_order: 188,
  #       text: "DeKalb Technical College"
  #     },
  #     %{
  #       id: 1817,
  #       question_id: 23,
  #       trait_value_id: 2038,
  #       display_order: 203,
  #       text: "East Georgia College"
  #     },
  #     %{
  #       id: 1818,
  #       question_id: 23,
  #       trait_value_id: 2039,
  #       display_order: 219,
  #       text: "Emmanuel College"
  #     },
  #     %{
  #       id: 1819,
  #       question_id: 23,
  #       trait_value_id: 2040,
  #       display_order: 221,
  #       text: "Emory University"
  #     },
  #     %{
  #       id: 1820,
  #       question_id: 23,
  #       trait_value_id: 2041,
  #       display_order: 256,
  #       text: "Fort Valley State University"
  #     },
  #     %{
  #       id: 1821,
  #       question_id: 23,
  #       trait_value_id: 2042,
  #       display_order: 267,
  #       text: "Gainesville State College"
  #     },
  #     %{
  #       id: 1822,
  #       question_id: 23,
  #       trait_value_id: 2043,
  #       display_order: 268,
  #       text: "Gammon Theological Seminary"
  #     },
  #     %{
  #       id: 1823,
  #       question_id: 23,
  #       trait_value_id: 2044,
  #       display_order: 272,
  #       text: "Georgia Gwinnett College "
  #     },
  #     %{
  #       id: 1824,
  #       question_id: 23,
  #       trait_value_id: 2045,
  #       display_order: 273,
  #       text: "Georgia Highlands College"
  #     },
  #     %{
  #       id: 1825,
  #       question_id: 23,
  #       trait_value_id: 2046,
  #       display_order: 374,
  #       text: "Lanier Technical College"
  #     },
  #     %{
  #       id: 1826,
  #       question_id: 23,
  #       trait_value_id: 2047,
  #       display_order: 383,
  #       text: "Life University"
  #     },
  #     %{
  #       id: 1827,
  #       question_id: 23,
  #       trait_value_id: 2048,
  #       display_order: 400,
  #       text: "Luther Rice Seminary & University"
  #     },
  #     %{
  #       id: 1828,
  #       question_id: 23,
  #       trait_value_id: 2049,
  #       display_order: 404,
  #       text: "Macon State College"
  #     },
  #     %{
  #       id: 1829,
  #       question_id: 23,
  #       trait_value_id: 2050,
  #       display_order: 419,
  #       text: "Medical College of Georgia"
  #     },
  #     %{
  #       id: 1830,
  #       question_id: 23,
  #       trait_value_id: 2051,
  #       display_order: 423,
  #       text: "Mercer University"
  #     },
  #     %{
  #       id: 1831,
  #       question_id: 23,
  #       trait_value_id: 2052,
  #       display_order: 435,
  #       text: "Middle Georgia College"
  #     },
  #     %{
  #       id: 1832,
  #       question_id: 23,
  #       trait_value_id: 2053,
  #       display_order: 458,
  #       text: "Morehouse College"
  #     },
  #     %{
  #       id: 1833,
  #       question_id: 23,
  #       trait_value_id: 2054,
  #       display_order: 459,
  #       text: "Morehouse School of Medicine"
  #     },
  #     %{
  #       id: 1834,
  #       question_id: 23,
  #       trait_value_id: 2055,
  #       display_order: 460,
  #       text: "Morris Brown College"
  #     },
  #     %{
  #       id: 1835,
  #       question_id: 23,
  #       trait_value_id: 2056,
  #       display_order: 478,
  #       text: "North Georgia Technical College"
  #     },
  #     %{
  #       id: 1836,
  #       question_id: 23,
  #       trait_value_id: 2057,
  #       display_order: 482,
  #       text: "North Metro Technical College"
  #     },
  #     %{
  #       id: 1837,
  #       question_id: 23,
  #       trait_value_id: 2058,
  #       display_order: 500,
  #       text: "Northwestern Technical College"
  #     },
  #     %{
  #       id: 1838,
  #       question_id: 23,
  #       trait_value_id: 2059,
  #       display_order: 510,
  #       text: "Ogeechee Technical College"
  #     },
  #     %{
  #       id: 1839,
  #       question_id: 23,
  #       trait_value_id: 2060,
  #       display_order: 511,
  #       text: "Oglethorpe University"
  #     },
  #     %{
  #       id: 1840,
  #       question_id: 23,
  #       trait_value_id: 2061,
  #       display_order: 530,
  #       text: "Paine College"
  #     },
  #     %{
  #       id: 1841,
  #       question_id: 23,
  #       trait_value_id: 2062,
  #       display_order: 549,
  #       text: "Piedmont College"
  #     },
  #     %{
  #       id: 1842,
  #       question_id: 23,
  #       trait_value_id: 2063,
  #       display_order: 563,
  #       text: "Reinhardt College"
  #     },
  #     %{
  #       id: 1843,
  #       question_id: 23,
  #       trait_value_id: 2064,
  #       display_order: 608,
  #       text: "Savannah College of Art & Design"
  #     },
  #     %{
  #       id: 1844,
  #       question_id: 23,
  #       trait_value_id: 2065,
  #       display_order: 609,
  #       text: "Savannah State University"
  #     },
  #     %{
  #       id: 1845,
  #       question_id: 23,
  #       trait_value_id: 2066,
  #       display_order: 610,
  #       text: "Savannah Technical College"
  #     },
  #     %{
  #       id: 1846,
  #       question_id: 23,
  #       trait_value_id: 2067,
  #       display_order: 616,
  #       text: "Shorter College"
  #     },
  #     %{
  #       id: 1847,
  #       question_id: 23,
  #       trait_value_id: 2068,
  #       display_order: 630,
  #       text: "South Georgia College"
  #     },
  #     %{
  #       id: 1848,
  #       question_id: 23,
  #       trait_value_id: 2069,
  #       display_order: 633,
  #       text: "South University"
  #     },
  #     %{
  #       id: 1849,
  #       question_id: 23,
  #       trait_value_id: 2070,
  #       display_order: 649,
  #       text: "Southern Polytechnic State University"
  #     },
  #     %{
  #       id: 1850,
  #       question_id: 23,
  #       trait_value_id: 2071,
  #       display_order: 670,
  #       text: "State University of West Georgia"
  #     },
  #     %{
  #       id: 1851,
  #       question_id: 23,
  #       trait_value_id: 2072,
  #       display_order: 700,
  #       text: "Thomas University"
  #     },
  #     %{
  #       id: 1852,
  #       question_id: 23,
  #       trait_value_id: 2073,
  #       display_order: 381,
  #       text: "Lexington Community College"
  #     },
  #     %{
  #       id: 1853,
  #       question_id: 23,
  #       trait_value_id: 2074,
  #       display_order: 382,
  #       text: "Lexington Theological Seminary"
  #     },
  #     %{
  #       id: 1854,
  #       question_id: 23,
  #       trait_value_id: 2075,
  #       display_order: 386,
  #       text: "Lindsey Wilson College"
  #     },
  #     %{
  #       id: 1856,
  #       question_id: 23,
  #       trait_value_id: 2077,
  #       display_order: 275,
  #       text: "Georgia Military College"
  #     },
  #     %{
  #       id: 1858,
  #       question_id: 23,
  #       trait_value_id: 2079,
  #       display_order: 278,
  #       text: "Georgia Southwestern State University"
  #     },
  #     %{
  #       id: 1859,
  #       question_id: 23,
  #       trait_value_id: 2080,
  #       display_order: 281,
  #       text: "Gordon College"
  #     },
  #     %{
  #       id: 1860,
  #       question_id: 23,
  #       trait_value_id: 2081,
  #       display_order: 288,
  #       text: "Griffin Technical College"
  #     },
  #     %{
  #       id: 1861,
  #       question_id: 23,
  #       trait_value_id: 2082,
  #       display_order: 291,
  #       text: "Gwinnett Technical College"
  #     },
  #     %{
  #       id: 1862,
  #       question_id: 23,
  #       trait_value_id: 2083,
  #       display_order: 323,
  #       text: "Institute of Paper Science & Technology"
  #     },
  #     %{
  #       id: 1863,
  #       question_id: 23,
  #       trait_value_id: 2084,
  #       display_order: 324,
  #       text: "Interdenominational Theological Center"
  #     },
  #     %{
  #       id: 1864,
  #       question_id: 23,
  #       trait_value_id: 2085,
  #       display_order: 344,
  #       text: "John Marshall Law School"
  #     },
  #     %{
  #       id: 1866,
  #       question_id: 23,
  #       trait_value_id: 2087,
  #       display_order: 365,
  #       text: "LaGrange College"
  #     },
  #     %{
  #       id: 1867,
  #       question_id: 23,
  #       trait_value_id: 2088,
  #       display_order: 654,
  #       text: "Southwest Georgia Technical College"
  #     },
  #     %{
  #       id: 1868,
  #       question_id: 23,
  #       trait_value_id: 2089,
  #       display_order: 662,
  #       text: "Spelman College"
  #     },
  #     %{
  #       id: 1869,
  #       question_id: 23,
  #       trait_value_id: 2090,
  #       display_order: 701,
  #       text: "Toccoa Falls College"
  #     },
  #     %{
  #       id: 1870,
  #       question_id: 23,
  #       trait_value_id: 2091,
  #       display_order: 710,
  #       text: "Troy University - Atlanta"
  #     },
  #     %{
  #       id: 1871,
  #       question_id: 23,
  #       trait_value_id: 2092,
  #       display_order: 711,
  #       text: "Troy University - Fort Benning"
  #     },
  #     %{
  #       id: 1872,
  #       question_id: 23,
  #       trait_value_id: 2093,
  #       display_order: 712,
  #       text: "Truett-McConnell College"
  #     },
  #     %{
  #       id: 1873,
  #       question_id: 23,
  #       trait_value_id: 2094,
  #       display_order: 873,
  #       text: "Waycross College"
  #     },
  #     %{
  #       id: 1874,
  #       question_id: 23,
  #       trait_value_id: 2095,
  #       display_order: 879,
  #       text: "Wesleyan College"
  #     },
  #     %{
  #       id: 1875,
  #       question_id: 23,
  #       trait_value_id: 2096,
  #       display_order: 880,
  #       text: "West Central Technical College"
  #     },
  #     %{
  #       id: 1876,
  #       question_id: 23,
  #       trait_value_id: 2097,
  #       display_order: 881,
  #       text: "West Georgia Technical College"
  #     },
  #     %{
  #       id: 1877,
  #       question_id: 23,
  #       trait_value_id: 2098,
  #       display_order: 902,
  #       text: "Young Harris College"
  #     },
  #     %{
  #       id: 1878,
  #       question_id: 23,
  #       trait_value_id: 2099,
  #       display_order: 7,
  #       text: "Alice Lloyd College"
  #     },
  #     %{
  #       id: 1879,
  #       question_id: 23,
  #       trait_value_id: 2100,
  #       display_order: 32,
  #       text: "Asbury College"
  #     },
  #     %{
  #       id: 1880,
  #       question_id: 23,
  #       trait_value_id: 2101,
  #       display_order: 33,
  #       text: "Asbury Theological Seminary"
  #     },
  #     %{
  #       id: 1881,
  #       question_id: 23,
  #       trait_value_id: 2102,
  #       display_order: 34,
  #       text: "Ashland Community College"
  #     },
  #     %{
  #       id: 1882,
  #       question_id: 23,
  #       trait_value_id: 2103,
  #       display_order: 59,
  #       text: "Bellarmine University"
  #     },
  #     %{
  #       id: 1883,
  #       question_id: 23,
  #       trait_value_id: 2104,
  #       display_order: 61,
  #       text: "Berea College"
  #     },
  #     %{
  #       id: 1884,
  #       question_id: 23,
  #       trait_value_id: 2105,
  #       display_order: 67,
  #       text: "Big Sandy Community & Technical College"
  #     },
  #     %{
  #       id: 1885,
  #       question_id: 23,
  #       trait_value_id: 2106,
  #       display_order: 74,
  #       text: "Bluegrass Community & Technical College"
  #     },
  #     %{
  #       id: 1886,
  #       question_id: 23,
  #       trait_value_id: 2107,
  #       display_order: 78,
  #       text: "Bowling Green Community College"
  #     },
  #     %{
  #       id: 1887,
  #       question_id: 23,
  #       trait_value_id: 2108,
  #       display_order: 82,
  #       text: "Brescia University"
  #     },
  #     %{
  #       id: 1888,
  #       question_id: 23,
  #       trait_value_id: 2109,
  #       display_order: 109,
  #       text: "Campbellsville University"
  #     },
  #     %{
  #       id: 1889,
  #       question_id: 23,
  #       trait_value_id: 2110,
  #       display_order: 119,
  #       text: "Central Kentucky Technical College"
  #     },
  #     %{
  #       id: 1890,
  #       question_id: 23,
  #       trait_value_id: 2111,
  #       display_order: 123,
  #       text: "Centre College"
  #     },
  #     %{
  #       id: 1891,
  #       question_id: 23,
  #       trait_value_id: 2112,
  #       display_order: 138,
  #       text: "Clear Creek Baptist Bible College"
  #     },
  #     %{
  #       id: 1892,
  #       question_id: 23,
  #       trait_value_id: 2113,
  #       display_order: 184,
  #       text: "Daymar College"
  #     },
  #     %{
  #       id: 1893,
  #       question_id: 23,
  #       trait_value_id: 2114,
  #       display_order: 217,
  #       text: "Elizabethtown Community College"
  #     },
  #     %{
  #       id: 1894,
  #       question_id: 23,
  #       trait_value_id: 2115,
  #       display_order: 270,
  #       text: "Georgetown College"
  #     },
  #     %{
  #       id: 1895,
  #       question_id: 23,
  #       trait_value_id: 2116,
  #       display_order: 298,
  #       text: "Hazard Community & Technical College"
  #     },
  #     %{
  #       id: 1896,
  #       question_id: 23,
  #       trait_value_id: 2117,
  #       display_order: 299,
  #       text: "Henderson Community College"
  #     },
  #     %{
  #       id: 1897,
  #       question_id: 23,
  #       trait_value_id: 2118,
  #       display_order: 310,
  #       text: "Hopkinsville Community College"
  #     },
  #     %{
  #       id: 1898,
  #       question_id: 23,
  #       trait_value_id: 2119,
  #       display_order: 336,
  #       text: "Jefferson Community & Technical College"
  #     },
  #     %{
  #       id: 1899,
  #       question_id: 23,
  #       trait_value_id: 2120,
  #       display_order: 338,
  #       text: "Jefferson Community College"
  #     },
  #     %{
  #       id: 1900,
  #       question_id: 23,
  #       trait_value_id: 2121,
  #       display_order: 356,
  #       text: "Kentucky Christian University"
  #     },
  #     %{
  #       id: 1901,
  #       question_id: 23,
  #       trait_value_id: 2122,
  #       display_order: 357,
  #       text: "Kentucky Mountain Bible College"
  #     },
  #     %{
  #       id: 1902,
  #       question_id: 23,
  #       trait_value_id: 2123,
  #       display_order: 358,
  #       text: "Kentucky State University"
  #     },
  #     %{
  #       id: 1903,
  #       question_id: 23,
  #       trait_value_id: 2124,
  #       display_order: 359,
  #       text: "Kentucky Wesleyan College"
  #     },
  #     %{
  #       id: 1904,
  #       question_id: 23,
  #       trait_value_id: 2125,
  #       display_order: 397,
  #       text: "Louisville Presbyterian Theological Seminary"
  #     },
  #     %{
  #       id: 1905,
  #       question_id: 23,
  #       trait_value_id: 2126,
  #       display_order: 405,
  #       text: "Madisonville Community College"
  #     },
  #     %{
  #       id: 1906,
  #       question_id: 23,
  #       trait_value_id: 2127,
  #       display_order: 416,
  #       text: "Maysville Community & Technical College"
  #     },
  #     %{
  #       id: 1907,
  #       question_id: 23,
  #       trait_value_id: 2128,
  #       display_order: 433,
  #       text: "Mid-Continent University "
  #     },
  #     %{
  #       id: 1908,
  #       question_id: 23,
  #       trait_value_id: 2129,
  #       display_order: 439,
  #       text: "Midway College"
  #     },
  #     %{
  #       id: 1909,
  #       question_id: 23,
  #       trait_value_id: 2130,
  #       display_order: 457,
  #       text: "Morehead State University"
  #     },
  #     %{
  #       id: 1910,
  #       question_id: 23,
  #       trait_value_id: 2131,
  #       display_order: 463,
  #       text: "Murray State University"
  #     },
  #     %{
  #       id: 1911,
  #       question_id: 23,
  #       trait_value_id: 2132,
  #       display_order: 490,
  #       text: "Northern Kentucky University"
  #     },
  #     %{
  #       id: 1912,
  #       question_id: 23,
  #       trait_value_id: 2133,
  #       display_order: 526,
  #       text: "Owensboro Community & Technical College"
  #     },
  #     %{
  #       id: 1913,
  #       question_id: 23,
  #       trait_value_id: 2134,
  #       display_order: 550,
  #       text: "Pikeville College"
  #     },
  #     %{
  #       id: 1914,
  #       question_id: 23,
  #       trait_value_id: 2135,
  #       display_order: 580,
  #       text: "Saint Catharine College"
  #     },
  #     %{
  #       id: 1915,
  #       question_id: 23,
  #       trait_value_id: 2136,
  #       display_order: 618,
  #       text: "Simmons College of Kentucky"
  #     },
  #     %{
  #       id: 1916,
  #       question_id: 23,
  #       trait_value_id: 2137,
  #       display_order: 624,
  #       text: "Somerset Community College"
  #     },
  #     %{
  #       id: 1917,
  #       question_id: 23,
  #       trait_value_id: 2138,
  #       display_order: 635,
  #       text: "Southeast Kentucky Community and Technical College "
  #     },
  #     %{
  #       id: 1918,
  #       question_id: 23,
  #       trait_value_id: 2139,
  #       display_order: 642,
  #       text: "Southern Baptist Theological Seminary"
  #     },
  #     %{
  #       id: 1919,
  #       question_id: 23,
  #       trait_value_id: 2140,
  #       display_order: 661,
  #       text: "Spalding University"
  #     },
  #     %{
  #       id: 1920,
  #       question_id: 23,
  #       trait_value_id: 2141,
  #       display_order: 663,
  #       text: "Spencerian College"
  #     },
  #     %{
  #       id: 1921,
  #       question_id: 23,
  #       trait_value_id: 2142,
  #       display_order: 674,
  #       text: "Sullivan University"
  #     },
  #     %{
  #       id: 1922,
  #       question_id: 23,
  #       trait_value_id: 2143,
  #       display_order: 699,
  #       text: "Thomas More College"
  #     },
  #     %{
  #       id: 1923,
  #       question_id: 23,
  #       trait_value_id: 2144,
  #       display_order: 704,
  #       text: "Transylvania University"
  #     },
  #     %{
  #       id: 1924,
  #       question_id: 23,
  #       trait_value_id: 2145,
  #       display_order: 718,
  #       text: "Union College"
  #     },
  #     %{
  #       id: 1925,
  #       question_id: 23,
  #       trait_value_id: 2146,
  #       display_order: 832,
  #       text: "University of the Cumberlands"
  #     },
  #     %{
  #       id: 1926,
  #       question_id: 23,
  #       trait_value_id: 2147,
  #       display_order: 882,
  #       text: "West Kentucky Community & Technical College"
  #     },
  #     %{
  #       id: 1927,
  #       question_id: 23,
  #       trait_value_id: 2148,
  #       display_order: 190,
  #       text: "Delgado Community College"
  #     },
  #     %{
  #       id: 1928,
  #       question_id: 23,
  #       trait_value_id: 2149,
  #       display_order: 196,
  #       text: "Dillard University"
  #     },
  #     %{
  #       id: 1929,
  #       question_id: 23,
  #       trait_value_id: 2150,
  #       display_order: 222,
  #       text: "Evangel Christian University of America"
  #     },
  #     %{
  #       id: 1930,
  #       question_id: 23,
  #       trait_value_id: 2151,
  #       display_order: 284,
  #       text: "Grantham University"
  #     },
  #     %{
  #       id: 1931,
  #       question_id: 23,
  #       trait_value_id: 2152,
  #       display_order: 396,
  #       text: "Louisiana State University Health Sciences Center - New Orleans"
  #     },
  #     %{
  #       id: 1932,
  #       question_id: 23,
  #       trait_value_id: 2153,
  #       display_order: 398,
  #       text: "Loyola University New Orleans"
  #     },
  #     %{
  #       id: 1933,
  #       question_id: 23,
  #       trait_value_id: 2154,
  #       display_order: 418,
  #       text: "McNeese State University"
  #     },
  #     %{
  #       id: 1934,
  #       question_id: 23,
  #       trait_value_id: 2155,
  #       display_order: 470,
  #       text: "New Orleans Baptist Theological Seminary"
  #     },
  #     %{
  #       id: 1935,
  #       question_id: 23,
  #       trait_value_id: 2156,
  #       display_order: 502,
  #       text: "Notre Dame Seminary Chapel"
  #     },
  #     %{
  #       id: 1936,
  #       question_id: 23,
  #       trait_value_id: 2157,
  #       display_order: 504,
  #       text: "Nunez Community College"
  #     },
  #     %{
  #       id: 1937,
  #       question_id: 23,
  #       trait_value_id: 2158,
  #       display_order: 523,
  #       text: "Our Lady of Holy Cross College"
  #     },
  #     %{
  #       id: 1938,
  #       question_id: 23,
  #       trait_value_id: 2159,
  #       display_order: 631,
  #       text: "South Louisiana Community College"
  #     },
  #     %{
  #       id: 1939,
  #       question_id: 23,
  #       trait_value_id: 2160,
  #       display_order: 651,
  #       text: "Southern University - New Orleans"
  #     },
  #     %{
  #       id: 1940,
  #       question_id: 23,
  #       trait_value_id: 2161,
  #       display_order: 658,
  #       text: "Southwest University"
  #     },
  #     %{
  #       id: 1941,
  #       question_id: 23,
  #       trait_value_id: 2162,
  #       display_order: 900,
  #       text: "Xavier University"
  #     },
  #     %{
  #       id: 1942,
  #       question_id: 23,
  #       trait_value_id: 2163,
  #       display_order: 12,
  #       text: "American Intercontinental University"
  #     },
  #     %{
  #       id: 1943,
  #       question_id: 23,
  #       trait_value_id: 2164,
  #       display_order: 21,
  #       text: "Argosy University"
  #     },
  #     %{
  #       id: 1944,
  #       question_id: 23,
  #       trait_value_id: 2165,
  #       display_order: 31,
  #       text: "Art Institute of Jacksonville, The"
  #     },
  #     %{
  #       id: 1945,
  #       question_id: 23,
  #       trait_value_id: 2166,
  #       display_order: 49,
  #       text: "Baptist College of Florida, The"
  #     },
  #     %{
  #       id: 1946,
  #       question_id: 23,
  #       trait_value_id: 2167,
  #       display_order: 56,
  #       text: "Beacon College"
  #     },
  #     %{
  #       id: 1947,
  #       question_id: 23,
  #       trait_value_id: 2168,
  #       display_order: 65,
  #       text: "Bethune-Cookman College"
  #     },
  #     %{
  #       id: 1948,
  #       question_id: 23,
  #       trait_value_id: 2169,
  #       display_order: 83,
  #       text: "Brevard Community College"
  #     },
  #     %{
  #       id: 1950,
  #       question_id: 23,
  #       trait_value_id: 2171,
  #       display_order: 111,
  #       text: "Capital Culinary Institute"
  #     },
  #     %{
  #       id: 1951,
  #       question_id: 23,
  #       trait_value_id: 2172,
  #       display_order: 117,
  #       text: "Central Florida Community College"
  #     },
  #     %{
  #       id: 1952,
  #       question_id: 23,
  #       trait_value_id: 2173,
  #       display_order: 128,
  #       text: "Chipola College"
  #     },
  #     %{
  #       id: 1953,
  #       question_id: 23,
  #       trait_value_id: 2174,
  #       display_order: 139,
  #       text: "Clearwater Christian College"
  #     },
  #     %{
  #       id: 1954,
  #       question_id: 23,
  #       trait_value_id: 2175,
  #       display_order: 186,
  #       text: "Daytona State College"
  #     },
  #     %{
  #       id: 1955,
  #       question_id: 23,
  #       trait_value_id: 2176,
  #       display_order: 195,
  #       text: "Digital Media Arts College"
  #     },
  #     %{
  #       id: 1956,
  #       question_id: 23,
  #       trait_value_id: 2177,
  #       display_order: 211,
  #       text: "Eckerd College"
  #     },
  #     %{
  #       id: 1957,
  #       question_id: 23,
  #       trait_value_id: 2178,
  #       display_order: 213,
  #       text: "Edison State College"
  #     },
  #     %{
  #       id: 1958,
  #       question_id: 23,
  #       trait_value_id: 2179,
  #       display_order: 214,
  #       text: "Edward Waters College"
  #     },
  #     %{
  #       id: 1959,
  #       question_id: 23,
  #       trait_value_id: 2180,
  #       display_order: 224,
  #       text: "Everest Institute"
  #     },
  #     %{
  #       id: 1960,
  #       question_id: 23,
  #       trait_value_id: 2181,
  #       display_order: 225,
  #       text: "Everglades University"
  #     },
  #     %{
  #       id: 1961,
  #       question_id: 23,
  #       trait_value_id: 2182,
  #       display_order: 232,
  #       text: "Flagler College"
  #     },
  #     %{
  #       id: 1962,
  #       question_id: 23,
  #       trait_value_id: 2183,
  #       display_order: 235,
  #       text: "Florida Center for Theological Studies"
  #     },
  #     %{
  #       id: 1963,
  #       question_id: 23,
  #       trait_value_id: 2184,
  #       display_order: 236,
  #       text: "Florida Christian College"
  #     },
  #     %{
  #       id: 1964,
  #       question_id: 23,
  #       trait_value_id: 2185,
  #       display_order: 237,
  #       text: "Florida Coastal School of Law"
  #     },
  #     %{
  #       id: 1965,
  #       question_id: 23,
  #       trait_value_id: 2186,
  #       display_order: 238,
  #       text: "Florida College"
  #     },
  #     %{
  #       id: 1966,
  #       question_id: 23,
  #       trait_value_id: 2187,
  #       display_order: 239,
  #       text: "Florida Community College - Jacksonville"
  #     },
  #     %{
  #       id: 1967,
  #       question_id: 23,
  #       trait_value_id: 2188,
  #       display_order: 241,
  #       text: "Florida Culinary Institute"
  #     },
  #     %{
  #       id: 1968,
  #       question_id: 23,
  #       trait_value_id: 2189,
  #       display_order: 242,
  #       text: "Florida Gulf Coast University"
  #     },
  #     %{
  #       id: 1969,
  #       question_id: 23,
  #       trait_value_id: 2190,
  #       display_order: 243,
  #       text: "Florida Hospital College of Health Sciences"
  #     },
  #     %{
  #       id: 1970,
  #       question_id: 23,
  #       trait_value_id: 2191,
  #       display_order: 244,
  #       text: "Florida Institute of Technology"
  #     },
  #     %{
  #       id: 1971,
  #       question_id: 23,
  #       trait_value_id: 2192,
  #       display_order: 246,
  #       text: "Florida Keys Community College"
  #     },
  #     %{
  #       id: 1972,
  #       question_id: 23,
  #       trait_value_id: 2193,
  #       display_order: 247,
  #       text: "Florida Memorial University"
  #     },
  #     %{
  #       id: 1973,
  #       question_id: 23,
  #       trait_value_id: 2194,
  #       display_order: 248,
  #       text: "Florida Southern College"
  #     },
  #     %{
  #       id: 1974,
  #       question_id: 23,
  #       trait_value_id: 2195,
  #       display_order: 250,
  #       text: "Florida State University Panama City"
  #     },
  #     %{
  #       id: 1975,
  #       question_id: 23,
  #       trait_value_id: 2196,
  #       display_order: 251,
  #       text: "Florida Technical College"
  #     },
  #     %{
  #       id: 1976,
  #       question_id: 23,
  #       trait_value_id: 2197,
  #       display_order: 290,
  #       text: "Gulf Coast Community College"
  #     },
  #     %{
  #       id: 1978,
  #       question_id: 23,
  #       trait_value_id: 2199,
  #       display_order: 306,
  #       text: "Hobe Sound Bible College"
  #     },
  #     %{
  #       id: 1979,
  #       question_id: 23,
  #       trait_value_id: 2200,
  #       display_order: 307,
  #       text: "Hodges University"
  #     },
  #     %{
  #       id: 1980,
  #       question_id: 23,
  #       trait_value_id: 2201,
  #       display_order: 317,
  #       text: "IMPAC University"
  #     },
  #     %{
  #       id: 1981,
  #       question_id: 23,
  #       trait_value_id: 2202,
  #       display_order: 319,
  #       text: "Indian River State College"
  #     },
  #     %{
  #       id: 1982,
  #       question_id: 23,
  #       trait_value_id: 2203,
  #       display_order: 325,
  #       text: "International Academy of Design & Technology"
  #     },
  #     %{
  #       id: 1983,
  #       question_id: 23,
  #       trait_value_id: 2204,
  #       display_order: 333,
  #       text: "Jacksonville University"
  #     },
  #     %{
  #       id: 1984,
  #       question_id: 23,
  #       trait_value_id: 2205,
  #       display_order: 345,
  #       text: "Johnson & Wales University"
  #     },
  #     %{
  #       id: 1985,
  #       question_id: 23,
  #       trait_value_id: 2206,
  #       display_order: 351,
  #       text: "Keiser Career College"
  #     },
  #     %{
  #       id: 1986,
  #       question_id: 23,
  #       trait_value_id: 2207,
  #       display_order: 352,
  #       text: "Keiser University"
  #     },
  #     %{
  #       id: 1987,
  #       question_id: 23,
  #       trait_value_id: 2208,
  #       display_order: 363,
  #       text: "Knox Theological Seminary"
  #     },
  #     %{
  #       id: 1988,
  #       question_id: 23,
  #       trait_value_id: 2209,
  #       display_order: 366,
  #       text: "Lake City Community College"
  #     },
  #     %{
  #       id: 1989,
  #       question_id: 23,
  #       trait_value_id: 2210,
  #       display_order: 367,
  #       text: "Lake-Sumter Community College"
  #     },
  #     %{
  #       id: 1990,
  #       question_id: 23,
  #       trait_value_id: 2211,
  #       display_order: 401,
  #       text: "Lynn University"
  #     },
  #     %{
  #       id: 1991,
  #       question_id: 23,
  #       trait_value_id: 2212,
  #       display_order: 408,
  #       text: "Manatee Community College"
  #     },
  #     %{
  #       id: 1993,
  #       question_id: 23,
  #       trait_value_id: 2214,
  #       display_order: 428,
  #       text: "Miami International University of Art & Design"
  #     },
  #     %{
  #       id: 1994,
  #       question_id: 23,
  #       trait_value_id: 2215,
  #       display_order: 468,
  #       text: "New College of Florida"
  #     },
  #     %{
  #       id: 1995,
  #       question_id: 23,
  #       trait_value_id: 2216,
  #       display_order: 476,
  #       text: "North Florida Community College"
  #     },
  #     %{
  #       id: 1996,
  #       question_id: 23,
  #       trait_value_id: 2217,
  #       display_order: 494,
  #       text: "Northwest Florida State College"
  #     },
  #     %{
  #       id: 1997,
  #       question_id: 23,
  #       trait_value_id: 2218,
  #       display_order: 501,
  #       text: "Northwood University"
  #     },
  #     %{
  #       id: 1998,
  #       question_id: 23,
  #       trait_value_id: 2219,
  #       display_order: 503,
  #       text: "Nova Southeastern University"
  #     },
  #     %{
  #       id: 1999,
  #       question_id: 23,
  #       trait_value_id: 2220,
  #       display_order: 531,
  #       text: "Palm Beach Atlantic University"
  #     },
  #     %{
  #       id: 2000,
  #       question_id: 23,
  #       trait_value_id: 2221,
  #       display_order: 532,
  #       text: "Palm Beach Community College"
  #     },
  #     %{
  #       id: 2001,
  #       question_id: 23,
  #       trait_value_id: 2222,
  #       display_order: 533,
  #       text: "Palmer College of Chiropractic Florida"
  #     },
  #     %{
  #       id: 2003,
  #       question_id: 23,
  #       trait_value_id: 2224,
  #       display_order: 544,
  #       text: "Pensacola Christian College"
  #     },
  #     %{
  #       id: 2004,
  #       question_id: 23,
  #       trait_value_id: 2225,
  #       display_order: 545,
  #       text: "Pensacola Junior College"
  #     },
  #     %{
  #       id: 2005,
  #       question_id: 23,
  #       trait_value_id: 2226,
  #       display_order: 552,
  #       text: "Polk Community College"
  #     },
  #     %{
  #       id: 2006,
  #       question_id: 23,
  #       trait_value_id: 2227,
  #       display_order: 571,
  #       text: "Ringling School of Art & Design"
  #     },
  #     %{
  #       id: 2007,
  #       question_id: 23,
  #       trait_value_id: 2228,
  #       display_order: 574,
  #       text: "Rollins College"
  #     },
  #     %{
  #       id: 2008,
  #       question_id: 23,
  #       trait_value_id: 2229,
  #       display_order: 583,
  #       text: "Saint John Vianney College Seminary"
  #     },
  #     %{
  #       id: 2009,
  #       question_id: 23,
  #       trait_value_id: 2230,
  #       display_order: 584,
  #       text: "Saint Johns River Community College"
  #     },
  #     %{
  #       id: 2010,
  #       question_id: 23,
  #       trait_value_id: 2231,
  #       display_order: 585,
  #       text: "Saint Leo University"
  #     },
  #     %{
  #       id: 2011,
  #       question_id: 23,
  #       trait_value_id: 2232,
  #       display_order: 589,
  #       text: "Saint Petersburg College"
  #     },
  #     %{
  #       id: 2012,
  #       question_id: 23,
  #       trait_value_id: 2233,
  #       display_order: 590,
  #       text: "Saint Thomas University"
  #     },
  #     %{
  #       id: 2013,
  #       question_id: 23,
  #       trait_value_id: 2234,
  #       display_order: 591,
  #       text: "Saint Vincent de Paul Regional Seminary"
  #     },
  #     %{
  #       id: 2014,
  #       question_id: 23,
  #       trait_value_id: 2235,
  #       display_order: 605,
  #       text: "Santa Fe College"
  #     },
  #     %{
  #       id: 2015,
  #       question_id: 23,
  #       trait_value_id: 2236,
  #       display_order: 611,
  #       text: "Schiller International University"
  #     },
  #     %{
  #       id: 2016,
  #       question_id: 23,
  #       trait_value_id: 2237,
  #       display_order: 612,
  #       text: "Seminole State College"
  #     },
  #     %{
  #       id: 2017,
  #       question_id: 23,
  #       trait_value_id: 2238,
  #       display_order: 620,
  #       text: "Smith Chapel Bible University"
  #     },
  #     %{
  #       id: 2018,
  #       question_id: 23,
  #       trait_value_id: 2239,
  #       display_order: 628,
  #       text: "South Florida Bible College"
  #     },
  #     %{
  #       id: 2019,
  #       question_id: 23,
  #       trait_value_id: 2240,
  #       display_order: 629,
  #       text: "South Florida Community College"
  #     },
  #     %{
  #       id: 2020,
  #       question_id: 23,
  #       trait_value_id: 2241,
  #       display_order: 638,
  #       text: "Southeastern University"
  #     },
  #     %{
  #       id: 2021,
  #       question_id: 23,
  #       trait_value_id: 2242,
  #       display_order: 653,
  #       text: "Southwest Florida College"
  #     },
  #     %{
  #       id: 2022,
  #       question_id: 23,
  #       trait_value_id: 2243,
  #       display_order: 672,
  #       text: "Stetson University"
  #     },
  #     %{
  #       id: 2023,
  #       question_id: 23,
  #       trait_value_id: 2244,
  #       display_order: 678,
  #       text: "Talmudic University of Florida"
  #     },
  #     %{
  #       id: 2024,
  #       question_id: 23,
  #       trait_value_id: 2245,
  #       display_order: 706,
  #       text: "Trinity College"
  #     },
  #     %{
  #       id: 2026,
  #       question_id: 23,
  #       trait_value_id: 2247,
  #       display_order: 816,
  #       text: "University of St. Augustine for Health Sciences"
  #     },
  #     %{
  #       id: 2027,
  #       question_id: 23,
  #       trait_value_id: 2248,
  #       display_order: 817,
  #       text: "University of Tampa"
  #     },
  #     %{
  #       id: 2030,
  #       question_id: 23,
  #       trait_value_id: 2251,
  #       display_order: 869,
  #       text: "Warner Southern College"
  #     },
  #     %{
  #       id: 2031,
  #       question_id: 23,
  #       trait_value_id: 2252,
  #       display_order: 874,
  #       text: "Webber International University"
  #     },
  #     %{
  #       id: 2032,
  #       question_id: 23,
  #       trait_value_id: 2253,
  #       display_order: 876,
  #       text: "Webster University North Florida Region"
  #     },
  #     %{
  #       id: 2033,
  #       question_id: 23,
  #       trait_value_id: 2254,
  #       display_order: 23,
  #       text: "Arkansas Baptist College"
  #     },
  #     %{
  #       id: 2034,
  #       question_id: 23,
  #       trait_value_id: 2255,
  #       display_order: 24,
  #       text: "Arkansas Northeastern College"
  #     },
  #     %{
  #       id: 2035,
  #       question_id: 23,
  #       trait_value_id: 2256,
  #       display_order: 26,
  #       text: "Arkansas State University Beebe"
  #     },
  #     %{
  #       id: 2036,
  #       question_id: 23,
  #       trait_value_id: 2257,
  #       display_order: 27,
  #       text: "Arkansas State University Mountain Home"
  #     },
  #     %{
  #       id: 2037,
  #       question_id: 23,
  #       trait_value_id: 2258,
  #       display_order: 28,
  #       text: "Arkansas State University Newport"
  #     },
  #     %{
  #       id: 2038,
  #       question_id: 23,
  #       trait_value_id: 2259,
  #       display_order: 29,
  #       text: "Arkansas Tech University"
  #     },
  #     %{
  #       id: 2039,
  #       question_id: 23,
  #       trait_value_id: 2260,
  #       display_order: 70,
  #       text: "Black River Technical College"
  #     },
  #     %{
  #       id: 2040,
  #       question_id: 23,
  #       trait_value_id: 2261,
  #       display_order: 115,
  #       text: "Central Baptist College"
  #     },
  #     %{
  #       id: 2041,
  #       question_id: 23,
  #       trait_value_id: 2262,
  #       display_order: 168,
  #       text: "Cossatot Community College"
  #     },
  #     %{
  #       id: 2042,
  #       question_id: 23,
  #       trait_value_id: 2263,
  #       display_order: 200,
  #       text: "East Arkansas Community College"
  #     },
  #     %{
  #       id: 2043,
  #       question_id: 23,
  #       trait_value_id: 2264,
  #       display_order: 261,
  #       text: "Freedom Bible College & Seminary"
  #     },
  #     %{
  #       id: 2044,
  #       question_id: 23,
  #       trait_value_id: 2265,
  #       display_order: 293,
  #       text: "Harding University"
  #     },
  #     %{
  #       id: 2045,
  #       question_id: 23,
  #       trait_value_id: 2266,
  #       display_order: 300,
  #       text: "Henderson State University"
  #     },
  #     %{
  #       id: 2046,
  #       question_id: 23,
  #       trait_value_id: 2267,
  #       display_order: 301,
  #       text: "Hendrix College"
  #     },
  #     %{
  #       id: 2047,
  #       question_id: 23,
  #       trait_value_id: 2268,
  #       display_order: 342,
  #       text: "John Brown University"
  #     },
  #     %{
  #       id: 2048,
  #       question_id: 23,
  #       trait_value_id: 2269,
  #       display_order: 402,
  #       text: "Lyon College"
  #     },
  #     %{
  #       id: 2049,
  #       question_id: 23,
  #       trait_value_id: 2270,
  #       display_order: 434,
  #       text: "Mid-South Community College"
  #     },
  #     %{
  #       id: 2050,
  #       question_id: 23,
  #       trait_value_id: 2271,
  #       display_order: 466,
  #       text: "National Park Community College"
  #     },
  #     %{
  #       id: 2051,
  #       question_id: 23,
  #       trait_value_id: 2272,
  #       display_order: 473,
  #       text: "North Arkansas College"
  #     },
  #     %{
  #       id: 2052,
  #       question_id: 23,
  #       trait_value_id: 2273,
  #       display_order: 493,
  #       text: "NorthWest Arkansas Community College"
  #     },
  #     %{
  #       id: 2053,
  #       question_id: 23,
  #       trait_value_id: 2274,
  #       display_order: 521,
  #       text: "Ouachita Baptist University"
  #     },
  #     %{
  #       id: 2054,
  #       question_id: 23,
  #       trait_value_id: 2275,
  #       display_order: 522,
  #       text: "Ouachita Technical College"
  #     },
  #     %{
  #       id: 2055,
  #       question_id: 23,
  #       trait_value_id: 2276,
  #       display_order: 528,
  #       text: "Ozarka College"
  #     },
  #     %{
  #       id: 2056,
  #       question_id: 23,
  #       trait_value_id: 2277,
  #       display_order: 546,
  #       text: "Philander Smith College"
  #     },
  #     %{
  #       id: 2057,
  #       question_id: 23,
  #       trait_value_id: 2278,
  #       display_order: 547,
  #       text: "Phillips Community College"
  #     },
  #     %{
  #       id: 2058,
  #       question_id: 23,
  #       trait_value_id: 2279,
  #       display_order: 557,
  #       text: "Pulaski Technical College"
  #     },
  #     %{
  #       id: 2059,
  #       question_id: 23,
  #       trait_value_id: 2280,
  #       display_order: 567,
  #       text: "Rich Mountain Community College"
  #     },
  #     %{
  #       id: 2060,
  #       question_id: 23,
  #       trait_value_id: 2281,
  #       display_order: 626,
  #       text: "South Arkasas Community College"
  #     },
  #     %{
  #       id: 2061,
  #       question_id: 23,
  #       trait_value_id: 2282,
  #       display_order: 634,
  #       text: "Southeast Arkansas College"
  #     },
  #     %{
  #       id: 2062,
  #       question_id: 23,
  #       trait_value_id: 2283,
  #       display_order: 640,
  #       text: "Southern Arkansas University"
  #     },
  #     %{
  #       id: 2063,
  #       question_id: 23,
  #       trait_value_id: 2284,
  #       display_order: 641,
  #       text: "Southern Arkansas University Tech"
  #     },
  #     %{
  #       id: 2064,
  #       question_id: 23,
  #       trait_value_id: 2285,
  #       display_order: 727,
  #       text: "University of Arkansas C.C. - Batesville"
  #     },
  #     %{
  #       id: 2065,
  #       question_id: 23,
  #       trait_value_id: 2286,
  #       display_order: 728,
  #       text: "University of Arkansas C.C. - Hope"
  #     },
  #     %{
  #       id: 2066,
  #       question_id: 23,
  #       trait_value_id: 2287,
  #       display_order: 729,
  #       text: "University of Arkansas C.C. - Morrilton"
  #     },
  #     %{
  #       id: 2067,
  #       question_id: 23,
  #       trait_value_id: 2288,
  #       display_order: 730,
  #       text: "University of Arkansas for Medical Sciences"
  #     },
  #     %{
  #       id: 2068,
  #       question_id: 23,
  #       trait_value_id: 2289,
  #       display_order: 742,
  #       text: "University of Central Arkansas"
  #     },
  #     %{
  #       id: 2069,
  #       question_id: 23,
  #       trait_value_id: 2290,
  #       display_order: 834,
  #       text: "University of the Ozarks"
  #     },
  #     %{
  #       id: 2070,
  #       question_id: 23,
  #       trait_value_id: 2291,
  #       display_order: 895,
  #       text: "Williams Baptist College"
  #     },
  #     %{
  #       id: 2071,
  #       question_id: 23,
  #       trait_value_id: 2292,
  #       display_order: 228,
  #       text: "Faulkner State Community College"
  #     },
  #     %{
  #       id: 2072,
  #       question_id: 23,
  #       trait_value_id: 2293,
  #       display_order: 229,
  #       text: "Faulkner University"
  #     },
  #     %{
  #       id: 2073,
  #       question_id: 23,
  #       trait_value_id: 2294,
  #       display_order: 266,
  #       text: "Gadsden State Community College"
  #     },
  #     %{
  #       id: 2074,
  #       question_id: 23,
  #       trait_value_id: 2295,
  #       display_order: 292,
  #       text: "H Councill Trenholm State Technical College"
  #     },
  #     %{
  #       id: 2075,
  #       question_id: 23,
  #       trait_value_id: 2296,
  #       display_order: 302,
  #       text: "Heritage Christian University"
  #     },
  #     %{
  #       id: 2076,
  #       question_id: 23,
  #       trait_value_id: 2297,
  #       display_order: 314,
  #       text: "Huntingdon College"
  #     },
  #     %{
  #       id: 2077,
  #       question_id: 23,
  #       trait_value_id: 2298,
  #       display_order: 330,
  #       text: "J. F. Drake State Technical College"
  #     },
  #     %{
  #       id: 2078,
  #       question_id: 23,
  #       trait_value_id: 2299,
  #       display_order: 339,
  #       text: "Jefferson Davis Community College"
  #     },
  #     %{
  #       id: 2079,
  #       question_id: 23,
  #       trait_value_id: 2300,
  #       display_order: 340,
  #       text: "Jefferson State Community College"
  #     },
  #     %{
  #       id: 2080,
  #       question_id: 23,
  #       trait_value_id: 2301,
  #       display_order: 348,
  #       text: "Judson College"
  #     },
  #     %{
  #       id: 2081,
  #       question_id: 23,
  #       trait_value_id: 2302,
  #       display_order: 377,
  #       text: "Lawson State Community College"
  #     },
  #     %{
  #       id: 2082,
  #       question_id: 23,
  #       trait_value_id: 2303,
  #       display_order: 399,
  #       text: "Lurleen B. Wallace Junior College"
  #     },
  #     %{
  #       id: 2083,
  #       question_id: 23,
  #       trait_value_id: 2304,
  #       display_order: 409,
  #       text: "Marion Military Institute"
  #     },
  #     %{
  #       id: 2084,
  #       question_id: 23,
  #       trait_value_id: 2305,
  #       display_order: 441,
  #       text: "Miles College"
  #     },
  #     %{
  #       id: 2085,
  #       question_id: 23,
  #       trait_value_id: 2306,
  #       display_order: 483,
  #       text: "Northeast Alabama Community College"
  #     },
  #     %{
  #       id: 2086,
  #       question_id: 23,
  #       trait_value_id: 2307,
  #       display_order: 498,
  #       text: "Northwest-Shoals Community College"
  #     },
  #     %{
  #       id: 2087,
  #       question_id: 23,
  #       trait_value_id: 2308,
  #       display_order: 508,
  #       text: "Oakwood College"
  #     },
  #     %{
  #       id: 2088,
  #       question_id: 23,
  #       trait_value_id: 2309,
  #       display_order: 562,
  #       text: "Reid State Technical College"
  #     },
  #     %{
  #       id: 2089,
  #       question_id: 23,
  #       trait_value_id: 2310,
  #       display_order: 595,
  #       text: "Samford University"
  #     },
  #     %{
  #       id: 2090,
  #       question_id: 23,
  #       trait_value_id: 2311,
  #       display_order: 615,
  #       text: "Shelton State Community College"
  #     },
  #     %{
  #       id: 2091,
  #       question_id: 23,
  #       trait_value_id: 2312,
  #       display_order: 622,
  #       text: "Snead State Community College"
  #     },
  #     %{
  #       id: 2092,
  #       question_id: 23,
  #       trait_value_id: 2313,
  #       display_order: 636,
  #       text: "Southeastern Bible College"
  #     },
  #     %{
  #       id: 2093,
  #       question_id: 23,
  #       trait_value_id: 2314,
  #       display_order: 650,
  #       text: "Southern Union State Community College"
  #     },
  #     %{
  #       id: 2094,
  #       question_id: 23,
  #       trait_value_id: 2315,
  #       display_order: 665,
  #       text: "Spring Hill College"
  #     },
  #     %{
  #       id: 2095,
  #       question_id: 23,
  #       trait_value_id: 2316,
  #       display_order: 673,
  #       text: "Stillman College"
  #     },
  #     %{
  #       id: 2096,
  #       question_id: 23,
  #       trait_value_id: 2317,
  #       display_order: 676,
  #       text: "Talladega College"
  #     },
  #     %{
  #       id: 2097,
  #       question_id: 23,
  #       trait_value_id: 2318,
  #       display_order: 709,
  #       text: "Troy University"
  #     },
  #     %{
  #       id: 2098,
  #       question_id: 23,
  #       trait_value_id: 2319,
  #       display_order: 716,
  #       text: "Tuskegee University"
  #     },
  #     %{
  #       id: 2099,
  #       question_id: 23,
  #       trait_value_id: 2320,
  #       display_order: 722,
  #       text: "University of Alabama - Tuscaloosa"
  #     },
  #     %{
  #       id: 2100,
  #       question_id: 23,
  #       trait_value_id: 2321,
  #       display_order: 785,
  #       text: "University of Mobile"
  #     },
  #     %{
  #       id: 2101,
  #       question_id: 23,
  #       trait_value_id: 2322,
  #       display_order: 787,
  #       text: "University of Montevallo"
  #     },
  #     %{
  #       id: 2102,
  #       question_id: 23,
  #       trait_value_id: 2323,
  #       display_order: 794,
  #       text: "University of North Alabama"
  #     },
  #     %{
  #       id: 2104,
  #       question_id: 23,
  #       trait_value_id: 2325,
  #       display_order: 840,
  #       text: "University of West Alabama, The"
  #     },
  #     %{
  #       id: 2105,
  #       question_id: 23,
  #       trait_value_id: 2326,
  #       display_order: 858,
  #       text: "Virginia College"
  #     },
  #     %{
  #       id: 2106,
  #       question_id: 23,
  #       trait_value_id: 2327,
  #       display_order: 865,
  #       text: "Wallace Community College"
  #     },
  #     %{
  #       id: 2107,
  #       question_id: 23,
  #       trait_value_id: 2328,
  #       display_order: 866,
  #       text: "Wallace Community College Selma"
  #     },
  #     %{
  #       id: 2108,
  #       question_id: 23,
  #       trait_value_id: 2329,
  #       display_order: 867,
  #       text: "Wallace State Community College"
  #     },
  #     %{
  #       id: 2109,
  #       question_id: 23,
  #       trait_value_id: 2330,
  #       display_order: 6,
  #       text: "Alcorn State University"
  #     },
  #     %{
  #       id: 2110,
  #       question_id: 23,
  #       trait_value_id: 2331,
  #       display_order: 19,
  #       text: "Antonelli College"
  #     },
  #     %{
  #       id: 2111,
  #       question_id: 23,
  #       trait_value_id: 2332,
  #       display_order: 58,
  #       text: "Belhaven College"
  #     },
  #     %{
  #       id: 2112,
  #       question_id: 23,
  #       trait_value_id: 2333,
  #       display_order: 72,
  #       text: "Blue Mountain College"
  #     },
  #     %{
  #       id: 2113,
  #       question_id: 23,
  #       trait_value_id: 2334,
  #       display_order: 142,
  #       text: "Coahoma Community College"
  #     },
  #     %{
  #       id: 2114,
  #       question_id: 23,
  #       trait_value_id: 2335,
  #       display_order: 166,
  #       text: "Copiah Lincoln Community College"
  #     },
  #     %{
  #       id: 2115,
  #       question_id: 23,
  #       trait_value_id: 2336,
  #       display_order: 191,
  #       text: "Delta State University"
  #     },
  #     %{
  #       id: 2116,
  #       question_id: 23,
  #       trait_value_id: 2337,
  #       display_order: 202,
  #       text: "East Central Community College"
  #     },
  #     %{
  #       id: 2117,
  #       question_id: 23,
  #       trait_value_id: 2338,
  #       display_order: 205,
  #       text: "East Mississippi Community College"
  #     },
  #     %{
  #       id: 2118,
  #       question_id: 23,
  #       trait_value_id: 2339,
  #       display_order: 304,
  #       text: "Hinds Community College"
  #     },
  #     %{
  #       id: 2119,
  #       question_id: 23,
  #       trait_value_id: 2340,
  #       display_order: 309,
  #       text: "Holmes Community College"
  #     },
  #     %{
  #       id: 2120,
  #       question_id: 23,
  #       trait_value_id: 2341,
  #       display_order: 329,
  #       text: "Itawamba Community College"
  #     },
  #     %{
  #       id: 2121,
  #       question_id: 23,
  #       trait_value_id: 2342,
  #       display_order: 347,
  #       text: "Jones County Junior College"
  #     },
  #     %{
  #       id: 2122,
  #       question_id: 23,
  #       trait_value_id: 2343,
  #       display_order: 406,
  #       text: "Magnolia Bible College"
  #     },
  #     %{
  #       id: 2123,
  #       question_id: 23,
  #       trait_value_id: 2344,
  #       display_order: 424,
  #       text: "Meridian Community College"
  #     },
  #     %{
  #       id: 2124,
  #       question_id: 23,
  #       trait_value_id: 2345,
  #       display_order: 444,
  #       text: "Millsaps College"
  #     },
  #     %{
  #       id: 2125,
  #       question_id: 23,
  #       trait_value_id: 2346,
  #       display_order: 447,
  #       text: "Mississippi College"
  #     },
  #     %{
  #       id: 2126,
  #       question_id: 23,
  #       trait_value_id: 2347,
  #       display_order: 448,
  #       text: "Mississippi Delta Community College"
  #     },
  #     %{
  #       id: 2127,
  #       question_id: 23,
  #       trait_value_id: 2348,
  #       display_order: 450,
  #       text: "Mississippi State University"
  #     },
  #     %{
  #       id: 2128,
  #       question_id: 23,
  #       trait_value_id: 2349,
  #       display_order: 451,
  #       text: "Mississippi University for Women"
  #     },
  #     %{
  #       id: 2129,
  #       question_id: 23,
  #       trait_value_id: 2350,
  #       display_order: 452,
  #       text: "Mississippi Valley State University"
  #     },
  #     %{
  #       id: 2130,
  #       question_id: 23,
  #       trait_value_id: 2351,
  #       display_order: 485,
  #       text: "Northeast Mississippi Community College"
  #     },
  #     %{
  #       id: 2131,
  #       question_id: 23,
  #       trait_value_id: 2352,
  #       display_order: 495,
  #       text: "Northwest Mississippi Community College"
  #     },
  #     %{
  #       id: 2132,
  #       question_id: 23,
  #       trait_value_id: 2353,
  #       display_order: 541,
  #       text: "Pearl River Community College"
  #     },
  #     %{
  #       id: 2133,
  #       question_id: 23,
  #       trait_value_id: 2354,
  #       display_order: 561,
  #       text: "Reformed Theological Seminary"
  #     },
  #     %{
  #       id: 2134,
  #       question_id: 23,
  #       trait_value_id: 2355,
  #       display_order: 575,
  #       text: "Rust College"
  #     },
  #     %{
  #       id: 2135,
  #       question_id: 23,
  #       trait_value_id: 2356,
  #       display_order: 655,
  #       text: "Southwest Mississippi Community College"
  #     },
  #     %{
  #       id: 2136,
  #       question_id: 23,
  #       trait_value_id: 2357,
  #       display_order: 702,
  #       text: "Tougaloo College"
  #     },
  #     %{
  #       id: 2137,
  #       question_id: 23,
  #       trait_value_id: 2358,
  #       display_order: 877,
  #       text: "Wesley Biblical Seminary"
  #     },
  #     %{
  #       id: 2138,
  #       question_id: 23,
  #       trait_value_id: 2359,
  #       display_order: 878,
  #       text: "Wesley College"
  #     },
  #     %{
  #       id: 2139,
  #       question_id: 23,
  #       trait_value_id: 2360,
  #       display_order: 894,
  #       text: "William Carey University "
  #     },
  #     %{
  #       id: 2140,
  #       question_id: 23,
  #       trait_value_id: 2361,
  #       display_order: 3,
  #       text: "Aiken Technical College"
  #     },
  #     %{
  #       id: 2141,
  #       question_id: 23,
  #       trait_value_id: 2362,
  #       display_order: 15,
  #       text: "Anderson University"
  #     },
  #     %{
  #       id: 2142,
  #       question_id: 23,
  #       trait_value_id: 2363,
  #       display_order: 75,
  #       text: "Bob Jones University"
  #     },
  #     %{
  #       id: 2144,
  #       question_id: 23,
  #       trait_value_id: 2365,
  #       display_order: 265,
  #       text: "Furman University"
  #     },
  #     %{
  #       id: 2146,
  #       question_id: 23,
  #       trait_value_id: 2367,
  #       display_order: 308,
  #       text: "Holmes Bible College"
  #     },
  #     %{
  #       id: 2147,
  #       question_id: 23,
  #       trait_value_id: 2368,
  #       display_order: 370,
  #       text: "Lander University"
  #     },
  #     %{
  #       id: 2148,
  #       question_id: 23,
  #       trait_value_id: 2369,
  #       display_order: 384,
  #       text: "Limestone College"
  #     },
  #     %{
  #       id: 2149,
  #       question_id: 23,
  #       trait_value_id: 2370,
  #       display_order: 811,
  #       text: "University of South Carolina-Aiken"
  #     },
  #     %{
  #       id: 2150,
  #       question_id: 23,
  #       trait_value_id: 2371,
  #       display_order: 68,
  #       text: "Bill J. Priest Institute for Economic Development"
  #     },
  #     %{
  #       id: 2151,
  #       question_id: 23,
  #       trait_value_id: 2372,
  #       display_order: 87,
  #       text: "Brookhaven College"
  #     },
  #     %{
  #       id: 2152,
  #       question_id: 23,
  #       trait_value_id: 2373,
  #       display_order: 148,
  #       text: "College of Saint Thomas More, The"
  #     },
  #     %{
  #       id: 2153,
  #       question_id: 23,
  #       trait_value_id: 2374,
  #       display_order: 172,
  #       text: "Criswell College"
  #     },
  #     %{
  #       id: 2154,
  #       question_id: 23,
  #       trait_value_id: 2375,
  #       display_order: 177,
  #       text: "Dallas Baptist University"
  #     },
  #     %{
  #       id: 2155,
  #       question_id: 23,
  #       trait_value_id: 2376,
  #       display_order: 178,
  #       text: "Dallas Christian College"
  #     },
  #     %{
  #       id: 2156,
  #       question_id: 23,
  #       trait_value_id: 2377,
  #       display_order: 180,
  #       text: "Dallas Theological Seminary"
  #     },
  #     %{
  #       id: 2157,
  #       question_id: 23,
  #       trait_value_id: 2378,
  #       display_order: 215,
  #       text: "El Centro College"
  #     },
  #     %{
  #       id: 2158,
  #       question_id: 23,
  #       trait_value_id: 2379,
  #       display_order: 481,
  #       text: "North Lake College"
  #     },
  #     %{
  #       id: 2159,
  #       question_id: 23,
  #       trait_value_id: 2380,
  #       display_order: 509,
  #       text: "Oblate School of Theology"
  #     },
  #     %{
  #       id: 2160,
  #       question_id: 23,
  #       trait_value_id: 2381,
  #       display_order: 524,
  #       text: "Our Lady of the Lake University"
  #     },
  #     %{
  #       id: 2161,
  #       question_id: 23,
  #       trait_value_id: 2382,
  #       display_order: 539,
  #       text: "Paul Quinn College"
  #     },
  #     %{
  #       id: 2162,
  #       question_id: 23,
  #       trait_value_id: 2383,
  #       display_order: 540,
  #       text: "PCI Health Training Center"
  #     },
  #     %{
  #       id: 2163,
  #       question_id: 23,
  #       trait_value_id: 2384,
  #       display_order: 569,
  #       text: "Richland College"
  #     },
  #     %{
  #       id: 2164,
  #       question_id: 23,
  #       trait_value_id: 2385,
  #       display_order: 588,
  #       text: "Saint Mary's University"
  #     },
  #     %{
  #       id: 2165,
  #       question_id: 23,
  #       trait_value_id: 2386,
  #       display_order: 659,
  #       text: "Southwestern Baptist Theological Seminary"
  #     },
  #     %{
  #       id: 2167,
  #       question_id: 23,
  #       trait_value_id: 2388,
  #       display_order: 691,
  #       text: "Texas Christian University"
  #     },
  #     %{
  #       id: 2168,
  #       question_id: 23,
  #       trait_value_id: 2389,
  #       display_order: 694,
  #       text: "Texas Wesleyan University"
  #     },
  #     %{
  #       id: 2169,
  #       question_id: 23,
  #       trait_value_id: 2390,
  #       display_order: 695,
  #       text: "Texas Woman's University"
  #     },
  #     %{
  #       id: 2170,
  #       question_id: 23,
  #       trait_value_id: 2391,
  #       display_order: 707,
  #       text: "Trinity University"
  #     },
  #     %{
  #       id: 2171,
  #       question_id: 23,
  #       trait_value_id: 2392,
  #       display_order: 750,
  #       text: "University of Dallas"
  #     },
  #     %{
  #       id: 2172,
  #       question_id: 23,
  #       trait_value_id: 2393,
  #       display_order: 833,
  #       text: "University of the Incarnate Word"
  #     },
  #     %{
  #       id: 2173,
  #       question_id: 23,
  #       trait_value_id: 2394,
  #       display_order: 856,
  #       text: "Vernon College"
  #     },
  #     %{
  #       id: 2174,
  #       question_id: 23,
  #       trait_value_id: 2395,
  #       display_order: 857,
  #       text: "Victoria College, The"
  #     },
  #     %{
  #       id: 2175,
  #       question_id: 23,
  #       trait_value_id: 2396,
  #       display_order: 862,
  #       text: "Wade College"
  #     },
  #     %{
  #       id: 2176,
  #       question_id: 10,
  #       trait_value_id: 2397,
  #       display_order: 2,
  #       text: "GED or High School Equivalency"
  #     },
  #     %{
  #       id: 2177,
  #       question_id: 10,
  #       trait_value_id: 2399,
  #       display_order: 1,
  #       text: "Zero"
  #     },
  #     %{
  #       id: 2178,
  #       question_id: 10,
  #       trait_value_id: 2400,
  #       display_order: 2,
  #       text: "1"
  #     },
  #     %{
  #       id: 2179,
  #       question_id: 10,
  #       trait_value_id: 2401,
  #       display_order: 3,
  #       text: "2"
  #     },
  #     %{
  #       id: 2180,
  #       question_id: 10,
  #       trait_value_id: 2402,
  #       display_order: 4,
  #       text: "3"
  #     },
  #     %{
  #       id: 2181,
  #       question_id: 10,
  #       trait_value_id: 2403,
  #       display_order: 5,
  #       text: "4 or more"
  #     },
  #     %{
  #       id: 2182,
  #       question_id: 10,
  #       trait_value_id: 2404,
  #       display_order: 6,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2183,
  #       question_id: 10,
  #       trait_value_id: 2407,
  #       display_order: 1,
  #       text: "Acura"
  #     },
  #     %{
  #       id: 2184,
  #       question_id: 10,
  #       trait_value_id: 2408,
  #       display_order: 2,
  #       text: "Audi"
  #     },
  #     %{
  #       id: 2185,
  #       question_id: 10,
  #       trait_value_id: 2409,
  #       display_order: 3,
  #       text: "Bentley"
  #     },
  #     %{
  #       id: 2186,
  #       question_id: 10,
  #       trait_value_id: 2410,
  #       display_order: 4,
  #       text: "BMW"
  #     },
  #     %{
  #       id: 2187,
  #       question_id: 10,
  #       trait_value_id: 2411,
  #       display_order: 5,
  #       text: "Buick"
  #     },
  #     %{
  #       id: 2188,
  #       question_id: 10,
  #       trait_value_id: 2412,
  #       display_order: 6,
  #       text: "Cadillac"
  #     },
  #     %{
  #       id: 2189,
  #       question_id: 10,
  #       trait_value_id: 2413,
  #       display_order: 7,
  #       text: "Chevrolet"
  #     },
  #     %{
  #       id: 2190,
  #       question_id: 10,
  #       trait_value_id: 2414,
  #       display_order: 8,
  #       text: "Chrysler"
  #     },
  #     %{
  #       id: 2191,
  #       question_id: 10,
  #       trait_value_id: 2415,
  #       display_order: 9,
  #       text: "Dodge"
  #     },
  #     %{
  #       id: 2192,
  #       question_id: 10,
  #       trait_value_id: 2416,
  #       display_order: 10,
  #       text: "Ford"
  #     },
  #     %{
  #       id: 2193,
  #       question_id: 10,
  #       trait_value_id: 2417,
  #       display_order: 11,
  #       text: "GMC"
  #     },
  #     %{
  #       id: 2194,
  #       question_id: 10,
  #       trait_value_id: 2418,
  #       display_order: 12,
  #       text: "Honda"
  #     },
  #     %{
  #       id: 2195,
  #       question_id: 10,
  #       trait_value_id: 2419,
  #       display_order: 13,
  #       text: "HUMMER"
  #     },
  #     %{
  #       id: 2196,
  #       question_id: 10,
  #       trait_value_id: 2420,
  #       display_order: 14,
  #       text: "Hyundai"
  #     },
  #     %{
  #       id: 2197,
  #       question_id: 10,
  #       trait_value_id: 2421,
  #       display_order: 15,
  #       text: "Infiniti"
  #     },
  #     %{
  #       id: 2198,
  #       question_id: 10,
  #       trait_value_id: 2422,
  #       display_order: 16,
  #       text: "Jaguar"
  #     },
  #     %{
  #       id: 2199,
  #       question_id: 10,
  #       trait_value_id: 2423,
  #       display_order: 17,
  #       text: "Jeep"
  #     },
  #     %{
  #       id: 2200,
  #       question_id: 10,
  #       trait_value_id: 2424,
  #       display_order: 18,
  #       text: "Kia"
  #     },
  #     %{
  #       id: 2201,
  #       question_id: 10,
  #       trait_value_id: 2425,
  #       display_order: 19,
  #       text: "Land Rover"
  #     },
  #     %{
  #       id: 2202,
  #       question_id: 10,
  #       trait_value_id: 2426,
  #       display_order: 20,
  #       text: "Lexus"
  #     },
  #     %{
  #       id: 2203,
  #       question_id: 10,
  #       trait_value_id: 2427,
  #       display_order: 21,
  #       text: "Lincoln"
  #     },
  #     %{
  #       id: 2204,
  #       question_id: 10,
  #       trait_value_id: 2428,
  #       display_order: 22,
  #       text: "Lotus"
  #     },
  #     %{
  #       id: 2205,
  #       question_id: 10,
  #       trait_value_id: 2429,
  #       display_order: 23,
  #       text: "Maserati"
  #     },
  #     %{
  #       id: 2206,
  #       question_id: 10,
  #       trait_value_id: 2430,
  #       display_order: 24,
  #       text: "Maybach"
  #     },
  #     %{
  #       id: 2207,
  #       question_id: 10,
  #       trait_value_id: 2431,
  #       display_order: 25,
  #       text: "Mazda"
  #     },
  #     %{
  #       id: 2208,
  #       question_id: 10,
  #       trait_value_id: 2432,
  #       display_order: 26,
  #       text: "Mercedes-Benz"
  #     },
  #     %{
  #       id: 2209,
  #       question_id: 10,
  #       trait_value_id: 2433,
  #       display_order: 27,
  #       text: "Mercury"
  #     },
  #     %{
  #       id: 2210,
  #       question_id: 10,
  #       trait_value_id: 2434,
  #       display_order: 28,
  #       text: "MINI"
  #     },
  #     %{
  #       id: 2211,
  #       question_id: 10,
  #       trait_value_id: 2435,
  #       display_order: 29,
  #       text: "Mitsubishi"
  #     },
  #     %{
  #       id: 2212,
  #       question_id: 10,
  #       trait_value_id: 2436,
  #       display_order: 30,
  #       text: "Nissan"
  #     },
  #     %{
  #       id: 2213,
  #       question_id: 10,
  #       trait_value_id: 2437,
  #       display_order: 31,
  #       text: "Pontiac"
  #     },
  #     %{
  #       id: 2214,
  #       question_id: 10,
  #       trait_value_id: 2438,
  #       display_order: 32,
  #       text: "Porsche"
  #     },
  #     %{
  #       id: 2215,
  #       question_id: 10,
  #       trait_value_id: 2439,
  #       display_order: 33,
  #       text: "Rolls-Royce"
  #     },
  #     %{
  #       id: 2216,
  #       question_id: 10,
  #       trait_value_id: 2440,
  #       display_order: 34,
  #       text: "Saab"
  #     },
  #     %{
  #       id: 2217,
  #       question_id: 10,
  #       trait_value_id: 2441,
  #       display_order: 35,
  #       text: "Saturn"
  #     },
  #     %{
  #       id: 2218,
  #       question_id: 10,
  #       trait_value_id: 2442,
  #       display_order: 36,
  #       text: "Scion"
  #     },
  #     %{
  #       id: 2219,
  #       question_id: 10,
  #       trait_value_id: 2443,
  #       display_order: 37,
  #       text: "Smart"
  #     },
  #     %{
  #       id: 2220,
  #       question_id: 10,
  #       trait_value_id: 2444,
  #       display_order: 38,
  #       text: "Subaru"
  #     },
  #     %{
  #       id: 2221,
  #       question_id: 10,
  #       trait_value_id: 2445,
  #       display_order: 39,
  #       text: "Suzuki"
  #     },
  #     %{
  #       id: 2222,
  #       question_id: 10,
  #       trait_value_id: 2446,
  #       display_order: 40,
  #       text: "Toyota"
  #     },
  #     %{
  #       id: 2223,
  #       question_id: 10,
  #       trait_value_id: 2447,
  #       display_order: 41,
  #       text: "Volkswagen"
  #     },
  #     %{
  #       id: 2224,
  #       question_id: 10,
  #       trait_value_id: 2448,
  #       display_order: 42,
  #       text: "Volvo"
  #     },
  #     %{
  #       id: 2225,
  #       question_id: 10,
  #       trait_value_id: 2449,
  #       display_order: 43,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 2226,
  #       question_id: 10,
  #       trait_value_id: 2450,
  #       display_order: 44,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 2227,
  #       question_id: 10,
  #       trait_value_id: 2451,
  #       display_order: 45,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2228,
  #       question_id: 10,
  #       trait_value_id: 2453,
  #       display_order: 1,
  #       text: "2-door/Coupe"
  #     },
  #     %{
  #       id: 2229,
  #       question_id: 10,
  #       trait_value_id: 2454,
  #       display_order: 2,
  #       text: "4-Door/Sedan"
  #     },
  #     %{
  #       id: 2230,
  #       question_id: 10,
  #       trait_value_id: 2455,
  #       display_order: 3,
  #       text: "Crossover (Car/SUV mix)"
  #     },
  #     %{
  #       id: 2231,
  #       question_id: 10,
  #       trait_value_id: 2456,
  #       display_order: 4,
  #       text: "SUV"
  #     },
  #     %{
  #       id: 2232,
  #       question_id: 10,
  #       trait_value_id: 2457,
  #       display_order: 5,
  #       text: "Pickup"
  #     },
  #     %{
  #       id: 2233,
  #       question_id: 10,
  #       trait_value_id: 2458,
  #       display_order: 6,
  #       text: "Van/Minivan"
  #     },
  #     %{
  #       id: 2234,
  #       question_id: 10,
  #       trait_value_id: 2459,
  #       display_order: 7,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 2235,
  #       question_id: 10,
  #       trait_value_id: 2460,
  #       display_order: 8,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 2236,
  #       question_id: 10,
  #       trait_value_id: 2461,
  #       display_order: 9,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2237,
  #       question_id: 11,
  #       trait_value_id: 2463,
  #       display_order: 1,
  #       text: "Owned/All cash up front"
  #     },
  #     %{
  #       id: 2238,
  #       question_id: 11,
  #       trait_value_id: 2464,
  #       display_order: 2,
  #       text: "Owned/Financing paid off"
  #     },
  #     %{
  #       id: 2239,
  #       question_id: 11,
  #       trait_value_id: 2465,
  #       display_order: 3,
  #       text: "Financed/Making payments"
  #     },
  #     %{
  #       id: 2240,
  #       question_id: 11,
  #       trait_value_id: 2466,
  #       display_order: 4,
  #       text: "Leasing"
  #     },
  #     %{
  #       id: 2241,
  #       question_id: 11,
  #       trait_value_id: 2467,
  #       display_order: 5,
  #       text: "Borrow/Do not own"
  #     },
  #     %{
  #       id: 2242,
  #       question_id: 11,
  #       trait_value_id: 2468,
  #       display_order: 6,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 2243,
  #       question_id: 11,
  #       trait_value_id: 2469,
  #       display_order: 7,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2244,
  #       question_id: 11,
  #       trait_value_id: 2471,
  #       display_order: 1,
  #       text: "Four/All-wheel drive"
  #     },
  #     %{
  #       id: 2245,
  #       question_id: 11,
  #       trait_value_id: 2472,
  #       display_order: 2,
  #       text: "Convertible"
  #     },
  #     %{
  #       id: 2246,
  #       question_id: 11,
  #       trait_value_id: 2473,
  #       display_order: 3,
  #       text: "High fuel efficiency"
  #     },
  #     %{
  #       id: 2247,
  #       question_id: 11,
  #       trait_value_id: 2474,
  #       display_order: 4,
  #       text: "Hybrid"
  #     },
  #     %{
  #       id: 2248,
  #       question_id: 11,
  #       trait_value_id: 2475,
  #       display_order: 5,
  #       text: "Electric powered"
  #     },
  #     %{
  #       id: 2249,
  #       question_id: 11,
  #       trait_value_id: 2476,
  #       display_order: 6,
  #       text: "Diesel powered"
  #     },
  #     %{
  #       id: 2250,
  #       question_id: 11,
  #       trait_value_id: 2477,
  #       display_order: 7,
  #       text: "Alternative fuel powered"
  #     },
  #     %{
  #       id: 2251,
  #       question_id: 11,
  #       trait_value_id: 2478,
  #       display_order: 8,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2252,
  #       question_id: 11,
  #       trait_value_id: 2479,
  #       display_order: 9,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 2253,
  #       question_id: 11,
  #       trait_value_id: 2480,
  #       display_order: 10,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2254,
  #       question_id: 11,
  #       trait_value_id: 2482,
  #       display_order: 1,
  #       text: "American"
  #     },
  #     %{
  #       id: 2255,
  #       question_id: 11,
  #       trait_value_id: 2483,
  #       display_order: 2,
  #       text: "Japanese"
  #     },
  #     %{
  #       id: 2256,
  #       question_id: 11,
  #       trait_value_id: 2484,
  #       display_order: 3,
  #       text: "German"
  #     },
  #     %{
  #       id: 2257,
  #       question_id: 11,
  #       trait_value_id: 2485,
  #       display_order: 4,
  #       text: "Korean"
  #     },
  #     %{
  #       id: 2258,
  #       question_id: 11,
  #       trait_value_id: 2486,
  #       display_order: 5,
  #       text: "Other non-American"
  #     },
  #     %{
  #       id: 2259,
  #       question_id: 11,
  #       trait_value_id: 2487,
  #       display_order: 6,
  #       text: "Large passenger room"
  #     },
  #     %{
  #       id: 2260,
  #       question_id: 11,
  #       trait_value_id: 2488,
  #       display_order: 7,
  #       text: "Eco-friendly, good gas mileage"
  #     },
  #     %{
  #       id: 2261,
  #       question_id: 11,
  #       trait_value_id: 2489,
  #       display_order: 8,
  #       text: "Towing power"
  #     },
  #     %{
  #       id: 2262,
  #       question_id: 11,
  #       trait_value_id: 2490,
  #       display_order: 9,
  #       text: "Four/All-wheel drive"
  #     },
  #     %{
  #       id: 2263,
  #       question_id: 11,
  #       trait_value_id: 2491,
  #       display_order: 10,
  #       text: "Convertible"
  #     },
  #     %{
  #       id: 2264,
  #       question_id: 11,
  #       trait_value_id: 2492,
  #       display_order: 11,
  #       text: "Luxurious interior ammenities"
  #     },
  #     %{
  #       id: 2265,
  #       question_id: 11,
  #       trait_value_id: 2493,
  #       display_order: 12,
  #       text: "Sporty lines/body"
  #     },
  #     %{
  #       id: 2266,
  #       question_id: 11,
  #       trait_value_id: 2494,
  #       display_order: 13,
  #       text: "Safety features"
  #     },
  #     %{
  #       id: 2267,
  #       question_id: 11,
  #       trait_value_id: 2495,
  #       display_order: 14,
  #       text: "Local service availability"
  #     },
  #     %{
  #       id: 2268,
  #       question_id: 11,
  #       trait_value_id: 2496,
  #       display_order: 15,
  #       text: "Performance, muscle"
  #     },
  #     %{
  #       id: 2269,
  #       question_id: 11,
  #       trait_value_id: 2497,
  #       display_order: 16,
  #       text: "Low maintenance costs/requirements"
  #     },
  #     %{
  #       id: 2270,
  #       question_id: 11,
  #       trait_value_id: 2498,
  #       display_order: 17,
  #       text: "Built-in GPS"
  #     },
  #     %{
  #       id: 2271,
  #       question_id: 11,
  #       trait_value_id: 2499,
  #       display_order: 18,
  #       text: "Premium sound system"
  #     },
  #     %{
  #       id: 2272,
  #       question_id: 11,
  #       trait_value_id: 2500,
  #       display_order: 19,
  #       text: "Storage capacity"
  #     },
  #     %{
  #       id: 2273,
  #       question_id: 11,
  #       trait_value_id: 2501,
  #       display_order: 20,
  #       text: "Uniqueness/individuality"
  #     },
  #     %{
  #       id: 2274,
  #       question_id: 11,
  #       trait_value_id: 2502,
  #       display_order: 21,
  #       text: "Truck bed/payload"
  #     },
  #     %{
  #       id: 2275,
  #       question_id: 11,
  #       trait_value_id: 2503,
  #       display_order: 22,
  #       text: "High resale value"
  #     },
  #     %{
  #       id: 2276,
  #       question_id: 11,
  #       trait_value_id: 2505,
  #       display_order: 1,
  #       text: "Purchase, All cash"
  #     },
  #     %{
  #       id: 2277,
  #       question_id: 11,
  #       trait_value_id: 2506,
  #       display_order: 2,
  #       text: "Purchase, Financing"
  #     },
  #     %{
  #       id: 2278,
  #       question_id: 11,
  #       trait_value_id: 2507,
  #       display_order: 3,
  #       text: "Lease"
  #     },
  #     %{
  #       id: 2279,
  #       question_id: 11,
  #       trait_value_id: 2508,
  #       display_order: 4,
  #       text: "No preference/Undecided"
  #     },
  #     %{
  #       id: 2280,
  #       question_id: 11,
  #       trait_value_id: 2509,
  #       display_order: 5,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2281,
  #       question_id: 11,
  #       trait_value_id: 2510,
  #       display_order: 6,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2282,
  #       question_id: 11,
  #       trait_value_id: 2512,
  #       display_order: 1,
  #       text: "New"
  #     },
  #     %{
  #       id: 2283,
  #       question_id: 11,
  #       trait_value_id: 2513,
  #       display_order: 2,
  #       text: "Used/pre-owned"
  #     },
  #     %{
  #       id: 2284,
  #       question_id: 11,
  #       trait_value_id: 2514,
  #       display_order: 3,
  #       text: "Open to either option"
  #     },
  #     %{
  #       id: 2285,
  #       question_id: 11,
  #       trait_value_id: 2515,
  #       display_order: 4,
  #       text: "Not applicable"
  #     },
  #     %{
  #       id: 2286,
  #       question_id: 11,
  #       trait_value_id: 2516,
  #       display_order: 5,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2287,
  #       question_id: 11,
  #       trait_value_id: 2518,
  #       display_order: 1,
  #       text: "Zero (Do not drink coffee)"
  #     },
  #     %{
  #       id: 2288,
  #       question_id: 11,
  #       trait_value_id: 2519,
  #       display_order: 2,
  #       text: "Less than 1 cup"
  #     },
  #     %{
  #       id: 2289,
  #       question_id: 11,
  #       trait_value_id: 2520,
  #       display_order: 3,
  #       text: "1 cup"
  #     },
  #     %{
  #       id: 2290,
  #       question_id: 11,
  #       trait_value_id: 2521,
  #       display_order: 4,
  #       text: "2-3 cups"
  #     },
  #     %{
  #       id: 2291,
  #       question_id: 11,
  #       trait_value_id: 2522,
  #       display_order: 5,
  #       text: "4 or more cups"
  #     },
  #     %{
  #       id: 2292,
  #       question_id: 11,
  #       trait_value_id: 2523,
  #       display_order: 6,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2293,
  #       question_id: 11,
  #       trait_value_id: 2525,
  #       display_order: 1,
  #       text: "I do not like the taste of coffee. (Non-Drinker)"
  #     },
  #     %{
  #       id: 2294,
  #       question_id: 11,
  #       trait_value_id: 2526,
  #       display_order: 2,
  #       text: "I like coffee, but it does not agree with me. (Regretful Non-Drinker)"
  #     },
  #     %{
  #       id: 2295,
  #       question_id: 11,
  #       trait_value_id: 2527,
  #       display_order: 3,
  #       text: "I'm in it for the caffeine. (Pick-Me-Up Drinker)"
  #     },
  #     %{
  #       id: 2296,
  #       question_id: 11,
  #       trait_value_id: 2528,
  #       display_order: 4,
  #       text: "Keep it simple, a smooth cup o' joe diner-style. (Basic Drinker)"
  #     },
  #     %{
  #       id: 2297,
  #       question_id: 11,
  #       trait_value_id: 2529,
  #       display_order: 5,
  #       text: "I pretty much like anything coffee.  (Enthusiast)"
  #     },
  #     %{
  #       id: 2298,
  #       question_id: 11,
  #       trait_value_id: 2530,
  #       display_order: 6,
  #       text: "I prefer only the finest or gourmet coffee.  (Connoisseur)"
  #     },
  #     %{
  #       id: 2299,
  #       question_id: 11,
  #       trait_value_id: 2531,
  #       display_order: 7,
  #       text: "I consider it mainly a social activity.  (Social-drinker)"
  #     },
  #     %{
  #       id: 2300,
  #       question_id: 11,
  #       trait_value_id: 2532,
  #       display_order: 8,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2301,
  #       question_id: 11,
  #       trait_value_id: 2533,
  #       display_order: 9,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2302,
  #       question_id: 11,
  #       trait_value_id: 2535,
  #       display_order: 1,
  #       text: "Regular"
  #     },
  #     %{
  #       id: 2303,
  #       question_id: 11,
  #       trait_value_id: 2536,
  #       display_order: 2,
  #       text: "Decaffeinated"
  #     },
  #     %{
  #       id: 2304,
  #       question_id: 11,
  #       trait_value_id: 2537,
  #       display_order: 3,
  #       text: "Instant"
  #     },
  #     %{
  #       id: 2305,
  #       question_id: 11,
  #       trait_value_id: 2538,
  #       display_order: 4,
  #       text: "Regular/Medium Roast"
  #     },
  #     %{
  #       id: 2306,
  #       question_id: 11,
  #       trait_value_id: 2539,
  #       display_order: 5,
  #       text: "Dark Roast"
  #     },
  #     %{
  #       id: 2307,
  #       question_id: 11,
  #       trait_value_id: 2540,
  #       display_order: 6,
  #       text: "Flavored"
  #     },
  #     %{
  #       id: 2308,
  #       question_id: 11,
  #       trait_value_id: 2541,
  #       display_order: 7,
  #       text: "Organic"
  #     },
  #     %{
  #       id: 2309,
  #       question_id: 11,
  #       trait_value_id: 2542,
  #       display_order: 8,
  #       text: "Blend"
  #     },
  #     %{
  #       id: 2310,
  #       question_id: 11,
  #       trait_value_id: 2543,
  #       display_order: 9,
  #       text: "Gourmet"
  #     },
  #     %{
  #       id: 2311,
  #       question_id: 11,
  #       trait_value_id: 2544,
  #       display_order: 10,
  #       text: "Mexican"
  #     },
  #     %{
  #       id: 2312,
  #       question_id: 11,
  #       trait_value_id: 2545,
  #       display_order: 11,
  #       text: "Central American"
  #     },
  #     %{
  #       id: 2313,
  #       question_id: 11,
  #       trait_value_id: 2546,
  #       display_order: 12,
  #       text: "South American"
  #     },
  #     %{
  #       id: 2314,
  #       question_id: 11,
  #       trait_value_id: 2547,
  #       display_order: 13,
  #       text: "African"
  #     },
  #     %{
  #       id: 2315,
  #       question_id: 11,
  #       trait_value_id: 2548,
  #       display_order: 14,
  #       text: "Pacific Island"
  #     },
  #     %{
  #       id: 2316,
  #       question_id: 11,
  #       trait_value_id: 2549,
  #       display_order: 15,
  #       text: "Carribean"
  #     },
  #     %{
  #       id: 2317,
  #       question_id: 11,
  #       trait_value_id: 2550,
  #       display_order: 16,
  #       text: "Kona/Hawaiian"
  #     },
  #     %{
  #       id: 2318,
  #       question_id: 11,
  #       trait_value_id: 2551,
  #       display_order: 17,
  #       text: "Imported - Other"
  #     },
  #     %{
  #       id: 2319,
  #       question_id: 11,
  #       trait_value_id: 2552,
  #       display_order: 18,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2320,
  #       question_id: 11,
  #       trait_value_id: 2553,
  #       display_order: 19,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2321,
  #       question_id: 11,
  #       trait_value_id: 2555,
  #       display_order: 1,
  #       text: "Nothing - Keep it black"
  #     },
  #     %{
  #       id: 2322,
  #       question_id: 11,
  #       trait_value_id: 2556,
  #       display_order: 2,
  #       text: "Sugar"
  #     },
  #     %{
  #       id: 2323,
  #       question_id: 11,
  #       trait_value_id: 2557,
  #       display_order: 3,
  #       text: "Artificial sweetener"
  #     },
  #     %{
  #       id: 2324,
  #       question_id: 11,
  #       trait_value_id: 2558,
  #       display_order: 4,
  #       text: "Milk"
  #     },
  #     %{
  #       id: 2325,
  #       question_id: 11,
  #       trait_value_id: 2559,
  #       display_order: 5,
  #       text: "Cream"
  #     },
  #     %{
  #       id: 2326,
  #       question_id: 11,
  #       trait_value_id: 2560,
  #       display_order: 6,
  #       text: "Half-n-half"
  #     },
  #     %{
  #       id: 2327,
  #       question_id: 11,
  #       trait_value_id: 2561,
  #       display_order: 7,
  #       text: "Whipped cream (sweet)"
  #     },
  #     %{
  #       id: 2328,
  #       question_id: 11,
  #       trait_value_id: 2562,
  #       display_order: 8,
  #       text: "Non-dairy creamer"
  #     },
  #     %{
  #       id: 2329,
  #       question_id: 11,
  #       trait_value_id: 2563,
  #       display_order: 9,
  #       text: "Soy milk"
  #     },
  #     %{
  #       id: 2330,
  #       question_id: 11,
  #       trait_value_id: 2564,
  #       display_order: 10,
  #       text: "Ice"
  #     },
  #     %{
  #       id: 2331,
  #       question_id: 11,
  #       trait_value_id: 2565,
  #       display_order: 11,
  #       text: "Flavoring (French Vanilla, Chocolate, Caramel, Hazlenut, etc.)"
  #     },
  #     %{
  #       id: 2332,
  #       question_id: 11,
  #       trait_value_id: 2566,
  #       display_order: 12,
  #       text: "Liquor"
  #     },
  #     %{
  #       id: 2333,
  #       question_id: 11,
  #       trait_value_id: 2567,
  #       display_order: 13,
  #       text: "None of the above (Non-Drinker)"
  #     },
  #     %{
  #       id: 2334,
  #       question_id: 11,
  #       trait_value_id: 2568,
  #       display_order: 14,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2335,
  #       question_id: 12,
  #       trait_value_id: 2570,
  #       display_order: 1,
  #       text: "Americano"
  #     },
  #     %{
  #       id: 2336,
  #       question_id: 12,
  #       trait_value_id: 2571,
  #       display_order: 2,
  #       text: "Caf au Lait"
  #     },
  #     %{
  #       id: 2337,
  #       question_id: 12,
  #       trait_value_id: 2572,
  #       display_order: 3,
  #       text: "Caffe Latte"
  #     },
  #     %{
  #       id: 2338,
  #       question_id: 12,
  #       trait_value_id: 2573,
  #       display_order: 4,
  #       text: "Caffe Mocha (Mochachino)"
  #     },
  #     %{
  #       id: 2339,
  #       question_id: 12,
  #       trait_value_id: 2574,
  #       display_order: 5,
  #       text: "Cappuccino"
  #     },
  #     %{
  #       id: 2340,
  #       question_id: 12,
  #       trait_value_id: 2575,
  #       display_order: 6,
  #       text: "Caramel Macchiato"
  #     },
  #     %{
  #       id: 2341,
  #       question_id: 12,
  #       trait_value_id: 2576,
  #       display_order: 7,
  #       text: "Espresso"
  #     },
  #     %{
  #       id: 2342,
  #       question_id: 12,
  #       trait_value_id: 2577,
  #       display_order: 8,
  #       text: "Other - Not listed"
  #     },
  #     %{
  #       id: 2343,
  #       question_id: 12,
  #       trait_value_id: 2578,
  #       display_order: 9,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2344,
  #       question_id: 12,
  #       trait_value_id: 2579,
  #       display_order: 10,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2345,
  #       question_id: 11,
  #       trait_value_id: 2581,
  #       display_order: 1,
  #       text: "Never"
  #     },
  #     %{
  #       id: 2346,
  #       question_id: 11,
  #       trait_value_id: 2582,
  #       display_order: 2,
  #       text: "Seldom"
  #     },
  #     %{
  #       id: 2347,
  #       question_id: 11,
  #       trait_value_id: 2583,
  #       display_order: 3,
  #       text: "Occasionally"
  #     },
  #     %{
  #       id: 2348,
  #       question_id: 11,
  #       trait_value_id: 2584,
  #       display_order: 4,
  #       text: "Regularly"
  #     },
  #     %{
  #       id: 2349,
  #       question_id: 11,
  #       trait_value_id: 2585,
  #       display_order: 5,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2350,
  #       question_id: 12,
  #       trait_value_id: 2587,
  #       display_order: 1,
  #       text: "Never"
  #     },
  #     %{
  #       id: 2351,
  #       question_id: 12,
  #       trait_value_id: 2588,
  #       display_order: 2,
  #       text: "Seldom"
  #     },
  #     %{
  #       id: 2352,
  #       question_id: 12,
  #       trait_value_id: 2589,
  #       display_order: 3,
  #       text: "Occasionally"
  #     },
  #     %{
  #       id: 2353,
  #       question_id: 12,
  #       trait_value_id: 2590,
  #       display_order: 4,
  #       text: "Regularly"
  #     },
  #     %{
  #       id: 2354,
  #       question_id: 12,
  #       trait_value_id: 2591,
  #       display_order: 5,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2355,
  #       question_id: 12,
  #       trait_value_id: 2593,
  #       display_order: 1,
  #       text: "Never"
  #     },
  #     %{
  #       id: 2356,
  #       question_id: 12,
  #       trait_value_id: 2594,
  #       display_order: 2,
  #       text: "Seldom"
  #     },
  #     %{
  #       id: 2357,
  #       question_id: 12,
  #       trait_value_id: 2595,
  #       display_order: 3,
  #       text: "Occasionally"
  #     },
  #     %{
  #       id: 2358,
  #       question_id: 12,
  #       trait_value_id: 2596,
  #       display_order: 4,
  #       text: "Regularly"
  #     },
  #     %{
  #       id: 2359,
  #       question_id: 12,
  #       trait_value_id: 2597,
  #       display_order: 5,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2360,
  #       question_id: 12,
  #       trait_value_id: 2599,
  #       display_order: 1,
  #       text: "Never"
  #     },
  #     %{
  #       id: 2361,
  #       question_id: 12,
  #       trait_value_id: 2600,
  #       display_order: 2,
  #       text: "Seldom"
  #     },
  #     %{
  #       id: 2362,
  #       question_id: 12,
  #       trait_value_id: 2601,
  #       display_order: 3,
  #       text: "Occasionally"
  #     },
  #     %{
  #       id: 2363,
  #       question_id: 12,
  #       trait_value_id: 2602,
  #       display_order: 4,
  #       text: "Regularly"
  #     },
  #     %{
  #       id: 2364,
  #       question_id: 12,
  #       trait_value_id: 2603,
  #       display_order: 5,
  #       text: "Rather not say"
  #     },
  #     %{
  #       id: 2365,
  #       question_id: 23,
  #       trait_value_id: 2604,
  #       display_order: 808,
  #       text: "University of Rochester"
  #     },
  #     %{
  #       id: 2456,
  #       question_id: 12,
  #       trait_value_id: 2700,
  #       display_order: 1,
  #       text: "Just me"
  #     },
  #     %{
  #       id: 2457,
  #       question_id: 12,
  #       trait_value_id: 2701,
  #       display_order: 2,
  #       text: "Spouse/companion"
  #     },
  #     %{
  #       id: 2458,
  #       question_id: 12,
  #       trait_value_id: 2702,
  #       display_order: 3,
  #       text: "Core family"
  #     },
  #     %{
  #       id: 2459,
  #       question_id: 12,
  #       trait_value_id: 2703,
  #       display_order: 4,
  #       text: "Extended family"
  #     },
  #     %{
  #       id: 2460,
  #       question_id: 12,
  #       trait_value_id: 2704,
  #       display_order: 5,
  #       text: "Small group of friends"
  #     },
  #     %{
  #       id: 2461,
  #       question_id: 12,
  #       trait_value_id: 2705,
  #       display_order: 6,
  #       text: "With large group"
  #     },
  #     %{
  #       id: 2462,
  #       question_id: 12,
  #       trait_value_id: 2706,
  #       display_order: 7,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2463,
  #       question_id: 12,
  #       trait_value_id: 2708,
  #       display_order: 1,
  #       text: "Warm climate"
  #     },
  #     %{
  #       id: 2464,
  #       question_id: 12,
  #       trait_value_id: 2709,
  #       display_order: 2,
  #       text: "Cold climate"
  #     },
  #     %{
  #       id: 2465,
  #       question_id: 12,
  #       trait_value_id: 2710,
  #       display_order: 3,
  #       text: "Cosmopolitan city"
  #     },
  #     %{
  #       id: 2466,
  #       question_id: 12,
  #       trait_value_id: 2711,
  #       display_order: 4,
  #       text: "Beautiful beaches"
  #     },
  #     %{
  #       id: 2467,
  #       question_id: 12,
  #       trait_value_id: 2712,
  #       display_order: 5,
  #       text: "Majestic mountains"
  #     },
  #     %{
  #       id: 2468,
  #       question_id: 12,
  #       trait_value_id: 2713,
  #       display_order: 6,
  #       text: "Charming countryside"
  #     },
  #     %{
  #       id: 2469,
  #       question_id: 12,
  #       trait_value_id: 2714,
  #       display_order: 7,
  #       text: "Quaint village or small town"
  #     },
  #     %{
  #       id: 2470,
  #       question_id: 12,
  #       trait_value_id: 2715,
  #       display_order: 8,
  #       text: "Great outdoors"
  #     },
  #     %{
  #       id: 2471,
  #       question_id: 12,
  #       trait_value_id: 2716,
  #       display_order: 9,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2472,
  #       question_id: 12,
  #       trait_value_id: 2718,
  #       display_order: 1,
  #       text: "Luxury hotel"
  #     },
  #     %{
  #       id: 2473,
  #       question_id: 12,
  #       trait_value_id: 2719,
  #       display_order: 2,
  #       text: "Name-brand hotel"
  #     },
  #     %{
  #       id: 2474,
  #       question_id: 12,
  #       trait_value_id: 2720,
  #       display_order: 3,
  #       text: "Hotel with a little character"
  #     },
  #     %{
  #       id: 2475,
  #       question_id: 12,
  #       trait_value_id: 2721,
  #       display_order: 4,
  #       text: "Full-service resort"
  #     },
  #     %{
  #       id: 2476,
  #       question_id: 12,
  #       trait_value_id: 2722,
  #       display_order: 5,
  #       text: "Condominium/Villa"
  #     },
  #     %{
  #       id: 2477,
  #       question_id: 12,
  #       trait_value_id: 2723,
  #       display_order: 6,
  #       text: "Bed & Breakfast"
  #     },
  #     %{
  #       id: 2478,
  #       question_id: 12,
  #       trait_value_id: 2724,
  #       display_order: 7,
  #       text: "Lodge"
  #     },
  #     %{
  #       id: 2479,
  #       question_id: 12,
  #       trait_value_id: 2725,
  #       display_order: 8,
  #       text: "Cruise ship"
  #     },
  #     %{
  #       id: 2480,
  #       question_id: 12,
  #       trait_value_id: 2726,
  #       display_order: 9,
  #       text: "Rented or borrowed apartment"
  #     },
  #     %{
  #       id: 2481,
  #       question_id: 12,
  #       trait_value_id: 2727,
  #       display_order: 10,
  #       text: "Hostel"
  #     },
  #     %{
  #       id: 2482,
  #       question_id: 12,
  #       trait_value_id: 2728,
  #       display_order: 11,
  #       text: "Recreational vehicle (RV)"
  #     },
  #     %{
  #       id: 2483,
  #       question_id: 12,
  #       trait_value_id: 2729,
  #       display_order: 12,
  #       text: "Cabin"
  #     },
  #     %{
  #       id: 2484,
  #       question_id: 12,
  #       trait_value_id: 2730,
  #       display_order: 13,
  #       text: "Tent"
  #     },
  #     %{
  #       id: 2485,
  #       question_id: 12,
  #       trait_value_id: 2731,
  #       display_order: 14,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2486,
  #       question_id: 12,
  #       trait_value_id: 2733,
  #       display_order: 1,
  #       text: "Budget conscious"
  #     },
  #     %{
  #       id: 2487,
  #       question_id: 12,
  #       trait_value_id: 2734,
  #       display_order: 2,
  #       text: "All-inclusive package"
  #     },
  #     %{
  #       id: 2488,
  #       question_id: 12,
  #       trait_value_id: 2735,
  #       display_order: 3,
  #       text: "Upscale"
  #     },
  #     %{
  #       id: 2489,
  #       question_id: 12,
  #       trait_value_id: 2736,
  #       display_order: 4,
  #       text: "Family friendly"
  #     },
  #     %{
  #       id: 2490,
  #       question_id: 12,
  #       trait_value_id: 2737,
  #       display_order: 5,
  #       text: "Adult only"
  #     },
  #     %{
  #       id: 2491,
  #       question_id: 12,
  #       trait_value_id: 2738,
  #       display_order: 6,
  #       text: "Casual/relaxed"
  #     },
  #     %{
  #       id: 2492,
  #       question_id: 12,
  #       trait_value_id: 2739,
  #       display_order: 7,
  #       text: "Energetic"
  #     },
  #     %{
  #       id: 2493,
  #       question_id: 12,
  #       trait_value_id: 2740,
  #       display_order: 8,
  #       text: "Romantic"
  #     },
  #     %{
  #       id: 2494,
  #       question_id: 12,
  #       trait_value_id: 2741,
  #       display_order: 9,
  #       text: "Adventure"
  #     },
  #     %{
  #       id: 2495,
  #       question_id: 12,
  #       trait_value_id: 2742,
  #       display_order: 10,
  #       text: "Local sights and culture"
  #     },
  #     %{
  #       id: 2496,
  #       question_id: 12,
  #       trait_value_id: 2743,
  #       display_order: 11,
  #       text: "Non-stop activity"
  #     },
  #     %{
  #       id: 2497,
  #       question_id: 12,
  #       trait_value_id: 2744,
  #       display_order: 12,
  #       text: "Being pampered"
  #     },
  #     %{
  #       id: 2498,
  #       question_id: 12,
  #       trait_value_id: 2745,
  #       display_order: 13,
  #       text: "Ocean access"
  #     },
  #     %{
  #       id: 2499,
  #       question_id: 12,
  #       trait_value_id: 2746,
  #       display_order: 14,
  #       text: "Lake access"
  #     },
  #     %{
  #       id: 2500,
  #       question_id: 12,
  #       trait_value_id: 2747,
  #       display_order: 15,
  #       text: "Wilderness access"
  #     },
  #     %{
  #       id: 2501,
  #       question_id: 12,
  #       trait_value_id: 2748,
  #       display_order: 16,
  #       text: "Crowds and energy"
  #     },
  #     %{
  #       id: 2502,
  #       question_id: 12,
  #       trait_value_id: 2749,
  #       display_order: 17,
  #       text: "Off the beaten path"
  #     },
  #     %{
  #       id: 2503,
  #       question_id: 12,
  #       trait_value_id: 2750,
  #       display_order: 18,
  #       text: "Popular tourist destinations"
  #     },
  #     %{
  #       id: 2504,
  #       question_id: 12,
  #       trait_value_id: 2751,
  #       display_order: 19,
  #       text: "Peace and quiet"
  #     },
  #     %{
  #       id: 2505,
  #       question_id: 12,
  #       trait_value_id: 2752,
  #       display_order: 20,
  #       text: "Thrill and adventure"
  #     },
  #     %{
  #       id: 2506,
  #       question_id: 12,
  #       trait_value_id: 2753,
  #       display_order: 21,
  #       text: "Among other singles"
  #     },
  #     %{
  #       id: 2507,
  #       question_id: 12,
  #       trait_value_id: 2754,
  #       display_order: 22,
  #       text: "Among other couples"
  #     },
  #     %{
  #       id: 2508,
  #       question_id: 12,
  #       trait_value_id: 2755,
  #       display_order: 23,
  #       text: "Among other families"
  #     },
  #     %{
  #       id: 2509,
  #       question_id: 12,
  #       trait_value_id: 2756,
  #       display_order: 24,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2510,
  #       question_id: 12,
  #       trait_value_id: 2758,
  #       display_order: 1,
  #       text: "Museums"
  #     },
  #     %{
  #       id: 2511,
  #       question_id: 12,
  #       trait_value_id: 2759,
  #       display_order: 2,
  #       text: "Spa"
  #     },
  #     %{
  #       id: 2512,
  #       question_id: 12,
  #       trait_value_id: 2760,
  #       display_order: 3,
  #       text: "Photography"
  #     },
  #     %{
  #       id: 2513,
  #       question_id: 12,
  #       trait_value_id: 2761,
  #       display_order: 4,
  #       text: "Snow skiing"
  #     },
  #     %{
  #       id: 2514,
  #       question_id: 12,
  #       trait_value_id: 2762,
  #       display_order: 5,
  #       text: "Wine tasting/Vineyard tours"
  #     },
  #     %{
  #       id: 2515,
  #       question_id: 12,
  #       trait_value_id: 2763,
  #       display_order: 6,
  #       text: "Markets and shopping"
  #     },
  #     %{
  #       id: 2516,
  #       question_id: 12,
  #       trait_value_id: 2764,
  #       display_order: 7,
  #       text: "Scenic and group tours"
  #     },
  #     %{
  #       id: 2517,
  #       question_id: 12,
  #       trait_value_id: 2765,
  #       display_order: 8,
  #       text: "Swimming"
  #     },
  #     %{
  #       id: 2518,
  #       question_id: 12,
  #       trait_value_id: 2766,
  #       display_order: 9,
  #       text: "Sun bathing"
  #     },
  #     %{
  #       id: 2519,
  #       question_id: 12,
  #       trait_value_id: 2767,
  #       display_order: 10,
  #       text: "Watersports/Boating/Skiing"
  #     },
  #     %{
  #       id: 2520,
  #       question_id: 12,
  #       trait_value_id: 2768,
  #       display_order: 11,
  #       text: "Golf"
  #     },
  #     %{
  #       id: 2521,
  #       question_id: 12,
  #       trait_value_id: 2769,
  #       display_order: 12,
  #       text: "Hunting"
  #     },
  #     %{
  #       id: 2522,
  #       question_id: 12,
  #       trait_value_id: 2770,
  #       display_order: 13,
  #       text: "Hiking/Walking"
  #     },
  #     %{
  #       id: 2523,
  #       question_id: 12,
  #       trait_value_id: 2771,
  #       display_order: 14,
  #       text: "Scuba diving"
  #     },
  #     %{
  #       id: 2524,
  #       question_id: 12,
  #       trait_value_id: 2772,
  #       display_order: 15,
  #       text: "Snorkeling"
  #     },
  #     %{
  #       id: 2525,
  #       question_id: 12,
  #       trait_value_id: 2773,
  #       display_order: 16,
  #       text: "Theater/Shows/Plays"
  #     },
  #     %{
  #       id: 2526,
  #       question_id: 12,
  #       trait_value_id: 2774,
  #       display_order: 17,
  #       text: "Concerts"
  #     },
  #     %{
  #       id: 2527,
  #       question_id: 12,
  #       trait_value_id: 2775,
  #       display_order: 18,
  #       text: "Casinos/Gaming"
  #     },
  #     %{
  #       id: 2528,
  #       question_id: 12,
  #       trait_value_id: 2776,
  #       display_order: 19,
  #       text: "Sports events (spectator)"
  #     },
  #     %{
  #       id: 2529,
  #       question_id: 12,
  #       trait_value_id: 2777,
  #       display_order: 20,
  #       text: "Fine dining"
  #     },
  #     %{
  #       id: 2530,
  #       question_id: 12,
  #       trait_value_id: 2778,
  #       display_order: 21,
  #       text: "Nightlife"
  #     },
  #     %{
  #       id: 2531,
  #       question_id: 12,
  #       trait_value_id: 2779,
  #       display_order: 22,
  #       text: "Local restaurants"
  #     },
  #     %{
  #       id: 2532,
  #       question_id: 12,
  #       trait_value_id: 2780,
  #       display_order: 23,
  #       text: "Theme parks"
  #     },
  #     %{
  #       id: 2533,
  #       question_id: 12,
  #       trait_value_id: 2781,
  #       display_order: 24,
  #       text: "Camping/RVing"
  #     },
  #     %{
  #       id: 2534,
  #       question_id: 12,
  #       trait_value_id: 2782,
  #       display_order: 25,
  #       text: "Shopping"
  #     },
  #     %{
  #       id: 2535,
  #       question_id: 12,
  #       trait_value_id: 2783,
  #       display_order: 26,
  #       text: "Sightseeing/Man-made attractions"
  #     },
  #     %{
  #       id: 2536,
  #       question_id: 12,
  #       trait_value_id: 2784,
  #       display_order: 27,
  #       text: "Sightseeing/Natural attractions"
  #     },
  #     %{
  #       id: 2537,
  #       question_id: 12,
  #       trait_value_id: 2785,
  #       display_order: 28,
  #       text: "Authentic local cuisine"
  #     },
  #     %{
  #       id: 2538,
  #       question_id: 12,
  #       trait_value_id: 2786,
  #       display_order: 29,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2539,
  #       question_id: 13,
  #       trait_value_id: 2788,
  #       display_order: 1,
  #       text: "Within United States"
  #     },
  #     %{
  #       id: 2540,
  #       question_id: 13,
  #       trait_value_id: 2789,
  #       display_order: 2,
  #       text: "Outside United States"
  #     },
  #     %{
  #       id: 2541,
  #       question_id: 13,
  #       trait_value_id: 2790,
  #       display_order: 3,
  #       text: "English-speaking"
  #     },
  #     %{
  #       id: 2542,
  #       question_id: 13,
  #       trait_value_id: 2791,
  #       display_order: 4,
  #       text: "English-optional"
  #     },
  #     %{
  #       id: 2543,
  #       question_id: 13,
  #       trait_value_id: 2792,
  #       display_order: 5,
  #       text: "Hawaii"
  #     },
  #     %{
  #       id: 2544,
  #       question_id: 13,
  #       trait_value_id: 2793,
  #       display_order: 6,
  #       text: "Las Vegas"
  #     },
  #     %{
  #       id: 2545,
  #       question_id: 13,
  #       trait_value_id: 2794,
  #       display_order: 7,
  #       text: "Europe"
  #     },
  #     %{
  #       id: 2546,
  #       question_id: 13,
  #       trait_value_id: 2795,
  #       display_order: 8,
  #       text: "Mexico"
  #     },
  #     %{
  #       id: 2547,
  #       question_id: 13,
  #       trait_value_id: 2796,
  #       display_order: 9,
  #       text: "Central/South America"
  #     },
  #     %{
  #       id: 2548,
  #       question_id: 13,
  #       trait_value_id: 2797,
  #       display_order: 10,
  #       text: "Carribean Islands"
  #     },
  #     %{
  #       id: 2549,
  #       question_id: 13,
  #       trait_value_id: 2798,
  #       display_order: 11,
  #       text: "Asia"
  #     },
  #     %{
  #       id: 2550,
  #       question_id: 13,
  #       trait_value_id: 2799,
  #       display_order: 12,
  #       text: "Africa"
  #     },
  #     %{
  #       id: 2551,
  #       question_id: 13,
  #       trait_value_id: 2800,
  #       display_order: 13,
  #       text: "Australia"
  #     },
  #     %{
  #       id: 2552,
  #       question_id: 13,
  #       trait_value_id: 2801,
  #       display_order: 14,
  #       text: "Other - Not Listed"
  #     },
  #     %{
  #       id: 2553,
  #       question_id: 13,
  #       trait_value_id: 2802,
  #       display_order: 15,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2554,
  #       question_id: 13,
  #       trait_value_id: 2804,
  #       display_order: 1,
  #       text: "Alternative"
  #     },
  #     %{
  #       id: 2555,
  #       question_id: 13,
  #       trait_value_id: 2805,
  #       display_order: 2,
  #       text: "Beach/Surfer"
  #     },
  #     %{
  #       id: 2556,
  #       question_id: 13,
  #       trait_value_id: 2806,
  #       display_order: 3,
  #       text: "Biker"
  #     },
  #     %{
  #       id: 2557,
  #       question_id: 13,
  #       trait_value_id: 2807,
  #       display_order: 4,
  #       text: "Bohemian"
  #     },
  #     %{
  #       id: 2558,
  #       question_id: 13,
  #       trait_value_id: 2808,
  #       display_order: 5,
  #       text: "Classic"
  #     },
  #     %{
  #       id: 2559,
  #       question_id: 13,
  #       trait_value_id: 2809,
  #       display_order: 6,
  #       text: "Conservative"
  #     },
  #     %{
  #       id: 2560,
  #       question_id: 13,
  #       trait_value_id: 2810,
  #       display_order: 7,
  #       text: "Designer"
  #     },
  #     %{
  #       id: 2561,
  #       question_id: 13,
  #       trait_value_id: 2811,
  #       display_order: 8,
  #       text: "Edgy"
  #     },
  #     %{
  #       id: 2562,
  #       question_id: 13,
  #       trait_value_id: 2812,
  #       display_order: 9,
  #       text: "Formal"
  #     },
  #     %{
  #       id: 2563,
  #       question_id: 13,
  #       trait_value_id: 2813,
  #       display_order: 10,
  #       text: "Girly"
  #     },
  #     %{
  #       id: 2564,
  #       question_id: 13,
  #       trait_value_id: 2814,
  #       display_order: 11,
  #       text: "Goth"
  #     },
  #     %{
  #       id: 2565,
  #       question_id: 13,
  #       trait_value_id: 2815,
  #       display_order: 12,
  #       text: "Grungy"
  #     },
  #     %{
  #       id: 2566,
  #       question_id: 13,
  #       trait_value_id: 2816,
  #       display_order: 13,
  #       text: "High-Fashion"
  #     },
  #     %{
  #       id: 2567,
  #       question_id: 13,
  #       trait_value_id: 2817,
  #       display_order: 14,
  #       text: "Hip-Hop/Urban"
  #     },
  #     %{
  #       id: 2568,
  #       question_id: 13,
  #       trait_value_id: 2818,
  #       display_order: 15,
  #       text: "Humorous"
  #     },
  #     %{
  #       id: 2569,
  #       question_id: 13,
  #       trait_value_id: 2819,
  #       display_order: 16,
  #       text: "Low-Key"
  #     },
  #     %{
  #       id: 2570,
  #       question_id: 13,
  #       trait_value_id: 2820,
  #       display_order: 17,
  #       text: "Mod/Retro"
  #     },
  #     %{
  #       id: 2571,
  #       question_id: 13,
  #       trait_value_id: 2821,
  #       display_order: 18,
  #       text: "Name-brand"
  #     },
  #     %{
  #       id: 2572,
  #       question_id: 13,
  #       trait_value_id: 2822,
  #       display_order: 19,
  #       text: "Nerd/Geek"
  #     },
  #     %{
  #       id: 2573,
  #       question_id: 13,
  #       trait_value_id: 2823,
  #       display_order: 20,
  #       text: "Preppy"
  #     },
  #     %{
  #       id: 2574,
  #       question_id: 13,
  #       trait_value_id: 2824,
  #       display_order: 21,
  #       text: "Professional"
  #     },
  #     %{
  #       id: 2575,
  #       question_id: 13,
  #       trait_value_id: 2825,
  #       display_order: 22,
  #       text: "Rock"
  #     },
  #     %{
  #       id: 2576,
  #       question_id: 13,
  #       trait_value_id: 2826,
  #       display_order: 23,
  #       text: "Sexy"
  #     },
  #     %{
  #       id: 2577,
  #       question_id: 13,
  #       trait_value_id: 2827,
  #       display_order: 24,
  #       text: "Shabby Chic"
  #     },
  #     %{
  #       id: 2578,
  #       question_id: 13,
  #       trait_value_id: 2828,
  #       display_order: 25,
  #       text: "Skater"
  #     },
  #     %{
  #       id: 2579,
  #       question_id: 13,
  #       trait_value_id: 2829,
  #       display_order: 26,
  #       text: "Sporty/Athletic"
  #     },
  #     %{
  #       id: 2580,
  #       question_id: 13,
  #       trait_value_id: 2830,
  #       display_order: 27,
  #       text: "Suits"
  #     },
  #     %{
  #       id: 2581,
  #       question_id: 13,
  #       trait_value_id: 2831,
  #       display_order: 28,
  #       text: "Tailored/Fitted"
  #     },
  #     %{
  #       id: 2582,
  #       question_id: 13,
  #       trait_value_id: 2832,
  #       display_order: 29,
  #       text: "Trendy"
  #     },
  #     %{
  #       id: 2583,
  #       question_id: 13,
  #       trait_value_id: 2833,
  #       display_order: 30,
  #       text: "Unique"
  #     },
  #     %{
  #       id: 2584,
  #       question_id: 13,
  #       trait_value_id: 2834,
  #       display_order: 31,
  #       text: "Vintage"
  #     },
  #     %{
  #       id: 2585,
  #       question_id: 13,
  #       trait_value_id: 2835,
  #       display_order: 32,
  #       text: "Western/Country"
  #     },
  #     %{
  #       id: 2586,
  #       question_id: 13,
  #       trait_value_id: 2836,
  #       display_order: 33,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 2587,
  #       question_id: 13,
  #       trait_value_id: 2837,
  #       display_order: 34,
  #       text: "No particular style / Not so into fashion"
  #     },
  #     %{
  #       id: 2588,
  #       question_id: 13,
  #       trait_value_id: 2838,
  #       display_order: 35,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2589,
  #       question_id: 13,
  #       trait_value_id: 2840,
  #       display_order: 1,
  #       text: "African"
  #     },
  #     %{
  #       id: 2590,
  #       question_id: 13,
  #       trait_value_id: 2841,
  #       display_order: 2,
  #       text: "Antique"
  #     },
  #     %{
  #       id: 2591,
  #       question_id: 13,
  #       trait_value_id: 2842,
  #       display_order: 3,
  #       text: "Art Deco"
  #     },
  #     %{
  #       id: 2592,
  #       question_id: 13,
  #       trait_value_id: 2843,
  #       display_order: 4,
  #       text: "Asian"
  #     },
  #     %{
  #       id: 2593,
  #       question_id: 13,
  #       trait_value_id: 2844,
  #       display_order: 5,
  #       text: "British India"
  #     },
  #     %{
  #       id: 2594,
  #       question_id: 13,
  #       trait_value_id: 2845,
  #       display_order: 6,
  #       text: "Casual"
  #     },
  #     %{
  #       id: 2595,
  #       question_id: 13,
  #       trait_value_id: 2846,
  #       display_order: 7,
  #       text: "Contemporary"
  #     },
  #     %{
  #       id: 2596,
  #       question_id: 13,
  #       trait_value_id: 2847,
  #       display_order: 8,
  #       text: "Cottage"
  #     },
  #     %{
  #       id: 2597,
  #       question_id: 13,
  #       trait_value_id: 2848,
  #       display_order: 9,
  #       text: "Country"
  #     },
  #     %{
  #       id: 2598,
  #       question_id: 13,
  #       trait_value_id: 2849,
  #       display_order: 10,
  #       text: "Eclectic"
  #     },
  #     %{
  #       id: 2599,
  #       question_id: 13,
  #       trait_value_id: 2850,
  #       display_order: 11,
  #       text: "English Country"
  #     },
  #     %{
  #       id: 2600,
  #       question_id: 13,
  #       trait_value_id: 2851,
  #       display_order: 12,
  #       text: "French Country"
  #     },
  #     %{
  #       id: 2601,
  #       question_id: 13,
  #       trait_value_id: 2852,
  #       display_order: 13,
  #       text: "Guy (Generic Male)"
  #     },
  #     %{
  #       id: 2602,
  #       question_id: 13,
  #       trait_value_id: 2853,
  #       display_order: 14,
  #       text: "Italian Decor"
  #     },
  #     %{
  #       id: 2603,
  #       question_id: 13,
  #       trait_value_id: 2854,
  #       display_order: 15,
  #       text: "Mediterranean"
  #     },
  #     %{
  #       id: 2604,
  #       question_id: 13,
  #       trait_value_id: 2855,
  #       display_order: 16,
  #       text: "Mexican"
  #     },
  #     %{
  #       id: 2605,
  #       question_id: 13,
  #       trait_value_id: 2856,
  #       display_order: 17,
  #       text: "Minimalist"
  #     },
  #     %{
  #       id: 2606,
  #       question_id: 13,
  #       trait_value_id: 2857,
  #       display_order: 18,
  #       text: "Modern"
  #     },
  #     %{
  #       id: 2607,
  #       question_id: 13,
  #       trait_value_id: 2858,
  #       display_order: 19,
  #       text: "Moroccan"
  #     },
  #     %{
  #       id: 2608,
  #       question_id: 13,
  #       trait_value_id: 2859,
  #       display_order: 20,
  #       text: "Oriental"
  #     },
  #     %{
  #       id: 2609,
  #       question_id: 13,
  #       trait_value_id: 2860,
  #       display_order: 21,
  #       text: "Retro/Vintage"
  #     },
  #     %{
  #       id: 2610,
  #       question_id: 13,
  #       trait_value_id: 2861,
  #       display_order: 22,
  #       text: "Romantic"
  #     },
  #     %{
  #       id: 2611,
  #       question_id: 13,
  #       trait_value_id: 2862,
  #       display_order: 23,
  #       text: "Rustic"
  #     },
  #     %{
  #       id: 2612,
  #       question_id: 13,
  #       trait_value_id: 2863,
  #       display_order: 24,
  #       text: "Shabby Chic"
  #     },
  #     %{
  #       id: 2613,
  #       question_id: 13,
  #       trait_value_id: 2864,
  #       display_order: 25,
  #       text: "Southwest"
  #     },
  #     %{
  #       id: 2614,
  #       question_id: 13,
  #       trait_value_id: 2865,
  #       display_order: 26,
  #       text: "Spanish"
  #     },
  #     %{
  #       id: 2615,
  #       question_id: 13,
  #       trait_value_id: 2866,
  #       display_order: 27,
  #       text: "Sports"
  #     },
  #     %{
  #       id: 2616,
  #       question_id: 13,
  #       trait_value_id: 2867,
  #       display_order: 28,
  #       text: "Swedish"
  #     },
  #     %{
  #       id: 2617,
  #       question_id: 13,
  #       trait_value_id: 2868,
  #       display_order: 29,
  #       text: "Texas"
  #     },
  #     %{
  #       id: 2618,
  #       question_id: 13,
  #       trait_value_id: 2869,
  #       display_order: 30,
  #       text: "Traditional"
  #     },
  #     %{
  #       id: 2619,
  #       question_id: 13,
  #       trait_value_id: 2870,
  #       display_order: 31,
  #       text: "Tropical Chic"
  #     },
  #     %{
  #       id: 2620,
  #       question_id: 13,
  #       trait_value_id: 2871,
  #       display_order: 32,
  #       text: "Victorian"
  #     },
  #     %{
  #       id: 2621,
  #       question_id: 13,
  #       trait_value_id: 2872,
  #       display_order: 33,
  #       text: "West Indies"
  #     },
  #     %{
  #       id: 2622,
  #       question_id: 13,
  #       trait_value_id: 2873,
  #       display_order: 34,
  #       text: "Whimsical"
  #     },
  #     %{
  #       id: 2623,
  #       question_id: 13,
  #       trait_value_id: 2874,
  #       display_order: 35,
  #       text: "Other - not listed"
  #     },
  #     %{
  #       id: 2624,
  #       question_id: 13,
  #       trait_value_id: 2875,
  #       display_order: 36,
  #       text: "No particular style"
  #     },
  #     %{
  #       id: 2625,
  #       question_id: 13,
  #       trait_value_id: 2876,
  #       display_order: 37,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2626,
  #       question_id: 13,
  #       trait_value_id: 2877,
  #       display_order: 15,
  #       text: "Indie"
  #     },
  #     %{
  #       id: 2627,
  #       question_id: 23,
  #       trait_value_id: 2878,
  #       display_order: 360,
  #       text: "Kilgore College"
  #     },
  #     %{
  #       id: 2628,
  #       question_id: 95,
  #       trait_value_id: 2879,
  #       display_order: 1,
  #       text: "Animal Rescue/Animal-Related"
  #     },
  #     %{
  #       id: 2629,
  #       question_id: 13,
  #       trait_value_id: 2881,
  #       display_order: 1,
  #       text: "MasterCard"
  #     },
  #     %{
  #       id: 2630,
  #       question_id: 13,
  #       trait_value_id: 2882,
  #       display_order: 2,
  #       text: "Visa"
  #     },
  #     %{
  #       id: 2631,
  #       question_id: 13,
  #       trait_value_id: 2883,
  #       display_order: 3,
  #       text: "Discover"
  #     },
  #     %{
  #       id: 2632,
  #       question_id: 13,
  #       trait_value_id: 2884,
  #       display_order: 4,
  #       text: "American Express"
  #     },
  #     %{
  #       id: 2633,
  #       question_id: 13,
  #       trait_value_id: 2885,
  #       display_order: 5,
  #       text: "Diners Club"
  #     },
  #     %{
  #       id: 2634,
  #       question_id: 13,
  #       trait_value_id: 2886,
  #       display_order: 6,
  #       text: "Gas cards"
  #     },
  #     %{
  #       id: 2635,
  #       question_id: 13,
  #       trait_value_id: 2887,
  #       display_order: 7,
  #       text: "Department store cards"
  #     },
  #     %{
  #       id: 2636,
  #       question_id: 13,
  #       trait_value_id: 2888,
  #       display_order: 8,
  #       text: "Debit cards"
  #     },
  #     %{
  #       id: 2637,
  #       question_id: 13,
  #       trait_value_id: 2889,
  #       display_order: 9,
  #       text: "Prepaid cards"
  #     },
  #     %{
  #       id: 2638,
  #       question_id: 13,
  #       trait_value_id: 2890,
  #       display_order: 10,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2639,
  #       question_id: 13,
  #       trait_value_id: 2891,
  #       display_order: 11,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2640,
  #       question_id: 13,
  #       trait_value_id: 2893,
  #       display_order: 1,
  #       text: "Airplane - Jet"
  #     },
  #     %{
  #       id: 2641,
  #       question_id: 13,
  #       trait_value_id: 2894,
  #       display_order: 2,
  #       text: "Airplane - Propeller"
  #     },
  #     %{
  #       id: 2642,
  #       question_id: 13,
  #       trait_value_id: 2895,
  #       display_order: 3,
  #       text: "ATV"
  #     },
  #     %{
  #       id: 2643,
  #       question_id: 13,
  #       trait_value_id: 2896,
  #       display_order: 4,
  #       text: "Boat - Fishing"
  #     },
  #     %{
  #       id: 2644,
  #       question_id: 13,
  #       trait_value_id: 2897,
  #       display_order: 5,
  #       text: "Boat - Recreational/Ski"
  #     },
  #     %{
  #       id: 2645,
  #       question_id: 13,
  #       trait_value_id: 2898,
  #       display_order: 6,
  #       text: "Boat - Yacht/Luxury"
  #     },
  #     %{
  #       id: 2646,
  #       question_id: 13,
  #       trait_value_id: 2899,
  #       display_order: 7,
  #       text: "Helicopter"
  #     },
  #     %{
  #       id: 2647,
  #       question_id: 13,
  #       trait_value_id: 2900,
  #       display_order: 8,
  #       text: "Motorcycle"
  #     },
  #     %{
  #       id: 2648,
  #       question_id: 13,
  #       trait_value_id: 2901,
  #       display_order: 9,
  #       text: "Personal Water Craft (Jet Ski)"
  #     },
  #     %{
  #       id: 2649,
  #       question_id: 13,
  #       trait_value_id: 2902,
  #       display_order: 10,
  #       text: "RV - Motorhome/Coach"
  #     },
  #     %{
  #       id: 2650,
  #       question_id: 13,
  #       trait_value_id: 2903,
  #       display_order: 11,
  #       text: "RV - Trailer"
  #     },
  #     %{
  #       id: 2651,
  #       question_id: 13,
  #       trait_value_id: 2904,
  #       display_order: 12,
  #       text: "Snowmobile"
  #     },
  #     %{
  #       id: 2652,
  #       question_id: 13,
  #       trait_value_id: 2905,
  #       display_order: 13,
  #       text: "None of the above"
  #     },
  #     %{
  #       id: 2653,
  #       question_id: 13,
  #       trait_value_id: 2906,
  #       display_order: 14,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2654,
  #       question_id: 14,
  #       trait_value_id: 2907,
  #       display_order: 1,
  #       text: "Soccer"
  #     },
  #     %{
  #       id: 2655,
  #       question_id: 13,
  #       trait_value_id: 2909,
  #       display_order: 1,
  #       text: "Daily"
  #     },
  #     %{
  #       id: 2656,
  #       question_id: 13,
  #       trait_value_id: 2910,
  #       display_order: 2,
  #       text: "A few times a week"
  #     },
  #     %{
  #       id: 2657,
  #       question_id: 13,
  #       trait_value_id: 2911,
  #       display_order: 3,
  #       text: "Once a week"
  #     },
  #     %{
  #       id: 2658,
  #       question_id: 13,
  #       trait_value_id: 2912,
  #       display_order: 4,
  #       text: "2-3 times a month"
  #     },
  #     %{
  #       id: 2659,
  #       question_id: 13,
  #       trait_value_id: 2913,
  #       display_order: 5,
  #       text: "Once a month"
  #     },
  #     %{
  #       id: 2660,
  #       question_id: 13,
  #       trait_value_id: 2914,
  #       display_order: 6,
  #       text: "Once every 2-3 months"
  #     },
  #     %{
  #       id: 2661,
  #       question_id: 13,
  #       trait_value_id: 2915,
  #       display_order: 7,
  #       text: "Less than once every 2-3 months"
  #     },
  #     %{
  #       id: 2662,
  #       question_id: 13,
  #       trait_value_id: 2916,
  #       display_order: 8,
  #       text: "Never"
  #     },
  #     %{
  #       id: 2663,
  #       question_id: 13,
  #       trait_value_id: 2917,
  #       display_order: 9,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2664,
  #       question_id: 13,
  #       trait_value_id: 2919,
  #       display_order: 1,
  #       text: "Light beer"
  #     },
  #     %{
  #       id: 2665,
  #       question_id: 13,
  #       trait_value_id: 2920,
  #       display_order: 2,
  #       text: "Low-carb"
  #     },
  #     %{
  #       id: 2666,
  #       question_id: 13,
  #       trait_value_id: 2921,
  #       display_order: 3,
  #       text: "Home Brew"
  #     },
  #     %{
  #       id: 2667,
  #       question_id: 13,
  #       trait_value_id: 2922,
  #       display_order: 4,
  #       text: "Domestic (American)"
  #     },
  #     %{
  #       id: 2668,
  #       question_id: 13,
  #       trait_value_id: 2923,
  #       display_order: 5,
  #       text: "Imported - Mexican"
  #     },
  #     %{
  #       id: 2669,
  #       question_id: 13,
  #       trait_value_id: 2924,
  #       display_order: 6,
  #       text: "Imported - European"
  #     },
  #     %{
  #       id: 2670,
  #       question_id: 13,
  #       trait_value_id: 2925,
  #       display_order: 7,
  #       text: "Imported - Other"
  #     },
  #     %{
  #       id: 2671,
  #       question_id: 13,
  #       trait_value_id: 2926,
  #       display_order: 8,
  #       text: "Specialty Brew"
  #     },
  #     %{
  #       id: 2672,
  #       question_id: 13,
  #       trait_value_id: 2927,
  #       display_order: 9,
  #       text: "Microbrew"
  #     },
  #     %{
  #       id: 2673,
  #       question_id: 13,
  #       trait_value_id: 2928,
  #       display_order: 10,
  #       text: "Premium Import"
  #     },
  #     %{
  #       id: 2674,
  #       question_id: 13,
  #       trait_value_id: 2929,
  #       display_order: 11,
  #       text: "Bock"
  #     },
  #     %{
  #       id: 2675,
  #       question_id: 13,
  #       trait_value_id: 2930,
  #       display_order: 12,
  #       text: "Wheat Beer"
  #     },
  #     %{
  #       id: 2676,
  #       question_id: 13,
  #       trait_value_id: 2931,
  #       display_order: 13,
  #       text: "Malt Liquor"
  #     },
  #     %{
  #       id: 2677,
  #       question_id: 13,
  #       trait_value_id: 2932,
  #       display_order: 14,
  #       text: "Pale Lager"
  #     },
  #     %{
  #       id: 2678,
  #       question_id: 13,
  #       trait_value_id: 2933,
  #       display_order: 15,
  #       text: "Pilsner"
  #     },
  #     %{
  #       id: 2679,
  #       question_id: 13,
  #       trait_value_id: 2934,
  #       display_order: 16,
  #       text: "Lager"
  #     },
  #     %{
  #       id: 2680,
  #       question_id: 13,
  #       trait_value_id: 2935,
  #       display_order: 17,
  #       text: "Pale Ale"
  #     },
  #     %{
  #       id: 2681,
  #       question_id: 13,
  #       trait_value_id: 2936,
  #       display_order: 18,
  #       text: "Ale"
  #     },
  #     %{
  #       id: 2682,
  #       question_id: 13,
  #       trait_value_id: 2937,
  #       display_order: 19,
  #       text: "Bitter"
  #     },
  #     %{
  #       id: 2683,
  #       question_id: 13,
  #       trait_value_id: 2938,
  #       display_order: 20,
  #       text: "Porter"
  #     },
  #     %{
  #       id: 2684,
  #       question_id: 13,
  #       trait_value_id: 2939,
  #       display_order: 21,
  #       text: "Stout"
  #     },
  #     %{
  #       id: 2685,
  #       question_id: 13,
  #       trait_value_id: 2940,
  #       display_order: 22,
  #       text: "Non-Alcholic"
  #     },
  #     %{
  #       id: 2686,
  #       question_id: 13,
  #       trait_value_id: 2941,
  #       display_order: 23,
  #       text: "None listed"
  #     },
  #     %{
  #       id: 2687,
  #       question_id: 13,
  #       trait_value_id: 2942,
  #       display_order: 24,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2688,
  #       question_id: 87,
  #       trait_value_id: 2943,
  #       display_order: 5,
  #       text: "Gluten Free"
  #     },
  #     %{
  #       id: 2689,
  #       question_id: 13,
  #       trait_value_id: 2945,
  #       display_order: 1,
  #       text: "Daily"
  #     },
  #     %{
  #       id: 2690,
  #       question_id: 13,
  #       trait_value_id: 2946,
  #       display_order: 2,
  #       text: "A few times a week"
  #     },
  #     %{
  #       id: 2691,
  #       question_id: 13,
  #       trait_value_id: 2947,
  #       display_order: 3,
  #       text: "Once a week"
  #     },
  #     %{
  #       id: 2692,
  #       question_id: 13,
  #       trait_value_id: 2948,
  #       display_order: 4,
  #       text: "2-3 times a month"
  #     },
  #     %{
  #       id: 2693,
  #       question_id: 13,
  #       trait_value_id: 2949,
  #       display_order: 5,
  #       text: "Once a month"
  #     },
  #     %{
  #       id: 2694,
  #       question_id: 13,
  #       trait_value_id: 2950,
  #       display_order: 6,
  #       text: "Once every 2-3 months"
  #     },
  #     %{
  #       id: 2695,
  #       question_id: 13,
  #       trait_value_id: 2951,
  #       display_order: 7,
  #       text: "Less than once every 2-3 months"
  #     },
  #     %{
  #       id: 2696,
  #       question_id: 13,
  #       trait_value_id: 2952,
  #       display_order: 8,
  #       text: "Seasonally/special occasions only"
  #     },
  #     %{
  #       id: 2697,
  #       question_id: 13,
  #       trait_value_id: 2953,
  #       display_order: 9,
  #       text: "Never"
  #     },
  #     %{
  #       id: 2698,
  #       question_id: 13,
  #       trait_value_id: 2954,
  #       display_order: 10,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2699,
  #       question_id: 13,
  #       trait_value_id: 2956,
  #       display_order: 1,
  #       text: "Bourbon"
  #     },
  #     %{
  #       id: 2700,
  #       question_id: 13,
  #       trait_value_id: 2957,
  #       display_order: 2,
  #       text: "Scotch"
  #     },
  #     %{
  #       id: 2701,
  #       question_id: 13,
  #       trait_value_id: 2958,
  #       display_order: 3,
  #       text: "Whiskey (Other)"
  #     },
  #     %{
  #       id: 2702,
  #       question_id: 13,
  #       trait_value_id: 2959,
  #       display_order: 4,
  #       text: "Vodka"
  #     },
  #     %{
  #       id: 2703,
  #       question_id: 13,
  #       trait_value_id: 2960,
  #       display_order: 5,
  #       text: "Gin"
  #     },
  #     %{
  #       id: 2704,
  #       question_id: 13,
  #       trait_value_id: 2961,
  #       display_order: 6,
  #       text: "Rum"
  #     },
  #     %{
  #       id: 2705,
  #       question_id: 13,
  #       trait_value_id: 2962,
  #       display_order: 7,
  #       text: "Tequila"
  #     },
  #     %{
  #       id: 2706,
  #       question_id: 13,
  #       trait_value_id: 2963,
  #       display_order: 8,
  #       text: "Brandy"
  #     },
  #     %{
  #       id: 2707,
  #       question_id: 13,
  #       trait_value_id: 2964,
  #       display_order: 9,
  #       text: "Cognac"
  #     },
  #     %{
  #       id: 2708,
  #       question_id: 13,
  #       trait_value_id: 2965,
  #       display_order: 10,
  #       text: "Liqueur"
  #     },
  #     %{
  #       id: 2709,
  #       question_id: 13,
  #       trait_value_id: 2966,
  #       display_order: 11,
  #       text: "Schnapps"
  #     },
  #     %{
  #       id: 2710,
  #       question_id: 13,
  #       trait_value_id: 2967,
  #       display_order: 12,
  #       text: "Absinthe"
  #     },
  #     %{
  #       id: 2711,
  #       question_id: 13,
  #       trait_value_id: 2968,
  #       display_order: 13,
  #       text: "None / None listed"
  #     },
  #     %{
  #       id: 2712,
  #       question_id: 13,
  #       trait_value_id: 2969,
  #       display_order: 14,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2713,
  #       question_id: 13,
  #       trait_value_id: 2971,
  #       display_order: 1,
  #       text: "Frozen / Blended"
  #     },
  #     %{
  #       id: 2714,
  #       question_id: 13,
  #       trait_value_id: 2972,
  #       display_order: 2,
  #       text: "On the Rocks"
  #     },
  #     %{
  #       id: 2715,
  #       question_id: 13,
  #       trait_value_id: 2973,
  #       display_order: 3,
  #       text: "Chilled / Up"
  #     },
  #     %{
  #       id: 2716,
  #       question_id: 13,
  #       trait_value_id: 2974,
  #       display_order: 4,
  #       text: "Neat / Straight up"
  #     },
  #     %{
  #       id: 2717,
  #       question_id: 13,
  #       trait_value_id: 2975,
  #       display_order: 5,
  #       text: "Hot / Warm"
  #     },
  #     %{
  #       id: 2718,
  #       question_id: 13,
  #       trait_value_id: 2976,
  #       display_order: 6,
  #       text: "Dirty"
  #     },
  #     %{
  #       id: 2719,
  #       question_id: 13,
  #       trait_value_id: 2977,
  #       display_order: 7,
  #       text: "Dry"
  #     },
  #     %{
  #       id: 2720,
  #       question_id: 13,
  #       trait_value_id: 2978,
  #       display_order: 8,
  #       text: "Sweet"
  #     },
  #     %{
  #       id: 2721,
  #       question_id: 13,
  #       trait_value_id: 2979,
  #       display_order: 9,
  #       text: "House / Well"
  #     },
  #     %{
  #       id: 2722,
  #       question_id: 13,
  #       trait_value_id: 2980,
  #       display_order: 10,
  #       text: "Top Shelf / Premium"
  #     },
  #     %{
  #       id: 2723,
  #       question_id: 13,
  #       trait_value_id: 2981,
  #       display_order: 11,
  #       text: "With a Twist"
  #     },
  #     %{
  #       id: 2724,
  #       question_id: 13,
  #       trait_value_id: 2982,
  #       display_order: 12,
  #       text: "With Salt"
  #     },
  #     %{
  #       id: 2725,
  #       question_id: 13,
  #       trait_value_id: 2983,
  #       display_order: 13,
  #       text: "None / None listed"
  #     },
  #     %{
  #       id: 2726,
  #       question_id: 13,
  #       trait_value_id: 2984,
  #       display_order: 14,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2727,
  #       question_id: 14,
  #       trait_value_id: 2986,
  #       display_order: 1,
  #       text: "Cola"
  #     },
  #     %{
  #       id: 2728,
  #       question_id: 14,
  #       trait_value_id: 2987,
  #       display_order: 2,
  #       text: "Lemon-Lime Soda"
  #     },
  #     %{
  #       id: 2729,
  #       question_id: 14,
  #       trait_value_id: 2988,
  #       display_order: 3,
  #       text: "Club Soda/Tonic"
  #     },
  #     %{
  #       id: 2730,
  #       question_id: 14,
  #       trait_value_id: 2989,
  #       display_order: 4,
  #       text: "Energy Drink"
  #     },
  #     %{
  #       id: 2731,
  #       question_id: 14,
  #       trait_value_id: 2990,
  #       display_order: 5,
  #       text: "Mint"
  #     },
  #     %{
  #       id: 2732,
  #       question_id: 14,
  #       trait_value_id: 2991,
  #       display_order: 6,
  #       text: "Coffee"
  #     },
  #     %{
  #       id: 2733,
  #       question_id: 14,
  #       trait_value_id: 2992,
  #       display_order: 7,
  #       text: "Citrus Juice (Lime/Lemon/Orange)"
  #     },
  #     %{
  #       id: 2734,
  #       question_id: 14,
  #       trait_value_id: 2993,
  #       display_order: 8,
  #       text: "Tropical Juice (Pineapple/Mango)"
  #     },
  #     %{
  #       id: 2735,
  #       question_id: 14,
  #       trait_value_id: 2994,
  #       display_order: 9,
  #       text: "Cranberry Juice"
  #     },
  #     %{
  #       id: 2736,
  #       question_id: 14,
  #       trait_value_id: 2995,
  #       display_order: 10,
  #       text: "Grapefruit Juice"
  #     },
  #     %{
  #       id: 2737,
  #       question_id: 14,
  #       trait_value_id: 2996,
  #       display_order: 11,
  #       text: "Olive Juice"
  #     },
  #     %{
  #       id: 2738,
  #       question_id: 14,
  #       trait_value_id: 2997,
  #       display_order: 12,
  #       text: "Coconut Milk/Cream"
  #     },
  #     %{
  #       id: 2739,
  #       question_id: 14,
  #       trait_value_id: 2998,
  #       display_order: 13,
  #       text: "Beer"
  #     },
  #     %{
  #       id: 2740,
  #       question_id: 14,
  #       trait_value_id: 2999,
  #       display_order: 14,
  #       text: "Wine"
  #     },
  #     %{
  #       id: 2741,
  #       question_id: 14,
  #       trait_value_id: 3000,
  #       display_order: 15,
  #       text: "Vermouth"
  #     },
  #     %{
  #       id: 2742,
  #       question_id: 14,
  #       trait_value_id: 3001,
  #       display_order: 16,
  #       text: "Water"
  #     },
  #     %{
  #       id: 2743,
  #       question_id: 14,
  #       trait_value_id: 3002,
  #       display_order: 17,
  #       text: "Never mixed"
  #     },
  #     %{
  #       id: 2744,
  #       question_id: 14,
  #       trait_value_id: 3003,
  #       display_order: 18,
  #       text: "None / None listed"
  #     },
  #     %{
  #       id: 2745,
  #       question_id: 14,
  #       trait_value_id: 3004,
  #       display_order: 19,
  #       text: "Prefer not to say"
  #     },
  #     %{
  #       id: 2746,
  #       question_id: 35,
  #       trait_value_id: 3005,
  #       display_order: 2,
  #       text: "Cars/Working on Cars"
  #     }
  #   ]
  #   |> Enum.each(fn attrs ->
  #     attrs = Map.merge(attrs, %{inserted_at: now, updated_at: now})
  #     struct(SurveyAnswer, attrs) |> Repo.insert!()
  #   end)
  # end
end

Seeds.run()
