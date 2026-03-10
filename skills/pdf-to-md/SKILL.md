---
name: pdf-to-md
description: 'Convert PDF files to Markdown. Use for requests like "convert PDF to markdown", "pdf to md", "extract text from PDF", "convert this PDF", or any .pdf file conversion task. Handles text cleanup, paragraph joining, footer/header removal, and hyphen fixing.'
argument-hint: 'Path to PDF file, or leave blank if file is already referenced'
---

# PDF to Markdown Conversion

## When to Use
- User asks to convert a `.pdf` to `.md`
- User references a PDF file and wants markdown
- Extracting readable text from legal documents, letters, reports

## Dependencies

Requires `pymupdf4llm`. Install if missing:
```
pip install pymupdf4llm
```

## Procedure

1. **Locate the PDF** — use the referenced file or search the workspace for the named PDF.

2. **Run conversion** using this Python snippet (adapt paths as needed):

```python
import pymupdf4llm, re, pathlib

pdf_path = "path/to/file.pdf"
out_path = pathlib.Path(pdf_path).with_suffix(".md")

md = pymupdf4llm.to_markdown(pdf_path)
lines = md.split('\n')
cleaned = []

# Pass 1: filter repeating headers/footers and bare page numbers
# Customize the footer pattern for the specific document if needed
for ln in lines:
    s = ln.rstrip()
    if re.match(r'^\d{1,2}$', s):   # standalone page numbers
        continue
    cleaned.append(s)

# Pass 2: join wrapped paragraph lines
# Only join if accumulated line is long (>=65 chars) and doesn't end a sentence
result = []
i = 0
while i < len(cleaned):
    ln = cleaned[i]
    if ln == '':
        result.append('')
        i += 1
        continue
    buf = ln
    while (i + 1 < len(cleaned) and
           cleaned[i+1] != '' and
           len(buf) >= 65 and
           not re.search(r'[.!?]\s*\*{0,2}$', buf)):
        i += 1
        buf = buf + ' ' + cleaned[i]
    result.append(buf)
    i += 1

# Pass 3: collapse multiple blank lines
final_lines = []
prev_blank = False
for ln in result:
    if ln == '':
        if not prev_blank:
            final_lines.append(ln)
        prev_blank = True
    else:
        final_lines.append(ln)
        prev_blank = False

out_path.write_text('\n'.join(final_lines).strip(), encoding='utf-8')
print("Written to", out_path)
```

3. **Fix common PDF text artifacts** after conversion:
   - Merged hyphenated words: `abovereferenced` → `above-referenced`, `furnacerelated` → `furnace-related`, `proofof-service` → `proof-of-service`
   - Split bold spans: `**word- ** **continuation**` → `**word-continuation**`
   - Mid-sentence paragraph breaks: look for paragraphs ending without punctuation before the break

4. **Remove repeating footers** — if a law firm / header address appears on each page, identify the pattern in Pass 1 and filter it. Example:
   ```python
   if s.startswith('401 West A Street,'):  # customize per document
       continue
   ```

5. **Write output** to `<same-name>.md` alongside the PDF, unless the user specifies otherwise.

6. **Review quality** — open the `.md` file and check for any remaining artifacts.

## Notes

- `pymupdf4llm` preserves bold/italic formatting and basic document structure.
- For scanned/image PDFs (no embedded text), use the `ocr-scan` skill instead.
- For complex multi-column layouts, consider `pymupdf_layout` package for improved analysis.
