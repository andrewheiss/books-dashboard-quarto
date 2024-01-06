library(tidyverse)
library(glue)
library(googlesheets4)
library(plumber)

person_lookup <- tribble(
  ~person_id,  ~name,       ~sheet_id,                                      ~goodreads,
  "andrew",    "Andrew",    "1oQqX4G4CJaa7cgfsEW4LeorcQwxVeYe0Q83WrJbcN6Y", TRUE,
  "nancy",     "Nancy",     "1dL16YfxQISsXz48mtJBd7QavyG5M4GvCcleuCIPjTz8", TRUE,
  "rachel",    "Rachel",    "1QYjeFP2UVYc2JcpWuJbMqDydKCq_GnBgiktcuu9WikM", TRUE,
  "miriam",    "Miriam",    "1LAVf7gaViZLBvf9Zy9QnmuwvOnpmnJhlmkVcIa56hdY", TRUE,
  "benjamin",  "Benjamin",  "1EHTpMW03XOzQtY8SrBSIVf7jNj-ulofoKVPl0bNRiLs", FALSE,
  "zoe",       "Zoë",       "1u1XSStcHU4akkf3LE8mvHgzE7jDvJcLzPKKDMAxJkAw", FALSE,
  "alexander", "Alexander", "1tPK4cJNY2zrgDXnFdPaErgFx6c7bMus4TyCnT4i5f2c", FALSE
)

parse_books <- function(name, sheet_id, goodreads) {
  gs4_deauth()  # All the sheets are public so there's no need to log in
  local_gs4_quiet()  # Turn off the googlesheets messages
  
  # Clean up the data from Google. The Goodreads data is a little different from
  # the manual Google Form, so we need to rename/select columns differently
  if (goodreads == TRUE) {
    results_raw <- read_sheet(sheet_id) |> 
      # Goodreads includes books added to the "to-read" shelf here, so we need
      # to omit them, since they haven't been read yet
      filter(!is.na(user_read_at)) |> 
      select(
        timestamp = user_read_at, 
        book_title = title, 
        book_author = author_name
      ) |> 
      mutate(timestamp = dmy_hms(timestamp))
  } else {
    results_raw <- read_sheet(sheet_id) |> 
      select(
        timestamp = Timestamp,
        book_title = `What was the title of the book?`,
        book_author = `Who was the author?`
      )
  }
  
  # Add some helper columns
  results <- results_raw |> 
    mutate(
      person = name,
      read_year = year(timestamp),
      read_month = month(timestamp),
      read_month_fct = month(timestamp, label = TRUE, abbr = FALSE),
      read_date_nice = str_replace(format(timestamp, "%B %e, %Y"), "  ", " ")
    ) |> 
    filter(read_year >= 2024)
  
  total <- results |> nrow()
  
  if (total > 0) {
    most_recent <- results |> arrange(desc(timestamp)) |> slice(1)
  } else {
    most_recent <- tibble(
      book_title = "Nothing yet", 
      book_author = "Nothing yet", 
      read_date_nice = "Nothing yet"
    )
  }
  
  monthly_count <- results |> 
    group_by(read_month_fct, .drop = FALSE) |> 
    summarize(count = n())
  
  # TODO: Somday return all the books as a dataframe for later use in a table or something
  
  return(
    list(
      name = name,
      count = total,
      monthly_count = monthly_count,
      most_recent = list(
        title = pull(most_recent, book_title),
        author = pull(most_recent, book_author),
        date = pull(most_recent, read_date_nice)
      )#,
      #data = results
    )
  )
}


# Custom error handling ---------------------------------------------------

# Adapted from https://unconj.ca/blog/structured-errors-in-plumber-apis.html

api_error <- function(message, status) {
  err <- structure(
    list(message = message, status = status),
    class = c("api_error", "error", "condition")
  )
  signalCondition(err)
}

error_handler <- function(req, res, err) {
  if (!inherits(err, "api_error")) {
    res$status <- 500
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
      status = 500,
      message = "Internal server error."
    ))
    res$setHeader("content-type", "application/json")  # Make this JSON
    
    # Print the internal error so we can see it from the server side. A more
    # robust implementation would use proper logging.
    print(err)
  } else {
    # We know that the message is intended to be user-facing.
    res$status <- err$status
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
      status = err$status,
      message = err$message
    ))
    res$setHeader("content-type", "application/json")  # Make this JSON
  }
  
  res
}

not_found <- function(message = "Not found.") {
  api_error(message = message, status = 404)
}

missing_params <- function(message = "Missing required parameters.") {
  api_error(message = message, status = 400)
}

invalid_params <- function(message = "Invalid parameter value(s).") {
  api_error(message = message, status = 400)
}


# Actual plumber API magic ------------------------------------------------

#* @apiTitle Heissatopia API
#* @apiDescription An API for accessing different data things about our family
#* @apiVersion 0.0.1
#* @apiTag Books Access data about reading
#* @apiTag Debugging Endpoints to help with debugging


#* Show date and time information
#* @tag Debugging
#* @serializer unboxedJSON
#* @get /_now
function() {
  list(current_date = lubridate::today(), current_time = lubridate::now())
}


#* Return JSON data about books
#* @tag Books
#* @serializer json
#* @get /books
function(res, person) {
  if (!(person %in% c("all", person_lookup$person_id))) {
    invalid_params(glue("Person '{person}' is invalid. You must use {valid_people}.",
      valid_people = glue_collapse(
        single_quote(c("all", person_lookup$person_id)), sep = ", ", last = " or "
      )
    ))
  }
  
  if (person == "all") {
    all_results <- person_lookup |> 
      mutate(results = pmap(list(name, sheet_id, goodreads), ~parse_books(..1, ..2, ..3)))
    
    results <- all_results$results |> 
      set_names(all_results$person_id)
    
  } else {
    current_person <- person_lookup |> filter(person_id == person)
    
    if (is.na(current_person$sheet_id)) {
      # Do Goodreads stuff
      results <- list(name = current_person$name, source = "Goodreads")
    } else {
      results <- parse_books(current_person$name, current_person$sheet_id, current_person$goodreads)
    } 
  }
  
  return(results)
}
