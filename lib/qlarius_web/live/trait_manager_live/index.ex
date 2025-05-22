defmodule QlariusWeb.TraitManagerLive.Index do
  use QlariusWeb, :live_view

  alias Qlarius.YouData.Traits
  alias Qlarius.YouData.Traits.Trait
  alias Qlarius.YouData.Traits.TraitValue

  @impl true
  def mount(_params, _session, socket) do
    traits = Traits.list_traits()
    trait_categories = Traits.list_trait_categories()

    socket =
      socket
      |> assign(:traits, traits)
      |> assign(:trait_categories, trait_categories)
      |> assign(:selected_trait, nil)
      |> assign(:trait_values, [])
      |> assign(:new_trait_form, to_form(Traits.change_trait(%Trait{})))
      |> assign(:new_trait_value_form, to_form(Traits.change_trait_value(%TraitValue{})))
      |> assign(:trait_modal_open, false)
      |> assign(:editing_value_id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Trait Manager")
  end

  @impl true
  def handle_event("open_trait_modal", _, socket) do
    {:noreply, assign(socket, :trait_modal_open, true)}
  end

  @impl true
  def handle_event("close_trait_modal", _, socket) do
    {:noreply, assign(socket, :trait_modal_open, false)}
  end

  @impl true
  def handle_event("select_trait", %{"id" => id}, socket) do
    trait = Traits.get_trait_with_values!(id)

    {:noreply,
     socket
     |> assign(:selected_trait, trait)
     |> assign(:trait_values, trait.values)
     |> assign(:editing_value_id, nil)
     |> assign(
       :new_trait_value_form,
       to_form(Traits.change_trait_value(%TraitValue{trait: trait}))
     )}
  end

  @impl true
  def handle_event("save_trait", %{"trait" => trait_params}, socket) do
    case Traits.create_trait(trait_params) do
      {:ok, _trait} ->
        socket =
          socket
          |> assign(:traits, Traits.list_traits())
          |> assign(:trait_modal_open, false)
          |> assign(:new_trait_form, to_form(Traits.change_trait(%Trait{})))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :new_trait_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("save_trait_value", %{"trait_value" => value_params}, socket) do
    if socket.assigns.editing_value_id do
      # Update existing value
      value = Traits.get_trait_value!(socket.assigns.editing_value_id)

      case Traits.update_trait_value(value, value_params) do
        {:ok, _value} ->
          trait = Traits.get_trait_with_values!(socket.assigns.selected_trait.id)

          {:noreply,
           socket
           |> assign(:selected_trait, trait)
           |> assign(:trait_values, trait.values)
           |> assign(:editing_value_id, nil)
           |> assign(
             :new_trait_value_form,
             to_form(Traits.change_trait_value(%TraitValue{trait: trait}))
           )}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :new_trait_value_form, to_form(changeset))}
      end
    else
      # Create new value
      case Traits.create_trait_value(value_params) do
        {:ok, _value} ->
          trait = Traits.get_trait_with_values!(socket.assigns.selected_trait.id)

          {:noreply,
           socket
           |> assign(:selected_trait, trait)
           |> assign(:trait_values, trait.values)
           |> assign(
             :new_trait_value_form,
             to_form(Traits.change_trait_value(%TraitValue{trait: trait}))
           )}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :new_trait_value_form, to_form(changeset))}
      end
    end
  end

  @impl true
  def handle_event("validate_trait", %{"trait" => trait_params}, socket) do
    changeset =
      %Trait{}
      |> Traits.change_trait(trait_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :new_trait_form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate_trait_value", %{"trait_value" => value_params}, socket) do
    changeset =
      %TraitValue{}
      |> Traits.change_trait_value(value_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :new_trait_value_form, to_form(changeset))}
  end

  @impl true
  def handle_event("edit_value", %{"id" => id}, socket) do
    value = Enum.find(socket.assigns.trait_values, &(&1.id == String.to_integer(id)))

    {:noreply,
     socket
     |> assign(:editing_value_id, value.id)
     |> assign(:new_trait_value_form, to_form(Traits.change_trait_value(value)))}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_value_id, nil)
     |> assign(
       :new_trait_value_form,
       to_form(Traits.change_trait_value(%TraitValue{trait: socket.assigns.selected_trait}))
     )}
  end

  @impl true
  def handle_event("add_mode", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_value_id, nil)
     |> assign(
       :new_trait_value_form,
       to_form(Traits.change_trait_value(%TraitValue{trait: socket.assigns.selected_trait}))
     )}
  end
end
