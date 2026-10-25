defmodule QlariusWeb.Live.TopicEditing do
  @moduledoc """
  Glue shared by the marketer and creator trait group pages for editing one
  topic of an existing group through `TraitGroupEditorComponent`.

  A page assigns the editor with `open_topic/4`, clears it with `close/1`, and
  passes `saver/3` as the component's `on_save`.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Qlarius.Sponster.Campaigns.AudienceBuilder
  alias QlariusWeb.Components.Targeting

  @editor_assigns [
    editor_parent_trait_id: nil,
    editor_group_id: nil,
    editor_preselected_ids: [],
    editor_title: nil,
    editor_description: nil,
    editor_heading: nil,
    editor_submit_label: "Create Trait Group",
    editor_zip_seed: nil,
    editor_on_save: nil,
    adding_topic_to: nil
  ]

  def close(socket), do: assign(socket, @editor_assigns)

  @doc """
  Opens the editor on `parent_trait_id` for `group`. Answers the group already
  holds under that topic start checked; a topic the group lacks opens empty and
  is added on save.
  """
  def open_topic(socket, group, parent_trait_id, copy) do
    held = Enum.filter(group.traits, &(&1.parent_trait_id == parent_trait_id))
    adding? = held == []

    socket
    |> close()
    |> assign(
      editor_parent_trait_id: parent_trait_id,
      editor_group_id: group.id,
      editor_preselected_ids: Enum.map(held, & &1.id),
      editor_title: group.title,
      editor_description: group.description,
      editor_heading: if(adding?, do: "Add topic to #{group.title}", else: "Edit #{group.title}"),
      editor_submit_label: "Save",
      editor_zip_seed: if(adding?, do: Targeting.zip_seed(group, parent_trait_id)),
      editor_on_save: saver(group, parent_trait_id, copy)
    )
  end

  @doc """
  Opens the editor to create a new group on `parent_trait_id`.
  """
  def open_new(socket, parent_trait_id) do
    socket
    |> close()
    |> assign(editor_parent_trait_id: parent_trait_id)
  end

  def saver(group, parent_trait_id, copy) do
    fn attrs ->
      case AudienceBuilder.set_topic(group, parent_trait_id, attrs.trait_ids,
             title: attrs.title,
             description: attrs.description
           ) do
        {:ok, group} -> {:ok, group}
        {:error, reason} -> {:error, Targeting.topic_error(reason, copy)}
      end
    end
  end

  @doc """
  Drops a topic from a group, returning a flash kind and message.
  """
  def remove_topic(group, parent_trait_id, copy) do
    case AudienceBuilder.remove_topic(group, parent_trait_id) do
      {:ok, _group} -> {:info, "Topic removed"}
      {:error, reason} -> {:error, Targeting.topic_error(reason, copy) |> to_message()}
    end
  end

  defp to_message(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join(", ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end

  defp to_message(message) when is_binary(message), do: message
end
