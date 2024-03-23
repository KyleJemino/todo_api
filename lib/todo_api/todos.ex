defmodule TodoApi.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias TodoApi.Repo

  alias TodoApi.Todos.Todo
  alias TodoApi.Todos.Queries.TodoQuery, as: TQ

  @doc """
  Returns the list of todos.

  ## Examples

      iex> list_todos()
      [%Todo{}, ...]

  """
  def list_todos do
    todo_root_query =
      Todo
      |> TQ.is_unarchived()
      |> TQ.filter_where(%{:first? => true})
      |> select([q, lt], %{id: q.id, before_id: q.before_id, path: fragment("ARRAY[?]", q.id), archived_at: q.archived_at})

    todo_recursion_query =
      Todo
      |> join(:inner, [q], lt in "linked_list", on: q.before_id == lt.id and is_nil(q.archived_at) and is_nil(lt.archived_at))
      |> select([q, lt], %{id: q.id, before_id: q.before_id, path: fragment("? || ?", lt.path, q.id), archived_at: q.archived_at})

    todo_query =
      todo_root_query
      |> union_all(^todo_recursion_query)

    Todo
    |> recursive_ctes(true)
    |> with_cte("linked_list", as: ^todo_query)
    |> join(:inner, [q], l in "linked_list", on: q.id == l.id)
    |> where([q, _l], is_nil(q.archived_at))
    |> order_by([q, l], asc: l.path)
    |> Repo.all()
  end

  @doc """
  Gets a single todo.

  Raises `Ecto.NoResultsError` if the Todo does not exist.

  ## Examples

      iex> get_todo!(123)
      %Todo{}

      iex> get_todo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_todo!(id), do: Repo.get!(Todo, id)

  def get_todo_by_params(params) do
    Todo 
    |> TQ.filter_where(params)
    |> Repo.one()
  end

  @doc """
  Creates a todo.

  ## Examples

      iex> create_todo(%{field: value})
      {:ok, %Todo{}}

      iex> create_todo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_todo(attrs \\ %{}) do
    multi_result =
      attrs
      |> create_multi()
      |> Repo.transaction()

    case multi_result do
      {:ok, %{new_todo: todo}} -> {:ok, todo}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Updates a todo.

  ## Examples

      iex> update_todo(todo, %{field: new_value})
      {:ok, %Todo{}}

      iex> update_todo(todo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_todo(%Todo{} = todo, attrs) do
    todo
    |> Todo.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a todo.

  ## Examples

      iex> delete_todo(todo)
      {:ok, %Todo{}}

      iex> delete_todo(todo)
      {:error, %Ecto.Changeset{}}

  """
  def delete_todo(%Todo{} = todo) do
    Repo.delete(todo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking todo changes.

  ## Examples

      iex> change_todo(todo)
      %Ecto.Changeset{data: %Todo{}}

  """
  def change_todo(%Todo{} = todo, attrs \\ %{}) do
    Todo.changeset(todo, attrs)
  end

  def move_todo(todo_id, target_before_id) do
    result =
      todo_id
      |> move_multi(target_before_id)
      |> Repo.transaction()

    case result do
      {:ok, _} -> {:ok, list_todos()}
      {:error, _operation, error, _changes} -> {:error, error}
    end
  end

  def archive_todo(%Todo{} = todo) do
    result =
      todo
      |> archive_multi()
      |> Repo.transaction()

    case result do
      {:ok, %{archive_todo: todo}} -> {:ok, todo}
      {:error, _, _, _} = errors -> 
        IO.inspect errors
        {:error, "Something went wrong"}
    end
  end

  defp create_multi(attrs) do
    Multi.new()
    |> Multi.one(:last_todo, fn _multi ->
      Todo
      |> TQ.is_unarchived()
      |> TQ.filter_where(%{
        last?: true
      })
    end)
    |> Multi.insert(:new_todo, fn %{last_todo: last_todo} ->
        maybe_attrs_with_before_id =
          if is_nil(last_todo) do
            attrs
          else
            Map.put(attrs, "before_id", last_todo.id)
          end
        
        Todo.create_changeset(%Todo{}, maybe_attrs_with_before_id)
    end)
  end

  defp update_before_and_archive(todo, attrs) do
    todo
    |> Todo.temp_move_changeset(attrs)
    |> Repo.update()
  end

  defp move_multi(todo_id, target_before_id) do
    Multi.new()
    |> Multi.run(:current_todo, fn repo, _multi ->
      current_query =
        Todo
        |> TQ.is_unarchived()
        |> TQ.filter_where(%{
          :id => todo_id
        })

      case repo.one(current_query) do
        %Todo{before_id: ^target_before_id} ->
          {:error, "No change"}
        %Todo{} = todo ->
          {:ok, todo}
        _ ->
          {:error, "Something went wrong"}
      end
    end)
    |> Multi.all(:todos, fn _multi ->
      or_where_filters =
        if is_nil(target_before_id) do
          [
            first?: true,
            before_id: todo_id
          ]
        else
          [
            before_id: todo_id,
            before_id: target_before_id
          ]
        end

      Todo
      |> TQ.filter_or_where(or_where_filters)
      |> distinct(true)
    end)
    |> Multi.run(:updated_and_archived, 
        fn _repo, %{todos: todos, current_todo: current_todo} ->
          %{
            before_id: original_before_id
          } = current_todo

          Enum.reduce([current_todo | todos], {:ok, []}, fn
            todo, {:ok, todo_id_acc} -> 
              attrs =
                case todo do
                  %{id: ^todo_id} ->
                    %{"before_id" => target_before_id}
                  %{before_id: ^todo_id} ->
                    %{"before_id" => original_before_id}
                  %{before_id: ^target_before_id} ->
                    %{"before_id" => todo_id}
                end

              case update_before_and_archive(todo, attrs) do
                {:ok, %{id: id}} -> {:ok, [id | todo_id_acc]}
                error -> error
              end

            _todo, error -> error
          end)
        end
    )
    |> Multi.update_all(:updated_todos, 
      fn %{updated_and_archived: todo_ids} ->
        from(
          t in Todo, 
          where: fragment("?::TEXT", t.id) in ^todo_ids, 
          update: [set: [archived_at: nil]]
        )
      end, 
      []
    )
  end
  
  def archive_multi(todo) do
    Multi.new()
    |> Multi.update(:archive_todo, Todo.archive_changeset(todo))
    |> Multi.one(:next_todo, fn _multi ->
        Todo
        |> TQ.is_unarchived()
        |> TQ.filter_where(%{
          before_id: todo.id
        })
    end)
    |> Multi.run(:maybe_update_next, fn repo, %{next_todo: next_todo} ->
      if not is_nil(next_todo) do
        next_todo
        |> Todo.archive_next_changeset(%{
          "before_id" => todo.before_id
        })
        |> repo.update()
      else
        {:ok, "Nothing to update"}
      end
    end)
  end
end
