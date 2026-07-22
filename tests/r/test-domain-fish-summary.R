src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/fish_summary.R")

# Build a synthetic "Fish Trapping" sheet and return the xlsx path.
fish_trapping_xlsx <- function(rows) {
  df <- do.call(rbind, lapply(rows, function(r) data.frame(
    Season = r$season, Date = r$year, Catchment = r$catch, Site = r$site,
    Method = r$method, `Net/Trap #` = r$net, Species = r$species,
    Number = r$number, `Shrimp abundance` = r$shrimp,
    check.names = FALSE, stringsAsFactors = FALSE)))
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Fish Trapping" = df), tmp)
  tmp
}

rec <- function(site, season, year, catch, method, net, species,
                number = NA, shrimp = NA) {
  list(site = site, season = season, year = year, catch = catch,
       method = method, net = net, species = species,
       number = number, shrimp = shrimp)
}

# Group A: EM_A / Spring 2099 / Mangapepeke.
#   Fyke: 2 distinct nets recorded (Fyke 1 & Fyke 3, incl. a "no catch" row).
#   GMT: 2 distinct nets (GMT 1 & GMT 2). CPUE divides by nets recorded.
#   Mixed shrimp abundance; koura + unidentified eel included.
# Group B: EM_B / Summer 2099 / Mimi. Fyke only (no GMT -> CPUE_GMTs = NA),
#   shrimp all Abundant, plus an unidentified galaxiid (separate row, excluded
#   from richness).
FIXTURE <- list(
  rec("EM_A","Spring",2099,"Mangapepeke","Fyke","Fyke 1","longfin eel", 5),
  rec("EM_A","Spring",2099,"Mangapepeke","Fyke","Fyke 1","redfin bully", 10),
  rec("EM_A","Spring",2099,"Mangapepeke","Fyke","Fyke 1","shrimp", NA, "U"),
  rec("EM_A","Spring",2099,"Mangapepeke","Fyke","Fyke 3","koura", 2),
  rec("EM_A","Spring",2099,"Mangapepeke","Fyke","Fyke 3","shrimp", NA, "C"),
  rec("EM_A","Spring",2099,"Mangapepeke","Fyke","Fyke 3","no catch", NA),
  rec("EM_A","Spring",2099,"Mangapepeke","GMT","GMT 1","common bully", 3),
  rec("EM_A","Spring",2099,"Mangapepeke","GMT","GMT 2","unidentified eel", 1),
  rec("EM_A","Spring",2099,"Mangapepeke","GMT","GMT 1","shrimp", NA, "U"),
  rec("EM_B","Summer",2099,"Mimi","Fyke","Fyke 1","giant kokopu", 1),
  rec("EM_B","Summer",2099,"Mimi","Fyke","Fyke 2","unidentified galaxiid", 3),
  rec("EM_B","Summer",2099,"Mimi","Fyke","Fyke 1","shrimp", NA, "A"),
  rec("EM_B","Summer",2099,"Mimi","Fyke","Fyke 2","shrimp", NA, "A")
)

test_that("returns a DomainResult with FishSummary + schema columns", {
  result <- process_fish_summary_domain(fish_trapping_xlsx(FIXTURE))
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_equal(names(result$data$FishSummary), FISH_SUMMARY_COLUMNS)
  expect_equal(nrow(result$data$FishSummary), 2L)
})

test_that("group A: counts, totals, richness, CPUE (nets recorded), shrimp", {
  df <- process_fish_summary_domain(fish_trapping_xlsx(FIXTURE))$data$FishSummary
  a <- as.list(df[df$Site == "EM_A", ])

  expect_equal(a$Catchment, "Mangapepeke")
  expect_equal(a$Season, "Spring")
  expect_equal(a$Year, 2099L)

  expect_equal(a$LongfinEel, 5)
  expect_equal(a$RedfinBully, 10)
  expect_equal(a$CommonBully, 3)
  expect_equal(a$UnidEel, 1)
  expect_equal(a$Koura, 2)
  expect_equal(a$ShortfinEel, 0)

  # Total excludes koura & shrimp, includes unidentified eel: 5+10+3+1 = 19.
  expect_equal(a$TotalFish, 19)
  # Richness = taxa groups present + shrimp: Eel (longfin+unid), Bully
  # (redfin+common), Koura, Shrimp = 4.
  expect_equal(a$TaxaRichness, 4L)

  # CPUE divides by the count of distinct nets recorded for the method.
  # Fyke: 2 nets (Fyke 1, Fyke 3); fish (excl koura/shrimp) = 15 -> 15/2 = 7.5.
  expect_equal(a$CPUE_fykes, 15 / 2, tolerance = 1e-9)
  # GMT: 2 nets (GMT 1, GMT 2); fish = common bully 3 + unid eel 1 = 4 -> 4/2.
  expect_equal(a$CPUE_GMTs, 4 / 2, tolerance = 1e-9)

  # Shrimp = mean rank of (U,C,U) = mean(1,2,1) = 1.33 -> Uncommon.
  expect_equal(a$Shrimp, "Uncommon")
})

test_that("group B: no GMT -> NA CPUE_GMTs; all-Abundant shrimp", {
  df <- process_fish_summary_domain(fish_trapping_xlsx(FIXTURE))$data$FishSummary
  b <- as.list(df[df$Site == "EM_B", ])

  expect_equal(b$GiantKokopu, 1)
  expect_equal(b$UnidGalaxiid, 3)
  # Total includes the unidentified galaxiid (a caught fish): 1 + 3 = 4.
  expect_equal(b$TotalFish, 4)
  # Richness = Kokopu (giant) + Shrimp = 2. The galaxiid does NOT add a taxon
  # (kept separate, excluded from richness) even though it counts to the total.
  expect_equal(b$TaxaRichness, 2L)
  # Fyke: 2 nets (Fyke 1, Fyke 2); fish (excl shrimp) = giant 1 + galaxiid 3 = 4.
  expect_equal(b$CPUE_fykes, 4 / 2, tolerance = 1e-9)
  expect_true(is.na(b$CPUE_GMTs))
  expect_equal(b$Shrimp, "Abundant")
})

test_that("missing required column returns an error result", {
  bad <- FISH_SUMMARY_COLUMNS  # any non-source frame
  df <- data.frame(Season = "Spring", Site = "EM_A", check.names = FALSE)
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Fish Trapping" = df), tmp)
  result <- process_fish_summary_domain(tmp)
  expect_false(result$ok())
  expect_match(result$errors[[1]]$message, "Missing required columns")
})

test_that("missing 'Fish Trapping' sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Other" = data.frame(x = 1)), tmp)
  result <- process_fish_summary_domain(tmp)
  expect_false(result$ok())
  expect_equal(result$errors[[1]]$domain, "FishSummary")
})
