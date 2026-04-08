#!/usr/bin/env bun

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

type Column = {
  name: string;
  type: string;
  isPrimaryKey: boolean;
};

type Table = {
  name: string;
  columns: Column[];
  uniqueColumns: Set<string>;
};

type Relation = {
  parent: string;
  child: string;
  column: string;
};

const root = join(import.meta.dir, "..");
const schemaPath = join(root, "server", "src", "schema.rs");
const outputs = [
  join(root, "design", "assets", "generated-schema-relations.mmd"),
  join(root, "doc", "assets", "generated-schema-relations.mmd"),
];

const documentedTables = new Set([
  "groups",
  "group_authorities",
  "users",
  "sessions",
  "activities",
  "records",
  "channels",
  "channel_members",
  "messages",
  "export_batches",
  "export_items",
  "activity_comments",
]);

const relationTargets = new Map<string, string>([
  ["group_id", "groups"],
  ["user_id", "users"],
  ["activity_id", "activities"],
  ["channel_id", "channels"],
  ["batch_id", "export_batches"],
  ["creator_id", "users"],
  ["owner_id", "users"],
  ["author_id", "users"],
  ["sender_id", "users"],
  ["promoter_id", "users"],
  ["confirmed_by", "users"],
]);

const schema = readFileSync(schemaPath, "utf8");

const uniqueColumns = new Map<string, Set<string>>();
for (const match of schema.matchAll(/CREATE UNIQUE INDEX IF NOT EXISTS \w+ ON (\w+)\((\w+)\)/g)) {
  const [, table, column] = match;
  const tableColumns = uniqueColumns.get(table) ?? new Set<string>();
  tableColumns.add(column);
  uniqueColumns.set(table, tableColumns);
}

const tables: Table[] = [];
for (const match of schema.matchAll(/CREATE TABLE IF NOT EXISTS (\w+) \(([\s\S]*?)\n\s*\)\s*"#/g)) {
  const [, tableName, body] = match;
  if (!documentedTables.has(tableName)) {
    continue;
  }

  const compositePrimaryKeys = new Set<string>();
  const columns: Column[] = [];

  for (const rawLine of body.split("\n")) {
    const line = rawLine.trim().replace(/,$/, "");
    if (line.length === 0) {
      continue;
    }
    const compositePrimary = line.match(/^PRIMARY KEY \((.+)\)$/);
    if (compositePrimary) {
      for (const column of compositePrimary[1].split(",").map((part) => part.trim())) {
        compositePrimaryKeys.add(column);
      }
      continue;
    }
    if (line.startsWith("FOREIGN KEY")) {
      continue;
    }

    const parts = line.split(/\s+/);
    const [name, type] = parts;
    if (!name || !type) {
      throw new Error(`Cannot parse schema line: ${line}`);
    }
    columns.push({
      name,
      type,
      isPrimaryKey: line.includes("PRIMARY KEY"),
    });
  }

  for (const column of columns) {
    if (compositePrimaryKeys.has(column.name)) {
      column.isPrimaryKey = true;
    }
  }

  tables.push({
    name: tableName,
    columns,
    uniqueColumns: uniqueColumns.get(tableName) ?? new Set<string>(),
  });
}

if (tables.length === 0) {
  throw new Error("No documented tables were parsed from server/src/schema.rs");
}

const tableNames = new Set(tables.map((table) => table.name));
const relations: Relation[] = [];
for (const table of tables) {
  for (const column of table.columns) {
    const parent = relationTargets.get(column.name);
    if (!parent) {
      continue;
    }
    if (!tableNames.has(parent)) {
      continue;
    }
    relations.push({
      parent,
      child: table.name,
      column: column.name,
    });
  }
}

const parentsByChild = new Map<string, string[]>();
for (const relation of relations) {
  const current = parentsByChild.get(relation.child) ?? [];
  current.push(relation.parent);
  parentsByChild.set(relation.child, current);
}

const levelMemo = new Map<string, number>();
function levelOf(tableName: string): number {
  const existing = levelMemo.get(tableName);
  if (existing !== undefined) {
    return existing;
  }
  const parents = parentsByChild.get(tableName) ?? [];
  const level = parents.length === 0 ? 0 : Math.max(...parents.map((parent) => levelOf(parent) + 1));
  levelMemo.set(tableName, level);
  return level;
}

const tablesByLevel = new Map<number, Table[]>();
for (const table of tables) {
  const level = levelOf(table.name);
  const grouped = tablesByLevel.get(level) ?? [];
  grouped.push(table);
  tablesByLevel.set(level, grouped);
}

function nodeId(tableName: string): string {
  return tableName.toUpperCase();
}

function escapeLabel(line: string): string {
  return line.replaceAll('"', '\\"');
}

function displayLines(table: Table): string[] {
  const importantColumns = table.columns.filter((column) => {
    return (
      column.isPrimaryKey ||
      table.uniqueColumns.has(column.name) ||
      relationTargets.has(column.name)
    );
  });
  const lines = [table.name.toUpperCase()];
  for (const column of importantColumns) {
    const tags: string[] = [];
    if (column.isPrimaryKey) {
      tags.push("PK");
    }
    if (table.uniqueColumns.has(column.name)) {
      tags.push("UK");
    }
    if (relationTargets.has(column.name)) {
      tags.push("FK");
    }
    const prefix = tags.length === 0 ? "" : `${tags.join("/")} `;
    lines.push(`${prefix}${column.name}`);
  }
  return lines;
}

const lines: string[] = [];
lines.push("%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '18px', 'primaryColor': '#ffffff', 'primaryBorderColor': '#183153', 'primaryTextColor': '#183153', 'lineColor': '#5f6b7a'}, 'flowchart': {'nodeSpacing': 50, 'rankSpacing': 90, 'curve': 'basis'}}}%%");
lines.push("flowchart TB");
lines.push("  classDef table fill:#ffffff,stroke:#183153,stroke-width:1.4px,color:#183153;");
lines.push("  classDef layer fill:none,stroke:none;");

for (const level of [...tablesByLevel.keys()].sort((a, b) => a - b)) {
  lines.push(`  subgraph LEVEL_${level}[" "]`);
  lines.push("    direction LR");
  for (const table of tablesByLevel.get(level) ?? []) {
    const label = displayLines(table).map(escapeLabel).join("<br/>");
    lines.push(`    ${nodeId(table.name)}["${label}"]:::table`);
  }
  lines.push("  end");
  lines.push(`  class LEVEL_${level} layer`);
  lines.push(`  style LEVEL_${level} fill:none,stroke:none`);
}

for (const relation of relations) {
  lines.push(`  ${nodeId(relation.parent)} -->|${relation.column}| ${nodeId(relation.child)}`);
}

const output = `${lines.join("\n")}\n`;

for (const path of outputs) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, output);
}
