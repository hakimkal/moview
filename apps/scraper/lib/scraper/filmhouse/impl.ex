defmodule Moview.Scraper.Filmhouse.Impl do
  require Logger
  alias Moview.Movies.{Movie, Schedule}
  alias Moview.Scraper.Utils

  def do_scrape(cinemas) do
    cinemas
    |> Enum.map(fn %{data: %{url: url, address: a, branch_title: b}, id: cinema_id} ->
      Logger.info "Beginning to scrape: (#{b}) @ #{a}"
      Task.async(fn  ->  
        scrape(url)
        |> Enum.map(&create_or_return_movie/1)
        |> Enum.filter(fn
          %{movie: nil} -> false
          _ -> true
        end)
        |> Enum.map(fn %{movie: %{id: movie_id, data: %{title: title}}, times: times} ->
          Logger.debug("Fetching schedules to clear for movie #{title}")
          {:ok, schedules} = Schedule.get_schedules()
          deletion_candidates = get_schedules_for_deletion(schedules, cinema_id, movie_id)
          Logger.debug "Found #{length deletion_candidates} potential schedules to be cleared for #{title}"

          Logger.debug("Creating schedules params for movie #{title}")
          schedule_params = get_schedule_params(times, cinema_id, movie_id) 
          Logger.debug "Found #{length schedule_params} schedules to be inserted for #{title}"

          Logger.debug "Deleting schedules..."
          Enum.each(deletion_candidates, &Schedule.delete_schedule/1)
          Logger.debug "Creating new schedules..."
          Enum.each(schedule_params, &Schedule.create_schedule/1)
        end)
      end)
    end)
    |> Enum.each(&Task.await(&1, 120_000))
  end

  defp scrape(url) do
    url
    |> Utils.make_request(false)
    |> case do
      {:ok, body} ->
        body
        |> Floki.find("div.col-lg-7.col-md-6 > div.section_5")
        |> Enum.map(fn node ->
          Task.async(fn -> extract_info_from_node(node) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.filter(fn
          nil -> false
          _ -> true
        end)

      {:error, _} -> %{error: "Did not get response"}
    end
  end

  defp extract_info_from_node(movie_node) do
    title = movie_title(movie_node)
    Logger.debug "Extracted title: #{title}"
    Logger.debug "Extracting times..."

    times =
      movie_node
      |> movie_time_strings
      |> Enum.map(&expand_time_string/1)
      |> List.flatten

    %{title: title, times: times}
  end

  defp movie_title({_, _, [div_node | _]}) do
    {"div", [{"class", "clearfix"}], [title_node | _]} = div_node
    {"b", _, [{_, _, [title | _]}]} = title_node

    title
    |> String.trim
    |> String.downcase
    |> String.capitalize
  end

  defp create_or_return_movie(%{title: title} = map) do
    Logger.debug "Attempt to create movie: #{title}..."
    {:ok, movies} = Movie.get_movies()

    case Utils.get_movie_details(title) do
      {:error, _} = res ->
        Logger.error """
        #{title} is probably a Nigerian movie.
        get_movie_details(#{title}) returned #{inspect res}
        """
        Map.put(map, :movie, nil)
      {:ok, %{title: details_title, poster: poster, stars: _} = details} ->
        Enum.filter(movies, fn
          %{data: %{title: ^details_title, poster: ^poster}} -> true
          _ -> false
        end)
        |> case do
          [] ->
            case Movie.create_movie(details) do
              {:ok, movie} ->
                Logger.debug "Created movie: #{details_title}"
                Map.put(map, :movie, movie)
              _ = err ->
                Logger.error "Creating movie with #{inspect details} returned #{err}"
                Map.put(map, :movie, nil)
            end
          [movie|_] ->
            Logger.debug "Movie exists: #{movie.data.title}"
            Map.put(map, :movie, movie)
        end
    end
  end
  defp create_or_return_movie(err) do
    Logger.error "Could not create movies with #{inspect err}"
    %{movie: nil}
  end

  defp get_schedules_for_deletion(schedules, cinema_id, movie_id) do
    Enum.filter(schedules, fn
      %{cinema_id: ^cinema_id, movie_id: ^movie_id} -> true
      _ -> false
    end)
  end

  defp get_schedule_params(times, cinema_id, movie_id) do
    Enum.map(times, fn {day, list} ->
      Enum.map(list, fn time ->
        %{time: time, day: Utils.full_day(day), movie_id: movie_id, cinema_id: cinema_id, schedule_type: "2D"}
      end)
    end)
    |> List.flatten
  end

  defp movie_time_strings({_, _, [_ | nodes]}) do
    [{"div", [{"class", "post_text"}], [_ | nodes]}] = nodes
    [{"div", _, [_ | nodes]}] = nodes

    nodes
    |> Enum.reduce([], fn n, acc ->
      case is_list(n) do
        false ->
          case n do
            {"p", _, [first_node | rest]} ->
              other_nodes =
                case first_node do
                  {"strong", [], [str]} when is_binary(str) -> [first_node]
                  {"strong", [], [_ | other_nodes]} ->
                    Enum.map(other_nodes, fn
                      item when is_binary(item) -> String.trim(item)
                      item -> item
                    end)
                  _ -> [first_node]
                end

              nodes =
                other_nodes
                |> Kernel.++(rest)
                |> Enum.filter(fn
                  {"br", [], []} -> false
                  str when is_binary(str) ->
                    str
                    |> String.trim
                    |> String.length
                    |> Kernel.>(0)
                  _ -> true
                end)

              acc ++ nodes
             _ -> acc ++ [n]
          end
        true ->
          n
          |> Enum.map(fn
            {"p", _, nodes} -> nodes
            stuff -> stuff
          end)
          |> Kernel.++(acc)
      end
    end)
    |> Enum.filter(fn
      {"strong", [], [child_node]} when is_binary(child_node) -> true
      str when is_binary(str) -> true
      _ -> false
    end)
    |> Enum.reduce([], fn el_or_str, acc ->
      case el_or_str do
        {"strong", [], [day_range]} -> # Start another day range
          day_range =
            day_range
            |> String.replace_prefix("Late Night Show", "")
            |> String.replace_suffix(" :", ":")
            |> String.replace_suffix(",:", ":")
            |> String.trim

          day_range =
            case String.ends_with?(day_range, ":") do
              false -> "#{day_range}:"
              true -> day_range
            end

          List.insert_at(acc, -1, day_range)
        el_or_str ->
          el_or_str =
            el_or_str
            |> String.trim
            |> String.replace_suffix(",", "")
            |> String.replace_prefix(":", "")

          case List.last(acc) do
            nil -> [String.trim(el_or_str)]
            time_str ->
              case String.ends_with?(time_str, ":") do # Is this the start of a day range?
                true ->
                  last = "#{time_str} #{el_or_str}"
                  List.replace_at(acc, -1, last)
                false ->
                  last = "#{time_str}, #{el_or_str}"
                  List.replace_at(acc, -1, last)
              end
          end
      end
    end)
  end

  defp expand_time_string("Mon: " <> time_string), do: {"Mon", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string("Tue: " <> time_string), do: {"Tue", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string("Wed: " <> time_string), do: {"Wed", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string("Thu: " <> time_string), do: {"Thu", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string("Fri: " <> time_string), do: {"Fri", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string("Sat: " <> time_string), do: {"Sat", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string("Sun: " <> time_string), do: {"Sun", Utils.split_and_trim(time_string, ",")}
  defp expand_time_string(str) when is_binary(str) do
    Logger.debug "Expanding time string: #{str}"
    str =
      case str do
        <<range::binary-size(10)>> <> " " <> rest -> "#{range}: #{String.trim(rest)}"
        _ -> str
      end

    [day_range, time_string] = Utils.split_and_trim(str, ":", [parts: 2])
    time_string = String.downcase(time_string)

    day_range
    |> expand_range
    |> Enum.map(&(expand_time_string(&1, time_string)))
  end
  defp expand_time_string(day, time_string), do: expand_time_string("#{day}: #{time_string}")

  defp expand_range(str) do
    case String.contains?(str, "to") do
      false ->
        case String.contains?(str, ",") do
          false -> [str]
          true -> Utils.split_and_trim(str, ",")
        end
      true ->
        [start, stop] =
          case Utils.split_and_trim(str, "to") do
            [start, stop] -> [start, stop]
            [start] -> [start, start]
          end

        expand_range(start, stop, [])     
    end
  end
  defp expand_range(stop, stop, acc), do: acc ++ [stop]
  defp expand_range(start, stop, []), do: expand_range(Utils.day_after(start), stop, [start])
  defp expand_range(day, stop, acc), do: expand_range(Utils.day_after(day), stop, acc ++ [day])
end

