
FROM rocker/shiny:latest
MAINTAINER ANV "byobio.project@gmail.com"

## Install dependency for XML package
RUN apt-get update && apt-get install -y libxml2-dev libssl-dev

## Install packages from CRAN
RUN install2.r --e \
    -r 'http://cran.rstudio.com' \
    data.table flexdashboard ggplot2 highcharter httr parsedate rmarkdown wordcloud2 XML \
    ## clean up
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

EXPOSE 3838
 
COPY . /srv/shiny-server/


