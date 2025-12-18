require Logger
alias Qlarius.Repo
alias Qlarius.Accounts.AliasWord

Logger.info("=== Starting alias words seeding ===")

# Mix of themes: nature, space, tech, colors, emotions, etc.
adjectives = ~w(
  adorable adventurous agile alert amber ancient aqua arctic atomic azure
  balanced beautiful blazing blissful bold brave breezy bright brilliant bronze
  calm candid celestial charming cheerful classic clever coastal confident cool cosmic crimson crystal curious cyan
  dainty dapper daring dashing dazzling delicate delightful determined diamond digital divine dreamy dynamic
  eager earnest elegant emerald enchanted energetic epic ethereal euphoric excellent exotic exquisite
  faithful fantastic fierce fiery fluid focused fortunate free fresh friendly frozen fusion
  galactic gentle genuine gleaming glorious golden graceful grand grateful green groovy
  happy harmonic heroic hopeful humble hybrid
  imaginative infinite inner inspired inventive iron ivory
  jolly joyful jubilant just
  keen kind kinetic
  legendary lemon lively logical loyal lucky lunar luminous lush
  magical majestic marble mellow melodic mighty mineral mint modern moonlit mystic
  natural neat nebular neon nimble noble northern
  obsidian oceanic olive onyx opal optimal orange orchid organic oriental
  pacific peaceful pearl phantom phoenix pixel platinum playful pleasant plucky poetic polished pristine proud purple
  quantum quartz quick quiet
  radiant rapid rebel refined regal reliable resilient resonant retro rising robust royal ruby rustic
  sage sapphire scarlet serene shadow shining sierra silver simple sincere smooth snowy solar sonic sophisticated southern sparkling spectral spirited spring square stable star steady stellar sterling strong sunny supreme swift
  teal tender thankful thermal tidal timeless titanium topaz tranquil tropical true turbo turquoise twilight
  ultra unique upbeat urban utmost
  valiant verdant vibrant violet virtual vivid
  warm warp western whimsical wild wind wise witty wonder
  yellow youthful
  zen zenith zesty zippy
)

nouns = ~w(
  abyss adventure aether alpine anchor apex aquifer arch archive atlas aurora axis
  badge basin bay beacon beam berry blossom bolt branch breeze bridge brook burst byte
  canyon capital cascade castle cavern cedar chasm citadel city cliff cloud comet compass cove crater creek crest crystal current cyber
  dawn delta desert diamond dock dome drift dune dust
  eagle echo edge ember empire equinox essence
  falls falcon field fjord flame flash flint flower flux forest forge fountain frost fusion
  galaxy garden gate gateway geyser glacier glade glen globe gorge grove guild gulf
  harbor haven hawk heath helix hill hollow home horizon hub
  iris island ivy
  jade jungle
  keep kingdom
  lagoon lake lance leaf legacy light lily loop lotus lunar
  matrix meadow mesa meteor mirror mist moon mount mountain myth
  nebula nest nexus north nova nucleus
  ocean oasis orbit orchid origin
  palace path peak pearl phoenix pixel plains planet plasma plateau portal prairie prism pulse pyramid
  quarry quartz quantum quest quill
  radiance rainbow range raven realm reef refuge reserve ridge rift ring ripple river road rock root rose ruby rush
  sage sanctuary sapphire savanna sea sentinel shadow shore signal silver sky solar sound south spark sphere spirit spring star station stellar stone storm stream summit sun sunset surge
  temple terra tide tiger tower trace trail tree trek tsunami twilight
  union unity universe
  vale valley vault vertex village vista void volcano vortex voyage
  water wave west wind wisp wolf wood
  zenith zone
)

# Filter to get exactly 500 of each (take the first 500)
adjectives = Enum.take(adjectives, 500)
nouns = Enum.take(nouns, 500)

Logger.info("Seeding #{length(adjectives)} adjectives and #{length(nouns)} nouns...")

# Insert adjectives with error handling
adj_count = 
  Enum.reduce(adjectives, 0, fn word, count ->
    try do
      %AliasWord{}
      |> AliasWord.changeset(%{word: word, type: "adjective", active: true})
      |> Repo.insert!(on_conflict: :nothing)
      count + 1
    rescue
      e ->
        Logger.warning("Failed to insert adjective '#{word}': #{inspect(e)}")
        count
    end
  end)

Logger.info("Inserted #{adj_count} adjectives")

# Insert nouns with error handling
noun_count = 
  Enum.reduce(nouns, 0, fn word, count ->
    try do
      %AliasWord{}
      |> AliasWord.changeset(%{word: word, type: "noun", active: true})
      |> Repo.insert!(on_conflict: :nothing)
      count + 1
    rescue
      e ->
        Logger.warning("Failed to insert noun '#{word}': #{inspect(e)}")
        count
    end
  end)

Logger.info("Inserted #{noun_count} nouns")

# Verify final count
{:ok, result} = Repo.query("SELECT COUNT(*) FROM alias_words")
total = result.rows |> List.first() |> List.first()

Logger.info("=== Alias words seeding complete! Total words in database: #{total} ===")
