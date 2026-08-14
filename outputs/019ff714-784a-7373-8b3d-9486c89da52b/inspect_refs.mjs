import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const paths = [
  "C:/Users/Zack/Documents/Code/Michelman/Cognos Reports/Excel Validation/_report_out/14 - 1 - Ivan Global Inventory Excel - Select Date.xlsx",
];

for (const path of paths) {
  const input = await FileBlob.load(path);
  const workbook = await SpreadsheetFile.importXlsx(input);
  const summary = await workbook.inspect({
    kind: "workbook,sheet,table",
    maxChars: 6000,
    tableMaxRows: 12,
    tableMaxCols: 12,
    options: { maxResults: 80 },
  });
  console.log(`\n### ${path}\n${summary.ndjson}`);
}
