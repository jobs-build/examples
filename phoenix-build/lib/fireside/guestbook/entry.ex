defmodule Fireside.Guestbook.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entries" do
    field :name, :string
    field :message, :string
    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:name, :message])
    |> validate_required([:name, :message])
    |> validate_length(:name, max: 80)
    |> validate_length(:message, max: 500)
  end
end
