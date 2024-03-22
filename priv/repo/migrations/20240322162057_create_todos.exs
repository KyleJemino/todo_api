defmodule TodoApi.Repo.Migrations.CreateTodos do
  use Ecto.Migration

  def change do
    create table(:todos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :details, :string
      add :archived_at, :utc_datetime
      add :before_id, references(:todos, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:todos, [
        "COALESCE(before_id::TEXT, 'NULL_VALUE')"
      ],
      where: "archived_at IS NULL",
      name: :unique_before_id
    )
  end
end
