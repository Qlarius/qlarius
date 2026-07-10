defmodule QlariusWeb.MeCPOAuthController do
  @moduledoc """
  OAuth 2.1 authorization server surface for MCP remote connectors:
  discovery metadata, dynamic client registration, the user approval page
  (which creates the MeCP grant), and the token endpoint.
  """

  use QlariusWeb, :controller

  alias Qlarius.MeCP.OAuth
  alias Qlarius.YouData.Traits

  plug :put_view, html: QlariusWeb.MeCPOAuthHTML
  plug :rate_limit when action in [:register, :token]

  # --- discovery (RFC 9728 + RFC 8414) -----------------------------------------

  def protected_resource_metadata(conn, _params) do
    json(conn, %{
      "resource" => url(conn, ~p"/mecp/mcp"),
      "authorization_servers" => [origin(conn)],
      "bearer_methods_supported" => ["header"]
    })
  end

  def authorization_server_metadata(conn, _params) do
    json(conn, %{
      "issuer" => origin(conn),
      "authorization_endpoint" => url(conn, ~p"/mecp/oauth/authorize"),
      "token_endpoint" => url(conn, ~p"/mecp/oauth/token"),
      "registration_endpoint" => url(conn, ~p"/mecp/oauth/register"),
      "response_types_supported" => ["code"],
      "grant_types_supported" => ["authorization_code", "refresh_token"],
      "code_challenge_methods_supported" => ["S256"],
      "token_endpoint_auth_methods_supported" => ["none"]
    })
  end

  # --- dynamic client registration (RFC 7591) -----------------------------------

  def register(conn, params) do
    case OAuth.register_client(params) do
      {:ok, client} ->
        conn
        |> put_status(:created)
        |> json(%{
          "client_id" => client.client_id,
          "client_name" => client.client_name,
          "redirect_uris" => client.redirect_uris,
          "token_endpoint_auth_method" => client.token_endpoint_auth_method,
          "grant_types" => ["authorization_code", "refresh_token"],
          "response_types" => ["code"],
          "client_id_issued_at" => DateTime.to_unix(DateTime.utc_now())
        })

      {:error, _changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => "invalid_client_metadata"})
    end
  end

  # --- authorization (user approval creates the grant) ----------------------------

  def authorize(conn, params) do
    case OAuth.validate_authorize_request(params) do
      {:ok, client, checked} ->
        render(conn, :authorize,
          client: client,
          checked: checked,
          categories: Traits.list_trait_categories(),
          page_title: "Connect #{client.client_name || "an AI assistant"}"
        )

      {:error, reason} ->
        # Per OAuth 2.1, invalid client/redirect_uri must not redirect.
        conn
        |> put_status(:bad_request)
        |> render(:authorize_error, reason: reason, page_title: "Connection failed")
    end
  end

  def approve(conn, %{"decision" => decision} = params) do
    # Re-validate everything server-side; hidden form fields are untrusted.
    case OAuth.validate_authorize_request(params) do
      {:ok, client, checked} ->
        case decision do
          "approve" -> do_approve(conn, client, checked, params)
          _ -> deny_redirect(conn, checked)
        end

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> render(:authorize_error, reason: reason, page_title: "Connection failed")
    end
  end

  defp do_approve(conn, client, checked, params) do
    scope = conn.assigns.current_scope
    # Snapshot the active persona's MeFile; own the grant as the true user so
    # request-time resolution follows whichever proxy persona is active.
    me_file = scope.user.me_file

    grant_attrs = %{
      tier: String.to_integer(params["tier"] || "3"),
      category_ids: parse_category_ids(params),
      budget_max: parse_budget_max(params["budget_max"]),
      user_id: scope.true_user.id
    }

    case OAuth.approve_authorization(client, me_file, grant_attrs, checked) do
      {:ok, code, _grant} ->
        redirect(conn, external: callback_url(checked, code: code))

      {:error, _changeset} ->
        conn
        |> put_status(:bad_request)
        |> render(:authorize_error, reason: :grant_failed, page_title: "Connection failed")
    end
  end

  defp deny_redirect(conn, checked) do
    redirect(conn, external: callback_url(checked, error: "access_denied"))
  end

  defp callback_url(checked, query_params) do
    query =
      query_params
      |> Enum.into(%{})
      |> maybe_put_state(checked.state)
      |> URI.encode_query()

    uri = URI.parse(checked.redirect_uri)

    existing = if uri.query in [nil, ""], do: "", else: uri.query <> "&"
    %{uri | query: existing <> query} |> URI.to_string()
  end

  defp maybe_put_state(params, nil), do: params
  defp maybe_put_state(params, state), do: Map.put(params, :state, state)

  # --- token endpoint --------------------------------------------------------------

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    OAuth.exchange_code(
      params["client_id"],
      params["code"],
      params["code_verifier"],
      params["redirect_uri"]
    )
    |> token_response(conn)
  end

  def token(conn, %{"grant_type" => "refresh_token"} = params) do
    OAuth.refresh(params["client_id"], params["refresh_token"])
    |> token_response(conn)
  end

  def token(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{"error" => "unsupported_grant_type"})
  end

  defp token_response({:ok, response}, conn), do: json(conn, response)

  defp token_response({:error, reason}, conn) do
    status = if reason == :invalid_client, do: :unauthorized, else: :bad_request
    conn |> put_status(status) |> json(%{"error" => Atom.to_string(reason)})
  end

  # --- helpers -----------------------------------------------------------------------

  # DCR and token are unauthenticated by design (public clients); per-IP
  # throttling keeps them from becoming a write amplifier. Claude registers a
  # fresh client per connection, so the ceiling stays generous.
  defp rate_limit(conn, _opts) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case Hammer.check_rate("mecp_oauth:#{ip}", 60_000, 30) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{"error" => "slow_down"})
        |> halt()
    end
  end

  defp origin(conn) do
    uri = conn |> url(~p"/") |> URI.parse()
    %{uri | path: nil, query: nil} |> URI.to_string()
  end

  defp parse_category_ids(params) do
    params
    |> Map.get("category_ids", [])
    |> Enum.map(&String.to_integer/1)
  end

  defp parse_budget_max(value) when value in [nil, ""], do: nil

  defp parse_budget_max(value) do
    case Integer.parse(value) do
      {max, _} when max >= 0 -> max
      _ -> nil
    end
  end
end
