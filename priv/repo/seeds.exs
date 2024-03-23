alias TodoApi.Todos

Enum.each(1..10, fn x ->
  Todos.create_todo(%{
    "details" => "task #{x}"
  })
end)
