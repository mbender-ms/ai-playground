# Formatting & Auto-Fix Rules for Azure Documentation

Consolidated formatting standards and auto-fix rules for Microsoft Learn articles. Used by `doc-writer` (authoring), `documentor-workflow` (editing), and any skill that writes or fixes markdown.

---

## Heading Rules

| Rule | Auto-fix |
|---|---|
| One H1 per article, matches `title` frontmatter | Keep first H1; demote extras to H2 |
| No heading level skips (H2 → H4) | Insert intermediate or adjust level |
| Sentence-style capitalization on H2–H6 | Convert to sentence case (first word + proper nouns only) |
| No trailing period on headings (except `?`) | Remove trailing period |
| No inline formatting in headings (bold, code, links) | Strip formatting |
| Blank line before and after every heading | Add blank line |

---

## Code Fence Language Identifiers

Always include a language identifier — never use bare triple backticks.

| Context | Correct | Incorrect |
|---|---|---|
| Azure CLI commands | `azurecli` | `bash`, `shell`, `cli` |
| Azure PowerShell commands | `azurepowershell` | `powershell`, `ps`, `ps1` |
| ARM templates | `json` | `arm`, `armjson` |
| Bicep templates | `bicep` | — |
| Azure Resource Graph | `kusto` | `kql` |
| .NET / C# | `csharp` | `cs`, `c#` |
| Python | `python` | `py` |
| JavaScript | `javascript` | `js` |
| TypeScript | `typescript` | `ts` |
| Bash scripts (non-Azure CLI) | `bash` | `sh`, `shell` |
| PowerShell scripts (non-Azure) | `powershell` | `ps`, `ps1` |
| YAML configuration | `yaml` | `yml` |
| XML | `xml` | — |
| HTTP requests | `http` | `rest`, `api` |
| Console output | `output` | `console`, `text`, `plaintext` |
| Dockerfile | `dockerfile` | `docker` |
| Terraform | `terraform` | `tf`, `hcl` |
| JSON (general) | `json` | — |

### Code fence formatting

- Add a blank line before and after code fences
- Don't nest code fences

---

## Alert Block Syntax

```markdown
> [!NOTE]
> Supplementary information the reader should know.

> [!TIP]
> Optional advice to help the reader be more successful.

> [!IMPORTANT]
> Essential information required for success.

> [!CAUTION]
> Potential negative consequences of an action.

> [!WARNING]
> Dangerous consequences of an action.
```

### Alert auto-fixes

| Issue | Fix |
|---|---|
| `> **Note:**` or `> Note:` | Convert to `> [!NOTE]` |
| `> **Tip:**` or `> Tip:` | Convert to `> [!TIP]` |
| `> **Important:**` or `> Important:` | Convert to `> [!IMPORTANT]` |
| `> **Warning:**` or `> Warning:` | Convert to `> [!WARNING]` |
| `> **Caution:**` or `> Caution:` | Convert to `> [!CAUTION]` |
| Missing blank line before/after alert | Add blank line |
| Alert text not on `> ` continuation line | Move to `> ` prefixed line |

---

## Tables

Use tables for:
- Configuration settings (Setting | Value | Description)
- Portal navigation steps (Field | Value)
- Feature comparisons
- Parameter/property reference

Format:

```markdown
| Setting | Value | Description |
|---|---|---|
| Name | *myResource* | A unique name for the resource. |
| Region | East US | Select the region closest to your users. |
```

### Table auto-fixes

| Rule | Fix |
|---|---|
| Missing header separator row | Add `\|---\|---\|` row |
| Inconsistent column count | Pad shorter rows with empty cells |
| Missing leading/trailing pipes | Add pipes to all rows |
| Missing blank line before/after table | Add blank line |

---

## Lists

- **Numbered lists**: For sequential steps (procedures)
  - Use `1.` for all items (Markdown auto-numbers)
  - Maximum 7 steps per numbered list
  - Start each step with an imperative verb
- **Bulleted lists**: For non-sequential items
  - Use `-` (hyphen) for bullets
  - Use parallel construction (all start with same part of speech)

### List auto-fixes

| Rule | Fix |
|---|---|
| Mixed list markers (`-` and `*`) | Standardize to `-` for unordered lists |
| Missing blank line before/after list | Add blank line |
| Nested list wrong indentation | Use 2-space or 4-space indentation consistently |
| Ordered list wrong numbering | Use `1.` for all items |
| Missing blank line between complex list items | Add blank line between items with sub-content |

---

## Cross-Links

- **Internal links**: Use relative paths — `[Link text](other-article.md)`
- **Same-folder links**: `[Link text](./sibling-article.md)`
- **Parent-folder links**: `[Link text](../parent-folder/article.md)`
- **Service links**: `[Link text](/azure/service-name/article-name)`
- **Include files**: `[!INCLUDE [description](~/path/to/include.md)]`
- **Never use absolute URLs** for docs.microsoft.com or learn.microsoft.com content

### Link auto-fixes

| Rule | Fix |
|---|---|
| Bare URLs | Wrap in markdown link syntax `[display text](url)` |
| `https://learn.microsoft.com/...` absolute links to same docset | Convert to relative paths |
| Links with locale `/en-us/` | Remove locale segment |
| Broken anchor links | Fix to match actual heading (lowercase, hyphens for spaces) |
| "click here" anchor text | Replace with descriptive text |
| Link text same as URL | Replace with descriptive text |

---

## UI Element Formatting

- **Bold** for UI elements: Select **Create**, then select **Review + create**
- *Italics* for user-provided values: Enter *myResourceGroup* for the name
- `Code` for commands, parameters, file names: Run `az group create`
- "Quotes" for menu paths when needed: Go to "Settings" > "Configuration"

### UI interaction verbs

| Action | Verb | Example |
|---|---|---|
| Buttons / links / tabs | select | Select **Create** |
| Text input | enter | Enter *myValue* |
| Drop-down menus | select | Select **East US** |
| Checkboxes | select / clear | Select the **Enable** checkbox |
| Open apps / files | open | Open the Azure portal |
| Navigate menus | go to | Go to **Settings** > **Configuration** |

Do NOT use: click, click on, press, hit, type, choose.

---

## Images and Screenshots

- **Prefer text instructions** over screenshots
- If images are required: `:::image type="content" source="./media/folder/image-name.png" alt-text="Screenshot of the Azure portal showing the resource creation page.":::`
- Alt text format: "Screenshot of..." or "Diagram of..." describing what the reader sees
- Store images in `./media/<article-name>/` folder
- Use `.png` for screenshots, `.svg` for diagrams

### Image auto-fixes

| Rule | Fix |
|---|---|
| Missing alt text `![]()` | Add descriptive alt text (40-150 chars) |
| Alt text too short (< 40 chars) | Expand to be more descriptive |
| Alt text too long (> 150 chars) | Shorten while keeping meaning |
| Missing "Screenshot of" prefix | Add appropriate prefix |
| Image without surrounding blank lines | Add blank lines before and after |

---

## Spacing & Whitespace

| Rule | Fix |
|---|---|
| Trailing whitespace on lines | Remove trailing spaces |
| Multiple consecutive blank lines | Reduce to single blank line |
| No newline at end of file | Add single trailing newline |
| Tabs for indentation | Convert to spaces |
| Extra spaces between words | Reduce to single space |
| Missing blank line before/after block elements | Add blank line |

---

## Frontmatter Formatting

| Rule | Fix |
|---|---|
| Missing `---` delimiters | Add opening and closing `---` |
| Missing required fields | Add with placeholder values and flag for review |
| `ms.date` in wrong format | Convert to `MM/DD/YYYY` |
| Title over 65 characters | Flag for review (don't auto-truncate) |
| Description over 165 characters | Flag for review (don't auto-truncate) |
| Description under 120 characters | Flag for review (don't auto-expand) |
