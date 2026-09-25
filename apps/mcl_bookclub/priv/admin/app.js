// mcl-bookclub admin UI: the task cards, the lookup panel, and the call
// log. No framework, no build step -- every task is one POST to the JSON
// API, every lookup one GET.
"use strict";

// [method, route, [fields], label]
const TASKS = [
  ["POST", "/api/clubs/initiate",
   [["club_id", "Club id (minted when empty)"],
    ["name", "Name"],
    ["initiated_by", "Initiated by", "raf"]],
   "Initiate a club"],
  ["POST", "/api/clubs/plan_party",
   [["club_id", "Club id"]],
   "Plan a party"],
  ["POST", "/api/clubs/archive",
   [["club_id", "Club id"],
    ["archived_by", "Archived by", "raf"]],
   "Archive a club"],
  ["POST", "/api/members/register",
   [["club_id", "Club id"],
    ["member_id", "Member id (minted when empty)"],
    ["name", "Name"]],
   "Register a member"],
  ["POST", "/api/members/unregister",
   [["member_id", "Member id"],
    ["unregistered_by", "Unregistered by", "raf"]],
   "Unregister a member"],
  ["POST", "/api/books/procure",
   [["club_id", "Club id"],
    ["book_id", "Book id (minted when empty)"],
    ["title", "Title"],
    ["author", "Author"]],
   "Procure a book"],
  ["POST", "/api/books/retire",
   [["book_id", "Book id"],
    ["retired_by", "Retired by", "raf"]],
   "Retire a book"],
  ["POST", "/api/readings/start",
   [["member_id", "Member id"],
    ["book_id", "Book id"],
    ["reading_id", "Reading id (minted when empty)"]],
   "Start a reading"],
  ["POST", "/api/readings/finish",
   [["reading_id", "Reading id"],
    ["pages_read", "Pages read"]],
   "Finish a reading"],
];

const LOOKUPS = [
  ["Club", "/api/clubs/"],
  ["Member", "/api/members/"],
  ["Book", "/api/books/"],
  ["Reading", "/api/readings/"],
  ["Member's readings", "/api/members/__ID__/readings"],
];

function el(tag, attrs, ...children) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) n[k] = v;
  for (const c of children) n.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
  return n;
}

function makeTask([method, route, fields, title]) {
  const inputs = fields.map(([name, hint, def]) => {
    const input = el("input", { name, placeholder: hint });
    if (def !== undefined) input.value = def;
    return el("label", {}, hint, input);
  });
  const button = el("button", {}, "Run");
  button.onclick = async () => {
    const body = {};
    for (const [name] of fields) {
      const v = inputs.find(i => i.lastChild.name === name).lastChild.value.trim();
      if (v !== "") body[name] = v;
    }
    const r = await api(method, route, body);
    log(`${title}\n  ${method} ${route} ${JSON.stringify(body)}\n  ${r.text}`);
    if (r.ok && r.json.events && r.json.events[0]) {
      const ids = Object.entries(r.json.events[0])
        .filter(([k, v]) => k.endsWith("_id") && typeof v === "string")
        .map(([k, v]) => `${k}=${v}`);
      if (ids.length) log(`  -> ${ids.join(", ")}`);
    }
  };
  return el("section", { className: "task" },
    el("h2", {}, title),
    ...inputs, button);
}

function makeLookups() {
  const row = el("div", { className: "lookup-row" });
  for (const [label, prefix] of LOOKUPS) {
    const input = el("input", { placeholder: `${label} id` });
    const button = el("button", {}, `Get ${label}`);
    button.onclick = async () => {
      const id = input.value.trim();
      const r = await api("GET", prefix.replace("__ID__", id) + id);
      log(`${label} ${id}\n  ${r.text}`);
    };
    row.appendChild(input);
    row.appendChild(button);
  }
  return el("section", { className: "task lookup" },
    el("h2", {}, "Look up by id"), row,
    el("p", { className: "hint" },
      "Ids are minted by the tasks above; the task log echoes them back."));
}

async function api(method, route, body) {
  const opts = { method };
  if (method === "POST") {
    opts.headers = { "Content-Type": "application/json" };
    opts.body = JSON.stringify(body || {});
  }
  let text, ok, json;
  try {
    const res = await fetch(route, opts);
    text = await res.text();
    ok = res.ok;
    try { json = JSON.parse(text); } catch (_) { json = null; }
  } catch (e) {
    text = String(e); ok = false; json = null;
  }
  return { text, ok, json };
}

function log(line) {
  const pre = document.getElementById("log");
  if (pre.textContent === "—") pre.textContent = "";
  pre.textContent = `> ${new Date().toLocaleTimeString()} — ${line}\n\n` + pre.textContent;
}

document.getElementById("tasks").appendChild(makeLookups());
for (const t of TASKS) document.getElementById("tasks").appendChild(makeTask(t));
