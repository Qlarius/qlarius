defmodule QlariusWeb.RegistrationLive do
  use QlariusWeb, :live_view

  alias Qlarius.Accounts
  alias Qlarius.YouData.{MeFiles, Traits}
  alias QlariusWeb.Live.Helpers.ZipCodeLookup

  def mount(params, _session, socket) do
    mode = Map.get(params, "mode", "regular")
    proxy_user_id = Map.get(params, "proxy_user_id")

    mobile = Phoenix.Flash.get(socket.assigns.flash, :registration_mobile)
    alias_value = Phoenix.Flash.get(socket.assigns.flash, :registration_alias)
    username = Phoenix.Flash.get(socket.assigns.flash, :registration_username)

    socket =
      socket
      |> assign(:page_title, "Register")
      |> assign(:mode, mode)
      |> assign(:proxy_user_id, proxy_user_id)
      |> assign(:current_step, determine_starting_step(mode, mobile, alias_value))
      |> assign(:mobile_number, mobile || "")
      |> assign(:alias, alias_value || "")
      |> assign(:username, username || "")
      |> assign(:alias_error, nil)
      |> assign(:sex_trait_id, nil)
      |> assign(:sex_options, load_sex_options())
      |> assign(:birthdate_year, "")
      |> assign(:birthdate_month, "")
      |> assign(:birthdate_day, "")
      |> assign(:birthdate_valid, false)
      |> assign(:birthdate_error, nil)
      |> assign(:calculated_age, nil)
      |> assign(:age_trait_id, nil)
      |> assign(:confirmation_checked, false)
      |> ZipCodeLookup.initialize_zip_lookup_assigns()
      |> assign(:trait_in_edit, %{id: 4})

    {:ok, socket}
  end

  defp determine_starting_step("proxy", mobile, alias_value)
       when not is_nil(mobile) and not is_nil(alias_value),
       do: 3

  defp determine_starting_step(_mode, _mobile, _alias_value), do: 1

  defp load_sex_options do
    case Traits.get_trait_with_full_survey_data!(1) do
      {:ok, trait} ->
        trait.child_traits
        |> Enum.map(fn child ->
          %{id: child.id, name: child.trait_name}
        end)

      {:error, _} ->
        []
    end
  end

  def handle_event("next_step", _params, socket) do
    case socket.assigns.current_step do
      1 ->
        {:noreply, assign(socket, :current_step, 2)}

      2 ->
        {:noreply, assign(socket, :current_step, 3)}

      3 ->
        {:noreply, assign(socket, :current_step, 4)}

      4 ->
        {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do
    case socket.assigns.current_step do
      1 ->
        {:noreply, socket}

      step ->
        {:noreply, assign(socket, :current_step, step - 1)}
    end
  end

  def handle_event("update_mobile", %{"value" => mobile}, socket) do
    {:noreply, assign(socket, :mobile_number, mobile)}
  end

  def handle_event("validate_alias", %{"alias" => alias_value}, socket) do
    require Logger
    Logger.debug("validate_alias called with value: #{alias_value}")

    alias_value = String.trim(alias_value)

    socket =
      cond do
        alias_value == "" ->
          socket
          |> assign(:alias, alias_value)
          |> assign(:alias_error, nil)

        String.length(alias_value) < 10 ->
          socket
          |> assign(:alias, alias_value)
          |> assign(:alias_error, "Alias must be at least 10 characters")

        true ->
          available = Accounts.alias_available?(alias_value)

          if available do
            socket
            |> assign(:alias, alias_value)
            |> assign(:alias_error, nil)
          else
            socket
            |> assign(:alias, alias_value)
            |> assign(:alias_error, "This alias is already taken")
          end
      end

    {:noreply, socket}
  end

  def handle_event("select_sex", %{"sex_id" => sex_id}, socket) do
    {:noreply, assign(socket, :sex_trait_id, String.to_integer(sex_id))}
  end

  def handle_event("update_birthdate", params, socket) do
    year = Map.get(params, "year", socket.assigns.birthdate_year)
    month = Map.get(params, "month", socket.assigns.birthdate_month)
    day = Map.get(params, "day", socket.assigns.birthdate_day)

    socket =
      socket
      |> assign(:birthdate_year, year)
      |> assign(:birthdate_month, month)
      |> assign(:birthdate_day, day)
      |> validate_birthdate()

    {:noreply, socket}
  end

  def handle_event("lookup_zip_code", %{"zip" => zip_code}, socket) do
    socket = ZipCodeLookup.handle_zip_lookup(socket, zip_code)
    {:noreply, socket}
  end

  def handle_event("toggle_confirmation", %{"checked" => checked}, socket) do
    {:noreply, assign(socket, :confirmation_checked, checked == "true")}
  end

  def handle_event("complete_registration", _params, socket) do
    if can_complete?(socket.assigns) do
      case create_user(socket) do
        {:ok, result} ->
          socket =
            if socket.assigns.mode == "proxy" do
              case socket.assigns do
                %{current_scope: %{true_user: %{id: true_user_id}}} ->
                  Accounts.activate_proxy_user(true_user_id, result.user.id)
                  socket

                _ ->
                  socket
              end
            else
              socket
            end

          redirect_path =
            if socket.assigns.mode == "proxy" do
              ~p"/proxy_users"
            else
              ~p"/"
            end

          {:noreply,
           socket
           |> put_flash(:info, "Registration complete!")
           |> push_navigate(to: redirect_path)}

        {:error, _failed_operation, _failed_value, _changes_so_far} ->
          {:noreply,
           socket
           |> put_flash(:error, "Registration failed. Please try again.")
           |> assign(:current_step, 1)}
      end
    else
      {:noreply, put_flash(socket, :error, "Please complete all required fields")}
    end
  end

  defp validate_birthdate(socket) do
    year = socket.assigns.birthdate_year
    month = socket.assigns.birthdate_month
    day = socket.assigns.birthdate_day

    with true <- String.length(year) == 4,
         {year_int, ""} <- Integer.parse(year),
         true <- String.length(month) >= 1 and String.length(month) <= 2,
         {month_int, ""} <- Integer.parse(month),
         true <- month_int >= 1 and month_int <= 12,
         true <- String.length(day) >= 1 and String.length(day) <= 2,
         {day_int, ""} <- Integer.parse(day),
         true <- day_int >= 1 and day_int <= 31,
         {:ok, date} <- Date.new(year_int, month_int, day_int) do
      age = MeFiles.calculate_age(date)

      if age && age >= 18 do
        age_trait = MeFiles.get_age_trait_for_age(age)

        socket
        |> assign(:birthdate_valid, true)
        |> assign(:birthdate_error, nil)
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, if(age_trait, do: age_trait.id, else: nil))
      else
        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, "Must be 18 or older")
        |> assign(:calculated_age, age)
        |> assign(:age_trait_id, nil)
      end
    else
      _ ->
        socket
        |> assign(:birthdate_valid, false)
        |> assign(:birthdate_error, nil)
        |> assign(:calculated_age, nil)
        |> assign(:age_trait_id, nil)
    end
  end

  defp can_complete?(assigns) do
    assigns.alias != "" &&
      assigns.alias_error == nil &&
      assigns.sex_trait_id != nil &&
      assigns.birthdate_valid &&
      assigns.age_trait_id != nil &&
      assigns.confirmation_checked
  end

  defp create_user(socket) do
    date =
      Date.new!(
        String.to_integer(socket.assigns.birthdate_year),
        String.to_integer(socket.assigns.birthdate_month),
        String.to_integer(socket.assigns.birthdate_day)
      )

    attrs = %{
      alias: socket.assigns.alias,
      username: socket.assigns.username,
      mobile_number:
        if(socket.assigns.mobile_number != "", do: socket.assigns.mobile_number, else: nil),
      auth_provider_id:
        if(socket.assigns.mobile_number != "", do: socket.assigns.mobile_number, else: nil),
      role: "user",
      date_of_birth: date,
      sex_trait_id: socket.assigns.sex_trait_id,
      age_trait_id: socket.assigns.age_trait_id,
      zip_code_trait_id:
        if(socket.assigns.zip_lookup_valid, do: socket.assigns.zip_lookup_trait.id, else: nil)
    }

    attrs =
      case socket.assigns do
        %{current_scope: %{true_user: %{id: true_user_id}}} when socket.assigns.mode == "proxy" ->
          Map.put(attrs, :true_user_id, true_user_id)

        _ ->
          attrs
      end

    Accounts.register_new_user(attrs)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col pb-24">
      <div class="flex-1 px-4 py-6 max-w-2xl mx-auto w-full">
        <h1 class="text-4xl md:text-5xl font-bold mb-8 dark:text-white">
          {if @mode == "proxy", do: "Create Proxy User", else: "Register"}
        </h1>

        <ul class="steps w-full mb-8 text-xs md:text-sm">
          <li class={"step #{if @current_step >= 1, do: "step-primary"}"}>Mobile</li>
          <li class={"step #{if @current_step >= 2, do: "step-primary"}"}>Alias</li>
          <li class={"step #{if @current_step >= 3, do: "step-primary"}"}>Data</li>
          <li class={"step #{if @current_step >= 4, do: "step-primary"}"}>Confirm</li>
        </ul>

        <%= if @current_step == 1 do %>
          <.step_one mobile_number={@mobile_number} mode={@mode} />
        <% end %>

        <%= if @current_step == 2 do %>
          <.step_two alias={@alias} alias_error={@alias_error} />
        <% end %>

        <%= if @current_step == 3 do %>
          <.step_three
            sex_trait_id={@sex_trait_id}
            sex_options={@sex_options}
            birthdate_year={@birthdate_year}
            birthdate_month={@birthdate_month}
            birthdate_day={@birthdate_day}
            birthdate_valid={@birthdate_valid}
            birthdate_error={@birthdate_error}
            calculated_age={@calculated_age}
            zip_lookup_input={@zip_lookup_input}
            zip_lookup_valid={@zip_lookup_valid}
            zip_lookup_error={@zip_lookup_error}
            zip_lookup_trait={@zip_lookup_trait}
          />
        <% end %>

        <%= if @current_step == 4 do %>
          <.step_four
            mobile_number={@mobile_number}
            alias={@alias}
            username={@username}
            sex_trait_id={@sex_trait_id}
            sex_options={@sex_options}
            calculated_age={@calculated_age}
            zip_lookup_trait={@zip_lookup_trait}
            confirmation_checked={@confirmation_checked}
            can_complete={can_complete?(assigns)}
          />
        <% end %>
      </div>

      <div class="fixed bottom-0 left-0 right-0 bg-base-100 dark:bg-base-300 border-t border-base-300 dark:border-base-content/20 p-4 safe-area-inset-bottom">
        <div class="max-w-2xl mx-auto flex gap-3">
          <%= if @current_step > 1 do %>
            <button
              phx-click="prev_step"
              class="btn btn-outline btn-lg flex-1 rounded-full text-lg normal-case"
            >
              ← Previous
            </button>
          <% end %>

          <%= if @current_step < 4 do %>
            <%= if can_proceed_to_next_step?(assigns) do %>
              <button
                phx-click="next_step"
                class="btn btn-primary btn-lg flex-1 rounded-full text-lg normal-case"
              >
                Next →
              </button>
            <% else %>
              <button class="btn btn-disabled btn-lg flex-1 rounded-full text-lg normal-case" disabled>
                Next →
              </button>
            <% end %>
          <% else %>
            <%= if can_complete?(assigns) do %>
              <button
                phx-click="complete_registration"
                class="btn btn-success btn-lg flex-1 rounded-full text-lg normal-case"
              >
                Complete Registration
              </button>
            <% else %>
              <button class="btn btn-disabled btn-lg flex-1 rounded-full text-lg normal-case" disabled>
                Complete Registration
              </button>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp can_proceed_to_next_step?(assigns) do
    case assigns.current_step do
      1 ->
        true

      2 ->
        assigns.alias != "" && String.length(assigns.alias) >= 10 && assigns.alias_error == nil

      3 ->
        has_required =
          assigns.sex_trait_id != nil && assigns.birthdate_valid && assigns.age_trait_id != nil

        zip_ok =
          if assigns.zip_lookup_input != "" do
            assigns.zip_lookup_valid
          else
            true
          end

        has_required && zip_ok

      4 ->
        false
    end
  end

  defp step_one(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Mobile Number</h2>
        <p class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
          <%= if @mode == "proxy" do %>
            Optional: Enter a mobile number for this proxy user
          <% else %>
            This is a placeholder step. Authentication will be added later.
          <% end %>
        </p>
      </div>

      <div class="form-control w-full">
        <label class="label">
          <span class="label-text text-lg dark:text-gray-300">
            Mobile Number {if @mode == "proxy", do: "(optional)"}
          </span>
        </label>
        <input
          id="mobile-input"
          type="tel"
          placeholder="(555) 123-4567"
          class="input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white"
          value={@mobile_number}
          phx-change="update_mobile"
        />
      </div>
    </div>
    """
  end

  defp step_two(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Choose Your Alias</h2>
        <p class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
          We don't need or want your real name. Your alias will act as your username and display name.
        </p>
      </div>

      <.form for={%{}} phx-change="validate_alias" phx-debounce="300">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Alias (minimum 10 characters)</span>
          </label>
          <input
            id="alias-input"
            name="alias"
            type="text"
            placeholder="Enter your alias (10+ characters)"
            minlength="10"
            class={"input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white #{if @alias_error, do: "input-error"}"}
            value={@alias}
          />
          <%= if @alias_error do %>
            <label class="label">
              <span class="label-text-alt text-error text-base">{@alias_error}</span>
            </label>
          <% end %>
          <%= if @alias != "" && String.length(@alias) >= 10 && is_nil(@alias_error) do %>
            <label class="label">
              <span class="label-text-alt text-success flex items-center gap-1 text-base">
                <.icon name="hero-check-circle" class="w-5 h-5" /> Alias is available
              </span>
            </label>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  defp step_three(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-3 dark:text-white">Core MeFile Data</h2>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-base">
            <strong>Important:</strong>
            Birthdate and Sex cannot be changed later. Please ensure accuracy.
          </span>
        </div>
      </div>

      <.form for={%{}} phx-change="select_sex">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Sex (Biological) *</span>
          </label>
          <select
            name="sex_id"
            class="select select-bordered select-lg w-full text-lg dark:bg-base-100 dark:text-white"
          >
            <option value="" selected={is_nil(@sex_trait_id)}>Select...</option>
            <%= for option <- @sex_options do %>
              <option value={option.id} selected={@sex_trait_id == option.id}>{option.name}</option>
            <% end %>
          </select>
        </div>
      </.form>

      <.form for={%{}} phx-change="update_birthdate">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">Birthdate *</span>
          </label>
          <div class="flex gap-2">
            <input
              id="birthdate-year"
              name="year"
              type="text"
              placeholder="YYYY"
              maxlength="4"
              class={"input input-bordered input-lg flex-1 text-lg dark:bg-base-100 dark:text-white #{if @birthdate_error, do: "input-error"}"}
              value={@birthdate_year}
            />
            <input
              id="birthdate-month"
              name="month"
              type="text"
              placeholder="MM"
              maxlength="2"
              class={"input input-bordered input-lg w-24 text-lg dark:bg-base-100 dark:text-white #{if @birthdate_error, do: "input-error"}"}
              value={@birthdate_month}
            />
            <input
              id="birthdate-day"
              name="day"
              type="text"
              placeholder="DD"
              maxlength="2"
              class={"input input-bordered input-lg w-24 text-lg dark:bg-base-100 dark:text-white #{if @birthdate_error, do: "input-error"}"}
              value={@birthdate_day}
            />
          </div>
          <%= if @birthdate_error do %>
            <label class="label">
              <span class="label-text-alt text-error text-base">{@birthdate_error}</span>
            </label>
          <% end %>
          <%= if @birthdate_valid and @calculated_age do %>
            <div class="mt-3">
              <div class="badge badge-primary badge-lg p-4 text-base">
                <.icon name="hero-calendar" class="w-5 h-5 mr-2" /> Age: {@calculated_age}
              </div>
            </div>
          <% end %>
        </div>
      </.form>

      <.form for={%{}} phx-change="lookup_zip_code" phx-debounce="500">
        <div class="form-control w-full">
          <label class="label">
            <span class="label-text text-lg dark:text-gray-300">
              Home Zip Code (optional, but encouraged)
            </span>
          </label>
          <input
            id="zip-code-input"
            name="zip"
            type="text"
            placeholder="Enter 5-digit zip code"
            maxlength="5"
            class={"input input-bordered input-lg w-full text-lg dark:bg-base-100 dark:text-white #{if @zip_lookup_error, do: "input-error"}"}
            value={@zip_lookup_input}
          />
          <%= if @zip_lookup_error do %>
            <label class="label">
              <span class="label-text-alt text-error text-base">{@zip_lookup_error}</span>
            </label>
          <% end %>
          <%= if @zip_lookup_valid and @zip_lookup_trait do %>
            <div class="mt-3">
              <div class="badge badge-primary badge-lg p-4 text-base">
                <.icon name="hero-map-pin" class="w-5 h-5 mr-2" />
                {@zip_lookup_trait.meta_1}
              </div>
            </div>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  defp step_four(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h2 class="text-2xl md:text-3xl font-bold mb-6 dark:text-white">Confirm Your Information</h2>
      </div>

      <div class="space-y-4">
        <%= if @mobile_number != "" do %>
          <div class="flex justify-between items-center py-3 border-b border-base-300 dark:border-base-content/20">
            <span class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
              Mobile Number:
            </span>
            <span class="text-base md:text-lg font-medium dark:text-white">{@mobile_number}</span>
          </div>
        <% end %>

        <div class="flex justify-between items-center py-3 border-b border-base-300 dark:border-base-content/20">
          <span class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
            Alias:
          </span>
          <span class="text-base md:text-lg font-medium dark:text-white">{@alias}</span>
        </div>

        <%= if @username != "" do %>
          <div class="flex justify-between items-center py-3 border-b border-base-300 dark:border-base-content/20">
            <span class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
              Username (admin only):
            </span>
            <span class="text-base md:text-lg font-medium dark:text-white">{@username}</span>
          </div>
        <% end %>

        <div class="flex justify-between items-center py-3 border-b border-base-300 dark:border-base-content/20">
          <span class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
            Sex:
          </span>
          <span class="text-base md:text-lg font-medium dark:text-white">
            {Enum.find(@sex_options, fn opt -> opt.id == @sex_trait_id end).name}
          </span>
        </div>

        <div class="flex justify-between items-center py-3 border-b border-base-300 dark:border-base-content/20">
          <span class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
            Age:
          </span>
          <span class="text-base md:text-lg font-medium dark:text-white">{@calculated_age}</span>
        </div>

        <%= if @zip_lookup_trait do %>
          <div class="flex justify-between items-center py-3 border-b border-base-300 dark:border-base-content/20">
            <span class="text-base md:text-lg text-base-content/70 dark:text-base-content/60">
              Home Zip Code:
            </span>
            <span class="text-base md:text-lg font-medium dark:text-white">
              {@zip_lookup_trait.trait_name} - {@zip_lookup_trait.meta_1}
            </span>
          </div>
        <% end %>
      </div>

      <div class="form-control mt-8">
        <label class="cursor-pointer flex items-start gap-3 p-4 bg-base-200 dark:bg-base-200 rounded-lg">
          <input
            type="checkbox"
            class="checkbox checkbox-primary checkbox-lg flex-shrink-0 mt-1"
            checked={@confirmation_checked}
            phx-click="toggle_confirmation"
            phx-value-checked={to_string(!@confirmation_checked)}
          />
          <span class="text-base md:text-lg dark:text-gray-300">
            I confirm my birthdate and sex are correct and understand they cannot be changed.
          </span>
        </label>
      </div>

      <%= if not @can_complete do %>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
          <span class="text-base">Please check the confirmation box to complete registration.</span>
        </div>
      <% end %>
    </div>
    """
  end
end
