# Report Regeneration Review – Discussion Points

## General formatting and outputs

### Decimal places
Can we confirm the expected number of decimal places for each table? The current
report appears to use different levels of precision (e.g. MCI is shown to 1–2 dp,
QMCI to 2 dp, CPUE to 2 dp).

### Output format
Should regenerated outputs be produced as:

- one file per table, or
- one file per table type (with one table per worksheet/tab)?

*(The regeneration currently produces one `.xlsx` file per table.)*

### Date format
Can we confirm the preferred date format for all outputs?

---

## Table 5.6 – Macroinvertebrate community metrics (Spring 2025)

> Assumption: your email referred to Tables 5.5 and 5.6, but I've taken this to
> mean Tables 5.6 and 5.7 — there was no data available for Table 5.5, and Tables
> 5.6 (Spring 2025) and 5.7 (Summer 2026) are essentially the same table. Please
> confirm this is what you intended.

### 4. Dominant taxa
I've been able to reproduce the printed table using several different rules (for
example, "the two most abundant taxa, keeping the second only if it's at least
50% of the most abundant", or "all taxa at least 75% of the most abundant"), but
those methods would produce different results for other datasets.

A simple "% of total abundance" threshold doesn't appear to fit, as EM3's
Elmidae (20%) is excluded while EM4's Nothodixa (17.9%) is included.

**Currently implemented method:** for each site, taxon counts are summed across
the replicate samples (kōura excluded), then the taxa are ranked by total
abundance. The **most abundant taxon is always reported**, and the
**second-most-abundant is reported alongside it only if its count is at least
50% of the most abundant taxon's count** — so each site lists one or two
dominant taxa. This is the first of the candidate rules above; it reproduces
Table 5.6 but is not based on a documented definition.

**Can you confirm the intended definition of "dominant taxa"?**

### 5. MCI confidence interval
EM3's MCI value (121.53) has no ±95% confidence interval, while all other EM3
metrics (Individuals, Taxa, QMCI and %EPT) include one.

**Is the confidence interval intentionally omitted, or should it be shown?**

---

## Table 5.8 – Freshwater fish surveys

> Note: on both fish-richness and shrimp-abundance the reproduction matches the
> printed Table 5.8 exactly. The points below are places where the Section 5.2.9
> text and the table/footnotes appear to describe slightly different approaches,
> so it would help to confirm which was intended.

### 6. Taxa richness — treatment of shrimp
There appear to be two slightly different descriptions of how shrimp are treated
in taxa richness:

- **Table 5.8, footnote \*\*\*\*:** "Using taxa groups described in Section 5.2.9,
  **shrimp not included**."
- **Section 5.2.9, final bullet:** kōura and shrimp "were excluded from total fish
  caught, **but included within taxa richness**."

The printed richness values are consistent with shrimp being excluded. My method —
count distinct identified taxa present, include kōura, exclude shrimp and
unidentified taxa — reproduces 11 of the 12 site-season combinations (the 12th is
the EM2 Spring value in point 10, which looks like a possible data/transcription
outlier rather than a method difference).

**Can you confirm whether shrimp should be included or excluded from taxa
richness? (The footnote and the printed values both suggest excluded.)**

### 7. CPUE
I get an exact match to the report by dividing catch by the deployed effort of
6 mini-fyke nets and 12 GMTs per site, even where fewer nets actually recorded a
catch (for example, EM3 Spring has only five fyke nets in the data but CPUE is
still divided by six). This matches Section 5.2.9 ("six mini-fyke nets and 12
GMTs set at each site").

**Can you confirm that CPUE is based on deployed effort, and whether 6 fyke nets
and 12 GMTs is constant across all monitoring cycles?**

### 8. Shrimp abundance — method vs printed values
Section 5.2.9 describes the method as: score each trap (0–10 = Uncommon, 11–100 =
Common, 100+ = Abundant), then "**to assign the abundance by site, the most
frequent abundance category was chosen**" (i.e. the mode).

The printed values appear to correspond to the *average* of the per-trap scores
rather than the most frequent category. Assigning U = 1, C = 2, A = 3, averaging
and rounding reproduces all 12 sites; the most-frequent-category approach
reproduces 10. The two approaches differ at just two sites:

| Site | Per-trap scores | Most frequent (per §5.2.9) | Average → category | **Table 5.8 prints** |
|------|-----------------|----------------------------|--------------------|----------------------|
| EM4 Spring 2025 | 6× Uncommon, 4× Common, 3× Abundant | Uncommon | 1.77 → Common | Common |
| EM2 Summer 2026 | 8× Uncommon, 1× Common, 6× Abundant | Uncommon | 1.87 → Common | Common |

At these two sites Uncommon is the most frequent category, while the printed
value (Common) matches the average.

**Which approach is intended — the "most frequent category" method described in
Section 5.2.9 (which would make these two sites Uncommon), or the averaging
approach that matches the current table?**

### 9. Species mapping
I've mapped:

- "elver" → Unidentified eel species — consistent with Section 5.2.9 (elvers
  "not considered as a taxon"; "all eels were grouped together")
- "unidentified galaxiid" → Unidentified kōkopu species

**Can you confirm these groupings are correct?**

Related tension to confirm: Section 5.2.9 says "unidentified kōkopu" were
"assumed to be banded kōkopu" and "unidentified bully" assumed redfin bully, but
the table keeps **separate "Unid. kōkopu sp." / "Unid. bully sp." rows** (footnote
\*\*\*: included in the total, but not counted as a separate taxon). The
reproduction follows the table (separate unidentified rows), not the
"assumed to be…" grouping. Should the unidentified fish be folded into the
assumed species, or kept separate as the table shows?

### 10. Values worth checking against the source data
Two values look like possible outliers relative to the underlying data:

- **EM2 Spring** taxa richness is reported as **4**, whereas I can identify five
  taxa and the reported total (673) appears to include all five.
- **EM2 Summer** reports one Unidentified eel species, but I can't locate an
  unidentified eel in the source data and the reported total (560) doesn't appear
  to include one.

**Could you please check these two values against the source data?**

---

## Appendix B1

### 11. Table 3 – Included seasons
**Which seasons should be included by default in this table?**

### 12. Table 4 – Residual pool depth confidence intervals — RESOLVED
The printed ±95% confidence intervals match a **t-distribution** confidence
interval (t(0.975, N−1)·sd/√N, with within-season surveys pooled), whereas the
confidence intervals stored in the RPD spreadsheet use a standard 1.96 (z)
multiplier and are noticeably narrower (roughly 2.2× smaller).

**Should the report continue using the t-based confidence intervals?**

> **Confirmed 2026-07-29: t-based only.** The spreadsheet's z convention is not
> reproduced anywhere — the RPD sheet's own per-survey CI is now t-based too, not
> just Table 4's pooled one.

### 13. Season assignment — RESOLVED
To reproduce the report, I had to treat the Summer survey round as
**December–March** (and Autumn as April–May). For example, EM5's 12 March 2025
survey appears in Summer 2025.

**Is season assigned by survey round rather than by calendar month?**

> **Confirmed 2026-07-29: use the source's own Season labels, do not infer.** The
> raw "Residual pool depths" sheet records Season and Year per survey, and those
> values are now used directly. The December–March rule survives only as a
> fallback for surveys the sheet leaves blank (baseline and event-based ones) and
> for workbooks that carry only the pre-summarised `RPD Summary` tab.

---

## Appendix B3 – Spot water quality

### 14. EM2 Summer dissolved oxygen
EM2 Summer DO is reported as **88.5 mg/L**, which stands out as an outlier
against the other sites (around 8–10 mg/L) — it is close to the range you'd
expect for a percent-saturation value, so it may be worth a look.

**Could you check the source value?**
