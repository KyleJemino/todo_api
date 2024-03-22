defmodule TodoApi.TodosTest do
  use TodoApi.DataCase

  alias TodoApi.Todos

  describe "todos" do
    alias TodoApi.Todos.Todo

    import TodoApi.TodosFixtures

    @invalid_attrs %{"details" => nil, "archived_at" => nil}
    @valid_attrs %{"details" => "some details"} 

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

    test "get_todo!/1 returns the todo with given id" do
      todo = todo_fixture()
      assert Todos.get_todo!(todo.id) == todo
    end

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

    test "delete_todo/1 deletes the todo" do
      todo = todo_fixture()
      assert {:ok, %Todo{}} = Todos.delete_todo(todo)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_todo!(todo.id) end
    end

    test "change_todo/1 returns a todo changeset" do
      todo = todo_fixture()
      assert %Ecto.Changeset{} = Todos.change_todo(todo)
    end
  end
end
