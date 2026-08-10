// Round-trip check: does the curated MD transformer list in src/RichTextEditor.tsx produce
// markdown that src/richtext.tsx can parse back to the same thing?
//
// This is the one failure mode that would silently corrupt data — the editor writing a dialect
// the display renderer does not read (or vice versa). Runs Lexical headlessly, no browser.
//
//   node md-roundtrip.test.mjs

import { createHeadlessEditor } from "@lexical/headless";
import { ListNode, ListItemNode } from "@lexical/list";
import {
    $convertFromMarkdownString,
    $convertToMarkdownString,
    BOLD_ITALIC_STAR, BOLD_STAR, ITALIC_STAR, STRIKETHROUGH, INLINE_CODE,
    UNORDERED_LIST, ORDERED_LIST,
} from "@lexical/markdown";

// Must stay identical to MD in src/RichTextEditor.tsx.
const MD = [UNORDERED_LIST, ORDERED_LIST, BOLD_ITALIC_STAR, BOLD_STAR, ITALIC_STAR, STRIKETHROUGH, INLINE_CODE];

const editor = createHeadlessEditor({
    namespace: "obc",
    nodes: [ListNode, ListItemNode],
    onError: (e) => { throw e; },
});

// Must stay identical to readMarkdown() / the editorState seed in src/RichTextEditor.tsx.
const UNESCAPE = /\\([*_`~\\])/g;

function roundTrip(md) {
    let out = "";
    editor.update(() => { $convertFromMarkdownString(md, MD, undefined, true); }, { discrete: true });
    editor.getEditorState().read(() => { out = $convertToMarkdownString(MD, undefined, true).replace(UNESCAPE, "$1"); });
    return out;
}

let fails = 0;
const eq = (label, got, want) => {
    const ok = got === want;
    if (!ok) fails++;
    console.log(`${ok ? "PASS" : "FAIL"}  ${label}`);
    if (!ok) { console.log("      got : " + JSON.stringify(got)); console.log("      want: " + JSON.stringify(want)); }
};

console.log("──── markdown round-trip through Lexical ────");
eq("bold", roundTrip("**urgent** chase Ivan"), "**urgent** chase Ivan");
eq("italic stays star (not underscore)", roundTrip("*italic* here"), "*italic* here");
eq("strikethrough", roundTrip("~~dropped~~ now"), "~~dropped~~ now");
eq("inline code", roundTrip("check `order_line_id` please"), "check `order_line_id` please");
eq("bold + italic", roundTrip("**bold** and *italic*"), "**bold** and *italic*");
eq("bullets", roundTrip("- first\n- second"), "- first\n- second");
eq("numbered", roundTrip("1. alpha\n2. beta"), "1. alpha\n2. beta");
eq("bullet with bold", roundTrip("- **chase** Ivan"), "- **chase** Ivan");
eq("multi-line", roundTrip("line one\nline two"), "line one\nline two");
eq("paragraph then list", roundTrip("Actions:\n- chase Ivan"), "Actions:\n- chase Ivan");

console.log("\n──── JDE identifiers must survive verbatim ────");
for (const s of [
    "order_line_id maps to Order Line ID",
    "IM_HoursLogged feeds TRIR",
    "person_key and reason_dim",
    "RFRV_code_name stays literal",
]) eq(JSON.stringify(s), roundTrip(s), s);

console.log("\n──── plain text is untouched ────");
eq("arithmetic", roundTrip("2 * 3 * 4 = 24"), "2 * 3 * 4 = 24");
eq("percent", roundTrip("OTIF at 96% this month"), "OTIF at 96% this month");
eq("url", roundTrip("see https://x.workers.dev/reason-dim"), "see https://x.workers.dev/reason-dim");
eq("angle brackets are inert", roundTrip("<script>alert(1)</script>"), "<script>alert(1)</script>");

console.log(fails ? `\n${fails} FAILING` : "\nall green");
process.exit(fails ? 1 : 0);
