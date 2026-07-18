defmodule ExweaverCli.Token do
  @moduledoc """
  Helpers for the `exw_<key_uuid>_<secret>` personal-token format
  (authentication.md D8).

  `logout` needs the embedded access-key id to call `DELETE /access_keys/:id`.
  The secret is base64url and may itself contain `_`, so the token is split
  into exactly three parts — mirroring the server's `parse_token/1`.
  """

  @prefix "exw"

  @doc "Extracts the access-key id embedded in a token."
  @spec access_key_id(String.t()) :: {:ok, String.t()} | :error
  def access_key_id(token) when is_binary(token) do
    case String.split(token, "_", parts: 3) do
      [@prefix, id, secret] when byte_size(id) > 0 and byte_size(secret) > 0 -> {:ok, id}
      _ -> :error
    end
  end

  def access_key_id(_token), do: :error
end
