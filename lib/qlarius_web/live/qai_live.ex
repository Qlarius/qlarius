defmodule QlariusWeb.QaiLive do
  @moduledoc """
  Qai: the private chat surface inside the consumer app.

  First open shows the opt-in card; enabling creates Qai's MeCP grant (the
  same consent shape connectors use, revocable from AI Connectors). Chats are
  fleeting by default with a preserve toggle, stream token by token, and can
  be stopped or regenerated. The MeFile capsule is fetched through the MeCP
  gateway once per session (and again on regenerate), so every read is logged
  and budgeted like any other counterparty's.

  Streaming runs in a linked Task; deltas arrive as `{:qai_delta, text}`
  messages, the Task's return carries the final result, and Stop simply kills
  the Task and finalizes the partial transcript.
  """

  use QlariusWeb, :live_view

  alias Qlarius.Qai
  alias Qlarius.Qai.{Router, Session, Sessions}
  alias Qlarius.YouData.Traits

  on_mount {QlariusWeb.DetectMobile, :detect_mobile}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Qai")
      |> assign(:configured, Router.configured?())
      |> assign(:categories, Traits.list_trait_categories())
      |> assign(:session, nil)
      |> assign(:messages, [])
      |> assign(:stream, nil)
      |> assign(:title_task_ref, nil)
      |> assign(:system_prompt, nil)
      |> assign(:degraded, false)
      |> assign(:show_history, false)
      |> assign(:composer_error, nil)
      |> assign_grant()
      |> assign_sessions()

    {:ok, socket}
  end

  ## Events

  # Pushed by the app-global referral JS hook to every LiveView; ignored here.
  @impl true
  def handle_event("referral_code_from_storage", _params, socket) do
    {:noreply, socket}
  end

  # Pushed by the HiPagePWADetect hook wrapping this page.
  def handle_event("pwa_detected", params, socket) do
    QlariusWeb.PWAHelpers.handle_pwa_detection(socket, params)
  end

  def handle_event("enable_qai", params, socket) do
    attrs = %{category_ids: parse_category_ids(params)}

    case Qai.enable(me_file(socket).id, socket.assigns.current_scope.true_user.id, attrs) do
      {:ok, _grant} ->
        {:noreply, socket |> assign_grant() |> put_flash(:info, "Qai is ready.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not enable Qai. Try again.")}
    end
  end

  def handle_event("send", %{"message" => text}, socket) do
    text = String.trim(text || "")

    cond do
      socket.assigns.stream != nil or text == "" ->
        {:noreply, socket}

      socket.assigns.grant == nil ->
        {:noreply, socket}

      true ->
        socket = ensure_session(socket)
        {:ok, _} = Sessions.add_message(socket.assigns.session, "user", text)

        {:noreply,
         socket
         |> assign(:composer_error, nil)
         |> reload_messages()
         |> start_stream()
         # The composer field is phx-update="ignore" (it keeps focus, so a phone
         # keyboard stays up); its hook clears it once the message is taken.
         |> push_event("qai:composer_reset", %{})}
    end
  end

  def handle_event("stop", _params, socket) do
    {:noreply, stop_stream(socket)}
  end

  def handle_event("regenerate", _params, socket) do
    with nil <- socket.assigns.stream,
         %Session{} = session <- socket.assigns.session,
         [%{role: "assistant"} | _] <- Enum.reverse(socket.assigns.messages) do
      :ok = Sessions.delete_last_assistant_message(session.id)

      {:noreply,
       socket
       # Regenerate refetches the capsule (design: once per session start and
       # on regenerate), so corrections made in the Builder take effect here.
       |> assign(:system_prompt, nil)
       |> reload_messages()
       |> start_stream()}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("new_chat", _params, socket) do
    {:noreply,
     socket
     |> stop_stream()
     |> assign(:session, nil)
     |> assign(:messages, [])
     |> assign(:system_prompt, nil)
     |> assign(:degraded, false)
     |> assign(:show_history, false)}
  end

  def handle_event("open_session", %{"id" => id}, socket) do
    case Sessions.get_session(String.to_integer(id), me_file(socket).id) do
      nil ->
        {:noreply, assign_sessions(socket)}

      session ->
        {:noreply,
         socket
         |> stop_stream()
         |> assign(:session, session)
         |> assign(:system_prompt, nil)
         |> assign(:degraded, false)
         |> assign(:show_history, false)
         |> reload_messages()}
    end
  end

  def handle_event("toggle_history", _params, socket) do
    {:noreply, socket |> assign_sessions() |> assign(:show_history, !socket.assigns.show_history)}
  end

  # The chat list is the shell's slide-over; its back button sends this.
  def handle_event("close_slide_over", _params, socket) do
    {:noreply, assign(socket, :show_history, false)}
  end

  # Pushed by the CopyToClipboard hook on a reply's Copy button.
  def handle_event("copy_success", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_preserve", _params, socket) do
    case socket.assigns.session do
      nil ->
        {:noreply, socket}

      session ->
        {:ok, session} =
          if Session.preserved?(session),
            do: Sessions.fleet_session(session),
            else: Sessions.preserve_session(session)

        {:noreply, socket |> assign(:session, session) |> assign_sessions()}
    end
  end

  def handle_event("delete_session", %{"id" => id}, socket) do
    with %Session{} = session <- Sessions.get_session(String.to_integer(id), me_file(socket).id) do
      {:ok, _} = Sessions.delete_session(session)
    end

    socket =
      if socket.assigns.session && to_string(socket.assigns.session.id) == id do
        socket
        |> stop_stream()
        |> assign(:session, nil)
        |> assign(:messages, [])
        |> assign(:system_prompt, nil)
      else
        socket
      end

    {:noreply, assign_sessions(socket)}
  end

  ## Stream lifecycle

  @impl true
  def handle_info({:qai_delta, text}, socket) do
    case socket.assigns.stream do
      nil -> {:noreply, socket}
      stream -> {:noreply, assign(socket, :stream, %{stream | parts: [text | stream.parts]})}
    end
  end

  def handle_info({ref, result}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    cond do
      match?(%{task: %Task{ref: ^ref}}, socket.assigns.stream) ->
        {:noreply, finish_stream(socket, result)}

      socket.assigns.title_task_ref == ref ->
        {:noreply, apply_title(socket, result)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    cond do
      match?(%{task: %Task{ref: ^ref}}, socket.assigns.stream) ->
        {:noreply, finish_stream(socket, {:error, {:crashed, reason}})}

      socket.assigns.title_task_ref == ref ->
        {:noreply, assign(socket, :title_task_ref, nil)}

      true ->
        {:noreply, socket}
    end
  end

  defp ensure_session(%{assigns: %{session: nil}} = socket) do
    {:ok, session} = Sessions.create_session(me_file(socket).id)
    socket |> assign(:session, session) |> assign_sessions()
  end

  defp ensure_session(socket), do: socket

  defp start_stream(socket) do
    socket = ensure_system_prompt(socket)
    session = socket.assigns.session

    transcript =
      socket.assigns.messages
      |> Enum.filter(&(&1.content != ""))
      |> Enum.map(&%{role: &1.role, content: &1.content})

    {:ok, draft} =
      Sessions.add_message(session, "assistant", "", model: Router.model_for(:frontier))

    lv = self()
    system = socket.assigns.system_prompt
    grant = socket.assigns.grant

    task =
      Task.async(fn ->
        Router.stream_conversation(
          transcript,
          [
            system: system,
            session_id: session.id,
            # Same MeCP tool surface external connectors get, dispatched
            # in-process under Qai's grant (logged, budgeted, revocable).
            tools: Qai.tool_definitions(),
            tool_handler: Qai.tool_handler(grant)
          ],
          fn {:delta, text} -> send(lv, {:qai_delta, text}) end
        )
      end)

    assign(socket, :stream, %{task: task, parts: [], draft: draft})
  end

  defp finish_stream(socket, result) do
    %{parts: parts, draft: draft} = socket.assigns.stream
    partial = parts |> Enum.reverse() |> IO.iodata_to_binary()

    socket =
      case result do
        {:ok, %{content: content} = completed} ->
          {:ok, _} =
            Sessions.finalize_message(draft, content,
              usage: completed.usage,
              model: completed.model
            )

          maybe_generate_title(socket)

        {:error, reason} ->
          finalize_partial(draft, partial)
          assign(socket, :composer_error, error_message(reason))
      end

    socket |> assign(:stream, nil) |> reload_messages()
  end

  defp stop_stream(%{assigns: %{stream: nil}} = socket), do: socket

  defp stop_stream(socket) do
    %{task: task, parts: parts, draft: draft} = socket.assigns.stream
    Task.shutdown(task, :brutal_kill)

    finalize_partial(draft, parts |> Enum.reverse() |> IO.iodata_to_binary())

    socket |> assign(:stream, nil) |> reload_messages()
  end

  defp finalize_partial(draft, ""), do: Qlarius.Repo.delete(draft)

  defp finalize_partial(draft, partial),
    do: Sessions.finalize_message(draft, partial, stopped: true)

  defp ensure_system_prompt(%{assigns: %{system_prompt: prompt}} = socket)
       when is_binary(prompt),
       do: socket

  defp ensure_system_prompt(socket) do
    case Qai.system_prompt(socket.assigns.grant) do
      {:ok, prompt} ->
        socket |> assign(:system_prompt, prompt) |> assign(:degraded, false)

      {:degraded, prompt, _reason} ->
        socket |> assign(:system_prompt, prompt) |> assign(:degraded, true)
    end
  end

  defp maybe_generate_title(socket) do
    session = socket.assigns.session

    with nil <- session.title,
         nil <- socket.assigns.title_task_ref,
         %{content: opener} <- Enum.find(socket.assigns.messages, &(&1.role == "user")) do
      task = Task.async(fn -> Router.generate_title(opener, session_id: session.id) end)
      assign(socket, :title_task_ref, task.ref)
    else
      _ -> socket
    end
  end

  defp apply_title(socket, {:ok, title}) do
    socket =
      case socket.assigns.session do
        nil ->
          socket

        session ->
          {:ok, session} = Sessions.set_title(session, title)
          socket |> assign(:session, session) |> assign_sessions()
      end

    assign(socket, :title_task_ref, nil)
  end

  defp apply_title(socket, _error), do: assign(socket, :title_task_ref, nil)

  ## Assigns

  defp me_file(socket), do: socket.assigns.current_scope.user.me_file

  defp assign_grant(socket) do
    grant =
      Qai.active_grant(socket.assigns.current_scope.true_user.id, me_file(socket).id)

    assign(socket, :grant, grant)
  end

  defp assign_sessions(socket) do
    assign(socket, :sessions, Sessions.list_sessions(me_file(socket).id))
  end

  defp reload_messages(socket) do
    case socket.assigns.session do
      nil -> assign(socket, :messages, [])
      session -> assign(socket, :messages, Sessions.list_messages(session.id))
    end
  end

  defp parse_category_ids(params) do
    params
    |> Map.get("category_ids", [])
    |> Enum.map(&String.to_integer/1)
  end

  defp error_message(:not_configured), do: "Qai is not configured on this server yet."
  defp error_message({:http, 429, _}), do: "Qai is busy right now. Try again in a moment."

  defp error_message({:api_error, %{"type" => "overloaded_error"}}),
    do: "Qai is busy right now. Try again in a moment."

  defp error_message(_), do: "Something went wrong mid-reply. The partial answer was kept."

  ## Rendering helpers

  # Hard breaks: replies often put each item on its own line with a single
  # newline ("🤙 **Austin local** — …"), which CommonMark would run together.
  defp markdown(content) do
    MDEx.to_html(content,
      extension: [strikethrough: true, table: true, autolink: true, tasklist: true],
      render: [hardbreaks: true]
    )
    |> case do
      {:ok, html} -> Phoenix.HTML.raw(html)
      {:error, _} -> content
    end
  end

  defp streaming_text(%{parts: parts}), do: parts |> Enum.reverse() |> IO.iodata_to_binary()

  defp session_label(%Session{title: title}) when is_binary(title) and title != "", do: title
  defp session_label(_), do: "New chat"

  # History rows: "Kept · Oct 3" (last activity) or "Fleeting · auto-fleets in 5 hrs",
  # the same wording as a tiqit's status line.
  defp session_meta(%Session{} = session, user) do
    if Session.preserved?(session),
      do: "Kept · #{day_label(session.updated_at, user)}",
      else: "Fleeting · auto-fleets in #{time_left(session.expires_at)}"
  end

  defp time_left(%DateTime{} = expires_at) do
    seconds = max(DateTime.diff(expires_at, DateTime.utc_now()), 0)

    if seconds >= 3600 do
      hours = div(seconds + 1800, 3600)
      "#{hours} #{if hours == 1, do: "hr", else: "hrs"}"
    else
      "#{max(div(seconds, 60), 1)} min"
    end
  end

  defp day_label(datetime, user) do
    date = datetime |> Qlarius.DateTime.to_user_timezone(user) |> DateTime.to_date()
    today = DateTime.utc_now() |> Qlarius.DateTime.to_user_timezone(user) |> DateTime.to_date()

    cond do
      date == today -> "Today"
      date == Date.add(today, -1) -> "Yesterday"
      date.year == today.year -> Calendar.strftime(date, "%b %-d")
      true -> Calendar.strftime(date, "%b %-d, %Y")
    end
  end

  defp last_assistant?(messages, message),
    do: message.role == "assistant" and List.last(messages).id == message.id

  @impl true
  def render(assigns) do
    ~H"""
    <div id="qai-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile
        {assigns}
        title="Qai"
        fixed_viewport={true}
        slide_over_active={@show_history}
        slide_over_title="Chats"
      >
        <div class="flex flex-col flex-1 min-h-0 mx-auto w-full max-w-2xl">
          <%= cond do %>
            <% !@configured -> %>
              <div class="qai-empty">
                <span class="qai-mark qai-mark--lg">
                  <.icon name="hero-sparkles" class="size-7" />
                </span>
                <p class="qai-empty__title">Qai isn't available yet</p>
                <p class="qai-empty__copy">Qai is not configured on this server yet.</p>
              </div>
            <% @grant == nil -> %>
              {render_optin(assigns)}
            <% true -> %>
              {render_chat(assigns)}
          <% end %>
        </div>

        <:slide_over_content>
          {render_history(assigns)}
        </:slide_over_content>
      </Layouts.mobile>
    </div>
    """
  end

  defp render_optin(assigns) do
    ~H"""
    <div class="qai-scroll">
      <form phx-submit="enable_qai" class="qai-optin">
        <div class="qai-optin__hero">
          <span class="qai-mark qai-mark--lg">
            <.icon name="hero-sparkles" class="size-7" />
          </span>
          <h2 class="qai-optin__title">Meet Qai</h2>
          <p class="qai-optin__lead">Qai is your personal AI.</p>
        </div>

        <.surface_panel padding={false}>
          <ul class="qai-facts">
            <li class="qai-fact">
              <span class="qai-fact__icon"><.icon name="hero-eye-slash" class="size-5" /></span>
              <div>
                <p class="qai-fact__title">Private by design</p>
                <p class="qai-fact__copy">
                  Chats disappear after a day unless you keep them, and requests reach the
                  model anonymously.
                </p>
              </div>
            </li>
            <li class="qai-fact">
              <span class="qai-fact__icon">
                <.icon name="hero-identification" class="size-5" />
              </span>
              <div>
                <p class="qai-fact__title">Personal, through your MeFile</p>
                <p class="qai-fact__copy">
                  To personalize, Qai reads your MeFile through the same gated access any AI
                  connector gets.
                </p>
              </div>
            </li>
            <li class="qai-fact">
              <span class="qai-fact__icon">
                <.icon name="hero-shield-check" class="size-5" />
              </span>
              <div>
                <p class="qai-fact__title">Logged and revocable</p>
                <p class="qai-fact__copy">
                  Every read is logged, and you can revoke access any time from AI Connectors.
                </p>
              </div>
            </li>
          </ul>
        </.surface_panel>

        <section>
          <h3 class="detail-section-label">What Qai can see</h3>
          <.surface_panel>
            <p class="qai-optin__hint">Leave all unchecked to share your full MeFile.</p>
            <div class="qai-cats">
              <label :for={cat <- @categories} class="qai-cat">
                <input type="checkbox" name="category_ids[]" value={cat.id} class="sr-only" />
                <.icon name="hero-check" class="qai-cat__check size-4" />
                {cat.name}
              </label>
            </div>
          </.surface_panel>
        </section>

        <button type="submit" class="btn btn-primary rounded-full qai-optin__cta">
          Enable Qai
        </button>
      </form>
    </div>
    """
  end

  defp render_chat(assigns) do
    ~H"""
    <div id="qai-chat" class="flex flex-col flex-1 min-h-0" phx-hook="QaiKeyboard">
      <%!-- Session bar: like the slide-over header, round chips either side of the title --%>
      <div class="qai-bar">
        <button
          type="button"
          class="qai-bar__btn"
          phx-click="toggle_history"
          aria-label="Chats"
          title="Chats"
        >
          <.icon name="hero-chat-bubble-left-right" class="size-5" />
        </button>
        <div class="qai-bar__center">
          <p class="qai-bar__title">{if @session, do: session_label(@session), else: "New chat"}</p>
          <%= if @session do %>
            <button
              type="button"
              phx-click="toggle_preserve"
              class={["qai-keep", Session.preserved?(@session) && "is-kept"]}
              title={
                if Session.preserved?(@session),
                  do: "Kept until you delete it. Tap to make it fleeting.",
                  else:
                    "Auto-fleets #{Sessions.fleeting_hours()} hours after your last message. Tap to keep it."
              }
            >
              <.icon
                name={if Session.preserved?(@session), do: "hero-lock-closed", else: "hero-clock"}
                class="size-3.5"
              />
              {if Session.preserved?(@session), do: "Kept", else: "Fleeting"}
            </button>
          <% else %>
            <span class="qai-keep is-static">
              <.icon name="hero-clock" class="size-3.5" /> Fleeting
            </span>
          <% end %>
        </div>
        <button
          type="button"
          class="qai-bar__btn"
          phx-click="new_chat"
          disabled={@session == nil and @stream == nil}
          aria-label="New chat"
          title="New chat"
        >
          <.icon name="hero-pencil-square" class="size-5" />
        </button>
      </div>

      <%!-- Messages --%>
      <div id="qai-messages" class="qai-thread" phx-hook="QaiScroll">
        <div :if={@messages == [] && @stream == nil} class="qai-empty">
          <span class="qai-mark qai-mark--lg">
            <.icon name="hero-sparkles" class="size-7" />
          </span>
          <p class="qai-empty__title">Private, fleeting, yours.</p>
          <p class="qai-empty__copy">
            Ask anything. Chats auto-fleet {Sessions.fleeting_hours()} hours after your last
            message unless you keep them.
          </p>
          <p :if={@degraded} class="qai-empty__note">
            <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
            Heads up: your MeFile capsule could not be loaded, so this chat is unpersonalized.
          </p>
        </div>

        <%= for message <- @messages, message.content != "" or message.stopped do %>
          <div :if={message.role == "user"} class="qai-msg qai-msg--user">
            <div class="qai-bubble">{message.content}</div>
          </div>
          <div :if={message.role == "assistant"} class="qai-msg qai-msg--assistant">
            <span class="qai-mark"><.icon name="hero-sparkles" class="size-4" /></span>
            <div class="qai-msg__body">
              <div class="qai-md">{markdown(message.content)}</div>
              <p :if={message.stopped} class="qai-msg__stopped">
                <.icon name="hero-stop-circle" class="size-3.5" /> Stopped
              </p>
              <div
                :if={@stream == nil && last_assistant?(@messages, message)}
                class="qai-msg__actions"
              >
                <textarea id={"qai-msg-raw-#{message.id}"} class="hidden" readonly>{message.content}</textarea>
                <button
                  id={"qai-copy-#{message.id}"}
                  type="button"
                  class="qai-action"
                  phx-hook="CopyToClipboard"
                  data-target={"qai-msg-raw-#{message.id}"}
                  data-copied-label="Copied"
                >
                  <.icon name="hero-clipboard-document" class="size-4" />
                  <span data-copy-label>Copy</span>
                </button>
                <button type="button" class="qai-action" phx-click="regenerate">
                  <.icon name="hero-arrow-path" class="size-4" /> Regenerate
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <div :if={@stream} class="qai-msg qai-msg--assistant">
          <span class="qai-mark"><.icon name="hero-sparkles" class="size-4" /></span>
          <div class="qai-msg__body">
            <%= if streaming_text(@stream) == "" do %>
              <span class="qai-typing" aria-label="Qai is replying"><i></i><i></i><i></i></span>
            <% else %>
              <div class="qai-md">{markdown(streaming_text(@stream))}</div>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Composer: one capsule; send becomes Stop while a reply streams --%>
      <div class="qai-composer-area">
        <p :if={@composer_error} class="qai-composer-error">
          <.icon name="hero-exclamation-circle" class="size-4 shrink-0" /> {@composer_error}
        </p>
        <form
          id="qai-composer"
          phx-submit="send"
          phx-hook="QaiComposer"
          class="qai-composer"
          data-streaming={to_string(@stream != nil)}
        >
          <div id="qai-composer-field" class="qai-composer__field" phx-update="ignore">
            <textarea
              id="qai-composer-input"
              name="message"
              rows="1"
              placeholder="Message Qai"
              aria-label="Message Qai"
              autocomplete="off"
              enterkeyhint="send"
              class="qai-composer__input"
            ></textarea>
          </div>
          <button :if={@stream == nil} type="submit" class="qai-composer__send" aria-label="Send">
            <.icon name="hero-arrow-up" class="size-5" />
          </button>
          <button
            :if={@stream}
            type="button"
            class="qai-composer__send is-stop"
            phx-click="stop"
            aria-label="Stop"
            title="Stop"
          >
            <.icon name="hero-stop-solid" class="size-4" />
          </button>
        </form>
      </div>
    </div>
    """
  end

  # Chat list for the slide-over: current chat tinted, Kept chats marked with a lock.
  defp render_history(assigns) do
    ~H"""
    <div class="qai-history">
      <button type="button" class="qai-history__new" phx-click="new_chat">
        <.icon name="hero-pencil-square" class="size-4" /> New chat
      </button>

      <p :if={@sessions == []} class="qai-history__empty">
        No chats yet. Fleeting chats auto-fleet {Sessions.fleeting_hours()} hours after your
        last message.
      </p>

      <ul :if={@sessions != []} class="surface-panel qai-history__list">
        <li
          :for={session <- @sessions}
          class={["qai-history__item", @session && @session.id == session.id && "is-current"]}
        >
          <button
            type="button"
            class="qai-history__open"
            phx-click="open_session"
            phx-value-id={session.id}
          >
            <span class={["qai-history__icon", Session.preserved?(session) && "is-kept"]}>
              <.icon
                name={
                  if Session.preserved?(session),
                    do: "hero-lock-closed",
                    else: "hero-chat-bubble-left"
                }
                class="size-[18px]"
              />
            </span>
            <span class="qai-history__main">
              <span class="qai-history__title">{session_label(session)}</span>
              <span class="qai-history__meta">
                {session_meta(session, @current_scope.user)}
              </span>
            </span>
          </button>
          <button
            type="button"
            class="qai-history__delete"
            phx-click="delete_session"
            phx-value-id={session.id}
            data-confirm="Delete this chat permanently?"
            aria-label="Delete chat"
            title="Delete chat"
          >
            <.icon name="hero-trash" class="size-4" />
          </button>
        </li>
      </ul>
    </div>
    """
  end
end
