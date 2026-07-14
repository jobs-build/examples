defmodule Fireside.Guestbook do
  @moduledoc "The guestbook: create + list entries. Exercised in-build to prove the exqlite NIF."
  import Ecto.Query
  alias Fireside.Repo
  alias Fireside.Guestbook.Entry

  def list_entries, do: Repo.all(from e in Entry, order_by: [desc: e.id], limit: 50)
  def create_entry(attrs), do: %Entry{} |> Entry.changeset(attrs) |> Repo.insert()
  def change_entry(entry \\ %Entry{}, attrs \\ %{}), do: Entry.changeset(entry, attrs)
end
