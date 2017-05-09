library("reshape2")
library("plotly")
library("ggplot2")
library("tidyr")
library("shiny")
library("scales")
library('shinythemes')

#setwd("~/Documents/USF/Spring_Module_2/Data_Visualization/Project")

stores <- read.csv("stores.csv")
train <- read.csv("train.csv")

merge_df <- merge(stores,train, by.x = "Store", by.y = "Store")
merge_df$Date <- as.Date(merge_df$Date)
merge_df <- merge_df[merge_df$Date >= '2012-01-01',]


#########################
##### HEAT MAP DATA #####
#########################
agg_heat <- aggregate(merge_df$Weekly_Sales, by = list(merge_df$state, merge_df$Date), sum)
colnames(agg_heat) <- c("State","Weeks","Total_Sales")

agg_heat$part <- paste("Week of: ", agg_heat$Weeks, sep = "")
agg_heat$state <- paste("State: ",agg_heat$State, sep = "")
agg_heat$total_text <- format(agg_heat$Total_Sales, big.mark = ",", scientific = FALSE)
agg_heat$total_text <- paste("$",agg_heat$total_text,sep = "")
agg_heat$sales <- paste("Total Sales: ", agg_heat$total_text, sep = "")

agg_heat$date_state <- paste(agg_heat$part,agg_heat$state, sep = "<br>")
agg_heat$all_text <- paste(agg_heat$date_state,agg_heat$sales, sep = "<br>")
agg_heat$total_text <- format(agg_heat$Total_Sales, big.mark = ",", scientific = FALSE)


#########################
##### Times Series #####
#########################
time_series <- merge_df[, names(merge_df) %in% c("Date","Weekly_Sales","state","Store","region")]
time_series$Store <- as.factor(time_series$Store)

agg_by_region <- aggregate(time_series$Weekly_Sales, by = list(time_series$Date,time_series$region), sum)
colnames(agg_by_region) <- c("Date","Region","Weekly_Sales")

agg_by_store <- aggregate(time_series$Weekly_Sales, by = list(time_series$Date,time_series$region,time_series$Store),sum)
colnames(agg_by_store) <- c("Date","Region","Store","Weekly_Sales")


####################
### maps ##########
###################
data12 <- subset(merge_df, Date > as.Date("2012-01-01"))

# sum weekly sales by state

# plot 1
df3 <- aggregate(data12$Weekly_Sales, by=list(data12$state), FUN=sum)
colnames(df3) <- c("state", "sum_sales")


# second plot
df2 <- aggregate(data12$Weekly_Sales, by=list(data12$state, data12$lat, data12$lon, data12$Size), FUN=sum)
colnames(df2) <- c("state", "lat", "lon", "size", "sum_sales")


ui <- fluidPage(theme = shinytheme('flatly'),
  # headerPanel("Walmart Sales Data, Awesome Data Viz Group \n\n"),
  navbarPage(title = "Walmart Sales Data, Awesome Data Viz Group",
      tabPanel("Heatmap of Weekly Sales by State", plotlyOutput("heatmap")),
      tabPanel("Total Sales by State", plotlyOutput("map1")), 
      tabPanel("Store Size Across the Country", plotlyOutput("map2")),
      tabPanel("Time Series of Weekly Sales", plotlyOutput("timeseries"),
               sidebarPanel(
                 selectInput("region", "Select Region", choices = append(list("All"),levels(merge_df$region)))))
    
  )
)



server <- function(input, output) {
  
  data <- agg_heat
  
  output$heatmap <- renderPlotly({
    p <- plot_ly(data=data,
                 x = ~Weeks, y = ~State,
                 z = ~Total_Sales, type = "heatmap",text=~all_text, hoverinfo = "text",
                 colors = c('#ffffcc','#41b6c4','#2c7fb8','#253494')) %>%
      colorbar(title = "Weekly Sales in Millions USD", tickprefix = ' $')
  })
  
  output$timeseries <- renderPlotly({
    if(input$region == "All"){
      df <- reactive({agg_by_region})
      ggplot_timeseries <- ggplot(df(), aes(Date, Weekly_Sales, colour = Region)) + geom_line() +
        xlab("\nWeeks") + ylab("Weekly Sales\n\n") + scale_y_continuous(labels = scientific) +
        theme(plot.title = element_text(hjust = 0.5),
              legend.justification = c("right", "top"),
              # legend.position="none",
              panel.background = element_rect(fill="white",color = "black", size = 0.5),
              axis.title.x = element_text(size = 10),
              axis.title.y = element_text(size = 10),
              axis.text = element_text(size = 8)) 
      ggplotly(ggplot_timeseries)
      
    }
    else{
      df <- reactive({agg_by_store %>% filter(Region == input$region)})
      ggplot_timeseries1 <- ggplot(df(), aes(Date, Weekly_Sales, colour = Store)) + geom_line() +
        xlab("\nWeeks") + ylab("Weekly Sales\n\n") + scale_y_continuous(labels = scientific) +
        theme(plot.title = element_text(hjust = 0.5),
              legend.justification = c("right", "top"),
              # legend.position="none",
              panel.background = element_rect(fill="white",color = "black", size = 0.5),
              axis.title.x = element_text(size = 10),
              axis.title.y = element_text(size = 10),
              axis.text = element_text(size = 8)) 
      ggplotly(ggplot_timeseries1)
    }})
  
  output$map1 <- renderPlotly({
    l <- list(color = toRGB("white"), width = 2)
    g1 <- list(
      scope = 'usa',
      projection = list(type = 'albers usa'),
      showlakes = TRUE,
      lakecolor = toRGB('white')
    )
    
    p1 <- plot_geo(df3, locationmode = 'USA-states') %>%
      add_trace(
        z = ~sum_sales, locations = ~state,
        text = ~paste(paste("State:", state), paste("Total Sales in 2012:", format(sum_sales, scientific=FALSE, big.mark=",")), sep = "<br />"),
        color = ~sum_sales, colors = 'Purples', hoverinfo = "text"
      ) %>%
      colorbar(title = "Sales in Millions USD", tickprefix = ' $') %>%
      layout(
        #title = 'Total Store Sales by State for 2012',
        geo = g1
      )
  })
  
  output$map2 <- renderPlotly({
    g2 <- list(
      scope = 'usa',
      projection = list(type = 'albers usa'),
      showland = TRUE,
      landcolor = toRGB("gray95"),
      subunitcolor = toRGB("gray85"),
      countrycolor = toRGB("gray85"),
      countrywidth = 0.5,
      subunitwidth = 0.5
    )
    
    p2 <- plot_geo(df2, lat = ~lat, lon = ~lon) %>%
      add_markers(
        text = ~paste(paste("Size:", format(size, scientific=FALSE, big.mark=","), "sqft"), paste("Total Sales in 2012:", format(sum_sales, scientific=FALSE, big.mark=",")), sep = "<br />"),
        color = ~size, symbol = I("square"), size = I(10), hoverinfo = "text"
      ) %>%
      colorbar(title = "Square Footage of Store") %>%
      layout(
       # title = 'Store Sizes Across the Country',
        geo = g2
      )
    
  })
  
}




shinyApp(ui = ui, server = server)
