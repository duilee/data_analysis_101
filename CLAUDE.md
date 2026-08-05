# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Practice code and example data for a Korean-language **data-analysis book** (데이터 분석 책). Each chapter is a self-contained, runnable teaching artifact — not production code. The audience is a reader following along with the book, so clarity and reproducibility matter more than abstraction or performance.

## Repository structure

- **One folder per chapter**, named after the Korean chapter title with spaces → underscores and `?`/illegal characters dropped (e.g. `이_기능은_DAU_얼마짜리_기능일까/`).
- The top-level `README.md` holds a chapter index table; add a row when creating a new chapter.
- `.claude/skills/da101/` is a reader-facing Claude Code skill (method router + one `references/*.md` per chapter), also user-invocable as the `/da101` slash command. When adding or changing a chapter, update the skill's routing table and the matching reference file.
- A chapter folder contains: `README.md`, `requirements.txt`, a seeded `generate_data.py`, generated data in `data/*.csv`, optional `sql/*.sql`, and a Jupyter notebook that walks through the book's 실습 (practice) sections.

## Running / verifying a chapter

From inside a chapter folder:

```bash
python generate_data.py                                          # (re)generate data/*.csv
jupyter nbconvert --to notebook --execute --inplace <notebook>.ipynb   # run end-to-end
```

The notebook's first code cell installs deps via `%pip install -q -r requirements.txt`, so a reader does not run pip separately. **Always verify a chapter end-to-end before finishing**: run the generator, then execute the notebook and confirm exit 0 with no error outputs.

## Authoring conventions (important — these are deliberate teaching choices)

- **Synthetic data is generated from known parameters** (e.g. a planted power-law retention curve with chosen `a`, `b`), so the notebook's fitted results visibly recover the truth. This is the point — it lets the reader confirm the method works. Keep generators seeded for reproducibility.
- **Run SQL locally via DuckDB** on the committed CSV (`duckdb.query(sql).to_df()`), and **also show the SQL inline in a notebook cell** (as a `query = """ … """` string) so the reader sees the actual query, in addition to the standalone `sql/*.sql` file.
- **Keep example files self-contained.** Do NOT reference the original/real data source in chapter files — no BigQuery, real table names (e.g. `mart_user__active_daily`), `client.query`, or "원본 쿼리" mentions. It must read as standalone example material.
- **Don't hardcode values that can only be known after running** (e.g. `curve_fit` `p0` initial guesses) — let defaults work, since the reader can't determine them up front.
- Use **`%pip`** (the kernel magic), not `!pip`, for in-notebook installs.
- **Plot labels in English** (avoids matplotlib Korean-font glyph issues); markdown narration stays **Korean**.
- **Keep chapter READMEs short**: title + 1-line intro, a brief 실습 summary (one bullet per 실습), an `## 실행 방법` block, and a small `## 파일 구성` table. The conceptual theory lives in the book, not the README.
- **Chapter scope is decided per chapter** — don't assume a notebook must mirror every 실습 section of the book; confirm what to include.

## Git

Commit messages are written in Korean. Commit/push only when asked.
