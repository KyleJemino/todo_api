defmodule TodoApi.Todos.Queries.TodoQuery do
  import Ecto.Query

  def is_unarchived(query, unarchived? \\ true) do
    if unarchived? do
      where(query, [q], is_nil(q.archived_at))
    else
      query
    end
  end

  def filter_where(query, params) do
    filters =
      Enum.reduce(params, dynamic(true), 
        fn 
          {"id", id}, dynamic ->
            dynamic([q], ^dynamic and q.id == ^id)

          {"before_id", before_id}, dynamic ->
            dynamic([q], ^dynamic and q.before_id == ^before_id)

          {"first?", first?}, dynamic ->
            if first? do
              dynamic([q], ^dynamic and is_nil(q.before_id))
            else
              dynamic
            end

          {"last?", last?}, dynamic ->
            if last? do
              dynamic([q], ^dynamic and fragment(
                "NOT EXISTS(SELECT * FROM todos t WHERE t.before_id = ? AND t.archived_at IS NULL)",
                q.id
              ))
            else
              dynamic
            end

          _, dynamic ->
            dynamic
        end
      )

    where(query, ^filters)
  end
end
