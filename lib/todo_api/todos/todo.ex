defmodule TodoApi.Todos.Todo do
  use Ecto.Schema
  import Ecto.Changeset
  alias TodoApi.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "todos" do
    field :details, :string
    field :archived_at, :utc_datetime
    has_one :next, __MODULE__, foreign_key: :before_id 
    belongs_to :before, __MODULE__

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:details, :archived_at, :before_id])
    |> validate_required([:details])
    |> foreign_key_constraint(:before_id)
    |> unsafe_validate_unique(:before_id, Repo)
    |> unique_constraint(:before_id,
      name: :unique_before_id,
      message: "has already been taken"
    )
  end

  def create_changeset(todo, attrs) do
    todo
    |> cast(attrs, [:details, :before_id])
    |> validate_required([:details])
    |> foreign_key_constraint(:before_id)
    |> unsafe_validate_unique(:before_id, Repo)
    |> unique_constraint(:before_id,
      name: :unique_before_id,
      message: "has already been taken"
    )
  end

  def update_changeset(todo, attrs) do
    todo
    |> cast(attrs, [:details])
    |> validate_required([:details])
  end

  def temp_move_changeset(todo, attrs) do
    todo
    |> cast(attrs, [:before_id])
    |> change(archived_at: DateTime.utc_now(:second))
  end

  def archive_changeset(todo) do
    change(todo, archived_at: DateTime.utc_now(:second))
  end
end
