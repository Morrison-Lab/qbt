# GitHub Copilot Instructions

This file provides custom instructions for GitHub Copilot when working in this repository.

## General Guidelines

Follow the guidance in the [UCD-SERG Lab Manual](https://ucd-serg.github.io/lab-manual/).

The source files for the lab manual are available at <https://github.com/UCD-SERG/lab-manual> if easier to read.

## Style Guidelines

### Lists

When describing lists of three or more items, use a bullet list instead of a comma-separated list. Use your stylistic judgment to determine when this rule applies.

**Examples:**

❌ **Don't** use comma-separated lists for three or more items:
```
The template includes GitHub Actions workflows for publishing, link checking, and spell checking.
```

✅ **Do** use bullet lists instead:
```
The template includes GitHub Actions workflows for:

- Publishing
- Link checking
- Spell checking
```

Always put a blank line before the start of a bullet-point list in markdown (`.md`) files and variants (especially Quarto `.qmd` files).

**When to use your judgment:**

- Short, simple items in a sentence may remain comma-separated if it maintains readability
- Complex items or items with descriptions should always use bullet lists
- Use bullet lists when the items are important and deserve emphasis
- Technical lists (commands, file names, features) typically benefit from bullet format

## Code Chunks

### Code Folding

Use `code-fold: true` for code chunks where the output is what's important to the narrative and not the code used to produce it. This allows readers to focus on the results while still having the option to view the code if they want to.

**When to use `code-fold: true`:**

- Visualization code where the plot/figure is the main point
- Data preparation or cleaning code that produces a summary table
- Long or complex code that would distract from the narrative
- Code that generates output (plots, tables, results) that readers need to see

**When NOT to use `code-fold: true`:**

- Tutorial code where readers need to learn the syntax
- Short, simple examples that are part of the explanation
- Code that is the main focus of the section
- When the console output is part of the main content (unformatted tables, model summaries, etc.)

**Example:**

````markdown
```{{r}}
#| code-fold: true
#| fig-cap: "Relationship between weight and miles per gallon"

library(ggplot2)
ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point() +
  geom_smooth(method = "lm") +
  theme_minimal() +
  labs(x = "Weight (1000 lbs)", y = "Miles per Gallon")
```
````

## Quality Assurance

### Testing Renders

Before requesting review or marking work as complete:

- **Always test your changes locally** by running `quarto render` or rendering specific files
- **Check the rendered output** in the `docs/` directory to verify:
  - All content displays correctly
  - Macros are rendering properly (if applicable)
  - No broken links or missing images
  - Formatting is as expected
- **Review the PR preview** at the preview URL to ensure everything works in the deployed version
- **Fix any rendering issues** before requesting review

This ensures that reviewers see working, polished output rather than discovering basic rendering problems.

## CI Workflows

### Job Time Limits

Every job this repository defines must set `timeout-minutes`.
The value must be no more than 50.
Without it a job inherits GitHub's 6-hour default.
A hung step then burns runner minutes for hours before anyone notices.

- **Add `timeout-minutes` to every new job**, sized to the work
- **Use 20 for lint and check jobs**, and 45 for jobs that render or deploy the book
- **Never exceed 50**, even for a slow job

A job that genuinely needs longer is a signal to split it, not to raise the ceiling.

Jobs that call a reusable workflow are the exception, and not by choice.
GitHub rejects `timeout-minutes` on a job that uses `uses:`.
The limit therefore has to live in the reusable workflow itself.
The `Morrison-Lab/gha` workflows this repo calls already set their own.
Those callers need nothing here, and adding a limit to them makes the workflow fail to parse.

## Agent Sessions

### Check for New Comments Before Finishing

A session can run long enough that new comments arrive while it is working.
Those comments are not delivered to the session automatically.
An agent that finishes without looking again will miss them.

Before ending a session, re-read the issue or pull request being worked on:

- **Check for comments posted after the session started**, including reviews and corrections
- **Address anything new** as if it had been there from the beginning
- **Reply explaining why** when something will not be actioned, rather than leaving it unanswered

Only finish once nothing is left unanswered.
The same rule is applied to Claude sessions through `prompt-addendum` in `.github/workflows/claude.yml`.
