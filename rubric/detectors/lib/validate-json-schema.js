#!/usr/bin/env node
// Minimal JSON Schema validator for Claude TDD Pro contracts.
//
// Purpose: validate plugin-internal data files (rubric rules, source-folder
// files, profile snapshots, lock files) against their JSON Schemas without
// adding npm dependencies.
//
// Supported subset of JSON Schema draft 2020-12:
//   - type (object, string, integer, number, boolean, array, null)
//   - enum
//   - pattern, minLength
//   - minimum
//   - minItems, items (single schema or array tuple)
//   - properties, required, additionalProperties (false | object schema)
//   - oneOf
//
// Usage:
//   node validate-json-schema.js <schema-path>          # reads JSON from stdin
//   node validate-json-schema.js <schema-path> <json>   # reads JSON from file
//
// Exit codes per detector contract (§2.2):
//   0 = valid (no errors)
//   2 = invalid (errors printed to stderr, one per line)

'use strict';

const fs = require('fs');

const schemaPath = process.argv[2];
const jsonPath = process.argv[3];

if (!schemaPath) {
  console.error('usage: validate-json-schema.js <schema-path> [<json-path>]');
  process.exit(1);
}

let schema;
try {
  schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
} catch (e) {
  console.error(`schema load error: ${e.message}`);
  process.exit(1);
}

let instanceText;
try {
  instanceText = jsonPath
    ? fs.readFileSync(jsonPath, 'utf8')
    : fs.readFileSync(0, 'utf8');
} catch (e) {
  console.error(`instance load error: ${e.message}`);
  process.exit(1);
}

let instance;
try {
  instance = JSON.parse(instanceText);
} catch (e) {
  console.error(`instance JSON parse error: ${e.message}`);
  process.exit(1);
}

const errors = [];

function validateInto(inst, sch, path, errs) {
  // oneOf composition
  if (Array.isArray(sch.oneOf)) {
    let matched = false;
    for (const sub of sch.oneOf) {
      const tempErrs = [];
      validateInto(inst, sub, path, tempErrs);
      if (tempErrs.length === 0) {
        matched = true;
        break;
      }
    }
    if (!matched) {
      errs.push(`${path || '<root>'}: value did not match any oneOf alternative`);
    }
    return;
  }

  // type check
  if (sch.type) {
    const types = Array.isArray(sch.type) ? sch.type : [sch.type];
    let actual;
    if (inst === null) actual = 'null';
    else if (Array.isArray(inst)) actual = 'array';
    else if (typeof inst === 'number') actual = Number.isInteger(inst) ? 'integer' : 'number';
    else actual = typeof inst;
    // integer also satisfies number
    const matchesType = types.some(t =>
      t === actual || (t === 'number' && actual === 'integer')
    );
    if (!matchesType) {
      errs.push(`${path || '<root>'}: expected type ${types.join('|')}, got ${actual}`);
      return;
    }
  }

  // enum
  if (Array.isArray(sch.enum)) {
    if (!sch.enum.includes(inst)) {
      errs.push(`${path || '<root>'}: value ${JSON.stringify(inst)} not in enum [${sch.enum.map(JSON.stringify).join(', ')}]`);
    }
  }

  // string constraints
  if (typeof inst === 'string') {
    if (typeof sch.minLength === 'number' && inst.length < sch.minLength) {
      errs.push(`${path || '<root>'}: minLength ${sch.minLength}, got ${inst.length}`);
    }
    if (typeof sch.pattern === 'string') {
      let re;
      try { re = new RegExp(sch.pattern); }
      catch (e) {
        errs.push(`${path || '<root>'}: schema has invalid pattern: ${e.message}`);
        return;
      }
      if (!re.test(inst)) {
        errs.push(`${path || '<root>'}: value ${JSON.stringify(inst)} does not match pattern /${sch.pattern}/`);
      }
    }
  }

  // number constraints
  if (typeof inst === 'number') {
    if (typeof sch.minimum === 'number' && inst < sch.minimum) {
      errs.push(`${path || '<root>'}: minimum ${sch.minimum}, got ${inst}`);
    }
  }

  // array constraints
  if (Array.isArray(inst)) {
    if (typeof sch.minItems === 'number' && inst.length < sch.minItems) {
      errs.push(`${path || '<root>'}: minItems ${sch.minItems}, got ${inst.length}`);
    }
    if (sch.items !== undefined) {
      const itemsIsArray = Array.isArray(sch.items);
      inst.forEach((item, idx) => {
        const itemSch = itemsIsArray
          ? (sch.items[idx] !== undefined ? sch.items[idx] : sch.items[sch.items.length - 1])
          : sch.items;
        validateInto(item, itemSch, `${path}[${idx}]`, errs);
      });
    }
  }

  // object constraints
  if (typeof inst === 'object' && inst !== null && !Array.isArray(inst)) {
    if (Array.isArray(sch.required)) {
      for (const req of sch.required) {
        if (!(req in inst)) {
          errs.push(`${path || '<root>'}: missing required field "${req}"`);
        }
      }
    }
    if (sch.properties && typeof sch.properties === 'object') {
      for (const [key, subSch] of Object.entries(sch.properties)) {
        if (key in inst) {
          const childPath = path ? `${path}.${key}` : key;
          validateInto(inst[key], subSch, childPath, errs);
        }
      }
    }
    if (sch.additionalProperties === false) {
      const known = new Set(Object.keys(sch.properties || {}));
      for (const key of Object.keys(inst)) {
        if (!known.has(key)) {
          errs.push(`${path || '<root>'}: unexpected property "${key}" (additionalProperties is false)`);
        }
      }
    } else if (sch.additionalProperties && typeof sch.additionalProperties === 'object') {
      const known = new Set(Object.keys(sch.properties || {}));
      for (const [key, val] of Object.entries(inst)) {
        if (!known.has(key)) {
          const childPath = path ? `${path}.${key}` : key;
          validateInto(val, sch.additionalProperties, childPath, errs);
        }
      }
    }
  }
}

validateInto(instance, schema, '', errors);

if (errors.length > 0) {
  for (const err of errors) {
    process.stderr.write(err + '\n');
  }
  process.exit(2);
}
process.exit(0);
