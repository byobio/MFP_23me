fastfood <- read.csv("fastfoodlist.csv")
genexdiet <- read.csv("gene-x-diet.csv", check.names = F, stringsAsFactors = F)

error_MFP <- "Data could not be retrieved from MFP. Check that your diary is set to public and correct username/dates are entered."

food.units <- list(Calories = "kcal", Carbs = "g", Fat = "g", Protein = "g", 
              Cholest = "mg", Sodium = "mg", Sugars = "g", Fiber = "g")

parseMFP <- function(user, from, to) {  
  url <- paste0("http://www.myfitnesspal.com/reports/printable_diary/", 
                user, "?from=", from, "&to=", to)
  htmlParse(url)
}

findFoodMFP <- function(doc, dates) {
  food <- lapply(dates, function(x) paste0("//h2[text()='", x, "']/following-sibling::table[@id='food'][1]"))
  food <- lapply(food, function(p) xpathApply(doc, p, readHTMLTable, stringsAsFactors = F))
  food <- lapply(food, function(x) x[[1]])
  return(food)
}

formatMFP <- function(doc) {
  dates <- xpathApply(doc, "//h2[@id='date']", xmlValue)
  food <- findFoodMFP(doc, dates)
  
  # Convert to data.table
  dates <- lapply(dates, as.Date, format = "%B %d, %Y")
  names(food) <- lapply(dates, as.character)
  food <- lapply(food, as.data.table)
  food <- rbindlist(food, idcol = "Date")
  
  # Create column for meal labels and infer meals
  meals <- unique(xpathSApply(doc, "//table[@id='food']//td[@class='first last']", xmlValue))
  i <- which(food$Foods %in% meals)
  food[, Meal := rep(Foods[i], diff(c(i, .N+1)))]
  food <- food[-i]
  nutrition <- c("Calories", "Carbs", "Fat", "Protein", "Cholest", "Sodium", "Sugars", "Fiber")
  for (col in nutrition) food[, (col) := as.numeric(gsub(",|mg|g", "", food[[col]]))]
  
  # Fast food annotate
  food[, Foods := regmatches(Foods, regexpr("^.[^,]+(?=,)", Foods, perl = T))]
  items <- strsplit(food$Foods, " - ")
  food[, Brand := sapply(items, function(x) ifelse(length(x) == 1, "Generic", x[1]))]
  ffmatch <- lapply(fastfood$Regex, function(brand) grep(brand, food$Brand, ignore.case = T)) 
  names(ffmatch) <- fastfood$Name
  ffmatch <- ffmatch[sapply(ffmatch, length) > 0]
  for (i in seq_along(ffmatch)) food[ffmatch[[i]], Brand := names(ffmatch[i])]
  
  return(food)
}

delta <- function(x) last(x) - first(x)
