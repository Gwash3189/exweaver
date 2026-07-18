defmodule Exweaver.Auth do
  @moduledoc """
  Access-key mint/verify/revoke, both kinds sharing one code path
  - the `exw_<key_uuid>_<secret>` format, SHA-256
  storage , and constant-time comparison (authentication.md).
  """

  import Ecto.Query

  alias Exweaver.Accounts.{Company, Customer, Role}
  alias Exweaver.Auth.AccessKey
  alias Exweaver.Flags.Environment
  alias Exweaver.Pagination
  alias Exweaver.Repo
  alias Exweaver.UUIDv7

  @token_prefix "exw"

  @expiry_seconds %{
    "1d" => 86_400,
    "7d" => 7 * 86_400,
    "14d" => 14 * 86_400,
    "30d" => 30 * 86_400,
    "90d" => 90 * 86_400
  }

  @doc "Mints a personal (CLI) token for a customer. Default expiry is 30 days."
  def mint_personal_token(%Customer{} = customer, expires_in \\ :"30d") do
    mint(
      %{
        name: "CLI token",
        kind: :personal,
        company_id: customer.company_id,
        customer_id: customer.id
      },
      expires_in
    )
  end

  @doc "Mints an sdk key scoped to an environment; its role is always automated."
  def mint_sdk_key(%Environment{} = environment, name, expires_in \\ :never) do
    automated_role = Repo.get_by!(Role, name: "automated")

    mint(
      %{
        name: name,
        kind: :sdk,
        company_id: environment.company_id,
        environment_id: environment.id,
        role_id: automated_role.id
      },
      expires_in
    )
  end

  @doc """
  Parses and verifies a bearer token: fetches the access_key by its embedded
  id, then constant-time compares the secret's hash, then checks expiry.
  """
  def verify(token) do
    case parse_token(token) do
      {:ok, id, secret} -> verify_parsed(id, secret)
      :error -> {:error, :invalid_token}
    end
  end

  @doc "Both kinds, company-scoped (rest_api.md `GET /access_keys` — never exposes `hashed_value`)."
  def list_access_keys(%Company{} = company, opts \\ []) do
    from(a in AccessKey, where: a.company_id == ^company.id)
    |> Pagination.paginate(opts)
  end

  def get_access_key(%Company{} = company, id) do
    if UUIDv7.valid?(id), do: Repo.get_by(AccessKey, id: id, company_id: company.id)
  end

  def revoke(%AccessKey{} = access_key), do: Repo.delete(access_key)

  @doc "Revokes every personal access key belonging to a customer (Accounts.reset_customer)."
  def revoke_all_for_customer(%Customer{} = customer) do
    Repo.delete_all(from(a in AccessKey, where: a.customer_id == ^customer.id))
    :ok
  end

  defp mint(attrs, expires_in) do
    id = Exweaver.UUIDv7.generate()
    secret = generate_secret()

    changeset =
      AccessKey.changeset(
        %AccessKey{id: id},
        Map.merge(attrs, %{hashed_value: hash_secret(secret), expired_at: expires_at(expires_in)})
      )

    case Repo.insert(changeset) do
      {:ok, access_key} -> {:ok, access_key, @token_prefix <> "_" <> id <> "_" <> secret}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp verify_parsed(id, secret) do
    case Repo.get(AccessKey, id) do
      nil -> {:error, :invalid_token}
      access_key -> verify_secret(access_key, secret)
    end
  end

  defp verify_secret(access_key, secret) do
    if Plug.Crypto.secure_compare(access_key.hashed_value, hash_secret(secret)) do
      check_expiry(access_key)
    else
      {:error, :invalid_token}
    end
  end

  defp check_expiry(%AccessKey{expired_at: nil} = access_key), do: {:ok, access_key}

  defp check_expiry(%AccessKey{expired_at: expired_at} = access_key) do
    if DateTime.compare(DateTime.utc_now(), expired_at) == :gt do
      {:error, :token_expired}
    else
      {:ok, access_key}
    end
  end

  defp parse_token(token) when is_binary(token) do
    case String.split(token, "_", parts: 3) do
      [@token_prefix, id, secret] when byte_size(secret) > 0 -> validate_id(id, secret)
      _ -> :error
    end
  end

  defp parse_token(_), do: :error

  defp validate_id(id, secret) do
    case Ecto.UUID.cast(id) do
      {:ok, _} -> {:ok, id, secret}
      :error -> :error
    end
  end

  defp generate_secret do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  defp hash_secret(secret) do
    :sha256 |> :crypto.hash(secret) |> Base.encode16(case: :lower)
  end

  defp expires_at(:never), do: nil

  defp expires_at(expires_in) do
    seconds = Map.fetch!(@expiry_seconds, Atom.to_string(expires_in))
    DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)
  end
end
