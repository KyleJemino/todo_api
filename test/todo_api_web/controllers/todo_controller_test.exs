defmodule TodoApiWeb.TodoControllerTest do
  use TodoApiWeb.ConnCase

  import TodoApi.TodosFixtures

  alias TodoApi.Todos.Todo

  @create_attrs %{
    details: "some details",
    archived_at: ~U[2024-03-21 16:20:00Z]
  }
  @update_attrs %{
    details: "some updated details",
    archived_at: ~U[2024-03-22 16:20:00Z]
  }
  @invalid_attrs %{details: nil, archived_at: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all todos", %{conn: conn} do
      conn = get(conn, ~p"/api/todos")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create todo" do
    test "renders todo when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/todos", todo: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/todos/#{id}")

      assert %{
               "id" => ^id,
               "archived_at" => "2024-03-21T16:20:00Z",
               "details" => "some details"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/todos", todo: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update todo" do
    setup [:create_todo]

    test "renders todo when data is valid", %{conn: conn, todo: %Todo{id: id} = todo} do
      conn = put(conn, ~p"/api/todos/#{todo}", todo: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/todos/#{id}")

      assert %{
               "id" => ^id,
               "archived_at" => "2024-03-22T16:20:00Z",
               "details" => "some updated details"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, todo: todo} do
      conn = put(conn, ~p"/api/todos/#{todo}", todo: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete todo" do
    setup [:create_todo]

    test "deletes chosen todo", %{conn: conn, todo: todo} do
      conn = delete(conn, ~p"/api/todos/#{todo}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/todos/#{todo}")
      end
    end
  end

  defp create_todo(_) do
    todo = todo_fixture()
    %{todo: todo}
  end
end
