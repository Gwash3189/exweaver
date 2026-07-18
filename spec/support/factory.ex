defmodule Exweaver.Factory do
  use ExMachina.Ecto, repo: Exweaver.Repo

  alias Exweaver.Accounts.{Company, Customer, Permission, Role, RolePermission}
  alias Exweaver.Auth.AccessKey
  alias Exweaver.Flags.{EndUser, Environment, Flag, FlagAssignment, FlagState}

  def company_factory do
    %Company{name: sequence(:name, &"Acme #{&1}")}
  end

  def role_factory do
    %Role{name: sequence(:name, &"role-#{&1}")}
  end

  def permission_factory do
    %Permission{name: sequence(:name, &"permission-#{&1}")}
  end

  def role_permission_factory do
    %RolePermission{role: build(:role), permission: build(:permission)}
  end

  def customer_factory do
    %Customer{
      email: sequence(:email, &"customer-#{&1}@example.com"),
      hashed_password: nil,
      company: build(:company),
      role: build(:role)
    }
  end

  def environment_factory do
    %Environment{
      name: sequence(:name, &"Environment #{&1}"),
      key: sequence(:key, &"env-#{&1}"),
      company: build(:company)
    }
  end

  def flag_factory do
    %Flag{
      name: sequence(:name, &"Flag #{&1}"),
      key: sequence(:key, &"flag-#{&1}"),
      type: :boolean,
      company: build(:company)
    }
  end

  def flag_state_factory do
    %FlagState{
      state: :off,
      percentage: nil,
      flag: build(:flag),
      environment: build(:environment)
    }
  end

  def end_user_factory do
    %EndUser{
      identifier: sequence(:identifier, &"end-user-#{&1}"),
      company: build(:company)
    }
  end

  def flag_assignment_factory do
    %FlagAssignment{
      state: true,
      flag: build(:flag),
      environment: build(:environment),
      end_user: build(:end_user)
    }
  end

  def access_key_factory do
    %AccessKey{
      name: sequence(:name, &"Key #{&1}"),
      kind: :personal,
      hashed_value: sequence(:hashed_value, &"hash-#{&1}"),
      company: build(:company),
      customer: build(:customer)
    }
  end
end
