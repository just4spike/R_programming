# 1. Load libraries----
library(magrittr)

# 2. Define parameters----
page_link_main <- 'https://www.saeima.lv'
page_subdir <- '/lv/saeimas-struktura/deputatu-atalgojums'
pdf_file_dir_loc <- Sys.getenv('HOME') # Main folder with subfolder pdf_file_dirname
pdf_file_dirname <- 'Saeimas_atalgojums' # Subfolder name where all *.pdfs will be downloaded
overwrite_file <- FALSE # If there already exist .pdf into pdf_file_dirname with filename what you try to download
# then overwrite_file = FALSE means that file will not be overwritten

# Create subfolder if not exist
pdf_file_path <- file.path(pdf_file_dir_loc, pdf_file_dirname)

if (!dir.exists(pdf_file_path)) {
  dir.create(pdf_file_path)
}

files_in_subfolder <- list.files(path = pdf_file_path, pattern = '\\.pdf$', recursive = TRUE)

# 3. Get all pdfs from page----
## 3.1. get all necessary link names----
link_list <- rvest::read_html(x = paste0(page_link_main, page_subdir)) %>%
  rvest::html_elements(css = "a[href$='.pdf']") %>%
  rvest::html_attr(name = 'href')

## 3.2. Download and save PDF files----
for (i in link_list) {
  pdf_filename <- basename(i)
  pdf_year <- basename(dirname(i))
  pdf_exist <- file.path(pdf_year, pdf_filename) %in% files_in_subfolder ||
    pdf_filename %in% files_in_subfolder

  # If such pdf file exist and overwrite_file = FALSE then skip this step
  if (pdf_exist && !overwrite_file) next

  if (!dir.exists(file.path(pdf_file_path, pdf_year))) {
    dir.create(file.path(pdf_file_path, pdf_year))
  }

  download.file(url = paste0(page_link_main, i),
                destfile = file.path(pdf_file_path, pdf_year, pdf_filename),
                mode="wb") # mandatory
}

# 4. Read all pdfs----
files_in_subfolder <- list.files(pdf_file_path, full.names = TRUE,
                                 pattern = '\\.pdf$', recursive = TRUE)

# Main dataframe where all salary data will be collected
all_salary_data <- NULL

for (i in files_in_subfolder) {
  print(paste0("Process file: ", i))

  pdf_result <- pdftools::pdf_text(pdf = i) %>%
    strsplit(split = "\n") %>%
    unlist() %>%
    gsub(pattern = '\\s{2,}', replacement = ' ', .)

  #
  search_text <- 'Saeimas deput\u0101tiem izmaks\u0101tais atalgojums'
  title_name <- grepl(pattern = search_text,
                      x = pdf_result, ignore.case = TRUE)
  exclude_rows <- grepl(pattern = paste0('(', search_text, '|.*V\u0101rds Uzv\u0101rds.*)'),
                        x = pdf_result, ignore.case = TRUE)

  name_surname <- trimws(sub(pattern = ' \\d+\\.\\d{0,2}', replacement = '', x = pdf_result))
  amount <- as.double(sub(pattern = '\\D+', replacement = '', x = pdf_result))

  page_data <- data.frame(orig = pdf_result,
                          title = trimws(pdf_result[title_name][1]),
                          name_surname = name_surname,
                          salary_eur = amount,
                          file = i,
                          subfolder = basename(dirname(i)),
                          filename = basename(i),
                          stringsAsFactors = FALSE)[!exclude_rows,] # Exclude title row

  page_data <- page_data[nchar(page_data$orig) > 0, ]
  all_salary_data <- rbind(page_data, all_salary_data)

}

# 5. Save result as xlsx----
excel_filename <- 'Saeimas_atalgojums'
excel_fullname <- paste0(excel_filename, '.xlsx')
i <- 0
while (TRUE) {
  if (excel_fullname %in% list.files(pdf_file_path, pattern = '\\.xlsx$')) {
    i <- i + 1
    excel_fullname <- sprintf(paste0(excel_filename, '_%d.xlsx'), i)
  } else {
    openxlsx::write.xlsx(x = all_salary_data,
                         file = file.path(pdf_file_path, excel_fullname))
    break
  }
}


# Remove all object created in this example
rm(page_link_main, page_subdir, pdf_file_dir_loc, pdf_file_dirname,
   overwrite_file, pdf_file_path, files_in_subfolder, link_list,
   pdf_filename, pdf_year, pdf_exist, pdf_result, all_salary_data, name_surname,
   amount, page_data, search_text, title_name, exclude_rows, excel_filename, excel_fullname)
