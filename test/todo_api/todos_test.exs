defmodule TodoApi.TodosTest do
  use TodoApi.DataCase

  alias TodoApi.Todos
  alias TodoApi.Todos.Todo

  import TodoApi.TodosFixtures

  @invalid_attrs %{"details" => nil, "archived_at" => nil}
  @valid_attrs %{"details" => "some details"} 

  describe "list_todos/0" do
    test "list_todos/0 returns all todos without archived_at" do
      todo = todo_fixture()
      _archived_todo = todo_fixture(%{
        "archived_at" => DateTime.utc_now()
      })

      todos = Todos.list_todos()

      assert todos == [todo]
      assert Enum.count(todos) == 1
    end

    test "list_todos/0 returns all todos in correct order" do
      todo_1 = todo_fixture()
      todo_2 = todo_fixture(%{
        "before_id" => todo_1.id
      })
      todo_3 = todo_fixture(%{
        "before_id" => todo_2.id
      })
      todo_4 = todo_fixture(%{
        "before_id" => todo_3.id
      })

      assert [todo_1, todo_2, todo_3, todo_4] == Todos.list_todos()
    end
  end

  describe "get_todo!/1" do
    test "get_todo!/1 returns the todo with given id" do
      todo = todo_fixture()
      assert Todos.get_todo!(todo.id) == todo
    end
  end

  describe "create_todo/1" do
    test "create_todo/1 with valid data creates a todo" do
      assert {:ok, %Todo{} = todo} = Todos.create_todo(@valid_attrs)
      assert todo.details == "some details"
    end

    test "create_todo/1 with invalid data returns changeset" do
      assert {:error, %Ecto.Changeset{}} = Todos.create_todo(@invalid_attrs)
    end

    test "create_todo/1 only allows 1 todo with no before_id" do
      _todo = todo_fixture()
      assert_raise MatchError, &todo_fixture/0

      assert 1 == Enum.count(Todos.list_todos)
    end

    test "create_todo/1 only allows unique before_id" do
      %{id: todo_id} = todo_fixture()

      attr_with_before_id = Map.put(@valid_attrs, "before_id", todo_id)

      assert %Todo{before_id: ^todo_id} = todo_fixture(attr_with_before_id)
      assert_raise MatchError, fn -> todo_fixture(attr_with_before_id) end

      assert 2 == Enum.count(Todos.list_todos)
    end

    test "create_todo/1 with archived_at ignores archived_at" do
      attrs_with_archived_at = %{details: "some details", archived_at: DateTime.utc_now()}
      assert {:ok, %Todo{
        archived_at: nil
      }} = Todos.create_todo(attrs_with_archived_at)
    end

    test "create_todo/1 attaches last todo to new todo" do
      %Todo{id: last_todo_id} = todo_fixture()
      
      assert {:ok, %Todo{before_id: ^last_todo_id}} = Todos.create_todo(@valid_attrs)
    end
  end

  describe "move_todo/1" do
    setup do
      todos = 
        Enum.map(1..10, fn _ ->
          {:ok, todo} = Todos.create_todo(@valid_attrs)
          todo
        end)

      {:ok, %{todos: todos}}
    end

    test "change parent_id of todo to target", %{todos: todos} do
      {:ok, new_todo} = Todos.create_todo(@valid_attrs)
      target_before_id = Enum.at(todos, 4).id

      {:ok, updated_todos} = Todos.move_todo(new_todo.id, target_before_id)
      
      assert %Todo{before_id: ^target_before_id} = Enum.find(updated_todos, &(&1.id == new_todo.id))
    end

    test "also updates before_id of next todos", %{todos: todos} do
      %{id: todo_id, before_id: original_before_id} = Enum.at(todos, 8)
      %{id: todo_next_id} = Enum.at(todos, 9)
      %{id: target_id} = Enum.at(todos, 0)
      %{id: target_next_id} = Enum.at(todos, 1)

      {:ok, updated_todos} = Todos.move_todo(todo_id, target_id)

      assert %Todo{before_id: ^target_id} = Enum.find(updated_todos, &(&1.id == todo_id))
      assert %Todo{before_id: ^original_before_id} = Enum.find(updated_todos, &(&1.id == todo_next_id))
      assert %Todo{before_id: ^todo_id} = Enum.find(updated_todos, &(&1.id == target_next_id))
    end

    test "changes to before_id to nil if moved to first", %{todos: todos} do
      %{id: todo_id} = Enum.at(todos, 9)
      %{id: first_id} = Enum.at(todos, 0)

      {:ok, updated_todos} = Todos.move_todo(todo_id, nil)

      assert %Todo{before_id: ^todo_id} = Enum.find(updated_todos, &(&1.id == first_id))
      assert %Todo{before_id: nil} = Enum.find(updated_todos, &(&1.id == todo_id))
    end

    test "able to move last to first", %{todos: todos} do
      %{id: last_id} = Enum.at(todos, 9)
      %{id: first_id} = Enum.at(todos, 0)

      {:ok, updated_todos} = Todos.move_todo(last_id, nil)

      assert %Todo{before_id: nil} = Enum.find(updated_todos, &(&1.id == last_id))
      assert %Todo{before_id: ^last_id} = Enum.find(updated_todos, &(&1.id == first_id))
    end


    test "able to move first to last", %{todos: todos} do
      %{id: last_id, before_id: original_last_id} = Enum.at(todos, 9)
      %{id: first_id} = Enum.at(todos, 0)
      %{id: second_id} = Enum.at(todos, 1)

      {:ok, updated_todos} = Todos.move_todo(first_id, last_id)

      assert %Todo{before_id: ^last_id} = Enum.find(updated_todos, &(&1.id == first_id))
      assert %Todo{before_id: ^original_last_id} = Enum.find(updated_todos, &(&1.id == last_id))
      assert %Todo{before_id: nil} = Enum.find(updated_todos, &(&1.id == second_id))
    end

    test "able to move 1 position", %{todos: todos} do
      %{id: second_id} = Enum.at(todos, 1)
      %{id: third_id, before_id: original_before_id} = Enum.at(todos, 2)
      %{id: fourth_id} = Enum.at(todos, 3)

      {:ok, updated_todos} = Todos.move_todo(third_id, fourth_id)

      assert %Todo{before_id: ^fourth_id} = Enum.find(updated_todos, &(&1.id == third_id))
      assert %Todo{before_id: ^original_before_id} = Enum.find(updated_todos, &(&1.id == fourth_id))

      {:ok, updated_todos} = Todos.move_todo(third_id, second_id)
      assert %Todo{before_id: ^original_before_id} = Enum.find(updated_todos, &(&1.id == third_id))
      assert %Todo{before_id: ^third_id} = Enum.find(updated_todos, &(&1.id == fourth_id))
    end

    test "returns error if moving to current position", %{todos: todos} do
      %{id: third_id} = Enum.at(todos, 3)
      %{id: fourth_id} = Enum.at(todos, 2)

      assert {:error, "No change"} = Todos.move_todo(third_id, fourth_id)
    end

    test "able to be move more than 50 times", %{todos: todos} do
      {:ok, %{id: moving_todo_id }} = Todos.create_todo(@valid_attrs)

      Enum.each(1..50, fn x ->
        target_index = rem(x, 10)

        %{before_id: original_before_id} = Todos.get_todo!(moving_todo_id)
        maybe_next_todo = Todos.get_todo_by_params([before_id: moving_todo_id])
        %{id: target_id} = Enum.at(todos, target_index)
        maybe_target_next_todo = Todos.get_todo_by_params([before_id: target_id])

        {:ok, updated_todos} = Todos.move_todo(moving_todo_id, target_id)

        assert %Todo{before_id: ^target_id} = Enum.find(updated_todos, &(&1.id == moving_todo_id))

        if not is_nil(maybe_target_next_todo) do
          maybe_target_next_todo = Enum.find(updated_todos, &(&1.id == maybe_target_next_todo.id))

          assert %Todo{before_id: ^moving_todo_id} = Enum.find(updated_todos, &(&1.id == maybe_target_next_todo.id))
        end

        if not is_nil(maybe_next_todo) do
          assert %Todo{before_id: ^original_before_id} = Enum.find(updated_todos, &(&1.id == maybe_next_todo.id))
        end
      end)
    end
  end
end
