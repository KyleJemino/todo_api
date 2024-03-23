defmodule TodoApiWeb.TodoController do
  use TodoApiWeb, :controller

  alias TodoApi.Todos
  alias TodoApi.Todos.Todo

  action_fallback TodoApiWeb.FallbackController

  def index(conn, _params) do
    todos = Todos.list_todos()
    render(conn, :index, todos: todos)
  end

  def create(conn, %{"todo" => todo_params}) do
    case Todos.create_todo(todo_params) do
      {:ok, %Todo{} = todo} ->
        conn
        |> put_status(:created)
        |> render(:show, todo: todo)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
      _ ->
        conn
        |> put_status(500)
        |> render("error.json")
    end
  end

  def update(conn, %{"id" => id, "todo" => todo_params}) do
    todo = Todos.get_todo!(id)

    case Todos.update_todo(todo, todo_params) do
      {:ok, %Todo{} = todo} -> 
        render(conn, :show, todo: todo)
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
      _ ->
        conn
        |> put_status(500)
        |> render("error.json")
    end
  end

  def delete(conn, %{"id" => id}) do
    todo = Todos.get_todo!(id)

    case Todos.archive_todo(todo) do
      {:ok, %Todo{}} -> 
        send_resp(conn, :no_content, "")
    end
  end

  def move(conn, %{"id" => id, "target_before_id" => before_id}) do
    case Todos.move_todo(id, before_id) do
      {:ok, todos} ->
        render(conn, :index, todos: todos)
      _ ->
        conn
        |> put_status(500)
        |> render("error.json")
    end
  end
end
