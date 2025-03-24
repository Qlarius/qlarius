defmodule QlariusWeb.TraitGroupLive.Index do
  use QlariusWeb, :live_view

  alias Qlarius.Traits
  alias Qlarius.Campaigns.TraitGroup

  @impl true
  def mount(_params, _session, socket) do
    trait_groups = Traits.list_trait_groups()
    categories_with_traits = Traits.list_categories_with_traits()

    socket
    |> assign(
      categories_with_traits: categories_with_traits,
      trait_groups: trait_groups
    )
    |> ok()
  end

  @impl true
  def handle_event("show-trait-group-form-modal", %{"parent_id" => parent_id}, socket) do
    parent = Traits.get_parent_trait!(parent_id)
    children = Traits.list_child_traits(parent.id)

    form =
      %TraitGroup{}
      |> Traits.change_trait_group()
      |> to_form()

    socket
    |> assign(children: children, parent: parent, trait_group_form: form)
    |> noreply()
  end

  def handle_event("reset-trait-group-form", _params, socket) do
    socket |> assign(trait_group_form: nil) |> noreply()
  end

  @impl true
  def handle_event("submit-trait-group-form", %{"trait_group" => _trait_group_params}, _socket) do
  end

  @impl true
  def handle_event("validate-trait-group-form", %{"trait_group" => _trait_group_params}, _socket) do
  end

  def trait_checkbox(assigns) do
    ~H"""
    <div>
      <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
        <input
          type="checkbox"
          id={"trait_group_traits_to_add_#{@trait.id}"}
          name="trait_group[traits_to_add][]"
          value="true"
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
        />
        {@trait.name}
      </label>
    </div>
    """
  end
end
