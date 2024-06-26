#' Get cached reference titles
#'
#' Read `docs/data/titles.csv`, create if missing
#'
#' @return title containing DOIs and titles
get_cached_titles <- function() {
  futile.logger::flog.info("Getting cached titles...")
  
  if (!file.exists("docs/data/titles.csv")) {#if no cache, create an empty CSV with the right column names.
    futile.logger::flog.info("Cache file missing, creating...")
    write_lines("DOI,Title,PubDate", "docs/data/titles.csv")
  }
  
  titles <- readr::read_csv("docs/data/titles.csv",
                            col_types = readr::cols(
                              DOI   = readr::col_character(),
                              Title = readr::col_character(),
                              PubDate = readr::col_date()
                            )
  )
}


#' Add to titles cache
#'
#' Add a DOI-Title pair to the title cache
#'
#' @param swsheet Tibble containing software table
#' @param titles_cache Current titles cache
#'
#' @return Updated titles cache
add_to_titles_cache <- function(swsheet, titles_cache) {
  futile.logger::flog.info("Adding new titles to cache...")
  
  n_added <- 0
  for (dois in swsheet$DOIs) {#for each Tool, even if multiple dois.
    for (doi in str_trim(stringr::str_split(dois, ";")[[1]])) { #for each pub for that Tool. Be mindful of leading/trailing spaces.
      if (!is.na(doi) && !(doi %in% titles_cache$DOI)) { #if the pub isn’t already in the cache and is not empty. this doesn’t seem to skip Flye.
        
        if (stringr::str_detect(doi, "arxiv")) {
          id <- stringr::str_remove(doi, "arxiv/")
          title <- aRxiv::arxiv_search(id_list = id)$title
          date <- gsub (" .*$", "",aRxiv::arxiv_search(id_list = id)$submitted)
        } else {
          crossref <- rcrossref::cr_works(doi)
          title <- crossref$data$title
          date <- crossref$data$created
          date <- as.character(date)
        }
        
        if (!is.null(title)) {
          title_df <- data.frame(DOI = doi,
                                Title = title,
                                PubDate = suppressWarnings(readr::parse_date(date, na = NA_character_)) %>%
                                  lubridate::as_date())
          
          titles_cache <- dplyr::bind_rows(titles_cache,
                                           title_df)
          message(doi, " added to cache")
          n_added <- n_added + 1
        }
      }
    }
  }
  
  readr::write_csv(titles_cache, "docs/data/titles.csv")
  msg <- paste("Added", n_added, "new titles to cache")
  futile.logger::flog.info(msg)
  
  return(titles_cache)
}


#' Get titles
#'
#' Get title for DOIs. Return from cache if present, otherwise requests from
#' Crossref
#'
#' @param dois Character vector of dois
#' @param titles_cache Tibble containing cached titles
#'
#' @return vector of titles
get_titles <- function(dois, titles_cache) {
  
  `%>%` <- magrittr::`%>%`
  
  titles <- purrr::map(dois, function(doi) {
    if (doi %in% titles_cache$DOI) {
      titles_cache %>%
        dplyr::filter(DOI == doi) %>%
        dplyr::pull(Title)
    } else {
      NA
    }
  }) %>%
    purrr::flatten_chr()
  
  return(titles)
}