# Validation — the production probe host

This semantic model exists to hold gateway bindings, nothing else. Three anchor tables return one
row each and are the model's entire permanent contents:

| Anchor table | Binding |
|---|---|
| `Anchor SSAS` | `SSASPROD` / `BIQLTabular` |
| `Anchor ISH` | `SSASPROD` / `BIQLTabular_ISH` |
| `Anchor EDW` | `EDWPROD` / `EDW` |
| `Anchor ODS` | `ODSPROD` / `ODS` |

Probes are temporary tables added beside the anchors, refreshed alone, read, and deleted. Because
no deliverable lives here, a probe refresh cannot disturb a report.

**Never delete an anchor.** Each one is the model's only reference to its data source; remove it
and the binding goes with it.

Published to the `Zack (Validation)` workspace. The publish-and-bind recipe, the probe cycle, and
the rules that keep it safe are in the repo's `CLAUDE.md`.
