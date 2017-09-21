defmodule Moview.Movies.Schedule.Schema do
  use Moview.Movies.BaseSchema, :model
  import  Moview.Movies.BaseSchema, only: [new_id: 2]

  alias Moview.Movies.Movie.Schema, as: MovieSchema
  alias Moview.Movies.Cinema.Schema,  as: CinemaSchema

  @schedule_resource 5

  schema "schedules" do
    embeds_one :data, __MODULE__.Data
    belongs_to :movie, MovieSchema
    belongs_to :cinema, CinemaSchema
    timestamps()
  end

  def changeset(%{} = params) do
    %__MODULE__{}
    |> change
    |> changeset(params)
    |> new_id(@schedule_resource)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> change
    |> changeset(params)
  end

  def changeset(%Ecto.Changeset{} = struct, params) do
    case fetch_field(struct, :data) do
      {_, nil} ->
        struct
        |> cast(params, [:cinema_id, :movie_id])
        |> put_embed(:data, __MODULE__.Data.changeset(params))
      {_, data} ->
        struct
        |> cast(params, [:cinema_id, :movie_id])
        |> put_embed(:data, __MODULE__.Data.changeset(data, params))
    end
  end

end

defmodule Moview.Movies.Schedule.Schema.Data do
  use Moview.Movies.BaseSchema, :model

  embedded_schema do
    field :day, :string
    field :time, :string
    field :schedule_type, :string, default: ""
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
    |> capitalize_day
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [:day, :time, :schedule_type])
    |> validate_required([:day, :time])
    |> capitalize_day
  end

  defp capitalize_day(%Ecto.Changeset{valid?: false} = changeset), do: changeset
  defp capitalize_day(%Ecto.Changeset{valid?: true} = changeset) do
    case changeset do
      %{changes: %{day: day}} ->
        put_change(changeset, :day, String.capitalize(day))
      _ ->
        changeset
    end
  end
end


