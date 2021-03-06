##SELECT ParticipantBarcode, ID, Study, miRNAexpr FROM [pancancer-atlas:Annotated.pancanMiRs_EBadjOnProtocolPlatformWithoutRepsWithUnCorrectMiRs_08_04_16_annot] 
## where participantBarcode="TCGA-3C-AAAU" and ID="hsa-miR-9-3p" LIMIT 10
## answer is 18.275887
#' provide bigrquery connection to pancancer Annotated datasets
#' @import bigrquery DBI
#' @param dataset character(1) dataset name
#' @param billing character(1) Google cloud platform billing code; authentication will be attempted when using the resulting connection
#' @param \dots passed to \code{\link{dbConnect}}, for example, quiet=TRUE
#' @return BigQueryConnection instance
#' @examples
#' pancan_BQ
#' @export
pancan_BQ = function (dataset="Annotated", 
              billing=Sys.getenv("CGC_BILLING"), ...) 
{
    con <- DBI::dbConnect(bigrquery::bigquery(), project = "pancancer-atlas", 
        dataset = dataset, billing = billing, ...)
    con
}

#' give an interface to tablenames
#' @return interactive datatable from DT
#' @examples
#' if (interactive()) pancan_clinicalTabVarnames()
#' @export
pancan_clinicalTabVarnames = function() {
 if (!requireNamespace("DT")) stop("install DT package to use this function")
 DT::datatable(BiocOncoTK::pancan.clin.varnames)
}

#' tabulate a variable in a table
#' @param dataset character(1) dataset name
#' @param tblname character(1) table name in dataset
#' @param vblname character(1) field name in table
#' @return instance of tbl_dbi, constituting summarise result
#' @examples
#' if (interactive()) pancan_tabulate(tblname=
#'     "clinical_PANCAN_patient_with_followup", vblname="icd_10")
#' @export
pancan_tabulate = function(dataset="Annotated", tblname, vblname) {
 pancan_BQ(dataset=dataset) %>% tbl(tblname) %>% select_(vblname) %>%
   group_by_(vblname) %>% summarise(n=n())
}

#' provide a shiny app to 'glimpse' structure and content of pancan atlas
#' @import DT
#' @rawNamespace import("shiny", except=c("renderDataTable", "dataTableOutput"))
#' @param dataset character(1) name of a BigQuery dataset in the pancan-atlas project
#' @param nrecs numeric(1) number of records to request (limited through the n= parameter to as.data.table
#' @return currently only as a side effect of starting app
#' @examples
#' if (interactive()) pancan_app()
#' @export
pancan_app = function(dataset="Annotated", nrecs=5) {
 tbls = pancan_BQ(dataset=dataset) %>% dbListTables()
 if (dataset=="Annotated") tbls = BiocOncoTK::annotTabs
 ui = fluidPage(
  sidebarLayout(
   sidebarPanel(
    helpText(h3(paste("BiocOncoTK pancan_app: High-level views of",
      "tables and records in the BigQuery pancan-atlas project of",
      "November 2018."))),
    selectInput("table", "Select a table", tbls),
    helpText("See ", a(href="http://isb-cancer-genomics-cloud.readthedocs.io/en/latest/sections/PanCancer-Atlas-Mirror.html", "the ISB documentation on this project"), "for more details on the underlying data."),
    helpText(paste("Tab 'recs' presents a small number of records",
      "from the selected table; tab 'fullnames' shows the internal",
      "name of the table, which includes some relevant metadata.")),
    helpText("Tab allvbls is a searchable list of table fields"),
    width=3
   ),
   mainPanel(
    tabsetPanel(
     tabPanel("recs.", 
      tableOutput("chk")
     ),
     tabPanel("fullnames", 
      tableOutput("fullnames")
     ),
     tabPanel("allvbls", 
      dataTableOutput("allvbls")
     )
    )
   )
  )
 )
 server = function(input, output) {
  gettab = reactive({
   pancan_BQ(dataset=dataset) %>% tbl(input$table) %>% as.data.frame(n=nrecs)
  })
  output$chk = renderTable({
   gettab()
  })
  output$allvbls = renderDataTable({
   data.frame(vbls=names(gettab()))
  })
  output$fullnames = renderTable({
   data.frame(short=names(tbls), fullnames=tbls)
  })
 }
 shinyApp(ui=ui, server=server)
} 

#' utility to help find long table names
#' @param guess a regexp to match the table of interest
#' @param \dots passed to \code{\link[base]{agrep}}
#' @return character vector of matches
#' @note Note that ignore.case=TRUE is set in the function.
#' @examples
#' pancan_longname("rnaseq")
#' @export
pancan_longname  = function(guess, ...) 
  agrep(guess, BiocOncoTK::annotTabs, value=TRUE,
    ignore.case=TRUE, ...)

#' create list with SEs for tumor and normal for a tumor/assay pairing
#' @param bq a BigQuery connection
#' @param code character(1) a TCGA tumor code, defaults to "PRAD" for prostate tumor
#' @param assayDataTableName character(1) name of table in BigQuery
#' @param assayValueFieldName character(1) field from which assay quantifications are retrieved
#' @param assayFeatureName character(1) field from which assay feature names are retrieved
#' @examples
#' if (interactive()) {
#'  bqcon = try(pancan_BQ())
#'  if (!inherits(bqcon, "try-error")) {
#'    tn = tumNorSet(bqcon)
#'    tn
#'  }
#' }
#' @export
tumNorSet = function(bq, code="PRAD", assayDataTableName=pancan_longname("rnaseq"),
     assayValueFieldName="normalized_count", assayFeatureName="Entrez") {
 lapply(c("TP", "NT"), function(x)
   pancan_SE(bq, colDFilterValue=code, assayDataTableName=assayDataTableName, assaySampleTypeCode=x,
    tumorFieldValue=code, assayValueFieldName=assayValueFieldName, assayFeatureName=assayFeatureName))
}

