#' Reimport a CSV-file exported from CiteSource
#'
#' This function reimports a csv file that was tagged and deduplicated by CiteSource.
#' It allows to continue with further analyses without repeating that step, and also
#' allows users to make any manual corrections to tagging or deduplication. Note that
#' this function only works on CSV files that were written with `export_csv(..., separate = NULL)`
#'
#' @param filename Name (and path) of CSV file to be reimported, should end in .csv
#' @return A data frame containing the imported citation data if all required columns are present.
#' @export
#' @examples
#' \dontrun{
#' #example usage
#' citations <- reimport_csv("path/to/citations.csv")
#' }
#'
reimport_csv <- function(filename) {
  # Warn if the filename doesn't end with .csv
  if (tolower(tools::file_ext(filename)) != "csv") warning("Function reads a CSV file, so filename should (usually) end in .csv. For now, name is used as provided.")

  # Read the CSV file
  unique_citations_imported <- utils::read.csv(filename, stringsAsFactors = FALSE)

  # Check if the required columns are present
  if (!all(c("cite_source", "cite_label", "cite_string", "duplicate_id", "record_ids") %in% names(unique_citations_imported))) {
    stop(
      "CiteSource meta-data (i.e. columns cite_source, cite_label cite_string, duplicate_id, record_ids) were not found in ", filename,
      ". This function is intended to be used for files exported from CiteSource and thus requires these fields.",
      " Note that export_csv must be called with separate = NULL (the default value)."
    )
  }

  unique_citations_imported
}

#' Reimport a RIS-file exported from CiteSource
#'
#' This function reimports a RIS file that was tagged and deduplicated by CiteSource.
#' It allows to continue with further analyses without repeating that step, and also
#' allows users to make any manual corrections to tagging or deduplication. The function
#' can also be used to replace the import step (for instance if tags are to be added to
#' individual citations rather than entire files) - in this case, just call `dedup_citations()`
#' after the import.
#'
#' Note that this functions defaults' are based on those in `export_ris()` so that these functions
#' can easily be combined.
#'
#' @param filename Name (and path) of RIS file to be reimported, should end in .ris
#' @param source_field Character. Which RIS field should cite_sources be read from? NULL to set to missing
#' @param label_field Character. Which RIS field should cite_labels be read from? NULL to set to missing
#' @param string_field Character. Which RIS field should cite_strings be read from? NULL to set to missing
#' @param duplicate_id_field Character. Which RIS field should duplicate IDs be read from? NULL to recreate based on row number (note that neither duplicate nor record IDs directly affect CiteSource analyses - they can only allow you to connect processed data with raw data)
#' @param record_id_field Character. Which RIS field should record IDs be read from? NULL to recreate based on row number
#' @param tag_naming Synthesisr option specifying how RIS tags should be replaced with names. This should not
#' be changed when using this function to reimport a file exported from CiteSource. If you import your own
#' RIS, check `names(CiteSource:::synthesisr_code_lookup)` and select any of the options that start with `ris_`
#' @param verbose Should confirmation message be displayed?
#' @export
#' @examples
#' if (interactive()) {
#'   dedup_results <- dedup_citations(citations, merge_citations = TRUE)
#'   export_ris(dedup_results$unique, "citations.ris")
#'   unique_citations2 <- reimport_ris("citations.ris")
#' }
#'
reimport_ris <- function(filename = "citations.ris", 
                         source_field = "DB", label_field = "C7", string_field = "C8",
                         duplicate_id_field = "C1", record_id_field = "C2", 
                         tag_naming = "ris_synthesisr", verbose = TRUE) {

  if (!tag_naming %in% names(synthesisr_code_lookup)) {
    stop("tag_naming must be one of ", names(synthesisr_code_lookup) %>% stringr::str_subset("^ris_") %>%
      glue::glue_collapse(sep = ", ", last = " or "))
  }

  if (is.null(source_field)) source_field <- NA
  if (is.null(string_field)) string_field <- NA
  if (is.null(label_field)) label_field <- NA
  if (is.null(duplicate_id_field)) duplicate_id_field <- NA
  if (is.null(record_id_field)) record_id_field <- NA

  
  custom_codes <- tibble::tribble(
    ~code, ~field, ~tag_naming,
    source_field, "cite_source", TRUE,
    string_field, "cite_string", TRUE,
    label_field, "cite_label", TRUE,
    duplicate_id_field, "duplicate_id", TRUE,
    record_id_field, "record_ids", TRUE
  )

  names(custom_codes)[3] <- tag_naming

  synthesisr_codes <- dplyr::bind_rows(
    custom_codes,
    synthesisr_code_lookup %>% dplyr::filter(.data[[tag_naming]])
  ) %>%
    dplyr::filter(!is.na(.data$code)) %>%
    dplyr::distinct(.data$code, .keep_all = TRUE) # Remove fields from synthesisr specification used for CiteSource metadata

  citations <- read_ref(filename, tag_naming = synthesisr_codes)


  if (!"cite_source" %in% names(citations)) {
    message("No non-empty cite_source values found")
    citations$cite_source <- NA
  }

  if (!"cite_string" %in% names(citations)) {
    message("No non-empty cite_string values found")
    citations$cite_string <- NA
  }
  if (!"cite_label" %in% names(citations)) {
    message("No non-empty cite_label values found")
    citations$cite_label <- NA
  }

  if (!"duplicate_id" %in% names(citations)) {
    message("Duplicate IDs not found - will be recreated based on row number")
    citations$duplicate_id <- seq_len(nrow(citations))
  } else if (any(is.na(citations$duplicate_id))) {
    message("Some duplicate IDs are missing - these will be recreated based on row number")
    citations$duplicate_id[is.na(citations$duplicate_id)] <- seq_len(sum(is.na(citations$duplicate_id)))
  }
  
  if (!"record_ids" %in% names(citations)) {
    message("Record IDs not found - will be recreated based on row number")
    citations$record_ids <- seq_len(nrow(citations))
  } else if (any(is.na(citations$record_ids))) {
    message("Some record IDs are missing - these will be recreated based on row number")
    citations$record_ids[is.na(citations$record_ids)] <- seq_len(sum(is.na(citations$record_ids)))
  }

  citations
}
