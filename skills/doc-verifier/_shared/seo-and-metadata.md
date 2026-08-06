# SEO & Metadata Rules for Azure Documentation

Consolidated SEO optimization and metadata field specifications for Microsoft Learn articles. Merges title, description, H1, customer-intent, ms.date, ms.topic rules, and SEO checklist items into a single reference.

---

## Title (`title:` in YAML frontmatter)

| Rule | Requirement |
|---|---|
| Length | 30–65 characters (including spaces) |
| Case | **Title case** (capitalize major words; lowercase articles, prepositions, conjunctions unless first word) |
| Primary keyword | Include near the beginning |
| Uniqueness | Must differ from H1 and description |
| Gerunds | Avoid -ing words at start |
| Error codes | Prefix with error code for troubleshooting articles |
| Brand names | Use official product names (Azure Virtual Machines, not VMs) |

### Title quality checklist

- [ ] Contains primary keyword
- [ ] 30–65 characters
- [ ] Title case applied correctly
- [ ] Different from H1 heading
- [ ] Different from meta description
- [ ] No gerund (-ing) at start
- [ ] Would make sense as a search result

### Title examples

| Good | Bad | Why |
|---|---|---|
| Configure Health Probes for Azure Load Balancer | Configuring Azure Load Balancer Health Probes in Your Environment | Too long (67 chars), starts with gerund |
| Troubleshoot Error 502 - Azure Application Gateway | Azure Application Gateway Errors | Too vague, missing error code |
| Create a Virtual Network Using Azure Portal | How to Create a Virtual Network | Missing service context |

---

## Description (`description:` in YAML frontmatter)

| Rule | Requirement |
|---|---|
| Length | 120–165 characters (including spaces) |
| Primary keyword | At the beginning of the description |
| Call-to-action | Include one (Learn how to..., Find out..., Discover...) |
| Uniqueness | Must differ from title and H1 |
| Voice | Active language, compelling copy |
| Purpose | Convince searcher to click |
| Trailing period | No trailing period unless it's a complete sentence |

### Description quality checklist

- [ ] Contains primary keyword at start
- [ ] 120–165 characters
- [ ] Includes call-to-action
- [ ] Different from title
- [ ] Different from H1
- [ ] Uses active voice
- [ ] Would compel a click from search results

### Description examples

| Good (142 chars) | Bad (98 chars) |
|---|---|
| Learn how to configure health probes for Azure Load Balancer to monitor backend pool instance availability and route traffic effectively. | This article describes health probes in Azure Load Balancer. |

---

## H1 Heading (first `#` in article body)

| Rule | Requirement |
|---|---|
| Case | **Sentence case** (only capitalize first word and proper nouns) |
| Primary keyword | Include in the H1 |
| Gerunds | No -ing words |
| Count | Exactly one H1 per article |
| Unique from title | Title is title case; H1 is sentence case — they should differ |

> [!IMPORTANT]
> H1 uses **sentence case** while title uses **title case**. This is a common mistake — subheadings also use sentence case.

### H1 examples

| Good | Bad | Why |
|---|---|---|
| Configure health probes for Azure Load Balancer | Configure Health Probes For Azure Load Balancer | Title case used instead of sentence case |
| What is Azure Virtual Network? | Understanding Azure Virtual Network | Gerund start |

---

## Intro Paragraph

| Rule | Requirement |
|---|---|
| Primary keyword | Must appear in the first or second sentence |
| Length | 2–3 sentences recommended |
| Purpose | Establish what the article covers and for whom |
| Customer intent | Align with the `ms.custom: customer-intent` value |

---

## Subheadings (H2, H3, H4)

| Rule | Requirement |
|---|---|
| Case | **Sentence case** (NOT title case) |
| Secondary keywords | Include where natural |
| Gerunds | Avoid -ing words |
| Standard headings | Preserve template headings: Prerequisites, Related content, Next steps, Clean up resources, Overview |
| Hierarchy | No skipped levels (H2 → H3 → H4) |
| Periods | No periods at the end of headings |

---

## Customer Intent (`ms.custom: customer-intent="..."`)

Use the agile user story format:

```
As a <type of user>, I want <what?> so that <why?>
```

### Rules

1. **User role**: Use a specific Azure role (developer, network administrator, DevOps engineer, IT administrator, solution architect)
2. **What**: State the specific task or information need
3. **Why**: State the business outcome or value

### Customer intent examples

| Article type | Customer intent |
|---|---|
| How-to | `As a network administrator, I want to configure health probes for Azure Load Balancer so that I can monitor backend instance availability.` |
| Concept | `As a solution architect, I want to understand Azure Virtual Network peering so that I can design cross-region network connectivity.` |
| Quickstart | `As a developer, I want to deploy my first Azure Function so that I can run serverless code in the cloud.` |
| Troubleshooting | `As an IT administrator, I want to resolve error 502 on Application Gateway so that I can restore application availability.` |

---

## ms.date

- **Format**: `MM/DD/YYYY`
- **When to update**: Update when making substantive content changes, not for typo fixes
- **Freshness target**: Articles should be reviewed at least every 12 months

---

## ms.topic

| Article type | ms.topic value |
|---|---|
| How-to guide | `how-to` |
| Conceptual | `concept-article` |
| Quickstart | `quickstart` |
| Tutorial | `tutorial` |
| Overview | `overview` |
| Reference | `reference` |
| Troubleshooting | `troubleshooting` |
| FAQ | `faq` |
| Sample | `sample` |

---

## Image Alt Text

| Rule | Requirement |
|---|---|
| Length | 40–150 characters |
| Format | Start with "Screenshot of..." or "Diagram of..." |
| Content | Describe what the image shows, not what it is |
| Keywords | Include relevant keywords when natural |
| Decorative images | Use empty alt text `alt=""` only for purely decorative images |

---

## Internal Linking

| Rule | Requirement |
|---|---|
| Relative links | Use relative paths for links within the same docset |
| Anchor text | Use descriptive text, not "click here" or "this article" |
| Related content | Include 3–5 related links in the Related content section |
| Next steps | Include 1–3 actionable next steps with links |

---

## Required Frontmatter Template

Every Azure docs article must include:

```yaml
---
title: # 30-65 chars, title case
description: # 120-165 chars, CTA, primary keyword
ms.date: # MM/DD/YYYY
ms.topic: # article type
ms.service: # Azure service slug
ms.custom: # customer-intent="As a..."
author: # GitHub username
ms.author: # Microsoft alias
---
```
