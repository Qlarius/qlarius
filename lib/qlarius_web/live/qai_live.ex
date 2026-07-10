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
         |> start_stream()}
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

    task =
      Task.async(fn ->
        Router.stream_conversation(
          transcript,
          [system: system, session_id: session.id],
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
        {:ok, %{content: content}} ->
          {:ok, _} = Sessions.finalize_message(draft, content)
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
  defp finalize_partial(draft, partial), do: Sessions.finalize_message(draft, partial, stopped: true)

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
  defp error_message({:api_error, %{"type" => "overloaded_error"}}), do: "Qai is busy right now. Try again in a moment."
  defp error_message(_), do: "Something went wrong mid-reply. The partial answer was kept."

  ## Rendering helpers

  defp markdown(content) do
    MDEx.to_html(content,
      extension: [strikethrough: true, table: true, autolink: true, tasklist: true]
    )
    |> case do
      {:ok, html} -> Phoenix.HTML.raw(html)
      {:error, _} -> content
    end
  end

  defp streaming_text(%{parts: parts}), do: parts |> Enum.reverse() |> IO.iodata_to_binary()

  defp session_label(%Session{title: title}) when is_binary(title) and title != "", do: title
  defp session_label(_), do: "New chat"

  @impl true
  def render(assigns) do
    ~H"""
    <div id="qai-pwa-detect" phx-hook="HiPagePWADetect">
      <Layouts.mobile {assigns} title="Qai" fixed_viewport={true}>
        <div class="flex flex-col flex-1 min-h-0 mx-auto w-full max-w-2xl">
          <%= cond do %>
            <% !@configured -> %>
              <div class="text-center py-12 text-base-content/60">
                <.icon name="hero-sparkles" class="w-12 h-12 mx-auto mb-3 text-base-content/30" />
                <p>Qai is not configured on this server yet.</p>
              </div>
            <% @grant == nil -> %>
              {render_optin(assigns)}
            <% true -> %>
              {render_chat(assigns)}
          <% end %>
        </div>
      </Layouts.mobile>
    </div>
    """
  end

  defp render_optin(assigns) do
    ~H"""
    <form phx-submit="enable_qai" class="card bg-base-100 border border-base-300 mt-2">
      <div class="card-body gap-4">
        <h3 class="card-title text-base">
          <.icon name="hero-sparkles" class="w-5 h-5 text-primary" /> Meet Qai
        </h3>
        <p class="text-sm text-base-content/70">
          Qai is your personal AI. It is private by design: chats disappear after a day
          unless you keep them, and requests reach the model anonymously.
        </p>
        <p class="text-sm text-base-content/70">
          To personalize, Qai reads your MeFile through the same gated access any AI
          connector gets. Every read is logged, and you can revoke access any time from
          AI Connectors.
        </p>

        <fieldset>
          <span class="label-text font-medium">What Qai can see</span>
          <p class="text-xs text-base-content/60 pb-2">
            Leave all unchecked to share your full MeFile.
          </p>
          <div class="flex flex-col gap-1 max-h-48 overflow-y-auto">
            <label :for={cat <- @categories} class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" name="category_ids[]" value={cat.id} class="checkbox checkbox-sm" />
              <span class="text-sm">{cat.name}</span>
            </label>
          </div>
        </fieldset>

        <div class="card-actions justify-end">
          <button type="submit" class="btn btn-primary">Enable Qai</button>
        </div>
      </div>
    </form>
    """
  end

  defp render_chat(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 min-h-0">
      <%!-- Session bar --%>
      <div class="flex items-center gap-2 pb-2 flex-shrink-0">
        <button class="btn btn-sm btn-ghost" phx-click="toggle_history" title="Chat history">
          <.icon name="hero-clock" class="w-4 h-4" />
        </button>
        <div class="flex-1 truncate text-sm font-medium text-center">
          {if @session, do: session_label(@session), else: "New chat"}
        </div>
        <button
          :if={@session}
          class="btn btn-sm btn-ghost"
          phx-click="toggle_preserve"
          title={if Session.preserved?(@session), do: "Preserved. Tap to make fleeting.", else: "Fleeting. Tap to preserve."}
        >
          <.icon
            name={if Session.preserved?(@session), do: "hero-lock-closed", else: "hero-clock"}
            class={"w-4 h-4 " <> if(Session.preserved?(@session), do: "text-primary", else: "text-base-content/50")}
          />
        </button>
        <button class="btn btn-sm btn-ghost" phx-click="new_chat" title="New chat">
          <.icon name="hero-pencil-square" class="w-4 h-4" />
        </button>
      </div>

      <%!-- History drawer --%>
      <div :if={@show_history} class="card bg-base-100 border border-base-300 mb-2 flex-shrink-0">
        <div class="card-body py-3 gap-1 max-h-64 overflow-y-auto">
          <p :if={@sessions == []} class="text-sm text-base-content/60 text-center py-2">
            No chats yet. Fleeting chats expire after {Sessions.fleeting_hours()} hours.
          </p>
          <div :for={session <- @sessions} class="flex items-center gap-2">
            <button
              class="flex-1 text-left text-sm truncate hover:text-primary py-1"
              phx-click="open_session"
              phx-value-id={session.id}
            >
              <.icon
                :if={Session.preserved?(session)}
                name="hero-lock-closed"
                class="w-3 h-3 text-primary inline"
              />
              {session_label(session)}
            </button>
            <button
              class="btn btn-xs btn-ghost text-error"
              phx-click="delete_session"
              phx-value-id={session.id}
              data-confirm="Delete this chat permanently?"
            >
              <.icon name="hero-trash" class="w-3 h-3" />
            </button>
          </div>
        </div>
      </div>

      <%!-- Messages --%>
      <div
        id="qai-messages"
        class="flex-1 min-h-0 overflow-y-auto flex flex-col gap-3 py-2"
        phx-hook="QaiScroll"
      >
        <div :if={@messages == [] && @stream == nil} class="text-center py-12 text-base-content/50">
          <.icon name="hero-sparkles" class="w-10 h-10 mx-auto mb-2 text-base-content/30" />
          <p class="text-sm">Private, fleeting, yours. Ask anything.</p>
          <p :if={@degraded} class="text-xs pt-2">
            Heads up: your MeFile capsule could not be loaded, so this chat is unpersonalized.
          </p>
        </div>

        <div :for={message <- @messages} :if={message.content != "" or message.stopped}>
          <div :if={message.role == "user"} class="chat chat-end">
            <div class="chat-bubble chat-bubble-primary whitespace-pre-wrap">{message.content}</div>
          </div>
          <div :if={message.role == "assistant"} class="chat chat-start">
            <div class="chat-bubble bg-base-200 text-base-content prose prose-sm max-w-none">
              {markdown(message.content)}
              <p :if={message.stopped} class="text-xs text-base-content/50 italic mt-1">stopped</p>
            </div>
          </div>
        </div>

        <div :if={@stream} class="chat chat-start">
          <div class="chat-bubble bg-base-200 text-base-content whitespace-pre-wrap">
            {streaming_text(@stream)}<span class="animate-pulse">▍</span>
          </div>
        </div>
      </div>

      <%!-- Composer --%>
      <div class="flex-shrink-0 pt-2 pb-1">
        <p :if={@composer_error} class="text-xs text-error pb-1">{@composer_error}</p>
        <form :if={@stream == nil} phx-submit="send" class="flex items-end gap-2">
          <textarea
            id={"qai-composer-#{if @session, do: @session.id, else: "new"}-#{length(@messages)}"}
            name="message"
            rows="1"
            placeholder="Message Qai"
            class="textarea textarea-bordered flex-1 resize-none min-h-[2.75rem]"
            autocomplete="off"
          ></textarea>
          <button type="submit" class="btn btn-primary btn-circle">
            <.icon name="hero-arrow-up" class="w-5 h-5" />
          </button>
        </form>
        <div :if={@stream} class="flex justify-center">
          <button class="btn btn-sm btn-outline" phx-click="stop">
            <.icon name="hero-stop" class="w-4 h-4" /> Stop
          </button>
        </div>
        <div :if={@stream == nil && @messages != [] && List.last(@messages).role == "assistant"} class="flex justify-center pt-1">
          <button class="btn btn-xs btn-ghost text-base-content/60" phx-click="regenerate">
            <.icon name="hero-arrow-path" class="w-3 h-3" /> Regenerate
          </button>
        </div>
      </div>
    </div>
    """
  end
end
