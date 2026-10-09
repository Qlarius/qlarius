defmodule Qlarius.MeCP.Keys do
  @moduledoc """
  Keyed one-way hashes for MeCP records: HMAC-SHA256 with a key derived from
  the endpoint's `secret_key_base`, one key per purpose. Unlike a plain hash,
  a short input (a search query, a MeFile id) can't be recovered by hashing
  guesses without the server secret.
  """

  @doc "Lowercase hex HMAC-SHA256 of `data` under the key for `purpose`."
  @spec hmac(String.t(), iodata()) :: String.t()
  def hmac(purpose, data) when is_binary(purpose) do
    :hmac
    |> :crypto.mac(:sha256, key(purpose), data)
    |> Base.encode16(case: :lower)
  end

  # Key derivation is deliberately slow (PBKDF2), so keys are cached per node.
  defp key(purpose) do
    cache_key = {__MODULE__, purpose}

    case :persistent_term.get(cache_key, nil) do
      nil ->
        secret = Application.fetch_env!(:qlarius, QlariusWeb.Endpoint)[:secret_key_base]
        key = Plug.Crypto.KeyGenerator.generate(secret, "mecp:" <> purpose, length: 32)
        :persistent_term.put(cache_key, key)
        key

      key ->
        key
    end
  end
end
