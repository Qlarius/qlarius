defmodule Qlarius.YouData.TagTeaseAgent do
  @moduledoc """
  Agent for managing non-repeating tag tease messages.

  Provides a pool of randomized tag tease messages that are consumed sequentially.
  When the pool is empty, it automatically refills and reshuffles the messages.
  """

  @tag_tease_list [
    "Tags would look great here.",
    "Show me the tags!",
    "Tags wanted.",
    "Add your tags.",
    "Tag it up!",
    "Ready for some tags?",
    "This space is begging for tags.",
    "Tags, please!",
    "Make it yours with tags.",
    "Time to tag yourself.",
    "Express yourself here.",
    "What defines you?",
    "Fill in the blanks.",
    "Tell your story.",
    "Share who you are.",
    "Paint your picture.",
    "Complete the puzzle.",
    "Add your flavor.",
    "Make your mark.",
    "What's your vibe?",
    "Show your colors.",
    "Speak your truth.",
    "Own this space.",
    "Be authentically you."
  ]

  use Agent

  @doc """
  Starts the TagTeaseAgent.

  Initializes with a shuffled pool of tag tease messages.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> Enum.shuffle(@tag_tease_list) end, name: __MODULE__)
  end

  @doc """
  Gets the next tag tease message from the pool.

  Returns the head of the current pool. When the pool is empty,
  it automatically refills and reshuffles the messages.
  """
  def next_message do
    Agent.get_and_update(__MODULE__, fn
      [] ->
        # Refill and reshuffle when empty
        new_pool = Enum.shuffle(@tag_tease_list)
        [message | rest] = new_pool
        {message, rest}

      [message | rest] ->
        {message, rest}
    end)
  end

  @doc """
  Gets the current pool size for debugging purposes.
  """
  def pool_size do
    Agent.get(__MODULE__, &length/1)
  end

  @doc """
  Refills the pool with a fresh shuffled list.
  """
  def refill do
    Agent.update(__MODULE__, fn _ -> Enum.shuffle(@tag_tease_list) end)
  end
end
