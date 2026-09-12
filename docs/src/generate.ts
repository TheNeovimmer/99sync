import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

type DocsTag = "base" | "include";

type FieldDoc = {
  name: string;
  type: string;
  line: number;
  descriptionLines: string[];
  defaultValue?: string;
};

type ClassDoc = {
  name: string;
  extendsType?: string;
  line: number;
  filePath: string;
  tags: Set<DocsTag>;
  descriptionLines: string[];
  fields: FieldDoc[];
  references: string[];
};

const COMMENT_LINE = /^\s*---\s?(.*)$/;

async function main(): Promise<void> {
  const checkMode = process.argv.includes("--check");
  const stdoutMode = process.argv.includes("--stdout");

  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  const docsRoot = path.resolve(scriptDir, "..");
  const repoRoot = path.resolve(docsRoot, "..");
  const luaRoot = path.join(repoRoot, "lua", "99sync");
  const readmePath = path.join(docsRoot, "README.md");

  const luaFiles = await collectLuaFiles(luaRoot);
  const parsedClasses = await parseClassesFromFiles(luaFiles, repoRoot);
  const classesByName = dedupeClasses(parsedClasses);

  attachReferences(classesByName);

  const rootNames = [...classesByName.values()]
    .filter((cls) => cls.tags.has("base"))
    .map((cls) => cls.name)
    .sort((a, b) => a.localeCompare(b));

  const reachableNames = resolveReachableTypes(rootNames, classesByName);
  const documentedNames = reachableNames.filter((name) => {
    const cls = classesByName.get(name);
    return Boolean(cls && (cls.tags.has("base") || cls.tags.has("include")));
  });

  const markdown = renderMarkdown(documentedNames, classesByName);

  if (stdoutMode) {
    process.stdout.write(markdown);
    return;
  }

  if (checkMode) {
    const existing = await readFileIfExists(readmePath);
    if (existing !== markdown) {
      console.error("[docs] README.md is out of date. Run: ./gen-docs");
      process.exitCode = 1;
      return;
    }

    console.log("[docs] README.md is up to date");
    return;
  }

  await fs.writeFile(readmePath, markdown, "utf8");
  console.log(`[docs] wrote ${path.relative(repoRoot, readmePath)}`);
}

function renderMarkdown(
  documentedNames: string[],
  classesByName: Map<string, ClassDoc>,
): string {
  const lines: string[] = [];

  lines.push("# 99sync");
  lines.push("The AI Neovim experience");

  if (documentedNames.length === 0) {
    lines.push("");
    lines.push("No documented types found.");
    return `${lines.join("\n")}\n`;
  }

  for (const name of documentedNames) {
    const cls = classesByName.get(name);
    if (!cls) {
      continue;
    }

    const classDescription = renderDescription(cls.descriptionLines);
    const documentedFields = cls.fields.filter(
      (field) => renderDescription(field.descriptionLines).length > 0,
    );
    if (classDescription.length === 0 && documentedFields.length === 0) {
      continue;
    }

    lines.push("");
    lines.push(`## ${cls.name}`);

    if (classDescription.length > 0) {
      lines.push(...classDescription);
    }

    lines.push("");
    lines.push("### Description");
    lines.push("| Name | Type | Default Value |");
    lines.push("| --- | --- | --- |");

    if (cls.fields.length === 0) {
      lines.push("| - | - | - |");
    } else {
      for (const field of cls.fields) {
        lines.push(
          `| \`${escapeTableCell(field.name)}\` | \`${escapeTableCell(field.type)}\` | ${escapeTableCell(field.defaultValue ?? "-")} |`,
        );
      }
    }

    lines.push("");
    lines.push("### API");

    if (documentedFields.length === 0) {
      continue;
    }
    for (const field of documentedFields) {
      lines.push("");
      lines.push(`#### ${field.name}`);

      const fieldDescription = renderDescription(field.descriptionLines);
      if (fieldDescription.length > 0) {
        lines.push(...fieldDescription);
      }

      if (field.defaultValue) {
        lines.push("");
        lines.push(`**default**: ${field.defaultValue}`);
      }
    }
  }

  return `${lines.join("\n")}\n`;
}

function renderDescription(rawLines: string[]): string[] {
  const trimmed = trimEdgeBlankLines(rawLines);
  return trimmed;
}

function trimEdgeBlankLines(lines: string[]): string[] {
  let start = 0;
  let end = lines.length;

  while (start < end && lines[start]?.trim().length === 0) {
    start += 1;
  }

  while (end > start && lines[end - 1]?.trim().length === 0) {
    end -= 1;
  }

  return lines.slice(start, end);
}

function escapeTableCell(value: string): string {
  const normalized = normalizeWhitespace(value);
  if (normalized.length === 0) {
    return "-";
  }

  return normalized.replace(/\|/g, "\\|");
}

function resolveReachableTypes(
  roots: string[],
  classesByName: Map<string, ClassDoc>,
): string[] {
  const visited = new Set<string>();
  const queue = [...roots];
  const order: string[] = [];

  while (queue.length > 0) {
    const name = queue.shift();
    if (!name || visited.has(name)) {
      continue;
    }

    const cls = classesByName.get(name);
    if (!cls) {
      continue;
    }

    visited.add(name);
    order.push(name);

    for (const ref of cls.references) {
      if (!visited.has(ref)) {
        queue.push(ref);
      }
    }
  }

  return order;
}

function attachReferences(classesByName: Map<string, ClassDoc>): void {
  const names = new Set(classesByName.keys());

  for (const cls of classesByName.values()) {
    const refs = new Set<string>();

    if (cls.extendsType) {
      for (const token of extractTypeTokens(cls.extendsType)) {
        if (token !== cls.name && names.has(token)) {
          refs.add(token);
        }
      }
    }

    for (const field of cls.fields) {
      for (const token of extractTypeTokens(field.type)) {
        if (token !== cls.name && names.has(token)) {
          refs.add(token);
        }
      }
    }

    cls.references = [...refs].sort((a, b) => a.localeCompare(b));
  }
}

function extractTypeTokens(typeExpression: string): string[] {
  const withoutStrings = typeExpression.replace(
    /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g,
    " ",
  );

  const matches = withoutStrings.match(/[A-Za-z_][A-Za-z0-9_.]*/g);
  return matches ?? [];
}

function dedupeClasses(parsed: ClassDoc[]): Map<string, ClassDoc> {
  const sorted = [...parsed].sort((a, b) => {
    const byName = a.name.localeCompare(b.name);
    if (byName !== 0) {
      return byName;
    }

    const byPath = a.filePath.localeCompare(b.filePath);
    if (byPath !== 0) {
      return byPath;
    }

    return a.line - b.line;
  });

  const classesByName = new Map<string, ClassDoc>();

  for (const cls of sorted) {
    const existing = classesByName.get(cls.name);
    if (!existing) {
      classesByName.set(cls.name, cls);
      continue;
    }

    classesByName.set(cls.name, pickPreferredClass(existing, cls));
  }

  return classesByName;
}

function pickPreferredClass(a: ClassDoc, b: ClassDoc): ClassDoc {
  const score = (cls: ClassDoc): number => {
    const docsWeight = cls.tags.size > 0 ? 1000 : 0;
    const testPenalty = cls.filePath.includes("/test/") ? -100 : 0;
    return docsWeight + cls.fields.length + testPenalty;
  };

  return score(b) > score(a) ? b : a;
}

async function parseClassesFromFiles(
  luaFiles: string[],
  repoRoot: string,
): Promise<ClassDoc[]> {
  const classes: ClassDoc[] = [];

  for (const file of luaFiles) {
    const source = await fs.readFile(file, "utf8");
    const relative = normalizePath(path.relative(repoRoot, file));
    classes.push(...parseLuaDocClasses(source, relative));
  }

  return classes;
}

function parseLuaDocClasses(source: string, filePath: string): ClassDoc[] {
  const lines = source.split(/\r?\n/);
  const classes: ClassDoc[] = [];

  let pendingTags = new Set<DocsTag>();
  let currentClass: ClassDoc | undefined;
  let currentField: FieldDoc | undefined;

  const flushCurrentClass = (): void => {
    if (!currentClass) {
      return;
    }

    classes.push(currentClass);
    currentClass = undefined;
    currentField = undefined;
  };

  for (let i = 0; i < lines.length; i += 1) {
    const commentMatch = lines[i]?.match(COMMENT_LINE);

    if (!commentMatch) {
      flushCurrentClass();
      pendingTags = new Set<DocsTag>();
      continue;
    }

    const text = commentMatch[1] ?? "";
    const tagText = text.trim();

    if (tagText.startsWith("@class ")) {
      flushCurrentClass();

      const parsedClass = parseClassSignature(tagText.slice("@class ".length));
      if (!parsedClass) {
        pendingTags = new Set<DocsTag>();
        continue;
      }

      currentClass = {
        name: parsedClass.name,
        extendsType: parsedClass.extendsType,
        line: i + 1,
        filePath,
        tags: pendingTags,
        descriptionLines: parsedClass.description ? [parsedClass.description] : [],
        fields: [],
        references: [],
      };
      pendingTags = new Set<DocsTag>();
      currentField = undefined;
      continue;
    }

    const docsTag = parseDocsTag(tagText);
    if (docsTag) {
      if (currentClass) {
        currentClass.tags.add(docsTag);
      } else {
        pendingTags.add(docsTag);
      }
      continue;
    }

    if (!currentClass) {
      continue;
    }

    if (tagText.startsWith("@field ")) {
      const field = parseFieldSignature(tagText.slice("@field ".length), i + 1);
      if (field) {
        currentClass.fields.push(field);
        currentField = field;
      }
      continue;
    }

    if (tagText.startsWith("@")) {
      flushCurrentClass();
      pendingTags = new Set<DocsTag>();
      continue;
    }

    if (text.trim().length === 0) {
      if (currentField) {
        currentField.descriptionLines.push("");
      } else {
        currentClass.descriptionLines.push("");
      }
      continue;
    }

    if (currentField) {
      applyFieldDocLine(currentField, text);
    } else {
      currentClass.descriptionLines.push(text);
    }
  }

  flushCurrentClass();
  return classes;
}

function parseDocsTag(text: string): DocsTag | undefined {
  if (!text.startsWith("@docs ")) {
    return undefined;
  }

  const value = text
    .slice("@docs ".length)
    .trim()
    .split(/\s+/)[0]
    ?.toLowerCase();

  if (value === "base") {
    return "base";
  }

  if (value === "include" || value === "included") {
    return "include";
  }

  return undefined;
}

function parseClassSignature(signature: string): {
  name: string;
  extendsType?: string;
  description?: string;
} | null {
  const text = signature.trim();
  if (text.length === 0) {
    return null;
  }

  let cursor = 0;
  while (cursor < text.length && !/[\s:]/.test(text[cursor]!)) {
    cursor += 1;
  }

  const name = text.slice(0, cursor);
  if (name.length === 0) {
    return null;
  }

  let rest = text.slice(cursor).trim();
  let extendsType: string | undefined;

  if (rest.startsWith(":")) {
    rest = rest.slice(1).trim();

    let extendsCursor = 0;
    while (extendsCursor < rest.length && !/\s/.test(rest[extendsCursor]!)) {
      extendsCursor += 1;
    }

    extendsType = rest.slice(0, extendsCursor).trim();
    rest = rest.slice(extendsCursor).trim();
  }

  return {
    name,
    extendsType,
    description: rest.length > 0 ? rest : undefined,
  };
}

function parseFieldSignature(signature: string, line: number): FieldDoc | null {
  const text = signature.trim();
  if (text.length === 0) {
    return null;
  }

  const firstSpace = text.search(/\s/);
  if (firstSpace < 0) {
    const normalized = normalizeFieldOptionality(text, "unknown");
    return {
      name: normalized.name,
      type: normalized.type,
      line,
      descriptionLines: [],
    };
  }

  const rawName = text.slice(0, firstSpace).trim();
  const remainder = text.slice(firstSpace + 1).trim();
  const { type, description } = splitTypeAndDescription(remainder);
  const normalized = normalizeFieldOptionality(rawName, type);

  const field: FieldDoc = {
    name: normalized.name,
    type: normalized.type,
    line,
    descriptionLines: [],
  };

  if (description) {
    applyFieldDocLine(field, description);
  }

  return field;
}

function normalizeFieldOptionality(
  rawName: string,
  rawType: string,
): { name: string; type: string } {
  const optional = rawName.endsWith("?");
  const name = optional ? rawName.slice(0, -1) : rawName;
  let type = normalizeWhitespace(rawType);

  if (optional) {
    type = ensureNilInType(type);
  }

  return { name, type };
}

function ensureNilInType(typeExpression: string): string {
  if (/\bnil\b/.test(typeExpression)) {
    return typeExpression;
  }

  return `${typeExpression} | nil`;
}

function splitTypeAndDescription(input: string): {
  type: string;
  description?: string;
} {
  const text = input.trim();
  if (text.length === 0) {
    return { type: "unknown" };
  }

  let i = 0;
  let inQuote: '"' | "'" | null = null;
  let angleDepth = 0;
  let parenDepth = 0;
  let braceDepth = 0;
  let expectTypeAtom = true;

  while (i < text.length) {
    const ch = text[i]!;

    if (inQuote) {
      if (ch === "\\") {
        i += 2;
        continue;
      }

      if (ch === inQuote) {
        inQuote = null;
      }

      i += 1;
      continue;
    }

    if (ch === '"' || ch === "'") {
      inQuote = ch;
      expectTypeAtom = false;
      i += 1;
      continue;
    }

    if (ch === "<") {
      angleDepth += 1;
      expectTypeAtom = true;
      i += 1;
      continue;
    }

    if (ch === ">") {
      angleDepth = Math.max(0, angleDepth - 1);
      expectTypeAtom = false;
      i += 1;
      continue;
    }

    if (ch === "(") {
      parenDepth += 1;
      expectTypeAtom = true;
      i += 1;
      continue;
    }

    if (ch === ")") {
      parenDepth = Math.max(0, parenDepth - 1);
      expectTypeAtom = false;
      i += 1;
      continue;
    }

    if (ch === "{") {
      braceDepth += 1;
      expectTypeAtom = true;
      i += 1;
      continue;
    }

    if (ch === "}") {
      braceDepth = Math.max(0, braceDepth - 1);
      expectTypeAtom = false;
      i += 1;
      continue;
    }

    if (ch === "|" || ch === "," || ch === ":") {
      expectTypeAtom = true;
      i += 1;
      continue;
    }

    if (ch === "?") {
      expectTypeAtom = false;
      i += 1;
      continue;
    }

    if (ch === "[" && text[i + 1] === "]") {
      expectTypeAtom = false;
      i += 2;
      continue;
    }

    if (/\s/.test(ch)) {
      let j = i;
      while (j < text.length && /\s/.test(text[j]!)) {
        j += 1;
      }

      if (j >= text.length) {
        i = j;
        break;
      }

      const next = text[j]!;
      const nested = angleDepth > 0 || parenDepth > 0 || braceDepth > 0;
      if (nested) {
        i = j;
        continue;
      }

      if (
        next === "|"
        || next === ","
        || next === ":"
        || next === ">"
        || next === ")"
        || next === "}"
        || next === "?"
      ) {
        i = j;
        continue;
      }

      if (next === "[" && text[j + 1] === "]") {
        i = j;
        continue;
      }

      if (expectTypeAtom && /[A-Za-z_"']/.test(next)) {
        i = j;
        continue;
      }

      if (!expectTypeAtom && /[A-Za-z_"']/.test(next)) {
        break;
      }

      i = j;
      continue;
    }

    expectTypeAtom = false;
    i += 1;
  }

  const type = text.slice(0, i).trim();
  const description = text.slice(i).trim();

  return {
    type: type.length > 0 ? type : "unknown",
    description: description.length > 0 ? description : undefined,
  };
}

function applyFieldDocLine(field: FieldDoc, line: string): void {
  const { cleanedText, defaultValue } = stripDefaultDirective(line);

  if (defaultValue && !field.defaultValue) {
    field.defaultValue = defaultValue;
  }

  if (cleanedText.trim().length > 0) {
    field.descriptionLines.push(cleanedText);
  }
}

function stripDefaultDirective(text: string): {
  cleanedText: string;
  defaultValue?: string;
} {
  let cursor = 0;
  let capturedDefault: string | undefined;
  const keptChunks: string[] = [];

  while (cursor < text.length) {
    const tail = text.slice(cursor);
    const match = /\bdefault\s*=\s*/i.exec(tail);
    if (!match) {
      keptChunks.push(tail);
      break;
    }

    const start = cursor + match.index;
    const valueStart = start + match[0].length;
    const parsed = readDefaultValue(text, valueStart);
    if (!parsed) {
      keptChunks.push(tail);
      break;
    }

    keptChunks.push(text.slice(cursor, start));
    if (!capturedDefault) {
      capturedDefault = parsed.value.trim();
    }

    cursor = parsed.end;
  }

  return {
    cleanedText: keptChunks.join(""),
    defaultValue: capturedDefault,
  };
}

function readDefaultValue(
  source: string,
  startIndex: number,
): { value: string; end: number } | undefined {
  let i = startIndex;
  while (i < source.length && /\s/.test(source[i]!)) {
    i += 1;
  }

  if (i >= source.length) {
    return undefined;
  }

  const start = i;
  const opening = source[i]!;

  if (opening === '"' || opening === "'") {
    i += 1;
    while (i < source.length) {
      const ch = source[i]!;
      if (ch === "\\") {
        i += 2;
        continue;
      }

      i += 1;
      if (ch === opening) {
        break;
      }
    }

    return {
      value: source.slice(start, i),
      end: i,
    };
  }

  if (opening === "{" || opening === "[" || opening === "(") {
    const pairs: Record<string, string> = {
      "{": "}",
      "[": "]",
      "(": ")",
    };

    const stack: string[] = [pairs[opening]!];
    i += 1;
    let inQuote: '"' | "'" | null = null;

    while (i < source.length) {
      const ch = source[i]!;

      if (inQuote) {
        if (ch === "\\") {
          i += 2;
          continue;
        }

        i += 1;
        if (ch === inQuote) {
          inQuote = null;
        }
        continue;
      }

      if (ch === '"' || ch === "'") {
        inQuote = ch;
        i += 1;
        continue;
      }

      if (ch === "{" || ch === "[" || ch === "(") {
        stack.push(pairs[ch]!);
        i += 1;
        continue;
      }

      const expected = stack.at(-1);
      if (expected && ch === expected) {
        stack.pop();
        i += 1;
        if (stack.length === 0) {
          break;
        }
        continue;
      }

      i += 1;
    }

    return {
      value: source.slice(start, i),
      end: i,
    };
  }

  while (i < source.length && !/\s/.test(source[i]!)) {
    i += 1;
  }

  return {
    value: source.slice(start, i),
    end: i,
  };
}

async function collectLuaFiles(root: string): Promise<string[]> {
  const out: string[] = [];

  async function walk(current: string): Promise<void> {
    const entries = await fs.readdir(current, { withFileTypes: true });
    entries.sort((a, b) => a.name.localeCompare(b.name));

    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }

      if (entry.isFile() && fullPath.endsWith(".lua")) {
        out.push(fullPath);
      }
    }
  }

  await walk(root);
  return out;
}

async function readFileIfExists(filePath: string): Promise<string | undefined> {
  try {
    return await fs.readFile(filePath, "utf8");
  } catch (error) {
    if (
      typeof error === "object"
      && error !== null
      && "code" in error
      && error.code === "ENOENT"
    ) {
      return undefined;
    }

    throw error;
  }
}

function normalizeWhitespace(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function normalizePath(value: string): string {
  return value.replace(/\\/g, "/");
}

void main();
