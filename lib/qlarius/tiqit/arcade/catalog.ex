defmodule Qlarius.Tiqit.Arcade.Catalog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Qlarius.Creators.Creator
  alias Qlarius.Tiqit.Arcade.ContentGroup
  alias Qlarius.Tiqit.Arcade.TiqitClass

  @types ~w[site catalog studio collection show curriculum semester]a
  @group_types ~w[section show season series album book class]a
  @piece_types ~w[article episode chapter song piece lesson segment]a

  schema "catalogs" do
    belongs_to :creator, Creator
    has_many :content_groups, ContentGroup

    field :name, :string
    field :url, :string
    field :type, Ecto.Enum, values: @types
    field :group_type, Ecto.Enum, values: @group_types
    field :piece_type, Ecto.Enum, values: @piece_types
    field :image, :string
    field :tiqit_undo_limit, :integer
    field :tiqit_up_enabled, :boolean, default: true

    has_many :tiqit_classes, TiqitClass,
      on_replace: :delete,
      preload_order: [asc: :duration_hours, asc: :id]

    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def group_types, do: @group_types
  def piece_types, do: @piece_types

  # Explicit {singular, plural} for every enum value (piece_type, group_type, type).
  # When a new enum value is added above, add its entry here — English pluralization
  # is too irregular for safe rule-based derivation ("Series" stays "Series",
  # "Class" becomes "Classes", etc.).
  @type_labels %{
    # piece_types
    article: {"Article", "Articles"},
    episode: {"Episode", "Episodes"},
    chapter: {"Chapter", "Chapters"},
    song: {"Song", "Songs"},
    piece: {"Piece", "Pieces"},
    lesson: {"Lesson", "Lessons"},
    segment: {"Segment", "Segments"},
    # group_types
    section: {"Section", "Sections"},
    show: {"Show", "Shows"},
    season: {"Season", "Seasons"},
    series: {"Series", "Series"},
    album: {"Album", "Albums"},
    book: {"Book", "Books"},
    class: {"Class", "Classes"},
    # catalog types
    site: {"Site", "Sites"},
    catalog: {"Catalog", "Catalogs"},
    studio: {"Studio", "Studios"},
    collection: {"Collection", "Collections"},
    curriculum: {"Curriculum", "Curriculums"},
    semester: {"Semester", "Semesters"}
  }

  # Indefinite article for lowercase singular labels in prose ("a lesson", "an episode").
  @type_indefinite_articles %{
    article: "an",
    episode: "an",
    album: "an"
  }

  @doc """
  Returns `"a"` or `"an"` for a catalog content-type atom's singular label.
  """
  @spec indefinite_article(atom() | String.t()) :: String.t()
  def indefinite_article(type) when is_binary(type) do
    type |> String.to_existing_atom() |> indefinite_article()
  rescue
    ArgumentError -> "a"
  end

  def indefinite_article(type) when is_atom(type) do
    Map.get(@type_indefinite_articles, type, "a")
  end

  @doc """
  Singular type label prefixed with the correct indefinite article.

  ## Examples

      iex> Qlarius.Tiqit.Arcade.Catalog.type_with_article(:lesson)
      "a lesson"

      iex> Qlarius.Tiqit.Arcade.Catalog.type_with_article(:episode)
      "an episode"
  """
  @spec type_with_article(atom() | String.t(), keyword()) :: String.t()
  def type_with_article(type, opts \\ []) do
    article = indefinite_article(type)
    label = type_label(type, 1, Keyword.put_new(opts, :capitalize, false))
    "#{article} #{label}"
  end

  @doc """
  Human-readable singular or plural label for a catalog content-type atom.

  Options:
    * `:capitalize` — when `false`, returns lowercase (e.g. `"class"`, `"classes"`)
      for inline counts like `"3 classes"`. Defaults to `true`.
  """
  @spec type_label(atom() | String.t(), non_neg_integer(), keyword()) :: String.t()
  def type_label(type, count \\ 1, opts \\ [])

  def type_label(type, count, opts) when is_binary(type) do
    type_label(String.to_existing_atom(type), count, opts)
  rescue
    ArgumentError -> type_label_fallback(type, count, opts)
  end

  def type_label(type, count, opts) when is_atom(type) do
    capitalize = Keyword.get(opts, :capitalize, true)

    word =
      case Map.get(@type_labels, type) do
        {singular, _plural} when count == 1 -> singular
        {_singular, plural} -> plural
        nil -> type_label_fallback(to_string(type), count, capitalize: capitalize)
      end

    if capitalize, do: word, else: String.downcase(word)
  end

  defp type_label_fallback(type, count, opts) do
    capitalize = Keyword.get(opts, :capitalize, true)
    base = if capitalize, do: String.capitalize(type), else: type
    if count == 1, do: base, else: base <> "s"
  end

  @doc false
  def changeset(catalog, attrs) do
    catalog
    |> cast(attrs, [
      :name,
      :url,
      :type,
      :group_type,
      :piece_type,
      :tiqit_undo_limit,
      :tiqit_up_enabled
    ])
    |> validate_required([:name, :url, :type, :group_type, :piece_type])
    |> validate_number(:tiqit_undo_limit, greater_than_or_equal_to: 3)
    |> validate_length(:name, max: 30)
    |> cast_assoc(
      :tiqit_classes,
      drop_param: :tiqit_class_drop,
      sort_param: :tiqit_class_sort,
      with: &TiqitClass.changeset/2
    )
  end

  @doc false
  def changeset_with_image(catalog, attrs) do
    catalog
    |> changeset(attrs)
    |> put_change(:image, attrs["image"])
  end
end
