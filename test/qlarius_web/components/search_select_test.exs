defmodule QlariusWeb.Components.SearchSelectTest do
  use QlariusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias QlariusWeb.Components.SearchSelect

  defmodule Host do
    use Phoenix.LiveView

    alias QlariusWeb.Components.SearchSelect

    def mount(_params, session, socket) do
      {:ok,
       assign(socket,
         options: session["options"],
         limit: session["limit"] || 50,
         picked: nil,
         submitted: nil,
         form: to_form(%{"choice" => session["value"]}, as: :thing)
       )}
    end

    def handle_info({SearchSelect, "picker", value}, socket) do
      {:noreply, assign(socket, picked: value)}
    end

    def handle_event("submit", params, socket) do
      {:noreply, assign(socket, submitted: params)}
    end

    def render(assigns) do
      ~H"""
      <.form for={@form} id="host-form" phx-submit="submit">
        <.live_component
          module={SearchSelect}
          id="picker"
          field={@form[:choice]}
          options={@options}
          limit={@limit}
          label="Ad Category"
        >
          <:footer>Attribution here</:footer>
        </.live_component>
      </.form>
      <div id="picked">{@picked}</div>
      <div id="submitted">{inspect(@submitted)}</div>
      """
    end
  end

  @options [
    %{value: 1, label: "Bakeries", group: "Food", search_text: "bakeries food pizza dough"},
    %{value: 2, label: "Pizza Places", group: "Food", search_text: "pizza places food"},
    %{value: 3, label: "Car Wash", group: "Cars", search_text: "car wash cars detailing"},
    %{value: 4, label: "Tire Shops", group: "Cars", search_text: "tire shops cars wheels"}
  ]

  defp host(conn, session \\ %{}) do
    live_isolated(conn, Host, session: Map.merge(%{"options" => @options}, session))
  end

  defp search(view, query) do
    view |> element("#picker input[role=combobox]") |> render_keyup(%{"value" => query})
  end

  test "multi-word search matches meta words and ranks label matches first", %{conn: conn} do
    {:ok, view, _html} = host(conn)

    html = search(view, "pizza")
    assert html =~ "Pizza Places"
    assert html =~ "Bakeries"
    [first | _] = Regex.scan(~r/id="picker-opt-(\d+)"/, html) |> Enum.map(&List.last/1)
    assert first == "2"

    html = search(view, "pizza dough")
    assert html =~ "Bakeries"
    refute html =~ "Pizza Places"

    assert html =~ "Attribution here"
  end

  test "caps results and says how many matched", %{conn: conn} do
    {:ok, view, _html} = host(conn, %{"limit" => 1})
    assert search(view, "cars") =~ "Showing 1 of 2, add a word to narrow"
  end

  test "an empty query shows a hint with a browse link", %{conn: conn} do
    {:ok, view, _html} = host(conn)
    html = view |> element("#picker input[role=combobox]") |> render_focus()
    assert html =~ "browse the full list"
  end

  test "browse shows every group, collapsed, with expand and collapse", %{conn: conn} do
    {:ok, view, _html} = host(conn, %{"limit" => 1})

    html = view |> element("#picker button.btn[phx-value-mode=browse]") |> render_click()
    assert html =~ "Food (2)"
    assert html =~ "Cars (2)"
    refute html =~ "Tire Shops"

    html = view |> element("#picker button[phx-value-group=Cars]") |> render_click()
    assert html =~ "Tire Shops"
    assert html =~ "Car Wash"
    refute html =~ "Bakeries"

    html = view |> element("#picker button", "Expand all") |> render_click()
    assert html =~ "Bakeries" and html =~ "Tire Shops"

    html = view |> element("#picker button", "Collapse all") |> render_click()
    refute html =~ "Tire Shops"
  end

  test "browse opens the group holding the current selection", %{conn: conn} do
    {:ok, view, _html} = host(conn, %{"value" => "4"})
    html = view |> element("#picker button.btn[phx-value-mode=browse]") |> render_click()
    assert html =~ "Car Wash"
    refute html =~ "Bakeries"
  end

  test "click pick sets the hidden input and notifies the parent", %{conn: conn} do
    {:ok, view, _html} = host(conn)
    search(view, "car")
    view |> element("#picker-opt-3") |> render_click()

    assert view |> element("#picked") |> render() =~ "3"
    assert view |> element("#picker-value") |> render() =~ ~s(value="3")
  end

  test "keyboard pick moves through results and picks with Enter", %{conn: conn} do
    {:ok, view, _html} = host(conn)
    input = "#picker input[role=combobox]"
    search(view, "cars")

    view |> element(input) |> render_keydown(%{"key" => "ArrowDown", "value" => "cars"})
    view |> element(input) |> render_keydown(%{"key" => "Enter", "value" => "cars"})

    assert view |> element("#picker-value") |> render() =~ ~s(value="4")
  end

  test "clear resets the selection", %{conn: conn} do
    {:ok, view, _html} = host(conn, %{"value" => "1"})
    assert render(view) =~ "Bakeries"
    view |> element("#picker button[aria-label='Clear selection']") |> render_click()
    assert view |> element("#picker-value") |> render() =~ ~s(value="")
    assert view |> element("#picked") |> render() =~ ~r/<div id="picked">\s*<\/div>/
  end

  test "only the hidden input lands in the parent form params", %{conn: conn} do
    {:ok, view, _html} = host(conn, %{"value" => "2"})
    search(view, "pizza")
    view |> element("#host-form") |> render_submit()

    submitted = view |> element("#submitted") |> render()
    assert submitted =~ "&quot;choice&quot; =&gt; &quot;2&quot;"
    refute submitted =~ "pizza"
  end

  test "search/3 ranks label matches first" do
    options = Enum.map(@options, &Map.update!(&1, :value, fn v -> to_string(v) end))

    assert {[%{label: "Pizza Places"}, %{label: "Bakeries"}], 2} =
             SearchSelect.search(options, "pizza")
  end
end
