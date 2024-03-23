defmodule TodoApiWeb.TodoControllerTest do
  use TodoApiWeb.ConnCase

  import TodoApi.TodosFixtures

  alias TodoApi.Todos.Todo

  @create_attrs %{
    details: "some details",
  }
  @update_attrs %{
    details: "some updated details",
  }
  @invalid_attrs %{details: nil, archived_at: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup do
      todos =
        Enum.map(1..10, fn x ->
          safe_todo_fixture(%{
            "details" => "#{x}"
          }) 
        end)

      {:ok, todos: todos}
    end

    test "lists all todos", %{conn: conn} do
      conn = get(conn, ~p"/todos")
      todos_from_response = json_response(conn, 200)["data"]

      assert Enum.count(todos_from_response) == 10
    end
  end

  describe "create todo" do
    test "renders todo when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/todos", todo: @create_attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/todos")
      todo_list = json_response(conn, 200)["data"]

      assert Enum.any?(todo_list, &(&1["id"] == id)) 
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/todos", todo: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update todo" do
    setup [:create_todo]

    test "renders todo when data is valid", %{conn: conn, todo: %Todo{id: id}} do
      conn = patch(conn, ~p"/todos/#{id}/edit", todo: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/todos")
      todo_list = json_response(conn, 200)["data"]

      assert %{
        "details" => "some updated details"
      } = Enum.find(todo_list, &(&1["id"] == id)) 
    end

    test "renders errors when data is invalid", %{conn: conn, todo: todo} do
      conn = patch(conn, ~p"/todos/#{todo}/edit", todo: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete todo" do
    setup [:create_todo]

    test "deletes chosen todo", %{conn: conn, todo: todo} do
      conn = delete(conn, ~p"/todos/#{todo}")
      assert response(conn, 204)

      conn = get(conn, ~p"/todos")
      todo_list = json_response(conn, 200)["data"]

      refute Enum.any?(todo_list, &(&1["id"] == todo.id)) 
    end
  end

  defp create_todo(_) do
    todo = todo_fixture()
    %{todo: todo}
  end
end
