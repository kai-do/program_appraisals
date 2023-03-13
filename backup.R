library(shiny)
library(shinyjs)
library(shinyWidgets)
#library(shinyDarkmode)
library(dplyr)
library(dbplyr)
library(data.table)
library(odbc)
library(DT)
library(stringr)
library(tidyr)
library(DBI)

# custom title columns function
title_columns <- function(list) {
  clean_list <- str_replace_all(list, "[._]+", " ")
  cased_list <- c()
  str_to_title(clean_list)
}

# connect to odbc sql server
con <- dbConnect(odbc(), "DCP-FDGAPP1DEV", Database = "Testing")

# specify queries to retrieve records
program_sql <- con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[program]"))
program_item_sql <- con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[program_item]"))
progress_note_sql <- con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[progress_note]"))


insert_progress_note <- function(con, program_item_id, date_time, note) {
  dbSendQuery(con,
              paste0("INSERT INTO [Testing].[dbo].[progress_note] (program_item_id, date_time, note) VALUES (", 
                     paste(sql_quote(program_item_id, "'"), 
                           sql_quote(date_time, "'"), 
                           sql_quote(note, "'"), sep = ", "),")")
  )
}

delete_progress_note <- function(con, progress_note_id) {
  dbSendQuery(con,
              paste0("DELETE FROM [Testing].[dbo].[progress_note] WHERE progress_note_id = ",
                     sql_quote(progress_note_id, "'")
              )
  )
}

insert_program_item <- function(con, program_id, item, core_comp_flag, category, description, 
                                recommendation, cpse_edition, status, start_date, end_date, goal_date) {
  dbSendQuery(con,
              paste0("INSERT INTO [Testing].[dbo].[program_item] (program_id, item, core_comp_flag, category, description, recommendation, 
                       cpse_edition, status, start_date, end_date, goal_date) VALUES (", 
                     paste(sql_quote(program_id, "'"), 
                           sql_quote(item, "'"), 
                           sql_quote(as.integer(core_comp_flag), "'"), 
                           sql_quote(category, "'"), 
                           sql_quote(description, "'"), 
                           sql_quote(recommendation, "'"), 
                           sql_quote(cpse_edition, "'"), 
                           sql_quote(status, "'"), 
                           sql_quote(start_date, "'"), 
                           sql_quote(end_date, "'"), 
                           sql_quote(goal_date, "'"), 
                           sep = ", "),")")
  )
}

#insert_program_item(con, '1', 'test', '1', 'Goal', 'test', 'CCFES', 'Ed10', 'Started', '2023-01-01', '2023-02-01', '2023-03-01')

delete_program_item <- function(con, program_item_id) {
  dbSendQuery(con,
              paste0("DELETE FROM [Testing].[dbo].[program_item] WHERE program_item_id = ",
                     sql_quote(program_item_id, "'")
              )
  )
}

# execute sql and collect results into dataframes
program_df <- program_sql %>%
  select(everything()) %>%
  collect()

program_item_df <- program_item_sql %>%
  select(everything()) %>%
  collect()

progress_note_df <- progress_note_sql %>%
  select(everything()) %>%
  collect()

# unique lists for populating picker/select inputs
program_list <- program_df %>% 
  distinct(program_id, program) %>%
  arrange(program) %>%
  relocate(program, program_id) %>%
  tibble::deframe()

category_choices <- program_item_df %>% distinct(category) %>% arrange(category)
recommendation_choices <- program_item_df %>% distinct(recommendation) %>% arrange(recommendation)
cpse_edition_choices <- program_item_df %>% distinct(cpse_edition) %>% arrange(cpse_edition)
status_choices <- program_item_df %>% distinct(status) %>% arrange(status)

# ui code for app front end
ui <- navbarPage("Accreditation",
                 fluid = TRUE,
                 tabPanel("Program Appraisals",
                          fluidRow(
                            column(3,
                                   wellPanel(
                                     pickerInput(
                                       "program",
                                       "Select Program",
                                       choices = program_list
                                     )
                                   ))
                          ),
                          fluidRow(
                            column(6,
                                   h3("Program Items"),
                                   wellPanel(
                                     actionButton("new_program_item", "New Item"),
                                     actionButton("edit_program_item", "Edit"),
                                     actionButton("delete_program_item", "Delete"),
                                     verbatimTextOutput("test"),
                                     hr(),
                                     DTOutput("program_item_tab")
                                   )),
                            column(6,
                                   h3("Item Description"),
                                   wellPanel(
                                     textOutput("program_item_description")
                                   ),
                                   h3("Progress Notes"),
                                   wellPanel(
                                     actionButton("new_note", "New Note"),
                                     #conditionalPanel(condition = "output.display_note_edit == 'true'",
                                     actionButton("edit_note", "Edit"),
                                     actionButton("delete_note", "Delete"),
                                     #    style = "display: inline;"
                                     #),
                                     #verbatimTextOutput("display_note_edit"),
                                     hr(),
                                     DTOutput("progress_notes_tab")
                                   ),
                            )
                          )
                 ),
                 tabPanel("User Session Info",
                          fluidRow(column(12, 
                                          h3("URL components"),
                                          verbatimTextOutput("urlText"),
                                          h3("Parsed query string"),
                                          verbatimTextOutput("queryText")
                          )))
)

# Define server logic
server <- function(input, output, session) {
  
  program_sql_df <- reactive({
    con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[program]")) %>%
      select(everything()) %>%
      collect()
  })
  
  # initializing reactive variables to store dataframes
  program_item_rv <- reactiveValues(df = data.frame())
  progress_note_rv <- reactiveValues(df = data.frame())
  
  # populate reactive variables whenever a dependency changes. Uses eager execution.
  observe({
    program_item_rv$df <-
      con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[program_item]")) %>%
      select(everything()) %>%
      collect()
  })
  
  observe({
    progress_note_rv$df <-
      con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[progress_note]")) %>%
      select(everything()) %>%
      collect()
  })
  
  # filter dataframes given input to send to display tables
  program_item_df <- reactive({
    program_item_rv$df %>%
      filter(program_id == input$program)
  })
  
  progress_note_filtered_df <- reactive({
    progress_note_rv$df %>% 
      filter(program_item_id == program_item_df()[input$program_item_tab_rows_selected, ]$program_item_id)
  })
  
  # run code on observation of event, such as button click
  observeEvent(input$new_program_item, {
    showModal(modalDialog(
      tags$h2('New Program Item'),
      textInput('prog_item_name', 'Item Name'),
      checkboxInput('prog_item_core_comp', 'Core Competency', value = FALSE),
      dateInput('prog_item_start_date', 'Start Date'),
      dateInput('prog_item_end_date', 'End Date'),
      dateInput('prog_item_goal_date', 'Goal Date'),
      selectInput('prog_item_category', 'Category', choices = category_choices),
      selectInput('prog_item_recommendation', 'Recommendation', choices = recommendation_choices),
      selectInput('prog_item_cpse_edition', 'CPSE Edition', choices = cpse_edition_choices),
      selectInput('prog_item_status', 'Status', choices = status_choices),
      textAreaInput('prog_item_description', 'Description', width = '90%', height = '400px'),
      footer=tagList(
        actionButton('prog_item_submit', 'Submit'),
        modalButton('Cancel')
      ),
      size = 'l'
    ))
  })
  
  observeEvent(input$new_note, {
    showModal(modalDialog(
      tags$h2('New Progress Note'),
      textAreaInput('prog_note_note', 'Progress Note', width = '90%', height = '400px'),
      footer=tagList(
        actionButton('prog_note_submit', 'Submit'),
        modalButton('Cancel')
      ),
      size = 'l'
    ))
  })
  
  observeEvent(input$prog_item_submit, {
    removeModal()
    insert_program_item(con, program_id = input$program, item = input$prog_item_name, core_comp_flag = input$prog_item_core_comp, 
                        category = input$prog_item_category, description = input$prog_item_description, recommendation = input$prog_item_recommendation, cpse_edition = input$prog_item_cpse_edition, 
                        status = input$prog_item_status, start_date = input$prog_item_start_date, end_date = input$prog_item_end_date, goal_date = input$prog_item_goal_date)
    # refresh data source after insert
    program_item_rv$df <-
      con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[program_item]")) %>%
      select(everything()) %>%
      collect()
  })
  
  observeEvent(input$prog_note_submit, {
    removeModal()
    insert_progress_note(con, program_item_df()[input$program_item_tab_rows_selected, ]$program_item_id, Sys.time(), input$prog_note_note)
    # refresh data source after insert
    progress_note_rv$df <-
      con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[progress_note]")) %>%
      select(everything()) %>%
      collect()
  })
  
  observeEvent(input$delete_program_item, {
    # display a modal dialog with a header, textinput and action buttons
    showModal(modalDialog(
      tags$h4('Are you sure you want to delete this item?'),
      footer=tagList(
        actionButton('delete_program_item_confirm', 'Delete Permanently', style="background-color: #ab7676;"),
        modalButton('Cancel')
      ),
      size = 's'
    ))
  })
  
  observeEvent(input$delete_note, {
    # display a modal dialog with a header, textinput and action buttons
    showModal(modalDialog(
      tags$h4('Are you sure you want to delete this note?'),
      footer=tagList(
        actionButton('delete_note_confirm', 'Delete Permanently', style="background-color: #ab7676;"),
        modalButton('Cancel')
      ),
      size = 's'
    ))
  })
  
  observeEvent(input$delete_program_item_confirm, {
    removeModal()
    delete_program_item(con, program_item_df()[input$program_item_tab_rows_selected, ]$program_item_id)
    program_item_rv$df <-
      con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[program_item]")) %>%
      select(everything()) %>%
      collect()
  })
  
  observeEvent(input$delete_note_confirm, {
    removeModal()
    delete_progress_note(con, progress_note_filtered_df()[input$progress_notes_tab_rows_selected, ]$progress_note_id)
    progress_note_rv$df <-
      con %>% tbl(sql("SELECT * FROM [Testing].[dbo].[progress_note]")) %>%
      select(everything()) %>%
      collect()
  })
  
  # render output to send to ui
  output$program_item_tab <- renderDT({
    datatable(
      program_item_df() %>%
        select(item, status, start_date, end_date, goal_date, category, recommendation, cpse_edition) %>%
        rename_with(.fn = title_columns),
      editable = FALSE, selection = 'single'
    )
  })
  
  output$progress_notes_tab <- renderDT({
    req(input$program_item_tab_rows_selected)
    datatable(progress_note_filtered_df() %>%
                select(progress_note_id, program_item_id, date_time, note) %>%
                rename_with(.fn = title_columns), editable = FALSE, selection = 'single')
  })
  
  output$test <- renderText({
    #program_item_df()[input$program_item_tab_rows_selected, ]$program_id
    input$program
  })
  
  output$program_item_description <- renderText({
    req(input$program_item_tab_rows_selected)
    program_item_df() %>%
      filter(program_item_id == program_item_df()[input$program_item_tab_rows_selected, ]$program_item_id) %>%
      select(description) %>%
      as.character()
  })
  
  output$urlText <- renderText({
    paste(sep = "",
          "protocol: ", session$clientData$url_protocol, "\n",
          "hostname: ", session$clientData$url_hostname, "\n",
          "pathname: ", session$clientData$url_pathname, "\n",
          "port: ",     session$clientData$url_port,     "\n",
          "search: ",   session$clientData$url_search,   "\n"
    )
  })
  
  output$queryText <- renderText({
    query <- parseQueryString(session$clientData$url_search)
    
    # Return a string with key-value pairs
    paste(names(query), query, sep = "=", collapse=", ")
  })
  
  #output$display_note_edit <- renderText({
  #    if(nrow(progress_note_filtered_df()) > 0) {
  #        return("true")
  #    } else {
  #        return("false")
  #    }
  #})
  
  
  #observe({
  #    if() {
  #        shinyjs::show(id = "edit_note")
  #        shinyjs::show(id = "edit_note")
  #    } else {
  #        shinyjs::hide(id = "delete_note")
  #        shinyjs::hide(id = "delete_note")
  #    }
  #})
}

# Run the application 
shinyApp(ui = ui, server = server)
