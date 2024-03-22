defmodule TodoApi.TodosFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TodoApi.Todos` context.
  """

  @doc """
  Generate a todo.
  """

  alias TodoApi.Todos.Todo
  alias TodoApi.Repo

  def todo_fixture(attrs \\ %{}) do
    updated_attrs =
      attrs
      |> Enum.into(%{
        "details" => "some details"
      })

    {:ok, todo} =
      %Todo{}
      |> Todo.changeset(updated_attrs)
      |> Repo.insert()

    todo
  end
end
