defmodule QlariusWeb.DebugHelpers do
  @moduledoc """
  Debug helpers for development environment
  """

  use Phoenix.Component
  require Logger

  def debug_enabled? do
    debug_var = System.get_env("DEBUG")
    result = debug_var == "true"

    Logger.info(
      "Debug check - DEBUG env var: #{inspect(debug_var)}, enabled: #{result}"
    )

    result
  end

  def debug_panel(assigns) do
    Logger.info("debug_panel called, enabled?: #{debug_enabled?()}")

    if debug_enabled?() do
      ~H"""
      <div class="fixed bottom-0 left-0 right-0 bg-gray-900 text-green-400 p-4 z-50 max-h-64 overflow-auto font-mono text-xs border-t-2 border-green-400">
        <div class="flex justify-between items-center mb-2">
          <h4 class="font-bold text-green-300">Debug: LiveView Assigns</h4>
          <button
            onclick="this.parentElement.parentElement.style.display='none'"
            class="text-red-400 hover:text-red-300 font-bold"
          >
            ✕
          </button>
        </div>
        <pre class="whitespace-pre-wrap"><%= inspect(assigns, pretty: true, limit: :infinity, width: 120) %></pre>
      </div>
      """
    else
      ~H"""
      <!-- Debug disabled -->
      """
    end
  end
end
