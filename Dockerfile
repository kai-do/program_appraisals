FROM rocker/r-base:latest
LABEL maintainer="Nakai Zemer <nakai.zemer@cobbcounty.org>"

USER root

# Install base linux packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libssh2-1-dev \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install packages for sql server support
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/msprod.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y mssql-tools \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y unixodbc \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install --yes --no-install-recommends msodbcsql18 \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile

# Install R libraries
RUN Rscript -e "install.packages('shiny')" \
    && Rscript -e "install.packages('dplyr')" \
    && Rscript -e "install.packages('shinyjs')" \
    && Rscript -e "install.packages('shinyWidgets')" \
    && Rscript -e "install.packages('dbplyr')" \
    && Rscript -e "install.packages('data.table')" \
    && Rscript -e "install.packages('odbc')" \
    && Rscript -e "install.packages('DT')" \
    && Rscript -e "install.packages('stringr')" \
    && Rscript -e "install.packages('tidyr')" \
    && Rscript -e "install.packages('DBI')"

# Configure port to shiny
RUN echo "local(options(shiny.port = 3838, shiny.host = '0.0.0.0'))" > /usr/lib/R/etc/Rprofile.site

# Set up the DSN for DCP-FDGAPP1DEV sql server
RUN odbcinst -i -s -f /etc/odbc.ini \
    && echo "[DCP-FDGAPP1DEV]" >> /etc/odbc.ini \
    && echo "Driver=ODBC Driver 18 for SQL Server" >> /etc/odbc.ini \
    && echo "Server=DCP-FDGAPP1DEV" >> /etc/odbc.ini \
    && echo "Database=Testing" >> /etc/odbc.ini \
    && echo "UID=program_appraisals" >> /etc/odbc.ini \
    && echo "PWD=PApass123!" >> /etc/odbc.ini

RUN addgroup --system app \
    && adduser --system --ingroup app app \
    && mkdir /home/app \
    && chown app:app /home/app

WORKDIR /home/app
COPY app /home/app/
USER app

# Open port to shinyproxy
EXPOSE 3838
CMD ["R", "-e", "shiny::runApp('/home/app')"]
