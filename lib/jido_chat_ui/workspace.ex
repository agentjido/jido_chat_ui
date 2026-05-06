defmodule JidoChatUI.Workspace do
  @moduledoc """
  Single-user workspace identity for the local adapter workbench.

  The UI no longer asks developers to log in, but the existing room and bridge
  schemas still need a `user_id`. This module creates and reuses one internal
  user for that ownership boundary.
  """

  import Ecto.Changeset

  alias JidoChatUI.Accounts.{Scope, User}
  alias JidoChatUI.Repo

  @email "workspace@jido-chat-ui.local"

  def email, do: @email

  def scope! do
    @email
    |> user!()
    |> Scope.for_user()
  end

  def user!, do: user!(@email)

  def user!(email) when is_binary(email) do
    Repo.get_by(User, email: email) || insert_workspace_user!(email)
  end

  defp insert_workspace_user!(email) do
    now = DateTime.utc_now(:second)

    changeset =
      %User{}
      |> User.email_changeset(%{email: email})
      |> put_change(:confirmed_at, now)

    case Repo.insert(changeset,
           on_conflict: [set: [updated_at: now]],
           conflict_target: :email,
           returning: true
         ) do
      {:ok, %User{} = user} -> user
      {:error, _changeset} -> Repo.get_by!(User, email: email)
    end
  end
end
