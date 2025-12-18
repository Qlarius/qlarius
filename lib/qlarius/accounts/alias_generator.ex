defmodule Qlarius.Accounts.AliasGenerator do
  use GenServer
  require Logger

  import Ecto.Query
  alias Qlarius.Repo
  alias Qlarius.Accounts.{AliasWord, User}

  @table_name :alias_words_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    case load_words() do
      :ok ->
        {:ok, %{}}
      {:error, :table_not_found} ->
        Logger.warning("alias_words table not found - using fallback words until migrations are run")
        load_fallback_words()
        {:ok, %{}}
    end
  end

  def generate_base_names(count \\ 5) do
    adjectives = get_adjectives()
    nouns = get_nouns()

    if Enum.empty?(adjectives) || Enum.empty?(nouns) do
      Logger.warning("No alias words available - using fallback defaults")
      # Fallback to some default words if cache is empty
      fallback_adjectives = ~w(brave calm eager happy jolly kind noble proud quiet wise)
      fallback_nouns = ~w(mountain river ocean forest meadow valley lake shore harbor island)

      1..count
      |> Enum.map(fn _ ->
        adj = Enum.random(fallback_adjectives)
        noun = Enum.random(fallback_nouns)
        "#{adj}-#{noun}"
      end)
      |> Enum.uniq()
    else
      1..count
      |> Enum.map(fn _ ->
        adj = Enum.random(adjectives)
        noun = Enum.random(nouns)
        "#{adj}-#{noun}"
      end)
      |> Enum.uniq()
      |> then(fn list ->
        if length(list) < count do
          generate_base_names(count)
        else
          list
        end
      end)
    end
  end

  def generate_available_numbers(base_name, count \\ 5) do
    existing_aliases =
      Repo.all(
        from u in User,
        where: fragment("? LIKE ?", u.alias, ^"#{base_name}-%"),
        select: u.alias
      )

    existing_numbers =
      existing_aliases
      |> Enum.map(fn alias_str ->
        case String.split(alias_str, "-") |> List.last() do
          nil -> nil
          num_str when byte_size(num_str) == 4 ->
            case Integer.parse(num_str) do
              {num, ""} -> num
              _ -> nil
            end
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    available_pool = 0..9999
      |> Enum.reject(&MapSet.member?(existing_numbers, &1))

    if length(available_pool) < count do
      available_pool
      |> Enum.map(&format_number/1)
    else
      available_pool
      |> Enum.take_random(count)
      |> Enum.map(&format_number/1)
    end
  end

  def check_alias_available?(alias_str) do
    !Repo.exists?(from u in User, where: u.alias == ^alias_str)
  end

  defp format_number(num) when is_integer(num) do
    num |> Integer.to_string() |> String.pad_leading(4, "0")
  end

  def get_adjectives do
    try do
      case :ets.lookup(@table_name, :adjectives) do
        [{:adjectives, words}] -> words
        [] -> []
      end
    rescue
      ArgumentError ->
        Logger.warning("ETS table not yet initialized for adjectives")
        []
    end
  end

  def get_nouns do
    try do
      case :ets.lookup(@table_name, :nouns) do
        [{:nouns, words}] -> words
        [] -> []
      end
    rescue
      ArgumentError ->
        Logger.warning("ETS table not yet initialized for nouns")
        []
    end
  end

  def refresh_cache do
    GenServer.call(__MODULE__, :refresh)
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    case load_words() do
      :ok -> {:reply, :ok, state}
      {:error, :table_not_found} -> {:reply, {:error, :table_not_found}, state}
    end
  end

  defp load_words do
    try do
      adjectives = Repo.all(
        from w in AliasWord,
        where: w.type == "adjective" and w.active == true,
        select: w.word
      )

      nouns = Repo.all(
        from w in AliasWord,
        where: w.type == "noun" and w.active == true,
        select: w.word
      )

      :ets.insert(@table_name, {:adjectives, adjectives})
      :ets.insert(@table_name, {:nouns, nouns})

      Logger.info("Loaded #{length(adjectives)} adjectives and #{length(nouns)} nouns into cache")
      :ok
    rescue
      Postgrex.Error ->
        Logger.warning("Failed to load alias words from database - table may not exist yet")
        {:error, :table_not_found}
    end
  end

  defp load_fallback_words do
    # Hardcoded fallback words for when database table doesn't exist
    fallback_adjectives = ~w(
      agile ancient brave calm clever daring eager friendly gentle happy
      jolly kind lively merry noble peaceful proud quiet radiant swift
      tender brave vibrant wise witty young zealous bold charming delightful
      earnest festive graceful honest inventive jubilant keen legendary mighty
      nimble optimistic playful quick resilient smart trusty unique valiant wonderful
    )

    fallback_nouns = ~w(
      mountain river ocean forest meadow valley lake shore harbor island
      canyon glacier desert prairie ridge summit trail creek waterfall plateau
      grove orchard garden grove thicket woodland glade marsh oasis stream
      pond brook fjord inlet lagoon peninsula cliff bluff knoll mesa butte
      coral reef cascade rapids spring basin delta estuary wetland savanna
    )

    :ets.insert(@table_name, {:adjectives, fallback_adjectives})
    :ets.insert(@table_name, {:nouns, fallback_nouns})

    Logger.info("Loaded #{length(fallback_adjectives)} fallback adjectives and #{length(fallback_nouns)} fallback nouns")
  end
end
