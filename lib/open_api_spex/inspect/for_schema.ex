defimpl Inspect, for: OpenApiSpex.Schema do
  import Inspect.Algebra

  def inspect(parameter, opts) do
    map =
      parameter
      |> Map.from_struct()
      |> Enum.filter(fn
        {_key, nil} -> false
        {_key, _value} -> true
      end)
      |> Map.new()

    # Note: We cannot use Inspect.Map.inspect/4 or Inspect.Map.inspect_as_struct/5
    # because they are private functions in the Inspect.Map module and not part of
    # the public API. Instead, we use Inspect.Algebra functions (concat, to_doc).
    concat(["#OpenApiSpex.Schema<", to_doc(map, opts), ">"])
  end
end
