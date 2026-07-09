defmodule QlariusWeb.MeCPOAuthHTML do
  use QlariusWeb, :html

  def authorize(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card bg-base-100 border border-base-300 w-full max-w-md">
        <div class="card-body gap-4">
          <h1 class="card-title">
            <.icon name="hero-cpu-chip" class="w-6 h-6" />
            Connect {@client.client_name || "an AI assistant"}
          </h1>

          <p class="text-sm text-base-content/70">
            This assistant is asking to read parts of your MeFile through MeCP.
            You choose what it can see and can revoke access any time from the
            AI Connectors page.
          </p>

          <form method="post" action={~p"/mecp/oauth/authorize"} class="flex flex-col gap-4">
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <input type="hidden" name="client_id" value={@client.client_id} />
            <input type="hidden" name="redirect_uri" value={@checked.redirect_uri} />
            <input type="hidden" name="response_type" value="code" />
            <input type="hidden" name="code_challenge" value={@checked.code_challenge} />
            <input type="hidden" name="code_challenge_method" value="S256" />
            <input :if={@checked.state} type="hidden" name="state" value={@checked.state} />

            <label class="form-control">
              <span class="label-text font-medium pb-1">Access level</span>
              <select name="tier" class="select select-bordered">
                <option value="3">Capsule: scoped profile context plus questions</option>
                <option value="2">Oracle: narrow question answers only</option>
                <option value="1">Rerank: relevance signals only</option>
              </select>
            </label>

            <fieldset>
              <span class="label-text font-medium">Categories it can see</span>
              <p class="text-xs text-base-content/60 pb-2">
                Leave all unchecked to share your full MeFile.
              </p>
              <div class="flex flex-col gap-1 max-h-48 overflow-y-auto">
                <label :for={cat <- @categories} class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    name="category_ids[]"
                    value={cat.id}
                    class="checkbox checkbox-sm"
                  />
                  <span class="text-sm">{cat.name}</span>
                </label>
              </div>
            </fieldset>

            <label class="form-control">
              <span class="label-text font-medium pb-1">Daily disclosure limit</span>
              <input
                type="number"
                name="budget_max"
                min="0"
                placeholder="Leave blank for unlimited"
                class="input input-bordered"
              />
            </label>

            <div class="flex gap-2 justify-end pt-2">
              <button type="submit" name="decision" value="deny" class="btn btn-ghost">
                Deny
              </button>
              <button type="submit" name="decision" value="approve" class="btn btn-primary">
                Approve
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def authorize_error(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card bg-base-100 border border-error w-full max-w-md">
        <div class="card-body gap-3">
          <h1 class="card-title text-error">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" /> Connection failed
          </h1>
          <p class="text-sm">{error_message(@reason)}</p>
          <p class="text-xs text-base-content/60">
            Close this window and try connecting again from your AI assistant.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp error_message(:unknown_client), do: "This assistant is not registered with MeCP."

  defp error_message(:unregistered_redirect_uri),
    do: "The assistant supplied a callback address it did not register."

  defp error_message(:missing_redirect_uri), do: "The request is missing a callback address."

  defp error_message(:missing_pkce_challenge),
    do: "The assistant did not supply the required security challenge."

  defp error_message(:unsupported_challenge_method),
    do: "The assistant used an unsupported security method."

  defp error_message(:unsupported_response_type),
    do: "The assistant requested an unsupported authorization type."

  defp error_message(_), do: "The connection request could not be completed."
end
