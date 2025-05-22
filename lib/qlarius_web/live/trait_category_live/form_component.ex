defmodule QlariusWeb.TraitCategoryLive.FormComponent do
  use QlariusWeb, :live_component

  alias Qlarius.YouData.Traits

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage trait category records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="trait_category-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:display_order]} type="number" label="Display order" />
        <.button phx-disable-with="Saving..." variant="primary">Save Trait Category</.button>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{trait_category: trait_category} = assigns, socket) do
    changeset = Traits.change_trait_category(trait_category)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"trait_category" => trait_category_params}, socket) do
    changeset =
      socket.assigns.trait_category
      |> Traits.change_trait_category(trait_category_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"trait_category" => trait_category_params}, socket) do
    save_trait_category(socket, socket.assigns.action, trait_category_params)
  end

  defp save_trait_category(socket, :edit, trait_category_params) do
    case Traits.update_trait_category(socket.assigns.trait_category, trait_category_params) do
      {:ok, _trait_category} ->
        # Notify parent to refresh the list
        send(self(), {:trait_category_updated})

        {:noreply,
         socket
         |> put_flash(:info, "Trait category updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_trait_category(socket, :new, trait_category_params) do
    case Traits.create_trait_category(trait_category_params) do
      {:ok, _trait_category} ->
        # Notify parent to refresh the list
        send(self(), {:trait_category_created})

        {:noreply,
         socket
         |> put_flash(:info, "Trait category created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
