# 2024 Heiss Family books dashboard

A Quarto dashboard with ObservableJS chunks that pull data from a {plumber} API! Magic!

### Data sources

The three younger kids have Google Forms that they fill out. Everyone else uses Goodreads. Once upon a time, Goodreads had an API, but that's been long dead (ever since the Amazon takeover). So, as a hack, I have a Make.com workflow that regularly parses Goodreads RSS feeds and inserts the data into a Google Sheet as a kind of poor man's database. This lets me use {googlesheets4} to pull data from Google directly, just like the three Google Forms.

### API

The actual API is hosted elsewhere and uses a private GitHub repository, but I've included a sample {plumber} API that shows how I'm grabbing the data from Google Sheets.

Alternatively, [see here for a more complete example of how this whole process works](https://www.andrewheiss.com/blog/2024/01/12/diy-api-plumber-quarto-ojs/).
